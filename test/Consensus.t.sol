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
import {BN254} from "@eigenlayer-middleware/src/libraries/BN254.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ConsensusTest is Test {
    TaaSServiceManager impl;
    TaaSServiceManager serviceManager;
    address blsSignatureChecker = address(0x456);
    address owner = address(1);

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
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        serviceManager = TaaSServiceManager(address(proxy));

        vm.prank(owner);
        serviceManager.setBLSSignatureChecker(IBLSSignatureChecker(blsSignatureChecker));
    }

    function test_ConsensusReachedAtThreshold() public {
        vm.prank(owner);
        bytes32 taskId = serviceManager.createNewTask("consensus_test", "", ITaaSServiceManager.AggregationStrategy.BLS_QUORUM, 1, 67, uint64(block.timestamp + 3600));
        
        bytes32 resultHash = keccak256("aggregated_result");

        // Mock checkSignatures: 70 signed / 100 total (70% > 67%)
        IBLSSignatureCheckerTypes.QuorumStakeTotals memory totals;
        totals.signedStakeForQuorum = new uint96[](1);
        totals.signedStakeForQuorum[0] = 70 ether;
        totals.totalStakeForQuorum = new uint96[](1);
        totals.totalStakeForQuorum[0] = 100 ether;

        vm.mockCall(
            blsSignatureChecker,
            abi.encodeWithSelector(IBLSSignatureChecker.checkSignatures.selector),
            abi.encode(totals, bytes32(0))
        );

        IBLSSignatureCheckerTypes.NonSignerStakesAndSignature memory emptySig;
        
        serviceManager.respondWithSignature(taskId, resultHash, bytes("result"), emptySig);

        (,,,,,,, bool completed, ) = serviceManager.tasks(taskId);
        assertTrue(completed);
    }

    function test_ConsensusFailsBelowThreshold() public {
        vm.prank(owner);
        bytes32 taskId = serviceManager.createNewTask("consensus_test", "", ITaaSServiceManager.AggregationStrategy.BLS_QUORUM, 1, 67, uint64(block.timestamp + 3600));
        
        bytes32 resultHash = keccak256("aggregated_result");

        // Mock checkSignatures: 60 signed / 100 total (60% < 67%)
        IBLSSignatureCheckerTypes.QuorumStakeTotals memory totals;
        totals.signedStakeForQuorum = new uint96[](1);
        totals.signedStakeForQuorum[0] = 60 ether;
        totals.totalStakeForQuorum = new uint96[](1);
        totals.totalStakeForQuorum[0] = 100 ether;

        vm.mockCall(
            blsSignatureChecker,
            abi.encodeWithSelector(IBLSSignatureChecker.checkSignatures.selector),
            abi.encode(totals, bytes32(0))
        );

        IBLSSignatureCheckerTypes.NonSignerStakesAndSignature memory emptySig;
        
        vm.expectRevert("Consensus threshold not met");
        serviceManager.respondWithSignature(taskId, resultHash, bytes("result"), emptySig);
    }
}
