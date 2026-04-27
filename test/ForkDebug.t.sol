// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "account-abstraction/interfaces/IEntryPoint.sol";
import "account-abstraction/interfaces/UserOperation.sol";
import "../src/TruthPaymaster.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract ForkDebug is Test {
    using ECDSA for bytes32;

    IEntryPoint public entryPoint = IEntryPoint(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);
    address public paymaster = 0xD159D812a662Fb9f0d518ac07329f7BBB4977524;
    address public sender = 0x1Fc0E45Ccd8b52047F7A78A12177319B7621d75D;
    
    // verifiableSigner = Private Key EOA
    address public verifiableSigner = 0xc1b5Dd31524aBF5d890C369509095A5bEF5d34fb;
    uint256 public signerKey;

    function setUp() public {
        signerKey = vm.envUint("PRIVATE_KEY");
        vm.createSelectFork(vm.envString("RPC_URL"));
    }

    function test_debugHandleOps() public {
        UserOperation memory userOp = UserOperation({
            sender: sender,
            nonce: entryPoint.getNonce(sender, 0),
            initCode: "",
            callData: abi.encodeWithSignature("test()"),
            callGasLimit: 300000,
            verificationGasLimit: 300000,
            preVerificationGas: 100000,
            maxFeePerGas: 40000000000,
            maxPriorityFeePerGas: 5000000000,
            paymasterAndData: abi.encodePacked(paymaster),
            signature: ""
        });

        bytes32 hash = TruthPaymaster(payable(paymaster)).getHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, hash.toEthSignedMessageHash());
        bytes memory sig = abi.encodePacked(r, s, v);

        userOp.paymasterAndData = abi.encodePacked(paymaster, sig);
        userOp.signature = sig;

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;

        console.log("Simulating handleOps on Sepolia Fork...");
        
        // We broadcast as the deployer to match on-chain behavior
        vm.startBroadcast(verifiableSigner);
        entryPoint.handleOps(ops, payable(verifiableSigner));
        vm.stopBroadcast();
        
        console.log("Success in fork!");
    }
}
