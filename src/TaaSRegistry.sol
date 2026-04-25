// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
// Copyright (c) 2026 Friehub. All rights reserved.
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";
import {ITaaSRegistry} from "./interfaces/ITaaSRegistry.sol";

/**
 * @title TaaSRegistry
 * @dev Manages operator registration and metadata for the TaaS AVS.
 * Upgradeable via UUPS Proxy.
 */
contract TaaSRegistry is UUPSUpgradeable, AccessControlUpgradeable, ITaaSRegistry {
    bytes32 public constant REGISTRY_ADMIN_ROLE = keccak256("REGISTRY_ADMIN_ROLE");

    error OperatorNotRegistered(address operator);
    error InsufficientStake(uint256 stake, uint256 minStake);
    uint256 public minStake = 1 ether;

    struct OperatorInfo {
        uint256 minStake;
        bool active;
    }

    mapping(address => OperatorInfo) public operators;
    address[] public operatorList;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the institutional TaaSRegistry.
     */
    function initialize(address initialOwner) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _grantRole(REGISTRY_ADMIN_ROLE, initialOwner);
        // Explicitly emit event for indexing
        emit OperatorRegistered(initialOwner, 0); 
    }

    /**
     * @notice UUPS Upgrade Authorization.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /**
     * @notice Registers an operator with a specific stake threshold.
     */
    function registerOperator(address operator, uint256 _minStake) external onlyRole(REGISTRY_ADMIN_ROLE) {
        require(!operators[operator].active, "Operator already registered");
        operators[operator] = OperatorInfo({
            minStake: _minStake,
            active: true
        });
        operatorList.push(operator);
        emit OperatorRegistered(operator, _minStake);
    }

    /**
     * @notice Deregisters an operator.
     */
    function deregisterOperator(address operator) external onlyRole(REGISTRY_ADMIN_ROLE) {
        operators[operator].active = false;
        emit OperatorDeregistered(operator);
    }

    /**
     * @notice Verifies if an operator is active and has sufficient stake.
     */
    function verifyOperator(address operator, uint256 currentStake) external view returns (bool) {
        OperatorInfo memory operatorStatus = operators[operator];
        if (!operatorStatus.active) return false;
        if (currentStake < operatorStatus.minStake) return false;
        return true;
    }
}
