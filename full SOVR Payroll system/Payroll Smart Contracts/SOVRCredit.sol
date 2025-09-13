// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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

    function mint(address _to, uint256 _amount) external onlyPayroll {
        totalSupply += _amount;
        balanceOf[_to] += _amount;
        emit Mint(_to, _amount);
        emit Transfer(address(0), _to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyPayroll {
        require(balanceOf[_from] >= _amount, "Insufficient balance");
        balanceOf[_from] -= _amount;
        totalSupply -= _amount;
        emit Burn(_from, _amount);
        emit Transfer(_from, address(0), _amount);
    }
}