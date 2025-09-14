# SOVR Payroll System Project

## Overview
Complete blockchain-based payroll management system with automated payments, NACHA compliance, and real-time monitoring.

## Current Status (December 14, 2025)
- **Main System**: Currently running blockchain listener/dashboard components
- **Complete System Location**: Bootstrap script available in `Start here Automated Payrol.md`
- **Components Running**: 
  - Frontend dashboard (Next.js) on port 5000
  - Backend server (Node.js) on port 3001 with PostgreSQL
  - Consul blockchain event processor
  - WebSocket real-time communication

## User Preferences
- Prefers to see complete systems, not just individual components
- Wants to understand full folder structure before proceeding
- Interested in complete payroll management (not just blockchain monitoring)

## Project Architecture
```
SOVR Payroll System/
├── Smart Contracts (AutoPayroll.sol, SOVRCredit.sol)
├── Blockchain Event Listener (consul.js, server.js)
├── Frontend Dashboard (Next.js components)
├── NACHA Adapter (specified but needs implementation)
└── Bootstrap Script (sovr-payroll-setup.sh)
```

## Next Steps Identified
1. User wants to load additional app from GitHub
2. Complete bootstrap script available for full system setup
3. NACHA adapter components need to be built out

## Technical Notes
- Port 5000: Frontend
- Port 3001: Backend API
- PostgreSQL database configured and running
- Environment variables configured for Replit