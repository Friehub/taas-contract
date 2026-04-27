// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {TaaSSpokeServiceManager} from "../src/TaaSSpokeServiceManager.sol";

contract DeploySpoke is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        TaaSSpokeServiceManager manager = new TaaSSpokeServiceManager(admin);
        
        console.log("TaaSSpokeServiceManager deployed at:", address(manager));
        console.log("Admin address:", admin);

        vm.stopBroadcast();
    }
}
