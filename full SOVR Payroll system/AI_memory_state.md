# SOVR Payroll System - Project State Memorandum

**Document Objective:** To provide a comprehensive summary of the SOVR Payroll project's current status, architecture, and operational procedures for auditing and agent continuity.

**Last Updated:** October 26, 2023

---

### 1. System Architecture Overview

The project consists of two primary components:

*   **On-Chain Contracts (Solidity/Foundry):**
    *   `SOVRCredit`: An ERC20 token representing a stablecoin credit within the payroll system. It includes role-based access control (`Ownable2Step` and `AccessControl`) for minting and burning.
    *   `AutoPayroll`: The core contract that manages employee salary data and handles the salary claim process.

*   **Off-Chain Service (`Consul` Listener - Node.js):**
    *   A service that listens for the `SalaryClaimed` event emitted by the `AutoPayroll` contract.
    *   Upon detecting an event, it is responsible for two actions:
        1.  **Processing Fiat Payout:** Initiating a (currently mocked) ACH transfer to the employee.
        2.  **Burning Tokens:** Calling the `burn` function on the `SOVRCredit` contract to reconcile the on-chain ledger.

---

### 2. Deployment and Configuration Status

The deployment process is **fully automated** and managed by the `deploy.sh` script.

*   **Automation:** The script handles the entire lifecycle: contract compilation, deployment to the Sepolia testnet, and on-chain verification via Etherscan.
*   **Configuration:** It automatically extracts the deployed contract addresses and generates the necessary `.env` file for the `Consul` listener, eliminating manual configuration and potential for error.
*   **Idempotency:** The process is designed to be repeatable and deterministic, ensuring consistent testnet environments.

---

### 3. Security Posture

A significant hardening effort has been completed, focusing on the **Principle of Least Privilege**.

*   **Role Segregation:** The system now uses three distinct wallet roles:
    1.  **Deployer/Admin:** A high-privilege role used *only* for initial contract deployment and administrative tasks (e.g., adding employees). Its key is not used in any long-running process.
    2.  **Operator:** A low-privilege, automated role used exclusively by the `Consul` listener.
    3.  **Employee:** A user role for claiming salary.

*   **Reduced Attack Surface:** The `Consul` listener's `OPERATOR_PRIVATE_KEY` is only granted the `BURNER_ROLE` on the `SOVRCredit` contract. It has no other permissions. A compromise of the listener's host environment will not expose minting or administrative keys.

*   **Secret Management:** A `.gitignore` file is in place to prevent the accidental commit of `.env` files containing private keys.

---

### 4. Current Operational State

The core functionality is implemented and validated on the Sepolia testnet. The end-to-end flow from an employee claiming a salary to the off-chain listener burning the corresponding tokens is operational.

The fiat payout mechanism within the `Consul` listener is currently a **mocked process** (i.e., it only logs to the console).

### 5. Defined Next Steps

The following extensions are documented in the project playbook as the next phases of work:

1.  **Processor Integration:** Replace the mock payout logic in `Consul` with a real sandbox integration to a payment processor (e.g., Stripe, Plaid) for ACH or card payouts.
2.  **Employee Dashboard:** Develop a frontend application to allow employees to view their balance and trigger the `claimSalary` function via a user interface.
3.  **Multisig Treasury:** Transition administrative control from a single Deployer/Admin address to a Gnosis Safe multisig wallet for enhanced security and governance.