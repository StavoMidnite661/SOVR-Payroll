This document outlines the SOVR Payroll Testnet Deployment Playbook. It is intended to provide a clean, review-ready guide for deployment.

SOVR Payroll Testnet Deployment Playbook

This gets your SOVRCredit + AutoPayroll contracts deployed live on Sepolia Testnet, hooked up to the Consul listener, and visible on Etherscan. Perfect for demos.

1. Prep Environment
**Install toolchains**
# Foundry (contracts, deployment)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Node.js (Consul listener side)
nvm install 18

echo "18" > .nvmrc # Add .nvmrc to lock in Node version
nvm use

**Get Sepolia Test ETH**
Use faucet sites (Alchemy, Infura, or Chainlink faucet).
Fund 3 wallets:
Deployer/Admin → contract deploy + mint credits
Operator → off-chain listener that burns tokens
Employee → demo account that “claims” salary

**Prevent Leaking Secrets**
Create a `.gitignore` file in your project root to ensure you never commit `.env` files or secrets.

```
.env
consul/.env
node_modules
cache
out
```

2. Provider API
Create free Alchemy/Infura account.
Copy Sepolia RPC URL, e.g.:
https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY

3. Configure Environment

Create .env in project root:

```.env
# WARNING: Keep this file secure and out of version control.
DEPLOYER_PRIVATE_KEY=0xYOUR_DEPLOYER_PK
OPERATOR_PRIVATE_KEY=0xYOUR_OPERATOR_PK # A SEPARATE key for the listener
RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
ETHERSCAN_API_KEY=YOUR_ETHERSCAN_API_KEY
```

4. Deploy & Configure Automatically

Use the automation script (`deploy.sh`) to handle deployment, verification, and configuration in one step.

This script will:
1.  Deploy `SOVRCredit` and `AutoPayroll` contracts.
2.  Extract their addresses.
3.  Mint `SOVRCredit` and fund the `AutoPayroll` contract.
4.  Grant the `BURNER_ROLE` to your Operator address.
5.  Create the `consul/.env` file with all required keys and addresses.

Run the script:
```bash
chmod +x deploy.sh
./deploy.sh
```

5. Add Employee (Demo Wallet)
The script will output the `AutoPayroll` contract address. Use it to add your demo employee.
```bash
cast send 0xAutoPayrollAddress "addEmployee(address,uint256)" 0xEMPLOYEE_ADDRESS 100000e18 \
  --rpc-url $RPC_URL --private-key $DEPLOYER_PRIVATE_KEY
```

7. Run Consul Listener

The `deploy.sh` script has already created the `consul/.env` file for you. It now uses the secure `OPERATOR_PRIVATE_KEY`.

Run:

cd consul
node consul.js


Listener logs when claim happens:

[EVENT] SalaryClaimed employee=0xEMP, amount=500.0
[PROCESSOR] Mock USD payout via ACH
[BURN] Burned 500.0 SOVRC

8. Employee Claims Salary

Demo employee wallet:
```bash
cast send 0xAutoPayroll "claimSalary()" \
  --rpc-url $RPC_URL --private-key $EMPLOYEE_PK
```

Note: The event shows on Sepolia Etherscan, the listener fires, and the mock payout and burn are executed.

Demo Flow
1. Show contract and events on Etherscan.
2. Employee executes `claimSalary`.
3. Listener (Consul) logs the payout and burn.
4. Ledger and rail reconciliation is visibly complete.

Next Extensions
Processor Integration (Sandbox ACH / Card APIs)
Attach real payout rails to Consul (e.g. Plaid ACH, Stripe Treasury, Marqeta).
Employee Dashboard
USD balances + “Claim Now” button (frontend).
Test w/ Multisig Treasury
Replace single-owner control with Gnosis Safe.