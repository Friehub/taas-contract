// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title MockServiceManager
 * @dev Lightweight proxy for testing the Relay-Payer gas delivery.
 */
contract MockServiceManager is AccessControl {
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    
    mapping(bytes32 => bool) public settledTasks;
    mapping(address => uint256) public relayerDailyLimit;
    mapping(address => uint256) public relayerCurrentSpend;
    mapping(address => uint256) public relayerLastRefill;

    event TaskSettled(bytes32 taskId, address relayer);

    constructor(address initialAdmin) {
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    }

    modifier enforceRelayerLimits() {
        require(hasRole(RELAYER_ROLE, msg.sender), "NOT_RELAYER");
        
        if (block.timestamp >= relayerLastRefill[msg.sender] + 1 days) {
            relayerCurrentSpend[msg.sender] = 0;
            relayerLastRefill[msg.sender] = block.timestamp;
        }

        uint256 limit = relayerDailyLimit[msg.sender];
        if (limit > 0) {
            require(relayerCurrentSpend[msg.sender] < limit, "LIMIT_EXCEEDED");
        }
        _;
    }

    function updateRelayerLimit(address relayer, uint256 limit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        relayerDailyLimit[relayer] = limit;
        relayerLastRefill[relayer] = block.timestamp;
    }

    function settle(
        bytes32 taskId,
        bytes32, // resultHash
        bytes calldata, // result
        bytes calldata // signatures/proof
    ) external enforceRelayerLimits {
        require(!settledTasks[taskId], "ALREADY_SETTLED");
        
        settledTasks[taskId] = true;
        relayerCurrentSpend[msg.sender]++;
        
        emit TaskSettled(taskId, msg.sender);
    }
}
