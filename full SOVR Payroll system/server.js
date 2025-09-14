// operator-dashboard/server.js
require("dotenv").config(); // Load .env from current directory
const express = require("express");
const fs = require("fs");
const path = require("path");
const { WebSocketServer } = require("ws");
const { ethers } = require("ethers");
const db = require("./db");

const app = express();

// Ledger Snapshot
app.get("/employees", async (req, res) => {
  try {
    const { rows } = await db.query(`
      SELECT DISTINCT ON (employee_address)
        employee_address as address,
        amount_usd as "lastPayout",
        status,
        stripe_mode as mode
      FROM events
      ORDER BY employee_address, created_at DESC;
    `);
    res.json(rows);
  } catch (err) {
    console.error("Error fetching employees from DB", err);
    res.status(500).json({ error: "Internal server error" });
  }
});

// Proof artifacts (link sealed CI/CD outputs)
app.get("/proofs", async (req, res) => {
  try {
    const { rows } = await db.query(`SELECT file_name as name, '/artifacts/' || file_name as url FROM proofs ORDER BY created_at DESC;`);
    res.json(rows);
  } catch (err) {
    console.error("Error fetching proofs from DB", err);
    res.status(500).json({ error: "Internal server error" });
  }
});

// Reconciliation Endpoint
app.get("/reconciliation", async (req, res) => {
  try {
    const { rows } = await db.query(`
        SELECT employee_address as address, status FROM events
        WHERE claim_tx_hash IN (
            SELECT claim_tx_hash FROM events
            GROUP BY claim_tx_hash
            HAVING MAX(CASE WHEN status = 'reconciled' THEN 1 ELSE 0 END) = 0
        )
        AND status != 'reconciled'
        ORDER BY created_at DESC;
    `);
    res.json(rows);
  } catch (err) {
    console.error("Error fetching reconciliation data from DB", err);
    res.status(500).json({ error: "Internal server error" });
  }
});

// Serve proof artifacts statically
const artifactsDir = path.join(__dirname, "artifacts");
if (!fs.existsSync(artifactsDir)) {
  fs.mkdirSync(artifactsDir);
}
app.use("/artifacts", express.static(artifactsDir));

async function syncProofs() {
  try {
    const files = fs.readdirSync(artifactsDir).filter(f => f.endsWith(".encrypted"));
    for (const file of files) {
      // Insert new proofs, ignore duplicates
      await db.query("INSERT INTO proofs (file_name) VALUES ($1) ON CONFLICT (file_name) DO NOTHING", [file]);
    }
    console.log(`[PROOFS] Synced ${files.length} proof artifacts with database.`);
  } catch (error) {
    console.error("[PROOFS] Could not sync proof artifacts:", error.message);
  }
}

const server = app.listen(3001, '0.0.0.0', async () => {
  console.log("Operator Backend running on 0.0.0.0:3001");
  await db.initializeDb();
  await syncProofs(); // Sync proofs on startup
});

// WebSocket bridge
const wss = new WebSocketServer({ server });

function broadcast(event) {
  const data = JSON.stringify(event);
  wss.clients.forEach(c => {
    if (c.readyState === c.OPEN) {
      c.send(data);
    }
  });
}

// Handle incoming messages from services like Consul and re-broadcast to UI clients
wss.on('connection', ws => {
  console.log('[WSS] Client connected.');
  ws.on('message', async message => {
    try {
      const event = JSON.parse(message.toString());
      console.log('[WSS] Received event from service:', event.type);

      // Update DB based on event from Consul
      if (event.type === 'StripePayout') {
        if (event.status === 'success') {
            await db.query(
              `UPDATE events SET status = 'paid', stripe_transfer_id = $1, stripe_mode = $2 WHERE claim_tx_hash = $3`,
              [event.stripeTransferId, event.mode, event.id]
            );
        } else { // Handle failure
            await db.query(`UPDATE events SET status = 'failed' WHERE claim_tx_hash = $1`, [event.id]);
        }
      } else if (event.type === 'Reconcile') {
        await db.query(
          `UPDATE events SET status = 'reconciled', reconcile_tx_hash = $1 WHERE claim_tx_hash = $2`,
          [event.txHash, event.id] // Assuming event from consul has txHash of the reconcile tx
        );
      }

      broadcast(event); // Re-broadcast to all UI clients
    } catch (error) {
      console.error('[WSS] Failed to process message:', error);
        }
    });
});

// Ethereum setup (optional - only if contract address is configured)
if (process.env.PAYROLL_ADDRESS && process.env.PAYROLL_ADDRESS !== "0xYOUR_DEPLOYED_AUTOPAYROLL_ADDRESS" && process.env.RPC_URL) {
  const payrollAbi = [
      "event SalaryClaimed(address indexed employee, uint256 amount, uint256 ts)"
  ];
  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
  const payroll = new ethers.Contract(
    process.env.PAYROLL_ADDRESS,
    payrollAbi,
    provider
  );

  console.log(`Listening for SalaryClaimed events on ${process.env.PAYROLL_ADDRESS}`);

  payroll.on("SalaryClaimed", async (employee, amount, ts, ev) => {
  try {
    const amountUsd = parseFloat(ethers.utils.formatUnits(amount, 18));
    const event = {
      id: ev.log.transactionHash,
      employee,
      amountUsd,
      type: "SalaryClaimed",
      status: "pending",
      txHash: ev.log.transactionHash,
      timestamp: Date.now()
    };

    // Insert initial event into DB
    await db.query(
      `INSERT INTO events (claim_tx_hash, employee_address, amount_usd, status) VALUES ($1, $2, $3, $4)`,
      [event.txHash, event.employee, event.amountUsd, event.status]
    );

    broadcast(event);
  } catch (err) {
    console.error('[EVM_LISTENER] Error processing SalaryClaimed event:', err);
  }
  });
} else {
  console.log('[EVM_LISTENER] Blockchain integration disabled - PAYROLL_ADDRESS or RPC_URL not configured');
}