// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title ITruthPaymaster
 * @dev Interface for the TaaS institutional ERC-4337 Paymaster.
 */
interface ITruthPaymaster {
    event VerifiableSignerUpdated(address indexed oldSigner, address indexed newSigner);

    function setVerifiableSigner(address _newSigner) external;
}
