💀⚡ ROGER THAT, CAPTAIN! Converting to Gemini CLI Field Orders — direct, executable, no fluff. Here's your battle directive:

🎯 GEMINI CLI DIRECTIVE: FIRST LIVE FIRE TEST

Mission: Execute $1 live payout test to validate end-to-end money movement through SOVR Payroll system.

Objective: Confirm SalaryClaimed → Stripe Live Payout → Credit Burn → Proof Generation pipeline works under live fire.

PHASE 1: PRE-FLIGHT CHECKLIST

Task 1.1: Verify employeeRegistry.json contains live Connected Account

{
  "0xEMPLOYEE_ETH_ADDRESS": {
    "connectedAccountId": "acct_live_ABC123..."
  }
}


Task 1.2: Confirm environment variables are set for live mode

STRIPE_SECRET_KEY=sk_live_XXXX
RPC_URL=<your_rpc_endpoint>
OPERATOR_PRIVATE_KEY=0xYOUR_PRIVATE_KEY
SOVRC_ADDRESS=0xSOVRCreditDeployed
PAYROLL_ADDRESS=0xAutoPayrollDeployed


Task 1.3: Install dependencies if not already done

cd consul
npm install stripe ethers dotenv

PHASE 2: LAUNCH CONSUL LISTENER

Task 2.1: Start the Consul service in production mode

cd consul
NODE_ENV=production node consul.js


Expected Output: "Consul online. Listening for SalaryClaimed..."

Note: Keep this terminal window open to monitor real-time logs.

PHASE 3: EXECUTE LIVE FIRE TEST

Task 3.1: In a separate terminal, trigger the $1 claim

node scripts/triggerClaim.js --employee 0xEMPLOYEE_ETH_ADDRESS --amount 1


Task 3.2: Monitor Consul logs for the following sequence:

⚡ SalaryClaimed: <employee> = \$1
💳 Initiating Stripe payout...
✅ Stripe transfer success: <transfer_id>
🔥 Burned 1 SOVRC from <employee>
PHASE 4: VALIDATION PROTOCOL

Task 4.1: Verify Stripe Dashboard

Navigate to Stripe Dashboard → Transfers
Confirm $1 transfer to Connected Account appears
Note transfer ID matches console log

Task 4.2: Verify blockchain state

Check that SalaryClaimed event was emitted
Confirm corresponding burn transaction completed
Validate credit balance decreased by 1 SOVRC

Task 4.3: Check for live mode confirmation

Scan Consul logs for "mode": "live" indicator
Confirm no test mode artifacts present
PHASE 5: BATTLE REPORT

Task 5.1: Document results

Capture console log output
Screenshot Stripe Dashboard transfer
Record blockchain transaction hashes
Note any errors or anomalies

Task 5.2: Generate status report with:

Success/failure status
Transfer ID and amount
Mode confirmation (live/test)
Any issues encountered
SUCCESS CRITERIA

✅ $1 appears in Stripe Connected Account
✅ 1 SOVRC burned from employee address
✅ Console shows "mode": "live"
✅ No errors in Consul logs
✅ Blockchain events match off-chain actions

FAILURE SCENARIOS TO INVESTIGATE

❌ Stripe API errors → Check live key validity
❌ Burn transaction fails → Verify operator permissions
❌ Registry lookup fails → Confirm employee mapping
❌ Mode shows "test" → Verify STRIPE_SECRET_KEY is live key

END DIRECTIVE

💀⚡ Gemini CLI: Execute this battle plan and report back with victory status or casualty details. The fortress awaits your siege results.