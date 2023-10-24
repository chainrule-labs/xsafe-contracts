// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { PredictiveDeployer } from "../../src/PredictiveDeployer.sol";
import { ERC1967Proxy } from "../../src/dependencies/proxy/ERC1967Proxy.sol";
import { IPredictiveDeployerAdmin } from "../../src/interfaces/IPredictiveDeployerAdmin.sol";
import { CONTRACT_DEPLOYER } from "../common/constants.t.sol";

contract ERC1967ProxyTest is Test {
    /* solhint-disable func-name-mixedcase */

    // Test Contracts
    PredictiveDeployer public implementation;
    ERC1967Proxy public proxy;

    function setUp() public {
        implementation = new PredictiveDeployer();
        vm.prank(CONTRACT_DEPLOYER);
        proxy = new ERC1967Proxy(address(implementation), abi.encodeWithSignature("initialize()"));
    }

    function test_upgradeToAndCall() public {
        // Setup
        bytes32 implentationStorageSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        address implementationAddressV1 = address(uint160(uint256(vm.load(address(proxy), implentationStorageSlot))));

        // Pre-action assertions
        assertEq(implementationAddressV1, address(implementation));

        // Act
        PredictiveDeployer implementationV2 = new PredictiveDeployer();
        vm.prank(CONTRACT_DEPLOYER);
        IPredictiveDeployerAdmin(address(proxy)).upgradeToAndCall(address(implementationV2), "");

        // Post-action assertions
        address implementationAddressV2 = address(uint160(uint256(vm.load(address(proxy), implentationStorageSlot))));
        assertEq(implementationAddressV2, address(implementationV2));
    }

    function testFail_UpgradeToAndCallUnauthorized(address invalidDeployer) public {
        // Assumptions
        vm.assume(invalidDeployer != CONTRACT_DEPLOYER);

        // Setup
        PredictiveDeployer implementationV2 = new PredictiveDeployer();

        // Act
        vm.prank(invalidDeployer);
        IPredictiveDeployerAdmin(address(proxy)).upgradeToAndCall(address(implementationV2), "");
    }
}
