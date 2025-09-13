// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/SOVRCredit.sol";
import "../contracts/AutoPayroll.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy contracts
        SOVRCredit sovr = new SOVRCredit();
        AutoPayroll payroll = new AutoPayroll(address(sovr));
        
        // Set payroll contract in token
        sovr.setPayrollContract(address(payroll));

        vm.stopBroadcast();

        console.log("SOVRCredit deployed at:", address(sovr));
        console.log("AutoPayroll deployed at:", address(payroll));
        console.log("Deployment successful!");
    }
}