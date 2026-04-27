// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {MockServiceManager} from "../src/MockServiceManager.sol";

contract DeployMock is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address admin = vm.addr(pk);
        
        vm.startBroadcast(pk);
        MockServiceManager mock = new MockServiceManager(admin);
        
        // Grant Relayer Role to Account 1
        address relayer = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        mock.grantRole(mock.RELAYER_ROLE(), relayer);
        mock.updateRelayerLimit(relayer, 100);

        console.log("MOCK_SERVICE_MANAGER_DEPLOYED_AT:", address(mock));
        console.log("RELAYER_AUTHORIZED:", relayer);
        
        vm.stopBroadcast();
    }
}
