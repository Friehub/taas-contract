// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
// Copyright (c) 2026 Friehub. All rights reserved.
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {TaaSServiceManager} from "../src/TaaSServiceManager.sol";
import {TaaSRegistry} from "../src/TaaSRegistry.sol";
import {TruthPaymaster} from "../src/TruthPaymaster.sol";
import {TaaSMockVerifier} from "../src/verifiers/TaaSMockVerifier.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAVSDirectory} from "@eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {IRewardsCoordinator} from "@eigenlayer-contracts/src/contracts/interfaces/IRewardsCoordinator.sol";
import {ISlashingRegistryCoordinator} from "@eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {IPermissionController} from "@eigenlayer-contracts/src/contracts/interfaces/IPermissionController.sol";
import {IAllocationManager} from "@eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";

import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {SimpleAccountFactory} from "account-abstraction/samples/SimpleAccountFactory.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

/**
 * @title EndToEndSponsored
 * @dev Integration test script to setup a full sponsored execution environment on Anvil.
 */
contract EndToEndSponsored is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // For integration testing, we use dummy addresses for EigenLayer if not provided
        IAVSDirectory avsDirectory = IAVSDirectory(0x0000000000000000000000000000000000000001);
        IRewardsCoordinator rewardsCoordinator = IRewardsCoordinator(0x0000000000000000000000000000000000000002);
        ISlashingRegistryCoordinator slashingRegistryCoordinator = ISlashingRegistryCoordinator(address(0));
        IStakeRegistry stakeRegistry = IStakeRegistry(address(0));
        IPermissionController permissionController = IPermissionController(address(0));
        IAllocationManager allocationManager = IAllocationManager(address(0));

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy 4337 Infrastructure
        EntryPoint entryPoint = new EntryPoint();
        SimpleAccountFactory factory = new SimpleAccountFactory(entryPoint);
        
        // 2. Deploy TaaS Core
        TaaSRegistry registryImpl = new TaaSRegistry();
        ERC1967Proxy registryProxy = new ERC1967Proxy(
            address(registryImpl),
            abi.encodeWithSelector(TaaSRegistry.initialize.selector, deployer)
        );

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

        // 3. Deploy TruthPaymaster
        // verifiableSigner = deployer (the node's EOA in our test)
        TruthPaymaster paymaster = new TruthPaymaster(IEntryPoint(address(entryPoint)), deployer, deployer);
        
        // 4. Fund Paymaster in EntryPoint
        entryPoint.depositTo{value: 10 ether}(address(paymaster));

        // 5. Setup TaaS Metadata
        TaaSMockVerifier verifier = new TaaSMockVerifier();
        TaaSServiceManager(address(sManagerProxy)).setVerifier("mock", address(verifier));
        TaaSServiceManager(address(sManagerProxy)).setDisputeBond(0.1 ether);

        // 6. Deploy the Node's Smart Account (Predictable)
        // This simulates what 'hot-core account deploy' does
        factory.createAccount(deployer, 0);

        // 7. Output Institutional Manifest for Rust Integration
        console.log("-----------------------------------------");
        console.log("SPONSORED_TEST_MANIFEST");
        console.log("ENTRY_POINT=", address(entryPoint));
        console.log("ACCOUNT_FACTORY=", address(factory));
        console.log("SERVICE_MANAGER=", address(sManagerProxy));
        console.log("PAYMASTER=", address(paymaster));
        console.log("OPERATOR_EOA=", deployer);
        console.log("-----------------------------------------");

        vm.stopBroadcast();
    }
}
