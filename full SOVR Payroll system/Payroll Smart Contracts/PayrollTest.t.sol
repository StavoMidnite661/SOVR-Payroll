// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./SOVRCredit.sol";
import "./AutoPayroll.sol";

contract PayrollTest is Test {
    SOVRCredit sovr;
    AutoPayroll payroll;
    address owner = address(this);
    address employee = address(0xBEEF);

    event SalaryClaimed(address indexed emp, uint256 amount, uint256 ts);

    function setUp() public {
        sovr = new SOVRCredit();
        payroll = new AutoPayroll(address(sovr));
        sovr.setPayrollContract(address(payroll));
    }

    function testFundSalaryMintsCredits() public {
        payroll.fundSalary(employee, 100 ether);
        assertEq(sovr.balanceOf(employee), 100 ether);
        assertEq(payroll.employees(employee).salaryOwed, 100 ether);
    }

    function testEmployeeClaim() public {
        payroll.fundSalary(employee, 50 ether);
        vm.startPrank(employee);
        vm.expectEmit(true, true, true, true);
        emit SalaryClaimed(employee, 50 ether, block.timestamp);
        payroll.claimSalary(50 ether);
        vm.stopPrank();
        assertEq(payroll.employees(employee).salaryOwed, 0);
    }

    function testReconcileBurnsCredits() public {
        uint256 amount = 25 ether;
        payroll.fundSalary(employee, amount);
        vm.prank(employee);
        payroll.claimSalary(25 ether);

        uint256 beforeBal = sovr.balanceOf(employee);
        payroll.reconcile(employee, 25 ether);
        uint256 afterBal = sovr.balanceOf(employee);

        assertEq(beforeBal - afterBal, 25 ether);
    }

    function testNonOperatorCannotBurn() public {
        payroll.fundSalary(employee, 10 ether);
        vm.prank(employee);
        payroll.claimSalary(10 ether);
        vm.stopPrank();

        vm.prank(employee); // Non-owner trying to reconcile
        vm.expectRevert("Not owner");
        payroll.reconcile(employee, 10 ether);
    }
}