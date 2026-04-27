// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {TaaSSpokeServiceManager} from "../src/TaaSSpokeServiceManager.sol";

contract TestSpokeRequest is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address spokeAddr = vm.envAddress("SPOKE_MANAGER");

        vm.startBroadcast(deployerPrivateKey);

        TaaSSpokeServiceManager manager = TaaSSpokeServiceManager(spokeAddr);
        
        bytes32 taskId = manager.createNewTask(
            "weather.temperature",
            abi.encode("New York"),
            TaaSSpokeServiceManager.AggregationStrategy.MEDIAN,
            1,   // min sources (set to 1 for quick test)
            67,  // quorum %
            uint64(block.timestamp + 1 hours)
        );
        
        console.log("Truth Requested on Spoke! TaskID:", vm.toString(taskId));

        vm.stopBroadcast();
    }
}
