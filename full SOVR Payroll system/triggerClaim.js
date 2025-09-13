// scripts/triggerClaim.js
require("dotenv").config();
const { ethers } = require("ethers");
const yargs = require("yargs/yargs");
const { hideBin } = require("yargs/helpers");

const argv = yargs(hideBin(process.argv))
  .option("amount", {
    alias: "a",
    type: "number",
    description: "The amount of salary to claim in USD",
    demandOption: true,
  })
  .argv;

const RPC_URL = process.env.RPC_URL;
const PAYROLL_ADDRESS = process.env.PAYROLL_ADDRESS;
const EMPLOYEE_PK = process.env.EMPLOYEE_PK;

if (!RPC_URL || !PAYROLL_ADDRESS || !EMPLOYEE_PK) {
  console.error("ERROR: Missing RPC_URL, PAYROLL_ADDRESS, or EMPLOYEE_PK from environment.");
  process.exit(1);
}

const payrollAbi = [
  "function claimSalary(uint256 amount) external"
];

(async () => {
  try {
    const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
    const employeeWallet = new ethers.Wallet(EMPLOYEE_PK, provider);
    const payrollContract = new ethers.Contract(
      PAYROLL_ADDRESS,
      payrollAbi,
      employeeWallet
    );

    const amountInWei = ethers.utils.parseUnits(argv.amount.toString(), 18);

    console.log(`Triggering claimSalary() from employee: ${employeeWallet.address}...`);
    const tx = await payrollContract.claimSalary(amountInWei);
    console.log(`Transaction sent: ${tx.hash}`);
    const receipt = await tx.wait();
    console.log(`Claim confirmed on-chain in block ${receipt.blockNumber}`);
  } catch (error) {
    console.error("ERROR: Failed to trigger claim:", error.reason || error.message);
    process.exit(1);
  }
})();