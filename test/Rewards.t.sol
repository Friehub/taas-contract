// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {TaaSServiceManager} from "../src/TaaSServiceManager.sol";
import {MockRewardsToken} from "../src/test/MockRewardsToken.sol";
import {IAVSDirectory} from "@eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {IRewardsCoordinator} from "@eigenlayer-contracts/src/contracts/interfaces/IRewardsCoordinator.sol";
import {IRewardsCoordinatorTypes} from "@eigenlayer-contracts/src/contracts/interfaces/IRewardsCoordinator.sol";
import {ISlashingRegistryCoordinator} from "@eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {IPermissionController} from "@eigenlayer-contracts/src/contracts/interfaces/IPermissionController.sol";
import {IAllocationManager} from "@eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {IServiceManager, IServiceManagerErrors} from "@eigenlayer-middleware/src/interfaces/IServiceManager.sol";

contract RewardsTest is Test {
    TaaSServiceManager impl;
    TaaSServiceManager serviceManager;
    MockRewardsToken token;
    address rewardsCoordinator = address(0x789);
    address owner = address(1);
    address rewardsInitiator = address(2);

    function setUp() public {
        token = new MockRewardsToken();
        
        impl = new TaaSServiceManager(
            IAVSDirectory(address(0)),
            IRewardsCoordinator(rewardsCoordinator),
            ISlashingRegistryCoordinator(address(0)),
            IStakeRegistry(address(0)),
            IPermissionController(address(0)),
            IAllocationManager(address(0))
        );
        
        bytes memory initData = abi.encodeWithSelector(
            TaaSServiceManager.initialize.selector,
            owner,
            rewardsInitiator
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        serviceManager = TaaSServiceManager(address(proxy));
    }

    function test_CreateRewardsSubmission() public {
        // 1. Prepare submission data
        IRewardsCoordinatorTypes.RewardsSubmission[] memory submissions = new IRewardsCoordinatorTypes.RewardsSubmission[](1);
        submissions[0] = IRewardsCoordinatorTypes.RewardsSubmission({
            strategiesAndMultipliers: new IRewardsCoordinatorTypes.StrategyAndMultiplier[](0),
            token: token,
            amount: 100 ether,
            startTimestamp: uint32(block.timestamp),
            duration: 86400
        });

        // 2. Fund the rewardsInitiator and approve the ServiceManager
        token.transfer(rewardsInitiator, 100 ether);
        
        vm.prank(rewardsInitiator);
        token.approve(address(serviceManager), 100 ether);
        
        // Mock the RewardsCoordinator call
        vm.mockCall(
            rewardsCoordinator,
            abi.encodeWithSelector(IRewardsCoordinator.createAVSRewardsSubmission.selector),
            abi.encode(true) // Return something if needed, but it's void
        );

        vm.prank(rewardsInitiator);
        serviceManager.createAVSRewardsSubmission(submissions);
    }

    function test_OnlyRewardsInitiatorCanSubmit() public {
        IRewardsCoordinatorTypes.RewardsSubmission[] memory submissions = new IRewardsCoordinatorTypes.RewardsSubmission[](0);
        
        vm.prank(address(0xdead));
        vm.expectRevert(IServiceManagerErrors.OnlyRewardsInitiator.selector);
        serviceManager.createAVSRewardsSubmission(submissions);
    }
}
