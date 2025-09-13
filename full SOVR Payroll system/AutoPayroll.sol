// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./SOVRCredit.sol";

contract AutoPayroll is Ownable, ReentrancyGuard, Pausable {
    SOVRCredit public immutable sovrToken;
    uint256 public payrollInterval;
    uint256 public lastPayrollTime;
    uint256 public maxEmployeesPerBatch = 100; // Gas limit protection
    
    // Employee tracking
    mapping(address => bool) public isEmployee;
    address[] public employees;
    
    // Events
    event PayrollDistributed(uint256 totalAmount, uint256 employeeCount);
    event EmployeeAdded(address indexed employee);
    event EmployeeRemoved(address indexed employee);
    event PayrollIntervalUpdated(uint256 oldInterval, uint256 newInterval);

    constructor(address _sovrToken) {
        require(_sovrToken != address(0), "Zero address");
        sovrToken = SOVRCredit(_sovrToken);
        payrollInterval = 30 days;
        lastPayrollTime = block.timestamp;
    }

    // FIXED: Gas-optimized payroll distribution
    function distributePayroll(
        address[] calldata _employees,
        uint256[] calldata _amounts
    ) external nonReentrant onlyOwner whenNotPaused {
        uint256 length = _employees.length;
        require(length == _amounts.length, "Length mismatch");
        require(length <= maxEmployeesPerBatch, "Too many employees");
        require(block.timestamp >= lastPayrollTime + payrollInterval, "Too early");

        uint256 totalAmount = 0;
        
        // Gas-optimized loop with unchecked arithmetic
        for (uint256 i = 0; i < length;) {
            address employee = _employees[i];
            uint256 amount = _amounts[i];
            
            require(employee != address(0), "Zero address");
            require(amount > 0, "Zero amount");
            
            // FIXED: Call mint instead of _mint
            sovrToken.mint(employee, amount);
            
            unchecked {
                totalAmount += amount;
                ++i;
            }
        }
        
        lastPayrollTime = block.timestamp;
        emit PayrollDistributed(totalAmount, length);
    }

    // Batch add employees
    function addEmployees(address[] calldata _employees) external onlyOwner {
        for (uint256 i = 0; i < _employees.length;) {
            address employee = _employees[i];
            require(employee != address(0), "Zero address");
            
            if (!isEmployee[employee]) {
                isEmployee[employee] = true;
                employees.push(employee);
                emit EmployeeAdded(employee);
            }
            
            unchecked { ++i; }
        }
    }

    // Remove employee
    function removeEmployee(address _employee) external onlyOwner {
        require(isEmployee[_employee], "Not an employee");
        isEmployee[_employee] = false;
        
        // Find and remove from array
        for (uint256 i = 0; i < employees.length; i++) {
            if (employees[i] == _employee) {
                employees[i] = employees[employees.length - 1];
                employees.pop();
                break;
            }
        }
        
        emit EmployeeRemoved(_employee);
    }

    // Set new interval
    function setPayrollInterval(uint256 _interval) external onlyOwner {
        require(_interval >= 1 days, "Minimum 1 day");
        require(_interval <= 365 days, "Maximum 1 year");
        
        uint256 oldInterval = payrollInterval;
        payrollInterval = _interval;
        emit PayrollIntervalUpdated(oldInterval, _interval);
    }

    // Set max batch size
    function setMaxEmployeesPerBatch(uint256 _max) external onlyOwner {
        require(_max > 0 && _max <= 500, "Invalid batch size");
        maxEmployeesPerBatch = _max;
    }

    // Emergency controls
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // View functions
    function getEmployeeCount() external view returns (uint256) {
        return employees.length;
    }

    function canDistributePayroll() external view returns (bool) {
        return block.timestamp >= lastPayrollTime + payrollInterval;
    }
}