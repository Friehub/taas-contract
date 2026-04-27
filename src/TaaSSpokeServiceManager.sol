// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
// Copyright (c) 2026 Friehub. All rights reserved.
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title TaaSSpokeServiceManager
 * @dev Lightweight Service Manager for non-EigenLayer Spoke chains (Optimism, BNB, etc).
 * Verifies truth settlements against a synchronized list of authorized TaaS operators.
 */
contract TaaSSpokeServiceManager is AccessControl {
    using ECDSA for bytes32;

    /* ROLES */
    bytes32 public constant SIGNER_UPDATER_ROLE = keccak256("SIGNER_UPDATER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    /* TYPES */
    enum AggregationStrategy { 
        BLS_QUORUM, MEDIAN, MAJORITY, UNION, LATEST, FIRST, MEAN, CONSENSUS, WEIGHTED_MAJORITY, IQR_MEDIAN 
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

    /* STATE */
    mapping(bytes32 => Task) public tasks;
    uint32 public taskCount;
    uint32 public defaultThreshold = 3; 

    /* EVENTS */
    event TruthRequested(
        bytes32 indexed taskId, 
        string capability, 
        bytes params,
        AggregationStrategy strategy,
        uint32 minSources,
        uint32 quorumThreshold,
        uint64 deadline
    );
    event TaskResponded(bytes32 indexed taskId, bytes32 resultHash, bytes result);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(SIGNER_UPDATER_ROLE, admin);
    }

    /**
     * @notice Registers or removes an operator as an authorized signer on this Spoke.
     */
    function updateOperator(address operator, bool authorized) external onlyRole(SIGNER_UPDATER_ROLE) {
        if (authorized) {
            _grantRole(OPERATOR_ROLE, operator);
        } else {
            _revokeRole(OPERATOR_ROLE, operator);
        }
    }

    /**
     * @notice Creates a new oracle task locally on the Spoke chain.
     */
    function createNewTask(
        string calldata capability, 
        bytes calldata params,
        AggregationStrategy strategy,
        uint32 minSources,
        uint32 quorumThreshold,
        uint64 deadline
    ) external returns (bytes32 taskId) {
        taskId = keccak256(abi.encodePacked(block.number, msg.sender, taskCount));
        taskCount++;

        tasks[taskId] = Task({
            creator: msg.sender,
            resultHash: bytes32(0),
            strategy: strategy,
            minSources: minSources,
            quorumThreshold: quorumThreshold,
            deadline: deadline,
            referenceBlock: uint32(block.number),
            completed: false,
            challenged: false
        });

        emit TruthRequested(taskId, capability, params, strategy, minSources, quorumThreshold, deadline);
        return taskId;
    }

    /**
     * @notice Settles the truth on the Spoke by verifying multiple ECDSA signatures.
     * @param taskId The ID of the task.
     * @param resultHash The hash of the truth.
     * @param result The actual data bytes.
     * @param signatures An array of signatures from authorized operators.
     */
    function settleTruth(
        bytes32 taskId,
        bytes32 resultHash,
        bytes calldata result,
        bytes[] calldata signatures
    ) external onlyRole(RELAYER_ROLE) {
        require(keccak256(result) == resultHash, "Result hash mismatch");
        Task storage task = tasks[taskId];
        require(!task.completed, "Task already completed");
        
        uint32 threshold = task.minSources > 0 ? task.minSources : defaultThreshold;
        require(signatures.length >= threshold, "Insufficient signatures for quorum");

        // [HARDENING] Domain-specific binding (ChainID + Contract Address)
        // Prevents cross-chain replay of operator signatures.
        bytes32 domainSeparatedHash = keccak256(
            abi.encode(block.chainid, address(this), taskId, resultHash)
        );

        // Verify that each signature is valid and from an authorized operator
        address[] memory signers = new address[](signatures.length);
        for (uint i = 0; i < signatures.length; i++) {
            address signer = domainSeparatedHash.toEthSignedMessageHash().recover(signatures[i]);
            require(hasRole(OPERATOR_ROLE, signer), "Unauthorized signer detected");
            
            // Ensure no duplicate signatures
            for (uint j = 0; j < i; j++) {
                require(signers[j] != signer, "Duplicate signature detected");
            }
            signers[i] = signer;
        }

        task.resultHash = resultHash;
        task.completed = true;

        emit TaskResponded(taskId, resultHash, result);
    }
}
