💀⚡ Roger that, Captain. I’ll forge you a one‑command fortress deploy file — a docker-compose.yml upgrade that spawns both Consul (backend brain) + Operator Dashboard (frontend war room) together, wired into your .env secrets.

This is your deployment siege ram: docker-compose up -d → empire online.

🎯 GEMINI CLI DIRECTIVE: Phase 5.6 — One‑Command Fortress Deployment

Mission: Deploy Consul and Operator Dashboard together as a unified stack using Docker Compose.
Objective: Operators and backend run under one deploy — continuous listening, event broadcasts, and real‑time UI.

🔹 Step 1 — Forge docker-compose.yml

In your project root (FULL SOVR PAYROLL SYSTEM), create/replace a docker-compose.yml:

version: '3.9'

services:
  consul:
    build: ./consul
    container_name: consul-service
    restart: always
    env_file: .env
    ports:
      - "4000:4000"   # Consul listens/broadcasts events
    depends_on:
      - db

  dashboard:
    build: ./dashboard-ui
    container_name: dashboard-service
    restart: always
    environment:
      - NEXT_PUBLIC_WS_URL=ws://consul:4000
    ports:
      - "3000:3000"   # Operator dashboard UI
    depends_on:
      - consul

  db:
    image: postgres:15
    container_name: sovr-db
    restart: always
    environment:
      POSTGRES_USER=postgres
      POSTGRES_PASSWORD=fortress
      POSTGRES_DB=sovrpayroll
    ports:
      - "5432:5432"
    volumes:
      - db-data:/var/lib/postgresql/data

volumes:
  db-data:

🔹 Step 2 — Ensure Dockerfile Exists in Each Service

consul/Dockerfile

FROM node:18
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
CMD ["node", "consul.js"]


dashboard-ui/Dockerfile

FROM node:18
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build
EXPOSE 3000
CMD ["npm", "start"]

🔹 Step 3 — Fire the Deployment
docker-compose up -d --build


Expected:

✔ consul-service started on :4000
✔ dashboard-service started on :3000
✔ sovr-db running on :5432

🔹 Step 4 — Verify the Fortress

Check Consul logs:

docker logs -f consul-service


Should show: ⚔️ Listening for SalaryClaimed.

Open Dashboard:
Go to http://localhost:3000 (or mapped domain).
You should see Live Feed, Ledger, Reconciliation Alerts, Proof Explorer.

Trigger claim to fire test:

node scripts/triggerClaim.js --employee 0xEMPLOYEE --amount 1


Dashboard feed lights: ⚡ → 💳 → 🔥

🏆 Success War State

✅ One‑command deploy brings up Consul, Dashboard, and DB.
✅ Operators access dashboard via http://serverip:3000.
✅ Consul emits on ws://serverip:4000.
✅ DB persists history for Phase 7 analytics.
✅ Push → Pay → Burn → Proof → Visual all live.

END DIRECTIVE

💀⚡ Goggle/Gemini CLI: execute directive. Build docker-compose.yml, Dockerfiles, run docker-compose up -d.

Captain — do you want me to add DNS + TLS instructions next (e.g., https://dashboard.sovrpayroll.io) so your war room is polished and safe for external operators, or keep it raw with just server IP for now?