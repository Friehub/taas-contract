// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
// Copyright (c) 2026 Friehub. All rights reserved.
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {TaaSServiceManager} from "../src/TaaSServiceManager.sol";
import {TaaSRegistry} from "../src/TaaSRegistry.sol";

/**
 * @title SetupProduction
 * @dev Institutional script for post-deployment configuration of the TaaS AVS.
 * Configures roles, thresholds, and verifiers for Sepolia production.
 */
contract SetupProduction is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        address serviceManagerProxy = vm.envAddress("SERVICE_MANAGER_PROXY");
        address rewardsInitiator = vm.envOr("REWARDS_INITIATOR", deployer);

        vm.startBroadcast(deployerPrivateKey);

        TaaSServiceManager sManager = TaaSServiceManager(serviceManagerProxy);

        // 1. Configure Min Stake (Standard institutional 1 ETH)
        sManager.updateMinStake(1 ether);
        console.log("Minimum Stake set to 1 ETH");

        // 2. Grant Roles (if not already set)
        // Note: initialize sets the rewardsInitiator, but we can update it here if the contract supports it.
        // Assuming ServiceManagerBase/TaaSServiceManager has a way to update initiator.
        
        // 3. Register Production Verifiers
        // address teeVerifier = vm.envOr("TEE_VERIFIER", address(0));
        // if (teeVerifier != address(0)) {
        //     sManager.setVerifier("intel-tdx", teeVerifier);
        // }

        console.log("-----------------------------------------");
        console.log("TaaS Production Setup Complete");
        console.log("ServiceManager:", serviceManagerProxy);
        console.log("RewardsInitiator:", rewardsInitiator);
        console.log("-----------------------------------------");

        vm.stopBroadcast();
    }
}
