💀⚡ Aye, Captain — now we draw the final blades: the on‑chain smart contracts that make the whole payroll fortress real. These are the beating heart: SOVRCredit.sol (your stable unit of payroll accounting, minted & burned) and AutoPayroll.sol (the contract employees interact with to claim salaries).

I’ll forge these in battle‑ready Solidity (0.8.x), stripped down to essentials but hardened with events, modifiers, access control, and reconciliation guarantees.

⚔️ SOVRCredit.sol

This is your "payroll currency" — minted to represent owed salaries, and burned upon payout. Think of it as an ERC20‑style credit voucher, but tightly controlled by the Payroll contract.

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SOVR Credits - Payroll Credit Token
/// @notice Minted when payrolls are registered, burned upon fiat payout reconciliation.
contract SOVRCredit {
    string public name = "SOVR Credit";
    string public symbol = "SOVRC";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    address public payrollContract;
    address public owner;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Mint(address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyPayroll() {
        require(msg.sender == payrollContract, "Not payroll contract");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setPayrollContract(address _payroll) external onlyOwner {
        payrollContract = _payroll;
    }

    /// Mint only from payroll contract
    function mint(address _to, uint256 _amount) external onlyPayroll {
        totalSupply += _amount;
        balanceOf[_to] += _amount;
        emit Mint(_to, _amount);
        emit Transfer(address(0), _to, _amount);
    }

    /// Burn called after completed payout
    function burn(address _from, uint256 _amount) external onlyPayroll {
        require(balanceOf[_from] >= _amount, "Insufficient balance");
        balanceOf[_from] -= _amount;
        totalSupply -= _amount;
        emit Burn(_from, _amount);
        emit Transfer(_from, address(0), _amount);
    }
}

⚔️ AutoPayroll.sol

This is the orchestrator. Employers/funding accounts can deposit credits for employees. Employees then claim salary → emits SalaryClaimed(employee, amount) which Consul listens to off‑chain. When payout is confirmed, Consul calls back markPaid + burns those SOVRCredits.

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SOVRCredit.sol";

/// @title AutoPayroll - Claims & Payout Lifecycle
/// @notice Employees claim salary credits, off-chain Consul reconciles payout & burns credits.
contract AutoPayroll {
    struct Employee {
        uint256 salaryOwed;     // Credits awaiting claim
        uint256 lastClaimTs;    // Last time claimed
    }

    mapping(address => Employee) public employees;
    address public owner;
    SOVRCredit public sovr;

    event SalaryFunded(address indexed employee, uint256 amount);
    event SalaryClaimed(address indexed employee, uint256 amount, uint256 ts);
    event SalaryReconciled(address indexed employee, uint256 amount, uint256 ts);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _sovr) {
        owner = msg.sender;
        sovr = SOVRCredit(_sovr);
    }

    /// Fund payroll obligation for employee.
    function fundSalary(address _employee, uint256 _amount) external onlyOwner {
        employees[_employee].salaryOwed += _amount;
        sovr.mint(_employee, _amount);
        emit SalaryFunded(_employee, _amount);
    }

    /// Employee claims their owed salary credits.
    function claimSalary(uint256 _amount) external {
        Employee storage emp = employees[msg.sender];
        require(emp.salaryOwed >= _amount, "Not enough salary owed");
        emp.salaryOwed -= _amount;
        emp.lastClaimTs = block.timestamp;

        // Emit event for Consul listener
        emit SalaryClaimed(msg.sender, _amount, block.timestamp);
    }

    /// Consul calls this post-payout to burn credits & finalize reconciliation.
    function reconcile(address _employee, uint256 _amount) external onlyOwner {
        sovr.burn(_employee, _amount);
        emit SalaryReconciled(_employee, _amount, block.timestamp);
    }
}

🔑 Lifecycle Recap

Employer funds salary:
fundSalary(employee, amount) → mints SOVRCredits → SalaryFunded event.

Employee claims:
claimSalary(amount) → emits SalaryClaimed.
⚡ Consul listens → routes to Stripe API.

Consul confirms payout:
reconcile(employee, amount) → burns credits → SalaryReconciled event.

🏆 Captain’s Arsenal Outcomes

Events define the battlefield:

⚡ SalaryClaimed → triggers off-chain payout.
💳 Stripe executes payout.
🔥 SalaryReconciled ensures credits burned.

On-chain state + off-chain state locked tight.

Auditable → Operator Dashboard + Proof Explorer mirror events.

💀⚡ Captain — do you want me to also write the Foundry/Hardhat test suite for these contracts (firing fund → claim → reconcile cycle, asserting balances + events)? That way, before you deploy final blade, the crew already sees the contracts slice clean in simulation?