// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
// Copyright (c) 2026 Friehub. All rights reserved.
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import {BLSApkRegistry} from "eigenlayer-middleware/src/BLSApkRegistry.sol";
import {IndexRegistry} from "eigenlayer-middleware/src/IndexRegistry.sol";
import {StakeRegistry} from "eigenlayer-middleware/src/StakeRegistry.sol";
import {SocketRegistry} from "eigenlayer-middleware/src/SocketRegistry.sol";
import {RegistryCoordinator} from "eigenlayer-middleware/src/RegistryCoordinator.sol";
import {ISlashingRegistryCoordinator} from "eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {IRegistryCoordinatorTypes} from "eigenlayer-middleware/src/interfaces/IRegistryCoordinator.sol";
import {IStakeRegistry} from "eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {IStrategy} from "eigenlayer-middleware/src/StakeRegistryStorage.sol";

import {IDelegationManager} from "@eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {IAVSDirectory} from "@eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {IAllocationManager} from "@eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {IPauserRegistry} from "@eigenlayer-contracts/src/contracts/interfaces/IPauserRegistry.sol";
import {IServiceManager} from "eigenlayer-middleware/src/interfaces/IServiceManager.sol";

import {PauserRegistry} from "@eigenlayer-contracts/src/contracts/permissions/PauserRegistry.sol";

/**
 * @title DeployTaaSMiddleware
 * @dev Deploys the full EigenLayer AVS middleware stack specifically for TaaS.
 * Solves circular dependency by predicting the RegistryCoordinator address.
 */
contract DeployTaaSMiddleware is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Sepolia Core Addresses (pulled from environment)
        IDelegationManager delegationManager = IDelegationManager(vm.envAddress("DELEGATION_MANAGER"));
        IAVSDirectory avsDirectory = IAVSDirectory(vm.envAddress("AVS_DIRECTORY"));
        IAllocationManager allocationManager = IAllocationManager(vm.envAddress("ALLOCATION_MANAGER"));
        
        vm.startBroadcast(deployerPrivateKey);

        // 0. Deploy PauserRegistry (Required by SlashingRegistryCoordinator)
        address[] memory pausers = new address[](1);
        pausers[0] = deployer;
        PauserRegistry pauserRegistry = new PauserRegistry(pausers, deployer);

        // Precompute the RegistryCoordinator address (it will be deployed after the 4 registries)
        // Registries: n+0, n+1, n+2, n+3. Coordinator: n+4.
        uint256 nonce = vm.getNonce(deployer);
        address predictedCoordinator = vm.computeCreateAddress(deployer, nonce + 4);
        ISlashingRegistryCoordinator coordinatorInterface = ISlashingRegistryCoordinator(predictedCoordinator);

        console.log("Predicted RegistryCoordinator:", predictedCoordinator);

        // 1. Deploy Registries
        BLSApkRegistry blsApkRegistry = new BLSApkRegistry(coordinatorInterface);
        IndexRegistry indexRegistry = new IndexRegistry(coordinatorInterface);
        StakeRegistry stakeRegistry = new StakeRegistry(
            coordinatorInterface,
            delegationManager,
            avsDirectory,
            allocationManager
        );
        SocketRegistry socketRegistry = new SocketRegistry(coordinatorInterface);

        // 2. Deploy RegistryCoordinator (Nonce n+4)
        IRegistryCoordinatorTypes.SlashingRegistryParams memory slashingParams = IRegistryCoordinatorTypes.SlashingRegistryParams({
            stakeRegistry: stakeRegistry,
            blsApkRegistry: blsApkRegistry,
            indexRegistry: indexRegistry,
            socketRegistry: socketRegistry,
            allocationManager: allocationManager,
            pauserRegistry: pauserRegistry
        });

        IRegistryCoordinatorTypes.RegistryCoordinatorParams memory coordinatorParams = IRegistryCoordinatorTypes.RegistryCoordinatorParams({
            serviceManager: IServiceManager(vm.envAddress("SERVICE_MANAGER_PROXY")),
            slashingParams: slashingParams
        });

        RegistryCoordinator registryCoordinator = new RegistryCoordinator(coordinatorParams);

        require(address(registryCoordinator) == predictedCoordinator, "Address prediction mismatch");

        console.log("-----------------------------------------");
        console.log("TaaS AVS Middleware Deployed (Sepolia)");
        console.log("RegistryCoordinator: ", address(registryCoordinator));
        console.log("StakeRegistry:       ", address(stakeRegistry));
        console.log("BLSApkRegistry:      ", address(blsApkRegistry));
        console.log("IndexRegistry:       ", address(indexRegistry));
        console.log("SocketRegistry:      ", address(socketRegistry));
        console.log("-----------------------------------------");

        vm.stopBroadcast();
    }
}
