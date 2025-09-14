// Simple server for development without database dependency
require("dotenv").config();
const express = require("express");
const { WebSocketServer } = require("ws");

const app = express();

// Enable CORS for cross-origin requests from frontend
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  next();
});

// Mock endpoints that return empty data
app.get("/employees", (req, res) => {
  res.json([]);
});

app.get("/proofs", (req, res) => {
  res.json([]);
});

app.get("/reconciliation", (req, res) => {
  res.json([]);
});

const server = app.listen(3001, '0.0.0.0', () => {
  console.log("Simple Backend running on 0.0.0.0:3001");
  console.log("Database integration disabled for initial setup");
});

// WebSocket server for real-time communication
const wss = new WebSocketServer({ server });

function broadcast(event) {
  const data = JSON.stringify(event);
  wss.clients.forEach(c => {
    if (c.readyState === c.OPEN) {
      c.send(data);
    }
  });
}

wss.on('connection', ws => {
  console.log('[WSS] Client connected.');
  
  // Send a welcome message to test WebSocket connectivity
  ws.send(JSON.stringify({
    type: 'system',
    message: 'WebSocket connection established',
    timestamp: Date.now()
  }));
  
  ws.on('message', async message => {
    try {
      const event = JSON.parse(message.toString());
      console.log('[WSS] Received event from service:', event.type);
      broadcast(event);
    } catch (error) {
      console.error('[WSS] Failed to process message:', error);
    }
  });
});

console.log('Simple SOVR Payroll Backend started successfully');
console.log('Frontend can now connect to API endpoints at http://localhost:3001');