// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {TaaSSpokeServiceManager} from "../src/TaaSSpokeServiceManager.sol";

contract SyncOperators is Script {
    function run() external {
        uint256 adminPrivateKey = vm.envUint("PRIVATE_KEY");
        address spokeAddr = vm.envAddress("SPOKE_MANAGER");
        address operator = vm.envAddress("OPERATOR_ADDRESS");

        vm.startBroadcast(adminPrivateKey);

        TaaSSpokeServiceManager manager = TaaSSpokeServiceManager(spokeAddr);
        manager.updateOperator(operator, true);
        
        console.log("Operator", operator, "authorized on spoke", spokeAddr);

        vm.stopBroadcast();
    }
}
