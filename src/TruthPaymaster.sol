// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "account-abstraction/core/BasePaymaster.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interfaces/ITruthPaymaster.sol";

/**
 * @title TruthPaymaster
 * @dev An institutional ERC-4337 Paymaster for the TaaS Gateway.
 * It sponsors gas for oracle settlement transactions that carry a valid TaaS signature.
 */
contract TruthPaymaster is BasePaymaster, ITruthPaymaster {
    using ECDSA for bytes32;
    
    // The address authorized to sign sponsorship requests (TaaS Oracle / Node Registry)
    address public verifiableSigner;

    constructor(
        IEntryPoint _entryPoint, 
        address _verifiableSigner,
        address _initialOwner
    ) BasePaymaster(_entryPoint) {
        verifiableSigner = _verifiableSigner;
        _transferOwnership(_initialOwner);
    }

    /**
     * @dev Sets a new verifiable signer.
     */
    function setVerifiableSigner(address _newSigner) external override onlyOwner {
        require(_newSigner != address(0), "Invalid signer");
        emit VerifiableSignerUpdated(verifiableSigner, _newSigner);
        verifiableSigner = _newSigner;
    }

    /**
     * @dev Validates that the UserOperation is sponsored by TaaS.
     * The paymasterAndData field must contain a signature of the UserOperation hash.
     */
    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) internal view override returns (bytes memory context, uint256 validationData) {
        (userOpHash, maxCost); // silence warnings

        // The paymasterAndData field format: [address(this) | signature]
        // BasePaymaster already stripped the address, so we expect just the signature.
        if (userOp.paymasterAndData.length < 20) {
            return ("", 1); // SIG_VALIDATION_FAILED
        }
        
        bytes calldata signature = userOp.paymasterAndData[20:];

        if (signature.length == 0) {
            return ("", 1); // SIG_VALIDATION_FAILED
        }

        // Verify the signature is from our verifiableSigner
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        if (hash.recover(signature) != verifiableSigner) {
            return ("", 1); // SIG_VALIDATION_FAILED
        }

        return ("", 0); // SIG_VALIDATION_SUCCESS
    }

    /**
     * @dev Post-operation logic (optional).
     */
    function _postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) internal override {
        (mode, context, actualGasCost); // silence warnings
    }
}
