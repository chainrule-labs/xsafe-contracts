// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { Create3Factory } from "../../src/create3/Create3Factory.sol";
import { ERC1967Proxy } from "../../src/dependencies/proxy/ERC1967Proxy.sol";
import { IERC20 } from "../../src/dependencies/token/interfaces/IERC20.sol";
import { ICreate3FactoryAdmin } from "../../src/create3/interfaces/ICreate3FactoryAdmin.sol";
import { TestSetup } from "./common/TestSetup.t.sol";
import { CONTRACT_DEPLOYER, TEST_ERC20_TOKEN } from "../common/Constants.t.sol";

contract Create3FactoryAdminTest is TestSetup {
    /* solhint-disable func-name-mixedcase */

    function test_ExtractNative(uint256 amount) public {
        // Setup
        vm.assume(amount > 0 && amount < 1e22);
        vm.deal(address(proxy), amount);

        assertEq(address(proxy).balance, amount, "Equivalence Violation: address(proxy) native balance and amount.");

        uint256 preLocalBalance = CONTRACT_DEPLOYER.balance;

        // Act
        vm.prank(CONTRACT_DEPLOYER);
        ICreate3FactoryAdmin(address(proxy)).extractNative();

        assertEq(
            CONTRACT_DEPLOYER.balance,
            preLocalBalance + amount,
            "Equivalence Violation: CONTRACT_DEPLOYER native balance and preLocalBalance + amount."
        );
    }

    function testFail_ExtractNativeUnauthorized(uint256 amount, address invalidExtractor) public {
        // Setup
        vm.assume(amount > 0 && amount < 1e22);
        vm.assume(invalidExtractor != CONTRACT_DEPLOYER);
        vm.deal(address(proxy), amount);

        // Act
        vm.prank(invalidExtractor);
        ICreate3FactoryAdmin(address(proxy)).extractNative();
    }
}

contract Create3FactoryForkTest is Test {
    /* solhint-disable func-name-mixedcase */

    Create3Factory public implementation;
    ERC1967Proxy public proxy;
    uint256 public mainnetFork;

    function setUp() public {
        // Setup: use mainnet fork
        mainnetFork = vm.createFork(vm.envString("ETHEREUM_RPC"));
        vm.selectFork(mainnetFork);

        // Instantiate contracts
        implementation = new Create3Factory();
        vm.prank(CONTRACT_DEPLOYER);
        proxy = new ERC1967Proxy(address(implementation), abi.encodeWithSignature("initialize()"));
    }

    function test_ActiveFork() public {
        assertEq(vm.activeFork(), mainnetFork, "Equivalence Violation: vm.activeFork() and mainnetFork.");
    }

    function test_ExtractERC20(uint256 amount) public {
        // Assumptions
        vm.assume(amount > 0 && amount <= 1e6 * 1e5);

        // Setup: give the contract ERC20 tokens
        deal(TEST_ERC20_TOKEN, address(proxy), amount);

        // Pre-action assertions
        assertEq(
            IERC20(TEST_ERC20_TOKEN).balanceOf(address(proxy)),
            amount,
            "Equivalence Violation: address(proxy) TEST_ERC20_TOKEN balance and amount."
        );

        // Act
        vm.prank(CONTRACT_DEPLOYER);
        ICreate3FactoryAdmin(address(proxy)).extractERC20(TEST_ERC20_TOKEN);

        // Post-action assertions
        assertEq(
            IERC20(TEST_ERC20_TOKEN).balanceOf(address(proxy)),
            0,
            "Equivalence Violation: address(proxy) TEST_ERC20_TOKEN balance and 0."
        );
        assertEq(
            IERC20(TEST_ERC20_TOKEN).balanceOf(CONTRACT_DEPLOYER),
            amount,
            "Equivalence Violation: CONTRACT_DEPLOYER TEST_ERC20_TOKEN balance and amount."
        );
    }

    function testFail_ExtractERC20Unauthorized(uint256 amount, address invalidExtractor) public {
        // Assumptions
        vm.assume(amount > 0 && amount <= 1e6 * 1e5);
        vm.assume(invalidExtractor != CONTRACT_DEPLOYER);

        // Setup: give the contract ERC20 tokens
        deal(TEST_ERC20_TOKEN, address(proxy), amount);

        // Act
        vm.prank(invalidExtractor);
        ICreate3FactoryAdmin(address(proxy)).extractERC20(TEST_ERC20_TOKEN);
    }
}
