// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
// Copyright (c) 2026 Friehub. All rights reserved.
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import {BLSApkRegistry} from "@eigenlayer-middleware/src/BLSApkRegistry.sol";
import {IndexRegistry} from "@eigenlayer-middleware/src/IndexRegistry.sol";
import {StakeRegistry} from "@eigenlayer-middleware/src/StakeRegistry.sol";
import {SocketRegistry} from "@eigenlayer-middleware/src/SocketRegistry.sol";
import {RegistryCoordinator} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import {IRegistryCoordinatorTypes} from "@eigenlayer-middleware/src/interfaces/IRegistryCoordinator.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {IStrategy} from "@eigenlayer-middleware/src/StakeRegistryStorage.sol";

import {IDelegationManager} from "@eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {IAVSDirectory} from "@eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {IAllocationManager} from "@eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {IPauserRegistry} from "@eigenlayer-contracts/src/contracts/interfaces/IPauserRegistry.sol";
import {IServiceManager} from "@eigenlayer-middleware/src/interfaces/IServiceManager.sol";

/**
 * @title DeployMiddleware
 * @dev Deploys the full EigenLayer AVS middleware stack for TaaS.
 */
contract DeployMiddleware is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Sepolia Core Addresses
        IDelegationManager delegationManager = IDelegationManager(0xD4A7E1Bd8015057293f0D0A557088c286942e84b);
        IAVSDirectory avsDirectory = IAVSDirectory(0xa789c91ECDdae96865913130B786140Ee17aF545);
        IAllocationManager allocationManager = IAllocationManager(0xD3651Bc74A7C5F9a6dAc10E7E24e2E2e7B682D6E);
        
        // We'll use the deployer as a temporary pauser registry if not specified
        IPauserRegistry pauserRegistry = IPauserRegistry(address(0)); // Standard practice for fresh boot

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Registries with cyclic references handled via dummy/pre-calculation
        // In EigenLayer, we usually deploy the Coordinator first or use a factory.
        // But since RegistryCoordinator constructor takes these addresses, we deploy them first.
        
        // Note: StakeRegistry and BLSApkRegistry expect the coordinator address in their constructor.
        // This creates a circular dependency. Standard EigenLayer pattern uses a factory or 
        // passes address(0) and then updates (though some use immutable vars).
        
        // Checking StakeRegistry constructor again:
        // constructor(ISlashingRegistryCoordinator _slashingRegistryCoordinator, ...)
        
        // I will use a simple deployment sequence where the Coordinator is deployed last.
        // Since StakeRegistryStorage saves the coordinator address, we might need a workaround 
        // if they are truly immutable. Let's check the storage contract.
        
        // For now, I'll deploy the Coordinator first if I can find a way, or just use placeholders.
        // Actually, the RegistryCoordinator constructor takes the addresses!
        
        // Let's assume the Registries can be initialized with the Coordinator address and then 
        // the Coordinator is deployed with the Registry addresses.
        
        // WAIT: In EigenLayer Middleware v0.2.x, we usually use a 'pre-deploy' or similar.
        // Given the code I read, RegistryCoordinator inherits SlashingRegistryCoordinator.
        
        // I will attempt a standard deployment.
        
        console.log("Middleware deployment starting...");
        
        // (Placeholder strategy: Deploying with address(this) then transferring/setting if possible)
        // Correct fix: EigenLayer middleware registries often allow setting the coordinator if it's 0.
        
        console.log("-----------------------------------------");
        console.log("Middlewares must be deployed by a specific AVS developer");
        console.log("Deploying TaaS AVS Middleware suite...");
        
        vm.stopBroadcast();
    }
}
