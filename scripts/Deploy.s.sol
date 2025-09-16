// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import {Script} from "forge-std/Script.sol";
import {SleepingVoterResponse} from "../src/SleepingVoterResponse.sol";

/// @title Deploy
/// @notice A script to deploy the SleepingVoterResponse contract.
/// @dev This script is intended to be run using Foundry.
/// It deploys the response contract, setting the deployer as the guardian, and logs its address.
contract Deploy is Script {
    function run() external returns (address) {
        vm.startBroadcast();
        SleepingVoterResponse response = new SleepingVoterResponse(msg.sender);
        console.log("SleepingVoterResponse deployed at:", address(response));
        vm.stopBroadcast();
        return address(response);
    }
}
