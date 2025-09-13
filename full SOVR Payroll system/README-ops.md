# SOVR Payroll Operator Guide

## 1. Purpose

This guide is for **operators** responsible for running demonstrations, executing tests, and auditing system logs. It assumes the system has already been built and deployed by the engineering team. This document focuses on operational procedures, not system architecture or development.

---

## 2. Operational Procedures

### 2.1. Running a Live Fire Test

This procedure executes a complete, end-to-end live fire test against the running production stack. It automates the entire protocol: triggering the on-chain claim, waiting for the full reconciliation cycle, validating the result with the Stripe API, and generating a final proof report.

1.  **Start the Fortress Stack:**
    Ensure all services are running via Docker Compose: `docker-compose up -d --build`

2.  **Execute the Live Fire Script:**
```bash
# Ensure all required environment variables are set (see .env.example)
bash live-fire.sh
```

### 2.2. Retrieving and Decrypting CI/CD Artifacts

After a CI/CD pipeline run completes, encrypted logs and reports are stored as artifacts.

1.  **Download Artifacts:**
    Use the `gh` CLI to download the `sealed-e2e-results` artifact from the latest run.
    ```bash
    gh run download --name sealed-live-proofs
    ```
    This will download `demo.log.encrypted` and `report.json.encrypted`.

2.  **Decrypt Artifacts (Team Members Only):**
    Use your GPG private key to decrypt the files. You only need to import the private key once.
    ```bash
    # First time setup: Import your private key
    gpg --import /path/to/your/crew_secret.asc

    # Decrypt the log and report
    gpg --decrypt demo.log.encrypted > demo.log
    gpg --decrypt report.json.encrypted > report.json
    ```

---

## 3. Interpreting Results

### 3.1. `demo.log`
The `demo.log` file provides a human-readable, step-by-step log of the test run. A successful run will contain entries similar to:
```
...
On-chain claimed amount: 500.00 USD
...
Stripe payout amount: 500.00 USD (ID: tr_...)
...
SUCCESS: On-chain amount matches Stripe payout amount.
...
```

### 3.2. `report.json`
The `report.json` file provides a machine-readable proof of the transaction for automated auditing.
```json
{
  "tx_hash": "0xabc123...",
  "employee": "0x999abc...",
  "onchain_claimed_usd": "500.00",
  "stripe_transfer_id": "tr_1NYxxABC123",
  "stripe_payout_usd": "500.00",
  "final_sovr_balance_wei": "0",
  "amounts_match": true
}
```
- **`amounts_match`**: The critical field. `true` indicates a successful reconciliation between the on-chain claim and the off-chain payout.

---

## 4. Troubleshooting Common Failures

| Symptom                                       | Potential Cause & Action                                                                                             |
| --------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| **Amount Mismatch** in `report.json`          | Check the `consul/employeeRegistry.json` file. The employee's ETH address may be mapped to the wrong Stripe account. |
| **No Stripe Transfer Logged**                 | 1. Verify the `Consul` listener service is running. <br> 2. Check if the `STRIPE_SECRET_KEY` in the `.env` file is valid. |
| **Reconcile Transaction Fails**               | The `consul` service must use the `DEPLOYER_PRIVATE_KEY` to call the owner-only `reconcile` function. Verify the key is correct. |
| **GPG Decryption Fails**                      | Ensure you are using the correct GPG private key that corresponds to the public key used for encryption in the CI pipeline. |