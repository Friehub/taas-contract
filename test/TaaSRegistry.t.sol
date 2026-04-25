// SPDX-License-Identifier: Proprietary - Friehub (TaaS Gateway)
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/TaaSCapabilityRegistry.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TaaSRegistryTest is Test {
    TaaSCapabilityRegistry registry;
    address owner = address(1);
    address operator1 = address(2);

    function setUp() public {
        vm.startPrank(owner);
        TaaSCapabilityRegistry impl = new TaaSCapabilityRegistry();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl),
            abi.encodeWithSelector(TaaSCapabilityRegistry.initialize.selector, owner, address(0))
        );
        registry = TaaSCapabilityRegistry(address(proxy));
        vm.stopPrank();
    }

    function test_declareCapabilities() public {
        // In bootstrap mode (stakeRegistry = 0), any address can declare

        // Declare capabilities
        vm.startPrank(operator1);
        string[] memory caps = new string[](2);
        caps[0] = "price-feeds";
        caps[1] = "zero-knowledge";
        registry.declareCapabilities(caps);
        vm.stopPrank();

        // Check if saved
        string[] memory savedCaps = registry.getOperatorCapabilities(operator1);
        assertEq(savedCaps.length, 2);
        assertEq(savedCaps[0], "price-feeds");
        assertEq(savedCaps[1], "zero-knowledge");
    }

    function test_unregisteredOperatorCannotDeclare() public {
        vm.startPrank(address(3));
        string[] memory caps = new string[](1);
        caps[0] = "invalid";
        vm.expectRevert(abi.encodeWithSelector(TaaSCapabilityRegistry.OperatorNotRegistered.selector, address(3)));
        registry.declareCapabilities(caps);
        vm.stopPrank();
    }
}
