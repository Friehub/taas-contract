// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "forge-std/Script.sol";
import "../src/TruthPaymaster.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

contract DeployPaymaster is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        TruthPaymaster pm = new TruthPaymaster(
            IEntryPoint(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789),
            0xc1b5Dd31524aBF5d890C369509095A5bEF5d34fb,
            0xc1b5Dd31524aBF5d890C369509095A5bEF5d34fb
        );
        
        console.log("TruthPaymaster deployed at:", address(pm));
        vm.stopBroadcast();
    }
}
