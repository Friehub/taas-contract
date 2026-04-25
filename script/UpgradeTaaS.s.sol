// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {TaaSServiceManager} from "../src/TaaSServiceManager.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IAVSDirectory} from "@eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {IRewardsCoordinator} from "@eigenlayer-contracts/src/contracts/interfaces/IRewardsCoordinator.sol";
import {ISlashingRegistryCoordinator} from "@eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {IPermissionController} from "@eigenlayer-contracts/src/contracts/interfaces/IPermissionController.sol";
import {IAllocationManager} from "@eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";

contract UpgradeTaaS is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address serviceManagerProxy = vm.envAddress("SERVICE_MANAGER_PROXY");

        // EigenLayer Sepolia System Addresses (from env)
        IAVSDirectory avsDirectory = IAVSDirectory(vm.envAddress("AVS_DIRECTORY"));
        IRewardsCoordinator rewardsCoordinator = IRewardsCoordinator(vm.envAddress("REWARDS_COORDINATOR"));
        ISlashingRegistryCoordinator slashingRegistryCoordinator = ISlashingRegistryCoordinator(vm.envAddress("SLASHING_REGISTRY_COORDINATOR"));
        IStakeRegistry stakeRegistry = IStakeRegistry(vm.envAddress("STAKE_REGISTRY"));
        IPermissionController permissionController = IPermissionController(vm.envAddress("PERMISSION_CONTROLLER"));
        IAllocationManager allocationManager = IAllocationManager(vm.envAddress("ALLOCATION_MANAGER"));

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy new Implementation
        console.log("Deploying new ServiceManager implementation...");
        TaaSServiceManager newImpl = new TaaSServiceManager(
            avsDirectory,
            rewardsCoordinator,
            slashingRegistryCoordinator,
            stakeRegistry,
            permissionController,
            allocationManager
        );
        console.log("New Implementation deployed at:", address(newImpl));

        // 2. Perform Upgrade
        console.log("Upgrading proxy at:", serviceManagerProxy);
        UUPSUpgradeable(serviceManagerProxy).upgradeTo(address(newImpl));
        console.log("Upgrade successful.");

        vm.stopBroadcast();
    }
}
