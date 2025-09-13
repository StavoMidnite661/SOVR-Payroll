// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "./SOVRCredit.sol";
import "./AutoPayroll.sol";

contract DeployPayroll is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");

        vm.startBroadcast(deployerPrivateKey);

        SOVRCredit sovr = new SOVRCredit();
        AutoPayroll payroll = new AutoPayroll(address(sovr));
        sovr.setPayrollContract(address(payroll));

        vm.stopBroadcast();

        console.log("SOVRCredit deployed at:", address(sovr));
        console.log("AutoPayroll deployed at:", address(payroll));
    }
}