// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import {IDelegationManager} from "@eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {IAVSDirectory} from "@eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {ISignatureUtilsMixinTypes} from "@eigenlayer-contracts/src/contracts/interfaces/ISignatureUtilsMixin.sol";
import {TaaSServiceManager} from "../src/TaaSServiceManager.sol";

contract RegisterOperator is Script {
    IDelegationManager public delegationManager;
    IAVSDirectory public avsDirectory;
    TaaSServiceManager public serviceManager;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address operator = vm.addr(deployerPrivateKey);

        delegationManager = IDelegationManager(vm.envAddress("DELEGATION_MANAGER"));
        avsDirectory = IAVSDirectory(vm.envAddress("AVS_DIRECTORY"));
        serviceManager = TaaSServiceManager(vm.envAddress("SERVICE_MANAGER_PROXY"));

        vm.startBroadcast(deployerPrivateKey);

        // 1. Register as EigenLayer Operator (if needed)
        if (!delegationManager.isOperator(operator)) {
            console.log("Registering as EigenLayer Operator...");
            delegationManager.registerAsOperator(
                operator,
                0, // delegationDelay
                "" // metadataURI
            );
        } else {
            console.log("Already registered as EigenLayer Operator.");
        }

        // 2. Register to TaaS AVS
        console.log("Opting into TaaS AVS...");
            
            bytes32 salt = keccak256(abi.encodePacked(block.timestamp, operator));
            uint256 expiry = block.timestamp + 1 hours;

            bytes32 digestHash = avsDirectory.calculateOperatorAVSRegistrationDigestHash(
                operator,
                address(serviceManager),
                salt,
                expiry
            );

            (uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerPrivateKey, digestHash);
            bytes memory signature = abi.encodePacked(r, s, v);

            ISignatureUtilsMixinTypes.SignatureWithSaltAndExpiry memory operatorSignature = 
                ISignatureUtilsMixinTypes.SignatureWithSaltAndExpiry({
                    signature: signature,
                    salt: salt,
                    expiry: expiry
                });

            serviceManager.registerOperatorToAVS(operator, operatorSignature);
            console.log("Registration transaction submitted.");

        vm.stopBroadcast();
        console.log("Registration process complete. Please check Etherscan for event verification.");
    }
}
