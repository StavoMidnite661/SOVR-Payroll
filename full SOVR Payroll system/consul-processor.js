require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { ethers } = require('ethers');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

const employeeRegistryPath = path.join(__dirname, 'employeeRegistry.json');

if (!process.env.STRIPE_SECRET_KEY) {
    console.error("[PROCESSOR] ERROR: STRIPE_SECRET_KEY not found in environment variables. Service cannot start.");
    process.exit(1);
}

/**
 * Processes a fiat payout for a given employee using the Stripe API.
 * @param {string} employeeAddress The Ethereum address of the employee.
 * @param {ethers.BigNumber} amount The amount to pay out in wei.
 * @returns {Promise<{success: boolean, transferId?: string, mode?: string}>} An object indicating success and containing transfer details.
 */
async function processPayout(employeeAddress, amount) {
    let employeeRegistry;
    try {
        employeeRegistry = JSON.parse(fs.readFileSync(employeeRegistryPath, 'utf8'));
    } catch (error) {
        console.error(`[PROCESSOR] ERROR: Could not read or parse employeeRegistry.json:`, error);
        return { success: false };
    }
    
    // Normalize address to handle checksum differences before lookup
    const employeeConfig = employeeRegistry[employeeAddress.toLowerCase()] || employeeRegistry[ethers.utils.getAddress(employeeAddress)];
    const stripeAccountId = employeeConfig ? employeeConfig.connectedAccountId : undefined;

    if (!stripeAccountId) {
        console.error(`[PROCESSOR] ERROR: No Stripe account ID found for employee ${employeeAddress} in registry.`);
        return { success: false };
    }

    const amountInUSD = parseFloat(ethers.utils.formatEther(amount));
    const amountInCents = Math.round(amountInUSD * 100);

    console.log(`[PROCESSOR] Initiating payout of $${amountInUSD.toFixed(2)} to Stripe account ${stripeAccountId}.`);

    try {
        const transfer = await stripe.transfers.create({
            amount: amountInCents,
            currency: 'usd',
            destination: stripeAccountId,
            metadata: {
                employee_eth_address: employeeAddress,
                payroll_event_id: `sovr_payroll_${Date.now()}`
            }
        });

        console.log(`[PROCESSOR] Stripe transfer successful. ID: ${transfer.id} | Mode: ${transfer.livemode ? 'live' : 'test'}`);
        return {
            success: true,
            transferId: transfer.id,
            mode: transfer.livemode ? "live" : "test"
        };
    } catch (error) {
        console.error(`[PROCESSOR] ERROR: Stripe API call failed:`, error.message);
        return { success: false };
    }
}

module.exports = { processPayout };