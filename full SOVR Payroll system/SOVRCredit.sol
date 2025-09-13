// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract SOVRCredit is ERC20, ERC20Permit, Ownable, ReentrancyGuard, Pausable {
    address public payrollContract;
    
    // Events for transparency
    event PayrollContractUpdated(address indexed oldPayroll, address indexed newPayroll);
    event TokensBurned(address indexed from, uint256 amount);
    event TokensMinted(address indexed to, uint256 amount);

    constructor() ERC20("SOVR Credit", "SOVR") ERC20Permit("SOVR Credit") {}

    // FIXED: Added mint function that only payroll can call
    function mint(address _to, uint256 _amount) external nonReentrant whenNotPaused {
        require(msg.sender == payrollContract, "Only payroll can mint");
        require(_to != address(0), "Zero address");
        require(_amount > 0, "Zero amount");
        
        _mint(_to, _amount);
        emit TokensMinted(_to, _amount);
    }

    // Only payroll or token holder can burn
    function burn(address _from, uint256 _amount) external nonReentrant whenNotPaused {
        require(_from != address(0), "Zero address");
        require(_amount > 0, "Zero amount");
        require(msg.sender == _from || msg.sender == payrollContract, "Unauthorized");
        
        _burn(_from, _amount);
        emit TokensBurned(_from, _amount);
    }

    // Only owner can set payroll
    function setPayrollContract(address _payroll) external onlyOwner {
        require(_payroll != address(0), "Zero address");
        address oldPayroll = payrollContract;
        payrollContract = _payroll;
        emit PayrollContractUpdated(oldPayroll, _payroll);
    }

    // Emergency pause/unpause
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Override transfer to respect pause
    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        super._update(from, to, value);
    }
}