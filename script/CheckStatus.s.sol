// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import {IAVSDirectory} from "@eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
interface IDelegationManager {
    function getOperatorStake(address operator, address strategy) external view returns (uint256);
}

contract CheckStatus is Script {
    // Sepolia Addresses
    address public constant AVS_DIRECTORY = 0xa789c91ECDdae96865913130B786140Ee17aF545;
    address public constant SERVICE_MANAGER = 0x8619dabd357CD4eF252C847ac1063a76A60F2261;
    address public constant DELEGATION_MANAGER = 0xa44151489Dafcc7Da8048601610e4931e4Af565a; // Sepolia (Verified Checksum)
    address public constant BEACON_ETH_STRATEGY = 0xbeaC0eeEeeeeEEeEeEEEEeeEEeEeeeEeeEEBEaC0;
    address public constant DEFAULT_OPERATOR = 0xc1b5Dd31524aBF5d890C369509095A5bEF5d34fb;

    function run() external view {
        address operator = vm.envOr("OPERATOR_ADDRESS", DEFAULT_OPERATOR);
        IAVSDirectory avsDirectory = IAVSDirectory(AVS_DIRECTORY);
        
        console.log("--- TaaS AVS Verification Audit ---");
        console.log("AVS ServiceManager:", SERVICE_MANAGER);
        console.log("Operator Address:", operator);
        
        bytes memory data = abi.encodeWithSignature("avsOperatorStatus(address,address)", SERVICE_MANAGER, operator);
        (bool success, bytes memory result) = AVS_DIRECTORY.staticcall(data);
        
        if (success) {
            uint8 status = abi.decode(result, (uint8));
            if (status == 1) {
                console.log("STATUS: REGISTERED (Proof Verified)");
                
                // Query Stake
                IDelegationManager dm = IDelegationManager(DELEGATION_MANAGER);
                uint256 stake = dm.getOperatorStake(operator, BEACON_ETH_STRATEGY);
                console.log("Native ETH Stake:", stake / 1e18, "ETH");
                
                if (stake < 1 ether) {
                    console.log("WARNING: Stake is below the 1 ETH minimum requirement!");
                }
            } else {
                console.log("STATUS: NOT REGISTERED");
            }
        } else {
            console.log("Query failed (Check RPC/Addresses)");
        }
    }
}
