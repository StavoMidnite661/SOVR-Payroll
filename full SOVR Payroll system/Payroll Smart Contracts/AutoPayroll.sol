// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SOVRCredit.sol";

contract AutoPayroll {
    struct Employee {
        uint256 salaryOwed;
        uint256 lastClaimTs;
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

    function fundSalary(address _employee, uint256 _amount) external onlyOwner {
        employees[_employee].salaryOwed += _amount;
        sovr.mint(_employee, _amount);
        emit SalaryFunded(_employee, _amount);
    }

    function claimSalary(uint256 _amount) external {
        Employee storage emp = employees[msg.sender];
        require(emp.salaryOwed >= _amount, "Not enough salary owed");
        emp.salaryOwed -= _amount;
        emp.lastClaimTs = block.timestamp;
        emit SalaryClaimed(msg.sender, _amount, block.timestamp);
    }

    function reconcile(address _employee, uint256 _amount) external onlyOwner {
        sovr.burn(_employee, _amount);
        emit SalaryReconciled(_employee, _amount, block.timestamp);
    }
}