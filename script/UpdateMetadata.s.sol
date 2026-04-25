// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import {IAVSDirectory} from "@eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";

contract UpdateMetadata is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // The public URL of your metadata.json
        string memory metadataURI = vm.envOr("METADATA_URI", string("https://raw.githubusercontent.com/Friehub/taas-contract/main/metadata.json"));

        IAVSDirectory avsDirectory = IAVSDirectory(vm.envAddress("AVS_DIRECTORY"));

        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Updating AVS Metadata URI on Sepolia...");
        avsDirectory.updateAVSMetadataURI(metadataURI);
        
        vm.stopBroadcast();
        console.log("Metadata update transaction submitted.");
    }
}
