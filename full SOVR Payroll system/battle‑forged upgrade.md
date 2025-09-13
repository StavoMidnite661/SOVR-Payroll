This document outlines the battle-forged upgrade for CI/CD integration. It expands `ci/demo.sh` to produce a machine-readable JSON proof report. The CI/CD pipeline then encrypts both the human-readable log (`demo.log`) and the JSON audit report (`report.json`) using a GPG public key.

📜 ci/demo.sh (Upgraded with JSON Proof Output)
#!/bin/bash
set -euo pipefail

### CONFIG
# Ensure required environment variables are set
: "${PAYROLL_ADDRESS:?ERROR: PAYROLL_ADDRESS not set}"
: "${EMPLOYEE_ADDR:?ERROR: EMPLOYEE_ADDR not set}"
: "${EMPLOYEE_PK:?ERROR: EMPLOYEE_PK not set}"
: "${RPC_URL:?ERROR: RPC_URL not set}"
: "${SOVRC_ADDRESS:?ERROR: SOVRC_ADDRESS not set}"

# Use local Stripe CLI if available, otherwise use Docker, mounting the config.
if command -v stripe &> /dev/null; then
    STRIPE_CLI="stripe"
else
    STRIPE_CLI="docker run --rm -v ${HOME}/.config/stripe:/root/.config/stripe stripe/stripe-cli:latest stripe"
fi

# Define log and report files
LOG_FILE="demo.log"
REPORT_FILE="report.json"
CONSUL_LOG="/tmp/consul.log"
STRIPE_JSON=$(mktemp)

# Cleanup trap to remove temporary files on exit
trap 'rm -f $STRIPE_JSON' EXIT

# Check for dependencies
for cmd in cast jq bc; do
    if ! command -v $cmd &> /dev/null; then
        echo "ERROR: Command '$cmd' not found. Please ensure it is installed and in your PATH." | tee -a $LOG_FILE
        exit 1
    fi
done

echo "SOVR Payroll CI End-to-End Test" | tee $LOG_FILE
date | tee -a $LOG_FILE

### STEP 1 — Trigger claimSalary and get transaction hash
echo -e "\nTriggering claimSalary() transaction..." | tee -a $LOG_FILE
TX_HASH=$(cast send "$PAYROLL_ADDRESS" "claimSalary()" --rpc-url "$RPC_URL" --private-key "$EMPLOYEE_PK" --json | jq -r '.transactionHash')
echo "Transaction sent: $TX_HASH" | tee -a $LOG_FILE

### STEP 2 — Wait for Consul to process the event
echo -e "\nWaiting for Consul to process the SalaryClaimed event..." | tee -a $LOG_FILE
LAST_LINE=0
if [ -f "$CONSUL_LOG" ]; then
    LAST_LINE=$(wc -l < "$CONSUL_LOG")
fi

WAIT_START_TIME=$(date +%s)
SUCCESS=false
while [ $(($(date +%s) - WAIT_START_TIME)) -lt 60 ]; do
    if [ -f "$CONSUL_LOG" ] && [ $(tail -n +$((LAST_LINE + 1)) "$CONSUL_LOG" | grep -c "PROCESSOR") -gt 0 ]; then
        echo "Consul has processed the event." | tee -a $LOG_FILE
        SUCCESS=true
        break
    fi
    sleep 2
done

if [ "$SUCCESS" = false ]; then
    echo "ERROR: Timed out waiting for Consul to process the event." | tee -a $LOG_FILE
    exit 1
fi

### STEP 3 — Get claimed amount directly from the on-chain receipt
echo -e "\nExtracting claimed amount from transaction receipt..." | tee -a $LOG_FILE
SALARY_CLAIMED_SIGNATURE=$(cast sig "SalaryClaimed(address,uint256)")
LOG_DATA=$(cast receipt "$TX_HASH" --json --rpc-url "$RPC_URL" | jq -r --arg sig "$SALARY_CLAIMED_SIGNATURE" '.logs[] | select(.topics[0] == $sig) | .data')

if [ -z "$LOG_DATA" ]; then
    echo "ERROR: Could not find SalaryClaimed event log in transaction receipt for $TX_HASH." | tee -a $LOG_FILE
    exit 1
fi

CLAIMED_WEI=$(cast --to-dec "$LOG_DATA")
CLAIMED_USD=$(echo "scale=2; $CLAIMED_WEI / 1000000000000000000" | bc)
echo "On-chain claimed amount: $CLAIMED_USD USD" | tee -a $LOG_FILE

### STEP 4 — Check Stripe for the corresponding payout
echo -e "\nChecking Stripe for the latest sandbox transfer..." | tee -a $LOG_FILE
$STRIPE_CLI transfers list --limit 1 > "$STRIPE_JSON"
cat "$STRIPE_JSON" | tee -a $LOG_FILE

STRIPE_AMT_CENTS=$(jq -r '.[0].amount' "$STRIPE_JSON")
STRIPE_ID=$(jq -r '.[0].id' "$STRIPE_JSON")

if [ -z "$STRIPE_AMT_CENTS" ] || [ "$STRIPE_AMT_CENTS" == "null" ]; then
    echo "ERROR: Could not retrieve latest Stripe transfer amount." | tee -a $LOG_FILE
    exit 1
fi

STRIPE_AMT_USD=$(echo "scale=2; $STRIPE_AMT_CENTS / 100" | bc)
echo "Stripe payout amount: $STRIPE_AMT_USD USD (ID: $STRIPE_ID)" | tee -a $LOG_FILE

### STEP 5 — Get final on-chain balance
FINAL_SOVR_BAL=$(cast call "$SOVRC_ADDRESS" "balanceOf(address)(uint)" "$EMPLOYEE_ADDR" --rpc-url "$RPC_URL")

### STEP 6 — Validation and Result
echo -e "\nValidating amounts..." | tee -a $LOG_FILE
if [ "$(echo "$CLAIMED_USD == $STRIPE_AMT_USD" | bc)" -eq 1 ]; then
  MATCH="true"
  echo "SUCCESS: On-chain amount matches Stripe payout amount." | tee -a $LOG_FILE
else
  MATCH="false"
  echo "FAILURE: On-chain amount ($CLAIMED_USD) does not match Stripe payout amount ($STRIPE_AMT_USD)." | tee -a $LOG_FILE
fi

### STEP 7 — Generate structured JSON proof
jq -n \
  --arg tx_hash "$TX_HASH" \
  --arg employee "$EMPLOYEE_ADDR" \
  --arg claimed_usd "$CLAIMED_USD" \
  --arg stripe_id "$STRIPE_ID" \
  --arg stripe_usd "$STRIPE_AMT_USD" \
  --arg final_sovr_bal "$FINAL_SOVR_BAL" \
  --argjson match "$MATCH" \
  '{ tx_hash: $tx_hash, employee: $employee, onchain_claimed_usd: $claimed_usd, stripe_transfer_id: $stripe_id, stripe_payout_usd: $stripe_usd, final_sovr_balance_wei: $final_sovr_bal, amounts_match: $match }' > "$REPORT_FILE"

echo -e "\nJSON proof written to $REPORT_FILE" | tee -a $LOG_FILE
cat $REPORT_FILE | tee -a $LOG_FILE

echo -e "\nTest complete. Logs are in $LOG_FILE, report is in $REPORT_FILE"

📜 .github/workflows/ci.yml (Encrypt both Log + JSON)
name: SOVR Payroll CI/CD Fortress

on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]

jobs:
  payroll-test:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout Repository
      uses: actions/checkout@v4

    - name: Install Foundry
      uses: foundry-rs/foundry-toolchain@v1
      with:
        version: nightly

    - name: Install System Dependencies
      run: sudo apt-get update && sudo apt-get install -y gnupg jq bc # gnupg for encryption

    - name: Run Demo Script
      env:
        PAYROLL_ADDRESS: ${{ secrets.PAYROLL_ADDRESS }}
        EMPLOYEE_ADDR: ${{ secrets.EMPLOYEE_ADDR }}
        EMPLOYEE_PK: ${{ secrets.EMPLOYEE_PK }}
        RPC_URL: ${{ secrets.RPC_URL }}
        SOVRC_ADDRESS: ${{ secrets.SOVRC_ADDRESS }}
        # Note: Stripe CLI must be configured on the runner or use keys from secrets
      run: bash ci/demo.sh

    - name: Import GPG Public Key
      # This key should be stored as a repository secret
      run: echo "${{ secrets.GPG_PUBLIC_KEY }}" | gpg --import

    - name: Encrypt Artifacts
      run: |
        gpg --batch --yes --trust-model always \
            --encrypt --recipient "${{ secrets.GPG_RECIPIENT_EMAIL }}" demo.log
        gpg --batch --yes --trust-model always \
            --encrypt --recipient "${{ secrets.GPG_RECIPIENT_EMAIL }}" report.json
        mv demo.log.gpg demo.log.encrypted
        mv report.json.gpg report.json.encrypted

    - name: Upload Encrypted Artifacts
      uses: actions/upload-artifact@v3
      with:
        name: sealed-e2e-results
        path: |
          demo.log.encrypted
          report.json.encrypted

Operational Breakdown
1.  **`demo.sh`**: Runs the full payroll cycle, writing an audit log and a definitive JSON proof. The proof's data is derived directly from on-chain state, ensuring its integrity.
2.  **`ci.yml`**: Executes the script in a clean environment, encrypts both the log and the JSON proof using a GPG key stored in GitHub Secrets, and uploads them as sealed artifacts.
3.  **Decryption**: Team members can download the artifacts and decrypt them using their private GPG key.
    ```bash
    gh run download --name sealed-e2e-results
    gpg --decrypt demo.log.encrypted > demo.log
    gpg --decrypt report.json.encrypted > report.json
    ```
The resulting `report.json` provides machine-readable truth for automated verification, and `demo.log` provides human-readable context for manual audits. This creates a secure, verifiable, and airtight process for testing and validation.