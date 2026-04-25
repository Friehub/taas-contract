// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
// Copyright (c) 2026 Friehub. All rights reserved.
pragma solidity ^0.8.24;

import {ITEEVerifier} from "../interfaces/ITEEVerifier.sol";

/**
 * @title TaaSMockVerifier
 * @dev A testnet-ready verifier for TaaS hardware proofs. 
 * Allows for protocol testing on Sepolia without requiring live Nitro/SGX root-of-trust contracts.
 */
contract TaaSMockVerifier is ITEEVerifier {
    event MockVerificationPerformed(address indexed caller, bytes32 indexed dataHash);

    /**
     * @notice In Mock mode, we verify that the quote contains a valid institutional development header.
     * @dev Header is 'TAAS_DEV_ENCLAVE'.
     */
    function verify(bytes calldata quote, bytes32 dataHash) external pure override returns (bool) {
        if (quote.length < 16) return false;
        
        bytes16 header = bytes16(quote[0:16]);
        return header == bytes16("TAAS_DEV_ENCLAVE");
    }
}
