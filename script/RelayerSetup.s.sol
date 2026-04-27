// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {TaaSServiceManager} from "../src/TaaSServiceManager.sol";

/**
 * @title RelayerSetup
 * @dev Prepares the ServiceManager for the new Relay-Payer model.
 */
contract RelayerSetup is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address relayer = vm.envAddress("RELAYER_ADDRESS");
        address managerAddr = vm.envAddress("TAAS_SERVICE_MANAGER");

        vm.startBroadcast(deployerPrivateKey);

        TaaSServiceManager manager = TaaSServiceManager(payable(managerAddr));
        
        // 1. Grant the Relayer role (The Sovereign Payer)
        bytes32 RELAYER_ROLE = manager.RELAYER_ROLE();
        if (!manager.hasRole(RELAYER_ROLE, relayer)) {
            console.log("Granting RELAYER_ROLE to:", relayer);
            manager.grantRole(RELAYER_ROLE, relayer);
        }

        // 2. Set institutional gas limits (The Firewall)
        console.log("Configuring daily gas spending limits for relayer...");
        manager.updateRelayerLimit(relayer, 0.5 ether); // 0.5 ETH daily limit protection

        vm.stopBroadcast();
        
        console.log("Relay-Payer Environment Hardened Successfully.");
    }
}
