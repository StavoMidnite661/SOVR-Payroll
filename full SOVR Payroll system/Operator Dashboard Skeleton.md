💀⚡ Copy that, Captain — converting the War Map into Gemini CLI marching orders so your CLI crew knows exactly what to build, in order, no fluff.

🎯 GEMINI CLI DIRECTIVE: Operator Dashboard Phase 2.2

Mission: Establish Operator Dashboard to visualize live on-chain & off-chain payroll events with audit trail integration.
Objective: Deliver a real-time "Command Center" where operators can see SalaryClaims, Stripe payouts, and Burns as they happen.

PHASE 1: BACKEND EVENT EMITTER

Task 1.1: Bootstrap Express service with WebSocket or SSE

mkdir operator-dashboard && cd operator-dashboard
npm init -y
npm install express ws dotenv ethers


Task 1.2: Create server.js

// operator-dashboard/server.js
require("dotenv").config();
const express = require("express");
const { WebSocketServer } = require("ws");
const { ethers } = require("ethers");

const app = express();
const server = app.listen(4000, () => {
  console.log("⚔️ Operator Backend running on :4000");
});

// WebSocket bridge
const wss = new WebSocketServer({ server });

function broadcast(event) {
  const data = JSON.stringify(event);
  wss.clients.forEach(c => c.send(data));
}

// Ethereum setup
const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
const payroll = new ethers.Contract(
  process.env.PAYROLL_ADDRESS,
  ["event SalaryClaimed(address indexed employee,uint256 amount)"],
  provider
);

payroll.on("SalaryClaimed", (employee, amount, ev) => {
  broadcast({
    id: ev.transactionHash,
    employee,
    amountUsd: parseFloat(ethers.formatUnits(amount, 18)),
    type: "SalaryClaimed",
    status: "pending",
    txHash: ev.transactionHash,
    timestamp: Date.now()
  });
});

PHASE 2: FRONTEND UI SKELETON

Task 2.1: Bootstrap Next.js project with TailwindCSS

npx create-next-app@latest dashboard-ui
cd dashboard-ui
npm install @heroicons/react
npm install
npm install tailwindcss postcss autoprefixer
npx tailwindcss init -p


Task 2.2: Configure Tailwind (tailwind.config.js)

module.exports = {
  content: ["./pages/**/*.{js,ts,jsx,tsx}", "./components/**/*.{js,ts,jsx,tsx}"],
  theme: { extend: {} },
  plugins: []
};


Task 2.3: Update globals.css for dark mode

@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  @apply bg-black text-white font-mono;
}

PHASE 3: DUMMY FEED COMPONENT

Task 3.1: Create components/LiveFeed.js

import { useEffect, useState } from "react";

export default function LiveFeed() {
  const [events, setEvents] = useState([]);

  useEffect(() => {
    const ws = new WebSocket("ws://localhost:4000");
    ws.onmessage = (msg) => {
      const evt = JSON.parse(msg.data);
      setEvents((prev) => [evt, ...prev]);
    };
    return () => ws.close();
  }, []);

  return (
    <div className="p-4">
      <h1 className="text-green-400 text-xl mb-4">⚔️ Live Event Feed</h1>
      <ul>
        {events.map((e) => (
          <li key={e.id} className="mb-2">
            {e.type === "SalaryClaimed" && <span className="text-yellow-400">⚡</span>}
            {e.type === "StripePayout" && <span className="text-green-400">💳</span>}
            {e.type === "Burn" && <span className="text-red-400">🔥</span>}
            {` ${e.type}: ${e.amountUsd} USD → ${e.employee.slice(0, 6)}...`}
          </li>
        ))}
      </ul>
    </div>
  );
}


Task 3.2: Use in pages/index.js

import LiveFeed from "../components/LiveFeed";

export default function Home() {
  return (
    <main className="min-h-screen p-8">
      <h1 className="text-2xl text-purple-400 mb-6">🏰 Cocky Crypto King Payroll Command Center</h1>
      <LiveFeed />
    </main>
  );
}

PHASE 4: INTEGRATION & STYLE

Task 4.1: Run Backend

node server.js


Task 4.2: Run Frontend

cd dashboard-ui
npm run dev


Task 4.3: Access UI at http://localhost:3000

Watch ⚡ SalaryClaimed stream into the feed.
Later, add 💳 StripePayout + 🔥 Burn from Consul’s broadcasts.
SUCCESS CRITERIA

✅ Events stream into dashboard feed in real-time.
✅ Dark-mode UI shows ⚡/💳/🔥 icons with proper colors.
✅ Operators see claims as they happen without parsing logs.
✅ Schema supports expansion (Stripe + Burn).

END DIRECTIVE

💀⚡ Gemini CLI: execute this battle plan to spin up the Operator Dashboard Skeleton — backend emits, frontend visualizes, and the Captain watches the war map light up in real time.

👉 Captain — do we want to pipe Stripe & Burn events into broadcast right now (so the feed shows all three stages), or march with just SalaryClaimed first for visual confirmation before expanding?