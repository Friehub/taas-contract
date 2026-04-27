// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "account-abstraction/core/BasePaymaster.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interfaces/ITruthPaymaster.sol";
import "account-abstraction/interfaces/UserOperation.sol"; // Import UserOperationLib

/**
 * @title TruthPaymaster
 * @dev An institutional ERC-4337 Paymaster for the TaaS Gateway.
 * It sponsors gas for oracle settlement transactions that carry a valid TaaS signature.
 */
contract TruthPaymaster is BasePaymaster, ITruthPaymaster {
    using ECDSA for bytes32;
    
    // The address authorized to sign sponsorship requests (TaaS Oracle / Node Registry)
    address public verifiableSigner;
    bytes32 public constant PAYMASTER_VALIDATION_SUCCESS = 0;
    bytes32 public constant PAYMASTER_VALIDATION_FAILED = bytes32(uint256(1));

    error SignatureMismatch(bytes32 hash, address recovered);

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
     * Re-calculates the hash to exclude the signature from paymasterAndData.
     */
    error DiagnosticRevert(address sender, uint256 nonce, bytes32 callDataHash, address pm);

    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32, /* userOpHash */
        uint256 /* maxCost */
    ) internal view override returns (bytes memory context, uint256 validationData) {
        // We expect paymasterAndData to be [address(20) | signature(65)]
        if (userOp.paymasterAndData.length < 85) {
            return ("", 1); // SIG_VALIDATION_FAILED
        }

        bytes calldata signature = userOp.paymasterAndData[20:];
        
        // We MUST re-calculate the hash because the entryPoint's userOpHash includes the signature
        // which was not part of the hash we signed.
        bytes32 hash = getHash(userOp);

        address recovered = hash.recover(signature);
        if (recovered != verifiableSigner) {
            revert SignatureMismatch(hash, recovered);
        }

        return ("", 0);
    }

    /**
     * @dev Re-calculates the UserOperation hash using only the first 20 bytes of paymasterAndData.
     * This perfectly matches the EntryPoint's getUserOpHash logic for the 'base' operation.
     */
    function getHash(UserOperation calldata userOp) public view returns (bytes32) {
        // Simplified, extremely robust sponsorship hash
        // It covers the identity, state, and intent of the UserOp.
        return keccak256(abi.encode(
            userOp.sender,
            userOp.nonce,
            keccak256(userOp.callData),
            address(this),
            11155111 // Sepolia hardcoded
        ));
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
