// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
// Copyright (c) 2026 Friehub. All rights reserved.
pragma solidity ^0.8.24;

/**
 * @title ITEEVerifier
 * @dev Standard interface for hardware-specific TEE verifiers (Nitro, SGX, SEV, etc).
 */
interface ITEEVerifier {
    /**
     * @notice Verifies a hardware-signed attestation document.
     * @param quote The binary attestation document (e.g., AWS Nitro Quote).
     * @param dataHash The hash of the oracle result that was attested inside the TEE.
     * @return bool True if the TEE proof is valid and linked to the dataHash.
     */
    function verify(bytes calldata quote, bytes32 dataHash) external view returns (bool);
}
