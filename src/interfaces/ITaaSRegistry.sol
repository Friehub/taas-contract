// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
// Copyright (c) 2026 Friehub. All rights reserved.
pragma solidity ^0.8.24;

/**
 * @title ITaaSRegistry
 * @dev Interface for the TaaS AVS Operator Registry.
 */
interface ITaaSRegistry {
    event OperatorRegistered(address indexed operator, uint256 minStake);
    event OperatorDeregistered(address indexed operator);

    function registerOperator(address operator, uint256 minStake) external;
    function deregisterOperator(address operator) external;
    function verifyOperator(address operator, uint256 currentStake) external view returns (bool);
}
