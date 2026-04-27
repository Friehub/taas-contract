// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
// Copyright (c) 2026 Friehub. All rights reserved.
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "account-abstraction/samples/SimpleAccount.sol";
import "account-abstraction/samples/SimpleAccountFactory.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
import {TruthPaymaster} from "../src/TruthPaymaster.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title ManualPaymasterTest
 * @dev A clinical script to test the TruthPaymaster sponsorship logic on Sepolia.
 */
contract ManualPaymasterTest is Script {
    using ECDSA for bytes32;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Institutional Coordinates from Environment
        address ENTRY_POINT = vm.envAddress("ENTRY_POINT");
        address PAYMASTER = vm.envAddress("TRUTH_PAYMASTER");

        vm.startBroadcast(deployerPrivateKey);

        console.log("-----------------------------------------");
        console.log("Starting Clinical Paymaster Test");
        console.log("Using EntryPoint:", ENTRY_POINT);
        console.log("Using Paymaster:", PAYMASTER);
        console.log("Deployer/Signer:", deployer);
        
        // 1. Predict Infrastructure (SELF-HEALING)
        address factoryAddr = vm.envAddress("SIMPLE_ACCOUNT_FACTORY");
        SimpleAccountFactory factory;
        if (factoryAddr.code.length == 0) {
            console.log("Factory not found at", factoryAddr);
            factory = new SimpleAccountFactory(IEntryPoint(ENTRY_POINT));
            console.log("REDEPLOYED FACTORY TO:", address(factory));
        } else {
            factory = SimpleAccountFactory(factoryAddr);
        }

        // Deploy MockSender for clinical isolation
        MockSender mockSender = new MockSender();
        address sender = address(mockSender);
        uint256 nonce = IEntryPoint(ENTRY_POINT).getNonce(sender, 0);

        console.log("--- HASH PARAMETERS ---");
        console.log("Sender:", sender);
        console.log("Nonce:", nonce);
        console.log("CallData Hash:");
        console.logBytes32(keccak256(abi.encodeWithSignature("execute(address,uint256,bytes)", sender, 0, "")));
        console.log("Paymaster:", PAYMASTER);
        console.log("ChainId: 11155111");
        console.log("-----------------------");

        // 2. Construct UserOperation (NO INITCODE - USING PRE-DEPLOYED MOCK)
        UserOperation memory userOp = UserOperation({
            sender: sender,
            nonce: nonce,
            initCode: "",
            callData: abi.encodeWithSignature("test()"),
            callGasLimit: 100000,
            verificationGasLimit: 200000,
            preVerificationGas: 60000, 
            maxFeePerGas: 200000000000, // 200 gwei
            maxPriorityFeePerGas: 50000000000, // 50 gwei
            paymasterAndData: abi.encodePacked(PAYMASTER),
            signature: abi.encodePacked("MOCK_SIG")
        });

        // 3. Get Hashes and sign (RAW HASHING - NO ETH WRAP)
        // Match TruthPaymaster.sol: getHash logic
        bytes32 pmHash = keccak256(abi.encode(
            userOp.sender,
            userOp.nonce,
            keccak256(userOp.callData),
            PAYMASTER,
            11155111
        ));
        
        (uint8 v_pm, bytes32 r_pm, bytes32 s_pm) = vm.sign(deployerPrivateKey, pmHash);
        userOp.paymasterAndData = abi.encodePacked(PAYMASTER, r_pm, s_pm, v_pm);

        console.log("PM Hash:");
        console.logBytes32(pmHash);
        address localRecovered = pmHash.recover(abi.encodePacked(r_pm, s_pm, v_pm));
        console.log("Local Recovered Signer:", localRecovered);
        require(localRecovered == deployer, "Local signature verification failed");

        // 4. Final Submission
        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;
        
        IEntryPoint(ENTRY_POINT).handleOps(ops, payable(deployer));
        
        console.log("Transaction Submitted Successfully!");

        vm.stopBroadcast();
    }
}

contract MockSender {
    function test() external {}
    
    // Required for EntryPoint v0.6 to interact with it as a sender
    function validateUserOp(
        UserOperation calldata,
        bytes32,
        uint256
    ) external pure returns (uint256) {
        return 0; // SIG_SUCCESS
    }
    
    receive() external payable {}
}
