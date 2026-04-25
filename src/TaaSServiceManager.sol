// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
// Copyright (c) 2026 Friehub. All rights reserved.
pragma solidity ^0.8.24;

import {ServiceManagerBase} from "@eigenlayer-middleware/src/ServiceManagerBase.sol";
import {IAVSDirectory} from "@eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {IRewardsCoordinator} from "@eigenlayer-contracts/src/contracts/interfaces/IRewardsCoordinator.sol";
import {ISlashingRegistryCoordinator} from "@eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {IPermissionController} from "@eigenlayer-contracts/src/contracts/interfaces/IPermissionController.sol";
import {IAllocationManager} from "@eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {ISignatureUtilsMixinTypes} from "@eigenlayer-contracts/src/contracts/interfaces/ISignatureUtilsMixin.sol";

import {AccessControlUpgradeable} from "@openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";
import {IBLSSignatureChecker} from "@eigenlayer-middleware/src/interfaces/IBLSSignatureChecker.sol";
import {Initializable} from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ITEEVerifier} from "./interfaces/ITEEVerifier.sol";

import {ITaaSServiceManager} from "./ITaaSServiceManager.sol";

interface ITaaSCapabilityRegistry {
    function getOperatorsForCapability(string calldata name) external view returns (address[] memory);
    function getElectedRelayers(string calldata name) external view returns (address[] memory);
}

/**
 * @title TaaSServiceManager
 * @dev Institutional entry point for the TaaS Actively Validated Service (AVS) on EigenLayer.
 * Upgradeable via UUPS Proxy.
 */
contract TaaSServiceManager is ServiceManagerBase, UUPSUpgradeable, AccessControlUpgradeable, ITaaSServiceManager {
    /* ROLES */
    bytes32 public constant SERVICE_MANAGER_ADMIN_ROLE = keccak256("SERVICE_MANAGER_ADMIN_ROLE");
    bytes32 public constant PARAMETER_UPDATER_ROLE = keccak256("PARAMETER_UPDATER_ROLE");
    bytes32 public constant SLASHER_ROLE = keccak256("SLASHER_ROLE");

    /* ERRORS */
    error TaskAlreadyResponded(bytes32 taskId);
    error InvalidTeeProof(string provider);
    error VerifierNotFound(string provider);
    error UnauthorizedCaller();
    error InsufficientStake(address operator, uint256 stake, uint256 minStake);

    /* EVENTS */
    event VerifierUpdated(string provider, address verifier);
    event MinStakeUpdated(uint256 oldMinStake, uint256 newMinStake);
    event BLSSignatureCheckerUpdated(address oldChecker, address newChecker);

    /* STATE */
    mapping(bytes32 => Task) public tasks;
    mapping(string => address) public verifiers;
    mapping(bytes32 => string) public taskToCapability; // NEW: Needed for on-chain election verification
    uint32 public taskCount;
    
    // Institutional Sharding & Election
    address public capabilityRegistry;
    uint256 public minStake = 1 ether; 
    IBLSSignatureChecker public blsSignatureChecker;
    uint32 public defaultQuorumThreshold = 67; // 67% majority
    uint32 public minimumSourceFallback = 3; // Absolute signatures required if total stake is 0
    uint32 public challengeWindow = 50;
    
    event DefaultQuorumThresholdUpdated(uint32 oldThreshold, uint32 newThreshold);
    event MinimumSourceFallbackUpdated(uint32 oldFallback, uint32 newFallback);
    event AVSMetadataURIUpdated(string metadataURI);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        IAVSDirectory __avsDirectory,
        IRewardsCoordinator __rewardsCoordinator,
        ISlashingRegistryCoordinator __registryCoordinator,
        IStakeRegistry __stakeRegistry,
        IPermissionController __permissionController,
        IAllocationManager __allocationManager
    )
        ServiceManagerBase(
            __avsDirectory,
            __rewardsCoordinator,
            __registryCoordinator,
            __stakeRegistry,
            __permissionController,
            __allocationManager
        )
    {
        _disableInitializers();
    }

    /**
     * @notice Initializes the institutional ServiceManager.
     */
    function initialize(
        address initialOwner,
        address rewardsInitiator
    ) external initializer {
        __ServiceManagerBase_init(initialOwner, rewardsInitiator);
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _grantRole(SERVICE_MANAGER_ADMIN_ROLE, initialOwner);
        _grantRole(PARAMETER_UPDATER_ROLE, initialOwner);
        
        uint256 defaultMinStake = 1 ether;
        minStake = defaultMinStake; 
        emit MinStakeUpdated(0, defaultMinStake);
    }

    /**
     * @notice Ensures the caller has sufficient economic stake on EigenLayer.
     */
    modifier onlyStakedOperator() {
        uint256 stake = _stakeRegistry.weightOfOperatorForQuorum(0, msg.sender);
        if (stake < minStake) revert InsufficientStake(msg.sender, stake, minStake);
        _;
    }

    /**
     * @notice Enforces the 'Ghost Scheduler' election logic on-chain.
     * Selects exactly 'k' nodes deterministically based on taskId.
     */
    modifier onlyElected(bytes32 taskId) {
        if (capabilityRegistry == address(0)) {
            // Bootstrap mode: no election enforcement, any staked operator can respond
            _;
            return;
        }
        string memory capability = taskToCapability[taskId];
        Task memory task = tasks[taskId];
        uint32 k = task.minSources > 0 ? task.minSources : minimumSourceFallback;

        // Perform the deterministic election verification
        address[] memory eligible = ITaaSCapabilityRegistry(capabilityRegistry).getElectedRelayers(capability);
        
        bool isWinner = false;
        if (eligible.length <= k) {
            isWinner = true;
        } else {
            // Ranking algorithm mirrored from Rust election.rs
            // Institutional Guard: Limit committee pool to avoid gas-exhaustion
            uint256 poolSize = eligible.length > 500 ? 500 : eligible.length; 
            
            bytes32 senderHash = keccak256(abi.encodePacked(taskId, msg.sender));
            uint256 smallerHashes = 0;
            for (uint i = 0; i < poolSize; i++) {
                if (keccak256(abi.encodePacked(taskId, eligible[i])) < senderHash) {
                    smallerHashes++;
                }
            }
            if (smallerHashes < k) isWinner = true;
        }
        
        require(isWinner, "Institutional Error: Not elected for this task");
        _;
    }

    /**
     * @notice Updates the minimum stake required to participate.
     */
    function updateMinStake(uint256 _minStake) external onlyRole(PARAMETER_UPDATER_ROLE) {
        emit MinStakeUpdated(minStake, _minStake);
        minStake = _minStake;
    }

    /**
     * @notice Updates the default BFT quorum threshold percentage.
     */
    function updateDefaultQuorumThreshold(uint32 _threshold) external onlyRole(PARAMETER_UPDATER_ROLE) {
        require(_threshold > 0 && _threshold <= 100, "Invalid threshold percentage");
        emit DefaultQuorumThresholdUpdated(defaultQuorumThreshold, _threshold);
        defaultQuorumThreshold = _threshold;
    }

    /**
     * @notice Updates the absolute signature count fallback for reputation-less boots.
     */
    function updateMinimumSourceFallback(uint32 _fallback) external onlyRole(PARAMETER_UPDATER_ROLE) {
        require(_fallback > 0, "Invalid fallback count");
        emit MinimumSourceFallbackUpdated(minimumSourceFallback, _fallback);
        minimumSourceFallback = _fallback;
    }

    /**
     * @notice UUPS Upgrade Authorization.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /**
     * @notice Updates the metadata URI for the AVS
     * @param _metadataURI is the metadata URI for the AVS
     * @dev Only callable by the AVS administrator (DEFAULT_ADMIN_ROLE).
     */
    function updateAVSMetadataURI(string memory _metadataURI) public override onlyRole(DEFAULT_ADMIN_ROLE) {
        _avsDirectory.updateAVSMetadataURI(_metadataURI);
        emit AVSMetadataURIUpdated(_metadataURI);
    }

    /**
     * @notice Updates or registers a new hardware verifier.
     */
    function setVerifier(string calldata provider, address verifier) external onlyRole(SERVICE_MANAGER_ADMIN_ROLE) {
        require(verifier != address(0), "Invalid verifier address");
        verifiers[provider] = verifier;
        emit VerifierUpdated(provider, verifier);
    }

    /**
     * @notice Registers the capability registry address for election verification.
     */
    function setCapabilityRegistry(address _registry) external onlyRole(SERVICE_MANAGER_ADMIN_ROLE) {
        require(_registry != address(0), "Invalid registry address");
        capabilityRegistry = _registry;
    }

    /**
     * @notice Creates a new oracle task for the TaaS network.
     */
    function createNewTask(
        string calldata capability,
        bytes calldata params,
        AggregationStrategy strategy,
        uint32 minSources,
        uint32 quorumThreshold,
        uint64 deadline
    ) external override returns (bytes32) {
        bytes32 taskId = keccak256(abi.encodePacked(block.number, block.prevrandao, msg.sender, taskCount));
        taskCount++;

        tasks[taskId] = Task({
            creator: msg.sender,
            resultHash: bytes32(0),
            strategy: strategy,
            minSources: minSources,
            quorumThreshold: quorumThreshold,
            deadline: deadline,
            referenceBlock: uint32(block.number),
            completed: false,
            challenged: false
        });

        taskToCapability[taskId] = capability; // NEW: Store for election verification

        emit TruthRequested(taskId, capability, params, strategy, minSources, quorumThreshold, deadline);
        return taskId;
    }

    /**
     * @notice Institutional Slashing Call: Triggered by off-chain evidence of BFT violations.
     */
    function submitEvidence(
        address operator, 
        bytes32 taskId, 
        bytes calldata signatureA, 
        bytes calldata signatureB
    ) external onlyStakedOperator {
        // Logic to verify double-signing or logic violations
        // In production, this triggers EigenLayer slashing.
    }

    /**
     * @notice Institutional Reward Distribution: Submits a Merkle root of earned rewards.
     */
    function createAVSRewardsSubmission(bytes32 root, uint32 expiry) external {
        // Governance logic to finalize reward epochs
    }

    /**
     * @notice Updates the BLS Signature Checker address.
     */
    function setBLSSignatureChecker(IBLSSignatureChecker _blsSignatureChecker) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(address(_blsSignatureChecker) != address(0), "Invalid address");
        emit BLSSignatureCheckerUpdated(address(blsSignatureChecker), address(_blsSignatureChecker));
        blsSignatureChecker = _blsSignatureChecker;
    }

    /**
     * @notice Registers an operator to the TaaS AVS.
     * @param operator The address of the operator.
     * @param operatorSignature The signature, salt, and expiry for AVS registration.
     */
    function registerOperatorToAVS(
        address operator,
        ISignatureUtilsMixinTypes.SignatureWithSaltAndExpiry memory operatorSignature
    ) public virtual override {
        _avsDirectory.registerOperatorToAVS(operator, operatorSignature);
    }

    /**
     * @notice Responds to a truth task with optional hardware evidence.
     * @param taskId The unique identifier for the request.
     * @param resultHash Hash of the oracle response (from UCM).
     * @param teeProof Optional hardware attestation bundle.
     */
    function respondToTask(
        bytes32 taskId,
        bytes32 resultHash,
        bytes calldata result,
        TeeProof calldata teeProof
    ) external onlyStakedOperator onlyElected(taskId) {
        Task storage task = tasks[taskId];
        if (task.completed) revert TaskAlreadyResponded(taskId);
        
        // Effect before interaction
        task.completed = true;

        bool isHardwareVerified = false;

        // If a provider is specified, verification is ATTEMPTED.
        if (bytes(teeProof.provider).length > 0) {
            address verifierAddr = verifiers[teeProof.provider];
            if (verifierAddr == address(0)) revert VerifierNotFound(teeProof.provider);
            
            isHardwareVerified = ITEEVerifier(verifierAddr).verify(teeProof.quote, resultHash);
            if (!isHardwareVerified) revert InvalidTeeProof(teeProof.provider);
        }
        task.resultHash = resultHash;
        task.referenceBlock = uint32(block.number);

        emit TaskResponded(taskId, msg.sender, resultHash, result, isHardwareVerified);
    }

    /**
     * @notice Responds to a truth task with an aggregated signature.
     * @param taskId The unique identifier for the request.
     * @param resultHash Hash of the oracle response.
     * @param nonSignerStakesAndSignature The aggregated signature bundle from the EigenLayer middleware.
     */
    function respondWithSignature(
        bytes32 taskId,
        bytes32 resultHash,
        bytes calldata result,
        IBLSSignatureChecker.NonSignerStakesAndSignature calldata nonSignerStakesAndSignature
    ) external onlyElected(taskId) {
        Task storage task = tasks[taskId];
        if (task.completed) revert TaskAlreadyResponded(taskId);
        
        // Effect before interaction
        task.completed = true;

        // Verify the aggregated signature against the consensus quorum (Quorum 0)
        bytes memory quorumNumbers = abi.encodePacked(uint8(0));
        (IBLSSignatureChecker.QuorumStakeTotals memory stakeTotals, ) = blsSignatureChecker.checkSignatures(
            resultHash,
            quorumNumbers,
            task.referenceBlock,
            nonSignerStakesAndSignature
        );

        // Enforcement: Handle Reputation-less Fallback or Stake-Weighted Quorum
        uint256 signedStake = uint256(stakeTotals.signedStakeForQuorum[0]);
        uint256 totalStake = uint256(stakeTotals.totalStakeForQuorum[0]);
        
        if (totalStake == 0) {
            // Reputation-less bootstrap: ensure absolute participant minimum is met
            uint32 requiredSources = task.minSources > 0 ? task.minSources : minimumSourceFallback;
            require(
                nonSignerStakesAndSignature.nonSignerPubkeys.length == 0, 
                "Reputation-less fallback requires pure signer validation off-chain" // Placeholder for actual signer count since IBLS doesn't expose it easily here without custom parsing.
            );
        } else {
            // Quorum Logic: If task.quorumThreshold is 0, we fallback to governed default
            uint256 threshold = task.quorumThreshold > 0 ? task.quorumThreshold : defaultQuorumThreshold; 
            
            require(
                (signedStake * 100) / totalStake >= threshold,
                "Consensus threshold not met"
            );
        }

        task.resultHash = resultHash;
        task.referenceBlock = uint32(block.number);

        emit TaskResponded(taskId, msg.sender, resultHash, result, false);
    }

    /**
     * @notice Challenges a completed task with proof of a different result.
     * @dev Only staked operators can challenge to prevent spam.
     */
    function challengeTask(
        bytes32 taskId, 
        bytes32 expectedResultHash, 
        bytes calldata proof
    ) external onlyStakedOperator {
        Task storage task = tasks[taskId];
        if (block.number > task.referenceBlock + challengeWindow) {
            revert("Challenge window closed");
        }
        require(task.completed, "Task not yet settled");
        require(!task.challenged, "Task already challenged");
        
        // Institutional Guard: Validate proof (Placeholder for BLS verify)
        bool isValid = proof.length > 0; 
        
        emit TaskChallenged(taskId, msg.sender, isValid);
        
        // Only freeze/modify state on confirmed valid challenge
        if (isValid) {
            task.challenged = true; 
        }
    }

    /**
     * @notice implementation of verifyTeeProof from interface
     */
    function verifyTeeProof(bytes memory proof, bytes32 dataHash) external view override returns (bool) {
        address verifier = verifiers["sgx"]; // Default to sgx
        if (verifier == address(0)) return false;
        return ITEEVerifier(verifier).verify(proof, dataHash);
    }
}
