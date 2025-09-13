require('dotenv').config();
const { ethers } = require('ethers');
const { processPayout } = require('./consul-processor');
const WebSocket = require('ws');

// ABIs for the new contract architecture
const payrollAbi = [
    "event SalaryClaimed(address indexed employee, uint256 amount, uint256 ts)",
    "function reconcile(address employee, uint256 amount) external"
];

const RPC_URL = process.env.RPC_URL;
// CRITICAL: Using DEPLOYER_PRIVATE_KEY because reconcile() is onlyOwner.
// This is a security trade-off of the new contract design.
const DEPLOYER_PK = process.env.DEPLOYER_PRIVATE_KEY;
const PAYROLL_ADDRESS = process.env.PAYROLL_ADDRESS;

if (!RPC_URL || !DEPLOYER_PK || !PAYROLL_ADDRESS) {
    console.error("ERROR: Missing RPC_URL, DEPLOYER_PRIVATE_KEY, or PAYROLL_ADDRESS from environment.");
    process.exit(1);
}

const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
const ownerWallet = new ethers.Wallet(DEPLOYER_PK, provider);

const payrollContract = new ethers.Contract(PAYROLL_ADDRESS, payrollAbi, ownerWallet);

// WebSocket client to broadcast events to the operator dashboard
const DASHBOARD_WS_URL = process.env.DASHBOARD_WS_URL || 'ws://localhost:4000';
const ws = new WebSocket(DASHBOARD_WS_URL);

ws.on('open', function open() {
  console.log('[WS_CLIENT] Connected to Operator Dashboard backend.');
});

ws.on('error', function error(err) {
  console.error('[WS_CLIENT] WebSocket error. Is the operator-dashboard server running?', err.message);
});

function broadcastToDashboard(event) {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(event));
  } else {
    // If the dashboard isn't connected, we just log it.
    // In a production system, this might go to a message queue.
    console.log('[WS_CLIENT] WebSocket not open. Could not send event:', event.type);
    }
}

async function main() {
    console.log("--- Consul Listener Initialized ---");
    console.log(`Listening for events on AutoPayroll contract: ${PAYROLL_ADDRESS}`);
    console.log(`Owner/Reconciler wallet address: ${ownerWallet.address}`);
    console.log("---------------------------------");

    // Kill switch guard clause
    if (process.env.CONSUL_MODE === "halt") {
        console.log("🛑 [HALT] Consul listener is in halted mode. No payouts will be processed.");
        return; // Do not attach listener
    }

    payrollContract.on("SalaryClaimed", async (employee, amount, ts, event) => {
        const amountFormatted = ethers.utils.formatUnits(amount, 18);
        const originalTxHash = event.log.transactionHash;

        console.log(`\n[EVENT] SalaryClaimed detected!`);
        console.log(`  - Employee: ${employee}`);
        console.log(`  - Amount: ${amountFormatted} SOVRC`);

        try {
            // 1. Process the fiat payout
            const payoutResult = await processPayout(employee, amount);

            if (payoutResult.success) {
                // Broadcast Stripe Payout success to the dashboard
                broadcastToDashboard({
                    id: originalTxHash, // Use original claim hash to group events
                    type: "StripePayout",
                    status: "success",
                    employee: employee,
                    amountUsd: parseFloat(amountFormatted),
                    stripeTransferId: payoutResult.transferId,
                    mode: payoutResult.mode,
                    timestamp: Date.now()
                });

                // 2. Reconcile the claim by calling the owner-only function
                console.log(`[RECONCILE] Attempting to reconcile ${amountFormatted} SOVRC for ${employee}...`);
                const reconcileTx = await payrollContract.reconcile(employee, amount);
                const reconcileReceipt = await reconcileTx.wait();
                console.log(`[RECONCILE] Successfully reconciled claim. Tx: ${reconcileReceipt.transactionHash}`);

                // Broadcast Reconcile success to the dashboard
                broadcastToDashboard({
                    id: originalTxHash, // Use original claim hash
                    type: "Reconcile",
                    status: "success",
                    employee: employee,
                    amountUsd: parseFloat(amountFormatted),
                    txHash: reconcileReceipt.transactionHash,
                    timestamp: Date.now()
                });
            } else {
                // Broadcast Stripe Payout failure to the dashboard
                broadcastToDashboard({
                    id: originalTxHash,
                    type: "StripePayout",
                    status: "fail",
                    employee: employee,
                    amountUsd: parseFloat(amountFormatted),
                    error: "Stripe processing failed. Check Consul logs.",
                    timestamp: Date.now()
                });
                console.error("[PROCESSOR] Payout failed. Reconcile operation will not be executed.");
            }
        } catch (error) {
            console.error("[ERROR] An error occurred during event processing:", error);
        }
    });
}

main().catch(error => {
    console.error("Fatal error in listener:", error);
    process.exit(1);
});