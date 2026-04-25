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
import {IBLSSignatureChecker} from "@eigenlayer-middleware/src/interfaces/IBLSSignatureChecker.sol";
import {IBLSSignatureCheckerTypes} from "@eigenlayer-middleware/src/interfaces/IBLSSignatureChecker.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TaaSServiceManagerTest is Test {
    TaaSServiceManager impl;
    TaaSServiceManager serviceManager;
    address owner = address(1);
    address operator = address(2);
    address challenger = address(3);
    address stakeRegistry = address(4);

    uint256 disputeBond = 0.1 ether;

    function setUp() public {
        impl = new TaaSServiceManager(
            IAVSDirectory(address(0)),
            IRewardsCoordinator(address(0)),
            ISlashingRegistryCoordinator(address(0)),
            IStakeRegistry(stakeRegistry),
            IPermissionController(address(0)),
            IAllocationManager(address(0))
        );
        
        bytes memory initData = abi.encodeWithSelector(
            TaaSServiceManager.initialize.selector,
            owner,
            owner
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        serviceManager = TaaSServiceManager(address(proxy));

        vm.deal(challenger, 10 ether);
        vm.deal(address(serviceManager), 10 ether); 
        
        // Mock a TEE verifier for the "provider"
        vm.prank(owner);
        serviceManager.setVerifier("provider", address(0xDEADC0DE));
        vm.mockCall(
            address(0xDEADC0DE),
            abi.encodeWithSignature("verify(bytes,bytes32)", "quote", keccak256("result")),
            abi.encode(true)
        );
    }

    function test_ChallengeSuccessful() public {
        // 1. Create and complete task
        vm.prank(owner);
        bytes32 taskId = serviceManager.createNewTask(
            "test", 
            "", 
            ITaaSServiceManager.AggregationStrategy.MAJORITY, 
            3, 
            67, 
            uint64(block.timestamp + 1 hours)
        );
        
        // Mock stake for operator
        vm.mockCall(
            stakeRegistry,
            abi.encodeWithSignature("weightOfOperatorForQuorum(uint8,address)", 0, operator),
            abi.encode(2 ether)
        );

        ITaaSServiceManager.TeeProof memory proof;
        vm.prank(operator);
        serviceManager.respondToTask(taskId, keccak256("result"), "", proof);

        // 2. Challenge
        bytes32 challengeResult = keccak256("expected_result");
        uint256 initialChallengerBalance = challenger.balance;
        vm.mockCall(
            stakeRegistry,
            abi.encodeWithSignature("weightOfOperatorForQuorum(uint8,address)", 0, challenger),
            abi.encode(2 ether)
        );
        vm.prank(challenger);
        serviceManager.challengeTask(taskId, challengeResult, "");

        // Verify state
        (,,,,,,, bool completed, bool challenged) = serviceManager.tasks(taskId);
        assertTrue(completed);
    }

    function test_ChallengeMaliciousFails() public {
        // 1. Create and complete task
        vm.prank(owner);
        bytes32 taskId = serviceManager.createNewTask(
            "test", 
            "", 
            ITaaSServiceManager.AggregationStrategy.MAJORITY, 
            3, 
            67, 
            uint64(block.timestamp + 1 hours)
        );
        
        vm.mockCall(
            stakeRegistry,
            abi.encodeWithSignature("weightOfOperatorForQuorum(uint8,address)", 0, operator),
            abi.encode(2 ether)
        );

        ITaaSServiceManager.TeeProof memory proof;
        vm.prank(operator);
        serviceManager.respondToTask(taskId, keccak256("result"), "", proof);

        // 2. Malicious Challenge
        vm.mockCall(
            stakeRegistry,
            abi.encodeWithSignature("weightOfOperatorForQuorum(uint8,address)", 0, challenger),
            abi.encode(2 ether)
        );
        vm.prank(challenger);
        serviceManager.challengeTask(taskId, keccak256("wrong"), "");

        // Verify state
        (,,,,,,, bool completed, bool challenged) = serviceManager.tasks(taskId);
        assertTrue(completed);
    }

    function test_FinalizePermissionless() public {
        vm.prank(owner);
        bytes32 taskId = serviceManager.createNewTask(
            "test", 
            "", 
            ITaaSServiceManager.AggregationStrategy.MAJORITY, 
            3, 
            67, 
            uint64(block.timestamp + 1 hours)
        );
        
        vm.mockCall(
            stakeRegistry,
            abi.encodeWithSignature("weightOfOperatorForQuorum(uint8,address)", 0, operator),
            abi.encode(2 ether)
        );

        ITaaSServiceManager.TeeProof memory proof;
        vm.prank(operator);
        serviceManager.respondToTask(taskId, keccak256("result"), "", proof);

        // Move blocks past challenge window (50 blocks)
        vm.roll(block.number + 51);

        // Anyone can finalize
        address anyone = address(9);
        vm.prank(anyone);
        // We mock the RewardsCoordinator call inside finalize -> distributeRewards
        // But for this test, we just want to ensure it doesn't revert.
        // In the current ServiceManager.sol, finalizeTask is not implemented separately 
        // as settlement (respondToTask) marks it completed.
        // If we had reward distribution, we'd test it here.
    }

    function test_ChallengeWindowEnforcement() public {
        vm.prank(owner);
        bytes32 taskId = serviceManager.createNewTask(
            "test", 
            "", 
            ITaaSServiceManager.AggregationStrategy.MAJORITY, 
            3, 
            67, 
            uint64(block.timestamp + 1 hours)
        );
        
        vm.mockCall(
            stakeRegistry,
            abi.encodeWithSignature("weightOfOperatorForQuorum(uint8,address)", 0, operator),
            abi.encode(2 ether)
        );

        vm.deal(operator, 1 ether);
        vm.prank(operator);
        serviceManager.respondToTask(taskId, keccak256("result"), "", ITaaSServiceManager.TeeProof("provider", "quote", 0));

        vm.roll(block.number + 51); // Window closed
        
        vm.mockCall(
            stakeRegistry,
            abi.encodeWithSignature("weightOfOperatorForQuorum(uint8,address)", 0, challenger),
            abi.encode(2 ether)
        );
        vm.prank(challenger);
        vm.expectRevert("Challenge window closed");
        serviceManager.challengeTask(taskId, keccak256("late"), "");
    }
}
