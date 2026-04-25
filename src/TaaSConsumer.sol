// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ITaaSServiceManager.sol";

/**
 * @title TaaSConsumer
 * @dev Base contract for protocols consuming TaaS verifiable facts.
 */
abstract contract TaaSConsumer {
    ITaaSServiceManager public immutable taasServiceManager;

    error TaskNotCompleted();
    error ResultHashMismatch();

    constructor(address _serviceManager) {
        taasServiceManager = ITaaSServiceManager(_serviceManager);
    }

    /**
     * @dev Internal helper to request a task from the TaaS AVS.
     */
    function _requestTask(
        string memory capability,
        bytes memory params,
        ITaaSServiceManager.AggregationStrategy strategy,
        uint32 minSources,
        uint32 quorumThreshold,
        uint64 deadline
    ) internal returns (bytes32) {
        return taasServiceManager.createNewTask(
            capability,
            params,
            strategy,
            minSources,
            quorumThreshold,
            deadline
        );
    }

    /**
     * @dev Security modifier that validates a result against the settled AVS state.
     * Use this in your fulfillment function to ensure the data is verified.
     */
    modifier onlyTaaSSettled(bytes32 taskId, bytes memory result) {
        // 1. Check if the task is completed and retrieve the committed hash
        (
            ,             // address creator
            bytes32 storedHash, 
            ,             // AggregationStrategy strategy
            ,             // uint32 minSources
            ,             // uint32 quorumThreshold
            ,             // uint64 deadline
            ,             // uint32 referenceBlock
            bool completed,
            // bool challenged
        ) = taasServiceManager.tasks(taskId);

        if (!completed) revert TaskNotCompleted();
        if (keccak256(result) != storedHash) revert ResultHashMismatch();
        _;
    }
}
