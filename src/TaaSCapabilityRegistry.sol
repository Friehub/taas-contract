// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
// Copyright (c) 2026 Friehub. All rights reserved.
pragma solidity ^0.8.24;

import {AccessControlUpgradeable} from "@openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";

import {ITaaSServiceManager} from "./ITaaSServiceManager.sol";

/**
 * @title TaaSCapabilityRegistry
 * @dev Dedicated registry for TaaS oracle capabilities (plugins). 
 * Manages the taxonomy of supported data sources and execution logic.
 */
contract TaaSCapabilityRegistry is Initializable, UUPSUpgradeable, AccessControlUpgradeable {
    bytes32 public constant CAPABILITY_ADMIN_ROLE = keccak256("CAPABILITY_ADMIN_ROLE");
    
    struct Capability {
        string category;
        string version;
        string schema;
        ITaaSServiceManager.AggregationStrategy strategy;
        bool active;
        bool requiresHardware;
    }

    IStakeRegistry public stakeRegistry;
    uint256 public minStakeForRegistration = 0.5 ether;

    mapping(string => Capability) public capabilities;
    string[] public capabilityNames;

    // Operator Capability Index
    mapping(address => string[]) public operatorCapabilities;
    mapping(address => mapping(string => bool)) public operatorSupports;
    mapping(string => address[]) public capabilityOperators;
    address[] public operators; // List of all operators who have declared capabilities
    mapping(address => bool) public hasDeclared;

    error OperatorNotRegistered(address operator);

    event CapabilityRegistered(string indexed name, string category, string version, bool requiresHardware);
    event CapabilityUpdated(string indexed name, bool active);
    event OperatorCapabilitiesDeclared(address indexed operator, string[] capabilities);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, address _stakeRegistry) external initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _grantRole(CAPABILITY_ADMIN_ROLE, initialOwner);

        if (_stakeRegistry != address(0)) {
            stakeRegistry = IStakeRegistry(_stakeRegistry);
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /**
     * @notice Checks if the address is a registered and staked operator on EigenLayer.
     */
    function isRegisteredOperator(address operator) public view returns (bool) {
        if (address(stakeRegistry) == address(0)) return true; // Bootstrap mode
        uint256 stake = stakeRegistry.weightOfOperatorForQuorum(0, operator);
        return stake >= minStakeForRegistration;
    }

    function setStakeRegistry(address _stakeRegistry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        stakeRegistry = IStakeRegistry(_stakeRegistry);
    }

    function declareCapabilities(string[] calldata capabilityNamesList) external {
        require(isRegisteredOperator(msg.sender), "Not a staked operator");
        if (!hasDeclared[msg.sender]) {
            operators.push(msg.sender);
            hasDeclared[msg.sender] = true;
        }

        for (uint i = 0; i < capabilityNamesList.length; i++) {
            require(capabilities[capabilityNamesList[i]].active, "Capability not active");
            if (!operatorSupports[msg.sender][capabilityNamesList[i]]) {
                operatorCapabilities[msg.sender].push(capabilityNamesList[i]);
                operatorSupports[msg.sender][capabilityNamesList[i]] = true;
                capabilityOperators[capabilityNamesList[i]].push(msg.sender);
            }
        }
        emit OperatorCapabilitiesDeclared(msg.sender, capabilityNamesList);
    }

    /**
     * @notice Returns the list of capabilities supported by an operator.
     */
    function getOperatorCapabilities(address operator) external view returns (string[] memory) {
        return operatorCapabilities[operator];
    }

    /**
     * @notice Registers or updates a capability.
     */
    function registerCapability(
        string calldata name,
        string calldata category,
        string calldata version,
        string calldata schema,
        ITaaSServiceManager.AggregationStrategy strategy,
        bool requiresHardware
    ) external onlyRole(CAPABILITY_ADMIN_ROLE) {
        if (!capabilities[name].active && bytes(capabilities[name].category).length == 0) {
            capabilityNames.push(name);
        }

        capabilities[name] = Capability({
            category: category,
            version: version,
            schema: schema,
            strategy: strategy,
            active: true,
            requiresHardware: requiresHardware
        });

        emit CapabilityRegistered(name, category, version, requiresHardware);
    }

    /**
     * @notice Toggles the active status of a capability.
     */
    function setCapabilityStatus(string calldata name, bool active) external onlyRole(CAPABILITY_ADMIN_ROLE) {
        require(bytes(capabilities[name].category).length > 0, "Capability not registered");
        capabilities[name].active = active;
        emit CapabilityUpdated(name, active);
    }

    /**
     * @notice Returns true if the capability is registered and active.
     */
    function isCapabilityActive(string calldata name) external view returns (bool) {
        return capabilities[name].active;
    }

    function getCapabilityNames() external view returns (string[] memory) {
        return capabilityNames;
    }

    function getCapability(string calldata name) external view returns (Capability memory) {
        return capabilities[name];
    }

    /**
     * @notice Institutional Optimization: Returns the raw list of declared operators for gas-efficient deterministic election.
     * Real security is applied later by the BLS signature verification over the actual stakes.
     */
    function getElectedRelayers(string calldata name) external view returns (address[] memory) {
        return capabilityOperators[name];
    }

    /**
     * @notice Returns the list of operators who support a specific capability, filtered by minimum stake requirements.
     */
    function getOperatorsForCapability(string calldata name) external view returns (address[] memory) {
        address[] memory allDeclared = capabilityOperators[name];
        
        // Optimistic Path: If 0.5 ETH minimum is not active, return everything
        if (address(stakeRegistry) == address(0)) {
            return allDeclared;
        }

        uint256 count = 0;
        address[] memory active = new address[](allDeclared.length);
        
        for (uint i = 0; i < allDeclared.length; i++) {
            address op = allDeclared[i];
            uint256 weight = stakeRegistry.weightOfOperatorForQuorum(0, op);
            if (weight >= minStakeForRegistration) {
                active[count] = op;
                count++;
            }
        }

        // Resize the array down to actual active count
        address[] memory finalActive = new address[](count);
        for (uint j = 0; j < count; j++) {
            finalActive[j] = active[j];
        }

        return finalActive;
    }
}
