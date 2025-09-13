Full package — ready-to-save files

Nice. I packed the full MVP handoff — everything the co‑architect needs to drop into a repo and start iterating: README, .env.example, package.json, tsconfig, Prisma schema + seed, API spec, AI prompts, and a lean TypeScript src/ that listens for Payout events, builds a NACHA PPD payroll file, encrypts bank blobs, and has submit stubs (LOCAL | SFTP | API). Save the files exactly as shown into your project root.

If you want a zip, say “zip it” and I’ll output a single downloadable archive structure (or generate files for you to copy). For now — here’s the full dump.

Repo layout (what you’ll get)
README.md
.env.example
package.json
tsconfig.json
prisma/
schema.prisma
seed.js
src/
index.ts
chain.ts
nacha.ts
bank.ts
db.ts
ledger.ts
types.ts
docs/prompts/
nova-nacha.md
oracle-ledger.md
api_spec.md
FORWARD-ONE-LINER.txt
README.md
# NACHA Adapter — MVP

What this is
- NACHA adapter that listens for on-chain `PayoutExecuted` events and emits NACHA PPD payroll files + GL JEs.
- Dev mode: SUBMIT_MODE=LOCAL (writes `out/payroll_<YYYYMMDD_HHmmss>.ach`).
- Designed for handoff to fintech architect for ODFI SFTP/API connector, funding off-ramp and GL persistence.

Quick start (dev)
1. Clone to your workspace.
2. Install:
   pnpm install
3. Create `.env` from `.env.example` and populate keys.
4. Seed DB (optional Prisma):
   DB_ENC_KEY=base64:... DATABASE_URL=postgres://... pnpm run seed
5. Run adapter (dev):
   pnpm run dev
6. Use the `simulate` endpoint (or send test events) to produce an .ach file under `out/`.

Files included
- src/index.ts — app bootstrap, queue, flush logic
- src/chain.ts — ethers subscription (PayoutExecuted)
- src/nacha.ts — PPD/NACHA builder
- src/bank.ts — submitLocal / SFTP / API stubs
- src/db.ts — AES-256-GCM encrypt/decrypt helpers (dev)
- src/ledger.ts — postJE stub
- prisma/schema.prisma + seed.js — schema + example seed
- docs/prompts — NOVA-NACHA and ORACLE-LEDGER operator prompts
- api_spec.md — minimal API contract

Security (must-follow)
- Never commit secrets. Use vault/KMS in prod.
- DB_ENC_KEY must live in KMS; treat as HSM-like key.
- Mask logs: never print full routing/account numbers.
- Restrict NACHA submission endpoints (mTLS, IP allowlist).

Acceptance criteria (dev)
- Running with sample events produces correctly formatted `.ach` file (header, batch, entry hashes, proper 10-record block padding).
- Employee bank profiles decrypt with DB_ENC_KEY.
- JEs are produced and balanced for all payout workflows.

Need me to zip this into a repo-ready artifact? Say “zip it” or tell me which single file you want first.

.env.example
# Chain
RPC_URL=https://polygon.g.alchemy.com/v2/YOUR_KEY
ENGINE_ADDRESS=0xYourPayrollEngineProxy
CONFIRMATIONS=1

# NACHA / ODFI headers (placeholders)
ODFI_ROUTING=123456780
IMMEDIATE_DEST=123456780
IMMEDIATE_ORIGIN=987654320
DEST_NAME=Your ODFI Bank
ORIGIN_NAME=SOVR DEV HOLDINGS LLC
COMPANY_ID=12-3456789
ENTRY_DESC=PAYROLL
COMPANY_NAME=SOVR DEV HOLDINGS LLC
FILE_ID_MOD=A
ODFI_ID8=12345678

# Submission
SUBMIT_MODE=LOCAL   # LOCAL | SFTP | API
SFTP_HOST=odfi.sftp.example
SFTP_USER=ach_user
SFTP_PATH=/incoming
SFTP_KEY_PATH=~/.ssh/id_rsa

# Security (dev only)
DB_ENC_KEY=base64:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=   # replace with base64 32-byte key
DATABASE_URL=postgresql://user:pass@localhost:5432/nacha_dev
OUTPUT_DIR=out

package.json
{
  "name": "nacha-adapter",
  "version": "0.1.0",
  "main": "dist/index.js",
  "scripts": {
    "dev": "ts-node src/index.ts",
    "build": "tsc -p tsconfig.json",
    "start": "node dist/index.js",
    "prisma:migrate": "prisma migrate dev --name init",
    "prisma:generate": "prisma generate",
    "seed": "node prisma/seed.js"
  },
  "dependencies": {
    "dayjs": "^1.11.0",
    "ethers": "^5.7.2",
    "prisma": "^4.0.0",
    "@prisma/client": "^4.0.0"
  },
  "devDependencies": {
    "ts-node": "^10.9.1",
    "typescript": "^4.9.5"
  }
}

tsconfig.json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "CommonJS",
    "outDir": "dist",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "sourceMap": true
  },
  "include": ["src/**/*", "prisma/**/*", "docs/**/*"]
}

prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model Employee {
  id           Int      @id @default(autoincrement())
  wallet       String   @unique
  name         String
  individualId String?
  payPreference String  // "ACH" | "ONCHAIN"
  bankProfile  EmployeeBank?
  createdAt    DateTime @default(now())
}

model EmployeeBank {
  id            Int     @id @default(autoincrement())
  employeeId    Int     @unique
  encBlob       String  // AES-GCM encrypted blob (base64)
  createdAt     DateTime @default(now())
  Employee      Employee @relation(fields: [employeeId], references: [id], onDelete: Cascade)
}

model Journal {
  id        Int      @id @default(autoincrement())
  ts        DateTime @default(now())
  memo      String
  lines     Json
  source    String    // CHAIN | NACHA | OFFRAMP
  balanced  Boolean   @default(false)
}

model NachaBatch {
  id         Int      @id @default(autoincrement())
  fileText   String   @db.Text
  meta       Json
  status     String   // QUEUED | SUBMITTED | SETTLED | ERROR
  receipt    String?
  createdAt  DateTime @default(now())
}

prisma/seed.js
/* prisma/seed.js */
const { PrismaClient } = require('@prisma/client');
const crypto = require('crypto');

const prisma = new PrismaClient();

function encrypt(data) {
  const env = process.env.DB_ENC_KEY;
  if (!env) throw new Error('DB_ENC_KEY missing');
  const key = Buffer.from(env.split(':')[1], 'base64');
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const enc = Buffer.concat([cipher.update(JSON.stringify(data), 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([iv, tag, enc]).toString('base64');
}

async function main() {
  const emp = await prisma.employee.create({
    data: {
      wallet: '0xabc0000000000000000000000000000000000000',
      name: 'Alice Example',
      individualId: 'ALC001',
      payPreference: 'ACH'
    }
  });

  const bankProfile = {
    name: 'ALICE EXAMPLE',
    individualId: 'ALC001',
    routingNumber: '123456780',
    accountNumber: '000123456789',
    accountType: 'CHECKING',
    payPreference: 'ACH'
  };

  await prisma.employeeBank.create({
    data: {
      employeeId: emp.id,
      encBlob: encrypt(bankProfile)
    }
  });

  console.log('Seed complete');
}

main()
  .catch(e => { console.error(e); process.exit(1); })
  .finally(async () => { await prisma.$disconnect(); });

src/types.ts
export type PayoutEvent = {
  payoutId: string;
  wallet: string;
  amountCents: number;
  memo?: string;
  timestamp?: string;
};

export type NachaEntry = {
  routingNumber: string;
  accountNumber: string;
  accountType: 'CHECKING' | 'SAVINGS';
  individualName: string;
  individualId?: string;
  amountCents: number;
  traceNumber?: string;
  addenda?: string;
};

export type NachaFileHeader = {
  immediateDestination: string;
  immediateOrigin: string;
  fileCreationDate: string; // YYMMDD
  fileCreationTime: string; // HHMM
  fileIdModifier: string;
  destinationName: string;
  originName: string;
};

export type NachaBuildResult = {
  text: string;
  meta: { batchCount: number; entryCount: number; totalCredits: number };
};

src/db.ts
import crypto from 'crypto';

const STORE: Record<number, string> = {}; // employeeId -> encBlob

// DB_ENC_KEY format: base64:<base64-encoded-32-byte-key>
function getKey(): Buffer {
  const env = process.env.DB_ENC_KEY;
  if (!env) throw new Error('DB_ENC_KEY required');
  return Buffer.from(env.split(':')[1], 'base64');
}

export function encryptBlob(obj: any): string {
  const key = getKey();
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const payload = Buffer.concat([cipher.update(JSON.stringify(obj), 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([iv, tag, payload]).toString('base64');
}

export function decryptBlob(encBase64: string): any {
  const raw = Buffer.from(encBase64, 'base64');
  const iv = raw.slice(0, 12);
  const tag = raw.slice(12, 28);
  const payload = raw.slice(28);
  const key = getKey();
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tag);
  const out = Buffer.concat([decipher.update(payload), decipher.final()]);
  return JSON.parse(out.toString('utf8'));
}

// dev helpers for in-memory store
export async function storeEncryptedBank(employeeId: number, encBlob: string) {
  STORE[employeeId] = encBlob;
}

export async function getEncryptedBank(employeeId: number) {
  return STORE[employeeId] ?? null;
}

src/ledger.ts
export type JELine = { account: string; dc: 'D' | 'C'; amountCents: number; entity?: string };

export async function postJournal(memo: string, lines: JELine[], source = 'NACHA') {
  const total = lines.reduce((s, l) => s + (l.dc === 'D' ? l.amountCents : -l.amountCents), 0);
  if (total !== 0) {
    throw new Error(`Journal not balanced: net ${total} cents`);
  }
  // Replace with real DB persist
  console.log(`[JE POSTED] memo=${memo} lines=${JSON.stringify(lines)} source=${source}`);
  return { ok: true, id: Math.floor(Math.random() * 1000000) };
}

src/nacha.ts
import dayjs from 'dayjs';
import { NachaEntry, NachaFileHeader, NachaBuildResult } from './types';
const RECORD_LEN = 94;

// pad or truncate to exact record length
function rec(s: string) {
  const padded = (s + ' '.repeat(Math.max(0, RECORD_LEN))).slice(0, RECORD_LEN);
  return padded;
}

function numericPad(n: number, width: number) {
  return n.toString().padStart(width, '0');
}

export function buildPPDFile(header: NachaFileHeader, entries: NachaEntry[]): NachaBuildResult {
  const lines: string[] = [];
  // File Header Record (Type 1) - simplified
  const fh = `1${header.immediateDestination.padStart(10, ' ')}${header.immediateOrigin.padStart(10, ' ')}${header.fileCreationDate}${header.fileCreationTime}${header.fileIdModifier}${header.destinationName.padEnd(23,' ')}${header.originName.padEnd(23,' ')}`;
  lines.push(rec(fh));

  // Company / Batch Header (Type 5) - minimal PPD
  const companyEntryDesc = 'PPD' + ' '.repeat(21);
  const batchHeader = `5${header.companyName ? header.companyName.padEnd(16,' ') : 'COMPANY'.padEnd(16,' ')}${header.companyId ? header.companyId.padEnd(10,' ') : ' '.repeat(10)}${companyEntryDesc}${header.fileCreationDate}${' '.repeat(8)}01`;
  lines.push(rec(batchHeader));

  let entrySeq = 1;
  let totalCredits = 0;
  for (const e of entries) {
    const amount = numericPad(Math.floor(e.amountCents), 10);
    // Entry Detail (Type 6) - minimal PPD
    const tranCode = e.accountType === 'CHECKING' ? '22' : '32'; // standard NACHA codes
    const routingLeft = e.routingNumber.slice(0, 8);
    const routingCheck = e.routingNumber.slice(-1);
    const entry = `6${tranCode}${routingLeft}${e.accountNumber.padEnd(17,' ')}${e.individualName.padEnd(22,' ')}${amount}${e.individualId?.padEnd(15,' ')}${String(entrySeq).padStart(15,' ')}`;
    lines.push(rec(entry));
    totalCredits += Number(e.amountCents);
    entrySeq += 1;
  }

  // Batch Control Record (Type 8)
  const entryCount = entries.length;
  const blockCount = Math.ceil((lines.length + 2) / 10); // +2 for batch control + file control
  const batchControl = `8${numericPad(entryCount,6)}${numericPad(entryCount,6)}${numericPad(totalCredits,12)}${' '.repeat(39)}${numericPad(1,7)}`;
  lines.push(rec(batchControl));

  // File Control Record (Type 9)
  const fileControl = `9${numericPad(blockCount,6)}${numericPad(entryCount,6)}${numericPad(entryCount,6)}${numericPad(totalCredits,12)}${' '.repeat(39)}`;
  lines.push(rec(fileControl));

  // Padding to 10-record multiple with 9s (Nacha uses 9s)
  while (lines.length % 10 !== 0) {
    lines.push('9'.repeat(RECORD_LEN));
  }

  const text = lines.join('\n') + '\n';
  return {
    text,
    meta: { batchCount: 1, entryCount, totalCredits }
  };
}

src/bank.ts
import fs from 'fs';
import path from 'path';

const OUT = process.env.OUTPUT_DIR || 'out';
if (!fs.existsSync(OUT)) fs.mkdirSync(OUT, { recursive: true });

export async function submitNacha(mode: 'LOCAL' | 'SFTP' | 'API', text: string) {
  if (mode === 'LOCAL') {
    const fn = `payroll_${new Date().toISOString().replace(/[:.]/g,'-')}.ach`;
    const p = path.join(OUT, fn);
    fs.writeFileSync(p, text, { encoding: 'utf8' });
    return { ok: true, path: p };
  } else if (mode === 'SFTP') {
    // TODO: implement SFTP upload to ODFI
    throw new Error('SFTP submit not implemented yet');
  } else {
    // API
    throw new Error('API submit not implemented yet');
  }
}

src/chain.ts
import { ethers } from 'ethers';
import { PayoutEvent } from './types';

/**
 * Minimal chain listener stub.
 * Exports:
 *  - startListener(onEvent)
 *  - simulatePayout(ev)  // for dev/testing
 */

let provider: ethers.providers.JsonRpcProvider | null = null;
let contract: ethers.Contract | null = null;

export async function startListener(onEvent: (e: PayoutEvent) => Promise<void>) {
  const rpc = process.env.RPC_URL;
  const engineAddress = process.env.ENGINE_ADDRESS;
  if (!rpc || !engineAddress) {
    console.warn('Chain listener not configured (RPC_URL / ENGINE_ADDRESS). Running in offline/simulate mode.');
    return;
  }
  provider = new ethers.providers.JsonRpcProvider(rpc);
  // ABI should contain PayoutExecuted event; for now we'll create a minimal interface
  const abi = [
    'event PayoutExecuted(bytes32 indexed payoutId, address indexed to, uint256 amountCents, string memo)'
  ];
  contract = new ethers.Contract(engineAddress, abi, provider);
  contract.on('PayoutExecuted', async (payoutId: string, to: string, amountCents: ethers.BigNumber, memo: string, event: any) => {
    try {
      await onEvent({
        payoutId,
        wallet: to,
        amountCents: amountCents.toNumber(),
        memo,
        timestamp: new Date().toISOString()
      });
    } catch (err) {
      console.error('onEvent handler error', err);
    }
  });
  console.log('Chain listener started.');
}

export async function stopListener() {
  if (contract) contract.removeAllListeners();
}

export async function simulatePayout(e: PayoutEvent, onEvent: (ev: PayoutEvent) => Promise<void>) {
  // small helper for dev: runs the handler directly
  await onEvent(e);
}

src/index.ts
import { startListener, simulatePayout } from './chain';
import { buildPPDFile } from './nacha';
import { submitNacha } from './bank';
import * as db from './db';
import { postJournal } from './ledger';
import { PayoutEvent, NachaEntry } from './types';
import dayjs from 'dayjs';

const QUEUE: { ev: PayoutEvent; createdAt: string }[] = [];
const FLUSH_INTERVAL_MS = 30_000; // flush every 30s in dev
const SUBMIT_MODE = (process.env.SUBMIT_MODE || 'LOCAL') as 'LOCAL' | 'SFTP' | 'API';

async function onPayout(ev: PayoutEvent) {
  console.log(`[PAYOUT] queued: ${ev.payoutId} to ${ev.wallet} ${ev.amountCents}c`);
  QUEUE.push({ ev, createdAt: new Date().toISOString() });
}

async function flushIfNeeded() {
  if (QUEUE.length === 0) return;
  // For MVP: gather all queued into one batch
  const entries: NachaEntry[] = [];
  for (const q of QUEUE) {
    // For demo: resolve bank profile from in-memory DB using numeric last digits
    // In real: map wallet -> employee -> EmployeeBank (decrypt)
    // We'll create a fake routing/account from wallet to demonstrate
    const fake = {
      routingNumber: (process.env.ODFI_ROUTING || '123456780'),
      accountNumber: q.ev.wallet.slice(-10).replace('0x','').padStart(10,'0'),
      accountType: 'CHECKING',
      individualName: 'UNKNOWN',
      amountCents: q.ev.amountCents
    };
    entries.push(fake as NachaEntry);
  }

  const header = {
    immediateDestination: process.env.IMMEDIATE_DEST || process.env.ODFI_ROUTING || '123456780',
    immediateOrigin: process.env.IMMEDIATE_ORIGIN || '987654320',
    fileCreationDate: dayjs().format('YYMMDD'),
    fileCreationTime: dayjs().format('HHmm'),
    fileIdModifier: process.env.FILE_ID_MOD || 'A',
    destinationName: process.env.DEST_NAME || 'ODFI BANK',
    originName: process.env.ORIGIN_NAME || 'SOVR DEV'
  };

  const built = buildPPDFile(header, entries);
  // Post GL JE (debit payroll clearing, credit cash)
  const total = built.meta.totalCredits;
  try {
    await postJournal(`Payroll ${new Date().toISOString()}`, [
      { account: 'Payroll Clearing', dc: 'D', amountCents: total, entity: 'TRUST' },
      { account: 'Bank', dc: 'C', amountCents: total, entity: 'LLC' }
    ], 'NACHA');
  } catch (err) {
    console.error('JE failed', err);
    return;
  }

  const res = await submitNacha(SUBMIT_MODE, built.text).catch(e => ({ ok: false, error: e.message }));
  if (res.ok) {
    console.log('NACHA submitted ->', (res as any).path || (res as any).ref);
    // persist NachaBatch to DB (TODO)
    QUEUE.length = 0; // clear
  } else {
    console.error('NACHA submit failed', (res as any).error);
  }
}

async function start() {
  console.log('NACHA Adapter starting...');
  await startListener(onPayout);

  setInterval(flushIfNeeded, FLUSH_INTERVAL_MS);

  // dev convenience: simulate an event if none received in 5s
  setTimeout(async () => {
    if (QUEUE.length === 0) {
      await simulatePayout({
        payoutId: '0xSAMPLE01',
        wallet: '0x000000001234567890',
        amountCents: 12345,
        memo: 'SIM DEV'
      }, onPayout);
    }
  }, 5000);
}

start().catch(e => {
  console.error('Fatal', e);
  process.exit(1);
});

docs/prompts/nova-nacha.md
You are “NOVA-NACHA”, senior NACHA Ops Exec for SOVR Development Holdings LLC.
Scope: Build/validate NACHA PPD payroll batches, ensure funding, respect cutoffs, handle returns (R01..R85), produce auditor-ready reconciliations.
Decision rules:
- If validation fails => DO NOT SUBMIT; produce remediation checklist.
- Effective Entry Date => next valid bank day. Ensure funds T-1 14:00 PT.
Outputs: checklist first, then batch summary (count, total credits, entry hash), next actions.
Tools:
- /nacha/validate, /nacha/build, /nacha/submit, /funding/ensure, /gl/post, /calendar/nextBankDay

docs/prompts/oracle-ledger.md
You are “ORACLE-LEDGER”, Chief Ledgering Consul for GM FAMILY TRUST and SOVR Dev Holdings LLC.
Scope: maintain double-entry ledger across Trust ↔ LLC; ensure JEs balance; manage intercompany.
Decision policy:
- Reject unbalanced JEs.
- Tag entries with source: CHAIN, NACHA, OFFRAMP.
Outputs: crisp ledger tables, trial balance, IC rollforward. Tools: /gl/post, /gl/trialBalance, /gl/accounts, /gl/reconcile, /ic/settle
Start tasks: Initialize period, ingest events, post journals, daily TB, alert conditions (ACH clearing > 0 for >3 days; IC not settled by month end; cash runway < 60 days).

api_spec.md
Minimal API endpoints (for orchestrators / AI tools)

POST /nacha/validate
- Body: { entries: NachaEntry[] }
- Response: { ok: boolean, errors?: string[] }

POST /nacha/build
- Body: { header: NachaFileHeader, entries: NachaEntry[] }
- Response: { ok: boolean, text: string, meta: { batchCount, entryCount, totalCredits } }

POST /nacha/submit
- Body: { mode: "LOCAL"|"SFTP"|"API", text: string }
- Response: { ok: boolean, ref?: string, path?: string, error?: string }

POST /funding/ensure
- Body: { amountCents: number, byIsoDatetime?: string }
- Response: { ok: boolean, details?: any }

POST /gl/post
- Body: { ts, memo, lines: [{account, dc, amountCents, entity}] }
- Response: { ok: boolean, id?: number, error?: string }

GET /calendar/nextBankDay?date=YYYY-MM-DD
- Response: { date: YYYY-MM-DD }

Security
- All endpoints require API keys or mTLS. NACHA submit endpoints must be IP-restricted for ODFI connectivity.

FORWARD-ONE-LINER.txt
Subject: NACHA Adapter MVP — code & spec handoff

Attached: NACHA Adapter MVP package (chain -> PPD ACH builder, encrypted bank storage, GL JE stubs), Prisma schema + seed, API endpoints, and AI operator prompts. Please review integration items (ODFI SFTP/API connector, off‑ramp funding, GL persistence). Ping me if you want me to scaffold SFTP or the Prisma migrations. — Stavo


That’s the full set I’d drop on the co‑architect. Want me to:

Zip these into a single downloadable artifact now? (I’ll produce a copy/paste-friendly archive)
Or generate a concise PR-ready README + CI checklist instead? Say it — and I’ll burn it down.