// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
// Copyright (c) 2026 Friehub. All rights reserved.
pragma solidity ^0.8.24;

import {IBLSSignatureChecker} from "@eigenlayer-middleware/src/interfaces/IBLSSignatureChecker.sol";

/**
 * @title ITaaSServiceManager
 * @dev Interface for the TaaS Actively Validated Service (AVS) Service Manager.
 * Defines the Task lifecycle and hardware attestation structure.
 */
interface ITaaSServiceManager {
    enum AggregationStrategy { 
        BLS_QUORUM, 
        MEDIAN, 
        MAJORITY, 
        UNION, 
        LATEST, 
        FIRST, 
        MEAN, 
        CONSENSUS, 
        WEIGHTED_MAJORITY,
        IQR_MEDIAN
    }

    struct TeeProof {
        string provider;
        bytes quote;
        uint64 timestamp;
    }

    struct Task {
        address creator;
        bytes32 resultHash;
        AggregationStrategy strategy;
        uint32 minSources;
        uint32 quorumThreshold;
        uint64 deadline;
        uint32 referenceBlock;
        bool completed;
        bool challenged;
    }

    event TruthRequested(
        bytes32 indexed taskId, 
        string capability, 
        bytes params,
        AggregationStrategy strategy,
        uint32 minSources,
        uint32 quorumThreshold,
        uint64 deadline
    );
    event TaskResponded(bytes32 indexed taskId, address indexed operator, bytes32 resultHash, bytes result, bool verified);
    event TaskChallenged(bytes32 indexed taskId, address indexed challenger, bool successful);

    function createNewTask(
        string calldata capability, 
        bytes calldata params,
        AggregationStrategy strategy,
        uint32 minSources,
        uint32 quorumThreshold,
        uint64 deadline
    ) external returns (bytes32 taskId);
    
    function respondWithSignature(
        bytes32 taskId, 
        bytes32 resultHash, 
        bytes calldata result,
        IBLSSignatureChecker.NonSignerStakesAndSignature calldata nonSignerStakesAndSignature
    ) external;

    /**
     * @notice Challenges a completed task with proof of a different result.
     * @param taskId The unique identifier for the request.
     * @param expectedResultHash The "correct" result hash.
     * @param proof Cryptographic proof (e.g. aggregate of other signed proposals).
     */
    function challengeTask(
        bytes32 taskId, 
        bytes32 expectedResultHash, 
        bytes calldata proof
    ) external;

    function respondToTask(
        bytes32 taskId,
        bytes32 resultHash,
        bytes calldata result,
        TeeProof calldata teeProof
    ) external;

    function verifyTeeProof(bytes memory proof, bytes32 dataHash) external view returns (bool);
}
