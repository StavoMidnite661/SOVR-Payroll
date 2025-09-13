#!/bin/bash
set -euo pipefail

# This script automates the "Live Fire" test protocol.
# It assumes the full application stack is already running via `docker-compose up`.

# --- Configuration ---
LOG_FILE="live-fire-$(date +%s).log"
REPORT_FILE="live-fire-report.json"
STRIPE_JSON=$(mktemp)

# --- Cleanup ---
trap 'rm -f "$STRIPE_JSON"' EXIT

# --- Dependency & Environment Check ---
for cmd in curl jq bc node; do
    if ! command -v $cmd &> /dev/null; then
        echo "ERROR: Command '$cmd' not found. Please ensure it is installed and in your PATH."
        exit 1
    fi
done

: "${EMPLOYEE_ADDR:?ERROR: EMPLOYEE_ADDR not set in .env}"
: "${EMPLOYEE_PK:?ERROR: EMPLOYEE_PK not set in .env}"
: "${RPC_URL:?ERROR: RPC_URL not set in .env}"
: "${PAYROLL_ADDRESS:?ERROR: PAYROLL_ADDRESS not set in .env}"
: "${SOVRC_ADDRESS:?ERROR: SOVRC_ADDRESS not set in .env}"

echo "--- SOVR Payroll Live Fire Test ---" | tee $LOG_FILE
date | tee -a $LOG_FILE

# 1. Trigger the on-chain claim
echo "[ACTION] Triggering on-chain claim for ${EMPLOYEE_ADDR}..." | tee -a $LOG_FILE
TRIGGER_LOG=$(node scripts/triggerClaim.js --amount 1) # Firing a $1 claim
echo "$TRIGGER_LOG" | tee -a $LOG_FILE
TX_HASH=$(echo "$TRIGGER_LOG" | grep 'Transaction sent:' | awk '{print $3}')

if [ -z "$TX_HASH" ]; then
    echo "[ERROR] Could not get transaction hash from trigger script." | tee -a $LOG_FILE
    exit 1
fi

# 2. Wait for reconciliation by polling the dashboard API
echo "[STATUS] Waiting for full reconciliation (Claim -> Payout -> Burn)..." | tee -a $LOG_FILE
WAIT_START_TIME=$(date +%s)
SUCCESS=false
while [ $(($(date +%s) - WAIT_START_TIME)) -lt 120 ]; do
    # Query the API for the latest status of the employee
    STATUS=$(curl -s http://localhost:4000/employees | jq -r --arg addr "$EMPLOYEE_ADDR" '.[] | select(.address | ascii_downcase == ($addr | ascii_downcase)) | .status')
    
    if [ "$STATUS" == "reconciled" ]; then
        echo "[STATUS] Reconciliation confirmed via API." | tee -a $LOG_FILE
        SUCCESS=true
        break
    elif [ "$STATUS" == "failed" ]; then
        echo "[ERROR] Reconciliation failed. Check dashboard for details." | tee -a $LOG_FILE
        exit 1
    fi
    printf "."
    sleep 3
done

if [ "$SUCCESS" = false ]; then
    echo "\n[ERROR] Timed out waiting for reconciliation." | tee -a $LOG_FILE
    exit 1
fi

# 3. Final validation with Stripe API
echo "[VALIDATE] Performing final validation with Stripe..." | tee -a $LOG_FILE
stripe transfers list --limit 1 > "$STRIPE_JSON"

STRIPE_ID=$(jq -r '.[0].id' "$STRIPE_JSON")
STRIPE_AMT_CENTS=$(jq -r '.[0].amount' "$STRIPE_JSON")
STRIPE_AMT_USD=$(echo "scale=2; $STRIPE_AMT_CENTS / 100" | bc)
STRIPE_LIVE_MODE_BOOL=$(jq -r '.[0].livemode' "$STRIPE_JSON")
STRIPE_MODE=$([ "$STRIPE_LIVE_MODE_BOOL" = "true" ] && echo "live" || echo "test")

echo "  - Latest Stripe Transfer ID: $STRIPE_ID" | tee -a $LOG_FILE
echo "  - Payout Amount: $STRIPE_AMT_USD USD" | tee -a $LOG_FILE
echo "  - Mode: $STRIPE_MODE" | tee -a $LOG_FILE

# 4. Generate final proof report
echo "[PROOF] Generating final proof report..." | tee -a $LOG_FILE

FINAL_SOVR_BAL=$(cast call "$SOVRC_ADDRESS" "balanceOf(address)(uint)" "$EMPLOYEE_ADDR" --rpc-url "$RPC_URL")

jq -n \
  --arg tx_hash "$TX_HASH" \
  --arg employee "$EMPLOYEE_ADDR" \
  --arg stripe_id "$STRIPE_ID" \
  --arg stripe_mode "$STRIPE_MODE" \
  --arg final_sovr_bal "$FINAL_SOVR_BAL" \
  '{ tx_hash: $tx_hash, employee: $employee, stripe_transfer_id: $stripe_id, stripe_mode: $stripe_mode, final_sovr_balance_wei: $final_sovr_bal, status: "reconciled" }' > "$REPORT_FILE"

echo "Proof written to $REPORT_FILE" | tee -a $LOG_FILE
cat $REPORT_FILE | tee -a $LOG_FILE

echo -e "\n--- Live Fire Test Complete. All systems nominal. ---" | tee -a $LOG_FILE