// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
// Copyright (c) 2026 Friehub. All rights reserved.
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {TaaSServiceManager} from "../src/TaaSServiceManager.sol";
import {TaaSRegistry} from "../src/TaaSRegistry.sol";
import {TaaSMockVerifier} from "../src/verifiers/TaaSMockVerifier.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAVSDirectory} from "@eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {IRewardsCoordinator} from "@eigenlayer-contracts/src/contracts/interfaces/IRewardsCoordinator.sol";
import {ISlashingRegistryCoordinator} from "@eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {IPermissionController} from "@eigenlayer-contracts/src/contracts/interfaces/IPermissionController.sol";
import {IAllocationManager} from "@eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";

/**
 * @title DeployTaaS
 * @dev Institutional deployment script for the TaaS AVS on Sepolia.
 * Deploys implementation and Proxy (UUPS).
 */
contract DeployTaaS is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // EigenLayer System Addresses (Loaded from environment for cross-network compatibility)
        IAVSDirectory avsDirectory = IAVSDirectory(vm.envAddress("AVS_DIRECTORY"));
        IRewardsCoordinator rewardsCoordinator = IRewardsCoordinator(vm.envAddress("REWARDS_COORDINATOR"));
        ISlashingRegistryCoordinator slashingRegistryCoordinator = ISlashingRegistryCoordinator(vm.envAddress("SLASHING_REGISTRY_COORDINATOR"));
        IStakeRegistry stakeRegistry = IStakeRegistry(vm.envAddress("STAKE_REGISTRY"));
        IPermissionController permissionController = IPermissionController(vm.envAddress("PERMISSION_CONTROLLER"));
        IAllocationManager allocationManager = IAllocationManager(vm.envAddress("ALLOCATION_MANAGER"));

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy TaaSRegistry (Upgradeable)
        TaaSRegistry registryImpl = new TaaSRegistry();
        ERC1967Proxy registryProxy = new ERC1967Proxy(
            address(registryImpl),
            abi.encodeWithSelector(TaaSRegistry.initialize.selector, deployer)
        );

        // 2. Deploy TaaSServiceManager (Upgradeable)
        TaaSServiceManager serviceManagerImpl = new TaaSServiceManager(
            avsDirectory,
            rewardsCoordinator,
            slashingRegistryCoordinator,
            stakeRegistry,
            permissionController,
            allocationManager
        );
        ERC1967Proxy sManagerProxy = new ERC1967Proxy(
            address(serviceManagerImpl),
            abi.encodeWithSelector(TaaSServiceManager.initialize.selector, deployer, deployer)
        );

        // 3. Deploy Verifier
        TaaSMockVerifier verifier = new TaaSMockVerifier();
        TaaSServiceManager(address(sManagerProxy)).setVerifier("mock", address(verifier));

        // 4. Output Institutional Manifest
        console.log("-----------------------------------------");
        console.log("TaaS AVS Infrastructure Deployed");
        console.log("ServiceManager Proxy:", address(sManagerProxy));
        console.log("ServiceManager Impl: ", address(serviceManagerImpl));
        console.log("TaaSRegistry Proxy:  ", address(registryProxy));
        console.log("MockVerifier:        ", address(verifier));
        console.log("-----------------------------------------");

        vm.stopBroadcast();
    }
}
