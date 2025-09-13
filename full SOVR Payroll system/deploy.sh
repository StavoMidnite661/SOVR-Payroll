#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.
set -o pipefail # The return value of a pipeline is the status of the last command to exit with a non-zero status.

echo "SOVR Payroll Deployment Script"
echo "=============================="

# 1. Load Environment Variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "ERROR: .env file not found. Please create one with DEPLOYER_PRIVATE_KEY, OPERATOR_PRIVATE_KEY, RPC_URL, and ETHERSCAN_API_KEY."
    exit 1
fi

# Check for required variables
if [ -z "$DEPLOYER_PRIVATE_KEY" ] || [ -z "$OPERATOR_PRIVATE_KEY" ] || [ -z "$RPC_URL" ] || [ -z "$ETHERSCAN_API_KEY" ]; then
    echo "ERROR: Missing required environment variables in .env file. Check for DEPLOYER_PRIVATE_KEY, OPERATOR_PRIVATE_KEY, RPC_URL, ETHERSCAN_API_KEY."
    exit 1
fi

echo "Environment variables loaded."

# 2. Deploy & Verify Contracts
echo "Deploying contracts to Sepolia... (This may take a moment)"

# Use a temporary file to capture the deployment output
DEPLOY_OUTPUT_FILE=$(mktemp)

forge script script/Deploy.s.sol:Deploy \
  --rpc-url $RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast --verify | tee $DEPLOY_OUTPUT_FILE

# 3. Extract Contract Addresses
echo "Extracting contract addresses..."
SOVRC_ADDRESS=$(grep 'SOVRCredit:' $DEPLOY_OUTPUT_FILE | awk '{print $2}')
PAYROLL_ADDRESS=$(grep 'AutoPayroll:' $DEPLOY_OUTPUT_FILE | awk '{print $2}')
DEPLOYER_ADDRESS=$(cast wallet address $DEPLOYER_PRIVATE_KEY)
OPERATOR_ADDRESS=$(cast wallet address $OPERATOR_PRIVATE_KEY)

if [ -z "$SOVRC_ADDRESS" ] || [ -z "$PAYROLL_ADDRESS" ]; then
    echo "ERROR: Failed to extract contract addresses from deployment output."
    rm $DEPLOY_OUTPUT_FILE
    exit 1
fi

echo "  - SOVRCredit: $SOVRC_ADDRESS"
echo "  - AutoPayroll: $PAYROLL_ADDRESS"
echo "  - Deployer: $DEPLOYER_ADDRESS"
echo "  - Operator: $OPERATOR_ADDRESS"

# 4. Post-Deployment Setup
echo "Funding payroll contract and setting permissions..."

echo "  - Minting 1,000,000 SOVRCredit to deployer..."
cast send $SOVRC_ADDRESS "mint(address,uint256)" $DEPLOYER_ADDRESS 1000000e18 \
  --rpc-url $RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --legacy

echo "  - Transferring 500,000 SOVRCredit to AutoPayroll contract..."
cast send $SOVRC_ADDRESS "transfer(address,uint256)" $PAYROLL_ADDRESS 500000e18 \
  --rpc-url $RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --legacy

echo "  - Granting BURNER_ROLE to the Operator address..."
BURNER_ROLE=$(cast call $SOVRC_ADDRESS "BURNER_ROLE()")
cast send $SOVRC_ADDRESS "grantRole(bytes32,address)" $BURNER_ROLE $OPERATOR_ADDRESS \
  --rpc-url $RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --legacy

echo "Post-deployment setup complete."

# 5. Generate Deployments File
echo "Generating deployments.json..."
NETWORK_NAME="sepolia" # This could be made dynamic later

jq -n \
  --arg sovr_address "$SOVRC_ADDRESS" \
  --arg payroll_address "$PAYROLL_ADDRESS" \
  '{ ($network): { "SOVRCredit": $sovr_address, "AutoPayroll": $payroll_address } }' --arg network "$NETWORK_NAME" > deployments.json

echo "deployments.json file created/updated."

# 6. Clean up and Finish
rm $DEPLOY_OUTPUT_FILE
echo -e "\nDeployment and setup complete."
echo "The AutoPayroll contract is at: $PAYROLL_ADDRESS"
echo "You can now add employees (Step 5) and start the listener (Step 7)."
