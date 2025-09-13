// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/SOVRCredit.sol";
import "../contracts/AutoPayroll.sol";

contract PayrollTest is Test {
    SOVRCredit sovr;
    AutoPayroll payroll;

    address owner = address(this);
    address employee1 = vm.addr(1);
    address employee2 = vm.addr(2);
    address nonOwner = vm.addr(3);

    function setUp() public {
        vm.startPrank(owner);
        sovr = new SOVRCredit();
        payroll = new AutoPayroll(address(sovr));
        sovr.setPayrollContract(address(payroll));
        vm.stopPrank();
    }

    function test_AddEmployees() public {
        address[] memory employeesToAdd = new address[](2);
        employeesToAdd[0] = employee1;
        employeesToAdd[1] = employee2;

        vm.prank(owner);
        payroll.addEmployees(employeesToAdd);

        assertTrue(payroll.isEmployee(employee1));
        assertTrue(payroll.isEmployee(employee2));
        assertEq(payroll.getEmployeeCount(), 2);
    }

    function test_RemoveEmployee() public {
        address[] memory employeesToAdd = new address[](2);
        employeesToAdd[0] = employee1;
        employeesToAdd[1] = employee2;
        vm.prank(owner);
        payroll.addEmployees(employeesToAdd);

        vm.prank(owner);
        payroll.removeEmployee(employee1);

        assertFalse(payroll.isEmployee(employee1));
        assertTrue(payroll.isEmployee(employee2)); // Ensure the other is still there
        assertEq(payroll.getEmployeeCount(), 1);
    }

    function test_DistributePayroll() public {
        // Add employees first
        address[] memory employeesToAdd = new address[](1);
        employeesToAdd[0] = employee1;
        vm.prank(owner);
        payroll.addEmployees(employeesToAdd);

        // Prepare distribution
        address[] memory employeesToPay = new address[](1);
        employeesToPay[0] = employee1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000 ether;

        // Distribute
        vm.prank(owner);
        payroll.distributePayroll(employeesToPay, amounts);

        assertEq(sovr.balanceOf(employee1), 1000 ether);
    }

    function test_Fail_DistributePayrollTooEarly() public {
        // Add employees
        address[] memory employeesToAdd = new address[](1);
        employeesToAdd[0] = employee1;
        vm.prank(owner);
        payroll.addEmployees(employeesToAdd);

        // Prepare distribution
        address[] memory employeesToPay = new address[](1);
        employeesToPay[0] = employee1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000 ether;

        // First distribution
        vm.prank(owner);
        payroll.distributePayroll(employeesToPay, amounts);

        // Try to distribute again immediately
        vm.prank(owner);
        vm.expectRevert("Too early");
        payroll.distributePayroll(employeesToPay, amounts);
    }

    function test_EmergencyPause() public {
        vm.prank(owner);
        payroll.pause();
        assertTrue(payroll.paused());

        // Prepare distribution
        address[] memory employeesToPay = new address[](1);
        employeesToPay[0] = employee1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000 ether;

        // Expect revert because it's paused
        vm.prank(owner);
        vm.expectRevert("Pausable: paused");
        payroll.distributePayroll(employeesToPay, amounts);

        // Unpause and try again
        vm.prank(owner);
        payroll.unpause();
        assertFalse(payroll.paused());

        vm.prank(owner);
        payroll.distributePayroll(employeesToPay, amounts);
        assertEq(sovr.balanceOf(employee1), 1000 ether);
    }

    function test_Fail_NonOwnerCannotAddEmployees() public {
        address[] memory employeesToAdd = new address[](1);
        employeesToAdd[0] = employee1;

        vm.prank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        payroll.addEmployees(employeesToAdd);
    }
}