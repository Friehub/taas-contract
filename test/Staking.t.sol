// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {TaaSServiceManager} from "../src/TaaSServiceManager.sol";
import {ITaaSServiceManager} from "../src/ITaaSServiceManager.sol";
import {IAVSDirectory} from "@eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {IRewardsCoordinator} from "@eigenlayer-contracts/src/contracts/interfaces/IRewardsCoordinator.sol";
import {ISlashingRegistryCoordinator} from "@eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {IPermissionController} from "@eigenlayer-contracts/src/contracts/interfaces/IPermissionController.sol";
import {IAllocationManager} from "@eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";

// Import Proxy for UUPS testing
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract StakingTest is Test {
    TaaSServiceManager impl;
    TaaSServiceManager serviceManager;
    address stakeRegistry = address(0x123); // Dummy address for mocking
    address owner = address(1);
    address operator = address(2);

    function setUp() public {
        // 1. Deploy Implementation
        impl = new TaaSServiceManager(
            IAVSDirectory(address(0)),
            IRewardsCoordinator(address(0)),
            ISlashingRegistryCoordinator(address(0)),
            IStakeRegistry(stakeRegistry),
            IPermissionController(address(0)),
            IAllocationManager(address(0))
        );
        
        // 2. Deploy Proxy and Initialize
        bytes memory initData = abi.encodeWithSelector(
            TaaSServiceManager.initialize.selector,
            owner,
            owner
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        serviceManager = TaaSServiceManager(address(proxy));
    }

    /**
     * @notice Helper to mock operator weight in the StakeRegistry
     */
    function mockOperatorStake(address _operator, uint256 _amount) internal {
        vm.mockCall(
            stakeRegistry,
            abi.encodeWithSignature("weightOfOperatorForQuorum(uint8,address)", 0, _operator),
            abi.encode(uint96(_amount))
        );
    }

    function test_RespondFailsWithLowStake() public {
        vm.prank(owner);
        bytes32 taskId = serviceManager.createNewTask("test", "", ITaaSServiceManager.AggregationStrategy.MAJORITY, 3, 67, uint64(block.timestamp + 1 hours));
        
        mockOperatorStake(operator, 0.5 ether);
        
        TaaSServiceManager.TeeProof memory emptyProof;
        
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(
            TaaSServiceManager.InsufficientStake.selector, 
            operator, 
            0.5 ether, 
            1 ether
        ));
        serviceManager.respondToTask(taskId, keccak256("result"), "", emptyProof);
    }

    function test_RespondSucceedsWithHighStake() public {
        vm.prank(owner);
        bytes32 taskId = serviceManager.createNewTask("test", "", ITaaSServiceManager.AggregationStrategy.MAJORITY, 3, 67, uint64(block.timestamp + 1 hours));
        
        mockOperatorStake(operator, 1 ether);
        
        TaaSServiceManager.TeeProof memory emptyProof;
        
        vm.prank(operator);
        serviceManager.respondToTask(taskId, keccak256("result"), "", emptyProof);
        
        (,,,,,,,bool completed, ) = serviceManager.tasks(taskId);
        assertTrue(completed);
    }
}
