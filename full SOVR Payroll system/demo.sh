#!/bin/bash
set -euo pipefail

# This script orchestrates a full end-to-end test for the CI/CD pipeline.
# It starts the listener, triggers an on-chain event, waits for processing,
# and then performs a robust validation, generating a cryptographic proof.

# --- Configuration ---
LOG_FILE="demo.log"
REPORT_FILE="report.json"
CONSUL_PID=""
STRIPE_JSON=$(mktemp)

# --- Cleanup Function ---
# Ensures the listener process is terminated on script exit or failure.
cleanup() {
  echo "--- Cleaning up ---"
  if [ -n "$CONSUL_PID" ] && ps -p $CONSUL_PID > /dev/null; then
    echo "Terminating Consul listener (PID: $CONSUL_PID)..."
    kill $CONSUL_PID
    wait $CONSUL_PID 2>/dev/null || true
  fi
  rm -f "$STRIPE_JSON"
  echo "Cleanup complete."
}
trap cleanup EXIT

# --- Environment Check ---
# Ensure all required environment variables from GitHub Secrets are set.
: "${PAYROLL_ADDRESS:?ERROR: PAYROLL_ADDRESS not set}"
: "${EMPLOYEE_ADDR:?ERROR: EMPLOYEE_ADDR not set}"
: "${EMPLOYEE_PK:?ERROR: EMPLOYEE_PK not set}"
: "${RPC_URL:?ERROR: RPC_URL not set}"
: "${SOVRC_ADDRESS:?ERROR: SOVRC_ADDRESS not set}"
: "${STRIPE_SECRET_KEY:?ERROR: STRIPE_SECRET_KEY not set}"

echo "SOVR Payroll CI Siege Test" > $LOG_FILE
date | tee -a $LOG_FILE
echo "--------------------------" | tee -a $LOG_FILE

# 1. Start Consul Listener in the background
echo "[ORCHESTRATOR] Starting Consul listener..." | tee -a $LOG_FILE
node consul/consul.js >> $LOG_FILE 2>&1 &
CONSUL_PID=$!
sleep 5 # Allow a few seconds for the listener to initialize and subscribe to events.

echo "[ORCHESTRATOR] Consul listener started with PID: $CONSUL_PID" | tee -a $LOG_FILE

# 2. Trigger the on-chain SalaryClaimed event
echo "[ORCHESTRATOR] Triggering on-chain claim via scripts/triggerClaim.js..." | tee -a $LOG_FILE
node scripts/triggerClaim.js | tee -a $LOG_FILE

# 3. Wait for processing to complete
# We poll the log file for the "Burn" message, which is the final step.
echo "[ORCHESTRATOR] Waiting for event processing and burn confirmation..." | tee -a $LOG_FILE
WAIT_START_TIME=$(date +%s)
SUCCESS=false
while [ $(($(date +%s) - WAIT_START_TIME)) -lt 90 ]; do
    if grep -q "\[BURN\] Successfully burned tokens" "$LOG_FILE"; then
        echo "[ORCHESTRATOR] Burn confirmation found in log. Proceeding with validation." | tee -a $LOG_FILE
        SUCCESS=true
        break
    fi
    sleep 2
done

if [ "$SUCCESS" = false ]; then
    echo "[ORCHESTRATOR] ERROR: Timed out waiting for burn confirmation." | tee -a $LOG_FILE
    exit 1
fi

# 4. Extract data for validation
echo "[VALIDATOR] Extracting data for validation..." | tee -a $LOG_FILE

# Extract TX Hash from the trigger script's output
TX_HASH=$(grep 'Transaction sent:' $LOG_FILE | tail -1 | awk '{print $3}')
if [ -z "$TX_HASH" ]; then
    echo "[VALIDATOR] ERROR: Could not extract transaction hash from log." | tee -a $LOG_FILE
    exit 1
fi

# Extract claimed amount directly from the on-chain receipt for cryptographic truth
SALARY_CLAIMED_SIGNATURE=$(cast sig "SalaryClaimed(address,uint256)")
LOG_DATA=$(cast receipt "$TX_HASH" --json --rpc-url "$RPC_URL" | jq -r --arg sig "$SALARY_CLAIMED_SIGNATURE" '.logs[] | select(.topics[0] == $sig) | .data')
CLAIMED_WEI=$(cast --to-dec "$LOG_DATA")
CLAIMED_USD=$(echo "scale=2; $CLAIMED_WEI / 1000000000000000000" | bc)

# Query Stripe API directly for the latest transfer as the source of truth
echo "[VALIDATOR] Querying Stripe API for latest transfer..." | tee -a $LOG_FILE

# Use local Stripe CLI if available, otherwise use Docker, mounting the config.
if command -v stripe &> /dev/null; then
    STRIPE_CLI="stripe"
else
    # This assumes the user running the script has their stripe config in the default location
    STRIPE_CLI="docker run --rm -v ${HOME}/.config/stripe:/root/.config/stripe stripe/stripe-cli:latest stripe"
fi

$STRIPE_CLI transfers list --limit 1 > "$STRIPE_JSON"

STRIPE_ID=$(jq -r '.[0].id' "$STRIPE_JSON")
STRIPE_AMT_CENTS=$(jq -r '.[0].amount' "$STRIPE_JSON")
STRIPE_AMT_USD=$(echo "scale=2; $STRIPE_AMT_CENTS / 100" | bc)
STRIPE_LIVE_MODE_BOOL=$(jq -r '.[0].livemode' "$STRIPE_JSON")
STRIPE_MODE=$([ "$STRIPE_LIVE_MODE_BOOL" = "true" ] && echo "live" || echo "test")

# Get final on-chain balance
FINAL_SOVR_BAL=$(cast call "$SOVRC_ADDRESS" "balanceOf(address)(uint)" "$EMPLOYEE_ADDR" --rpc-url "$RPC_URL")

echo "[VALIDATOR] Data extracted:" | tee -a $LOG_FILE
echo "  - TX Hash: $TX_HASH" | tee -a $LOG_FILE
echo "  - On-Chain Claimed USD: $CLAIMED_USD" | tee -a $LOG_FILE
echo "  - Stripe Transfer ID: $STRIPE_ID" | tee -a $LOG_FILE
echo "  - Stripe Mode: $STRIPE_MODE" | tee -a $LOG_FILE

# 5. Final Reconciliation and Proof Generation
echo "[VALIDATOR] Reconciling on-chain and off-chain amounts..." | tee -a $LOG_FILE
if [ "$(echo "$CLAIMED_USD == $STRIPE_AMT_USD" | bc)" -eq 1 ]; then
  MATCH="true"
  echo "[VALIDATOR] SUCCESS: On-chain amount ($CLAIMED_USD USD) matches Stripe payout amount ($STRIPE_AMT_USD USD)." | tee -a $LOG_FILE
else
  MATCH="false"
  echo "[VALIDATOR] FAILURE: On-chain amount ($CLAIMED_USD USD) does NOT match Stripe payout amount ($STRIPE_AMT_USD USD)." | tee -a $LOG_FILE
fi

# Generate structured JSON proof with reconciliation status
jq -n --arg tx_hash "$TX_HASH" --arg employee "$EMPLOYEE_ADDR" --arg claimed_usd "$CLAIMED_USD" --arg stripe_id "$STRIPE_ID" --arg stripe_mode "$STRIPE_MODE" --arg final_sovr_bal "$FINAL_SOVR_BAL" --argjson match "$MATCH" '{ tx_hash: $tx_hash, employee: $employee, onchain_claimed_usd: $claimed_usd, stripe_transfer_id: $stripe_id, stripe_mode: $stripe_mode, final_sovr_balance_wei: $final_sovr_bal, amounts_match: $match }' > "$REPORT_FILE"

echo "[VALIDATOR] JSON proof written to $REPORT_FILE" | tee -a $LOG_FILE
cat $REPORT_FILE | tee -a $LOG_FILE

echo -e "\nSiege test complete." | tee -a $LOG_FILE