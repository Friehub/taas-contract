// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/TaaSServiceManager.sol";
import "../src/ITaaSServiceManager.sol";
import {IAVSDirectory} from "@eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {IRewardsCoordinator} from "@eigenlayer-contracts/src/contracts/interfaces/IRewardsCoordinator.sol";
import {ISlashingRegistryCoordinator} from "@eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {IPermissionController} from "@eigenlayer-contracts/src/contracts/interfaces/IPermissionController.sol";
import {IAllocationManager} from "@eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TaskBroadcastTest is Test {
    TaaSServiceManager public impl;
    TaaSServiceManager public serviceManager;
    address public owner = address(0x1);
    address public consumer = address(0x2);

    event TruthRequested(
        bytes32 indexed taskId,
        string capability,
        bytes params,
        ITaaSServiceManager.AggregationStrategy strategy,
        uint32 minSources,
        uint32 quorumThreshold,
        uint64 deadline
    );

    function setUp() public {
        impl = new TaaSServiceManager(
            IAVSDirectory(address(0)),
            IRewardsCoordinator(address(0)),
            ISlashingRegistryCoordinator(address(0)),
            IStakeRegistry(address(0)),
            IPermissionController(address(0)),
            IAllocationManager(address(0))
        );
        
        bytes memory initData = abi.encodeWithSelector(
            TaaSServiceManager.initialize.selector,
            owner,
            owner
        );
        
        serviceManager = TaaSServiceManager(address(new ERC1967Proxy(address(impl), initData)));
    }

    function test_TaskReceptionAndBroadcast() public {
        vm.prank(consumer);
        
        string memory capability = "crypto.eth.price";
        bytes memory params = hex"1234";
        ITaaSServiceManager.AggregationStrategy strategy = ITaaSServiceManager.AggregationStrategy.MAJORITY;
        uint32 minSources = 3;
        uint32 quorumThreshold = 67;
        uint64 deadline = uint64(block.timestamp + 1 hours);

        // This is the "Broadcast" moment: we skip checking the indexed taskId because it's generated randomly
        vm.expectEmit(false, false, false, true);
        emit TruthRequested(
            bytes32(0), // taskId is not indexed in the expected emit check for this specific test
            capability,
            params,
            strategy,
            minSources,
            quorumThreshold,
            deadline
        );

        bytes32 taskId = serviceManager.createNewTask(
            capability,
            params,
            strategy,
            minSources,
            quorumThreshold,
            deadline
        );

        console.log("Task Created with ID:");
        console.logBytes32(taskId);

        // Verify state persistence
        (address creator,,,,,,, bool completed,) = serviceManager.tasks(taskId);
        assertEq(creator, consumer);
        assertFalse(completed);
        
        string memory storedCap = serviceManager.taskToCapability(taskId);
        assertEq(storedCap, capability);
    }
}
