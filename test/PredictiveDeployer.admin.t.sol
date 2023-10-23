// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { PredictiveDeployer } from "../src/PredictiveDeployer.sol";
import { ERC1967Proxy } from "../src/dependencies/proxy/ERC1967Proxy.sol";
import { IERC20 } from "../src/dependencies/token/interfaces/IERC20.sol";
import { IPredictiveDeployerAdmin } from "../src/interfaces/IPredictiveDeployerAdmin.sol";
import { CONTRACT_DEPLOYER, TEST_ERC20_TOKEN } from "./common/constants.t.sol";

contract PredictiveDeployerTest is Test {
    /* solhint-disable func-name-mixedcase */

    PredictiveDeployer public implementation;
    ERC1967Proxy public proxy;

    function setUp() public {
        // Instantiate contracts
        implementation = new PredictiveDeployer();
        vm.prank(CONTRACT_DEPLOYER);
        proxy = new ERC1967Proxy(address(implementation), abi.encodeWithSignature("initialize()"));
    }

    function test_ExtractNative(uint256 amount) public {
        // Setup
        vm.assume(amount > 0 && amount < 1e22);
        vm.deal(address(proxy), amount);

        assertEq(address(proxy).balance, amount);

        uint256 preLocalBalance = CONTRACT_DEPLOYER.balance;

        // Act
        vm.prank(CONTRACT_DEPLOYER);
        IPredictiveDeployerAdmin(address(proxy)).extractNative();

        assertEq(CONTRACT_DEPLOYER.balance, preLocalBalance + amount);
    }

    function testFail_ExtractNativeUnauthorized(uint256 amount, address invalidExtractor) public {
        // Setup
        vm.assume(amount > 0 && amount < 1e22);
        vm.assume(invalidExtractor != CONTRACT_DEPLOYER);
        vm.deal(address(proxy), amount);

        // Act
        vm.prank(invalidExtractor);
        IPredictiveDeployerAdmin(address(proxy)).extractNative();
    }
}

contract PredictiveDeployerForkTest is Test {
    /* solhint-disable func-name-mixedcase */

    PredictiveDeployer public implementation;
    ERC1967Proxy public proxy;
    uint256 public mainnetFork;

    function setUp() public {
        // Setup: use mainnet fork
        mainnetFork = vm.createFork(vm.envString("ETHEREUM_RPC"));
        vm.selectFork(mainnetFork);

        // Instantiate contracts
        implementation = new PredictiveDeployer();
        vm.prank(CONTRACT_DEPLOYER);
        proxy = new ERC1967Proxy(address(implementation), abi.encodeWithSignature("initialize()"));
    }

    function test_ActiveFork() public {
        assertEq(vm.activeFork(), mainnetFork);
    }

    function test_ExtractERC20(uint256 amount) public {
        // Assumptions
        vm.assume(amount > 0 && amount <= 1e6 * 1e5);

        // Setup: give the contract ERC20 tokens
        deal(TEST_ERC20_TOKEN, address(proxy), amount);

        // Pre-action assertions
        assertEq(IERC20(TEST_ERC20_TOKEN).balanceOf(address(proxy)), amount);

        // Act
        vm.prank(CONTRACT_DEPLOYER);
        IPredictiveDeployerAdmin(address(proxy)).extractERC20(TEST_ERC20_TOKEN);

        // Post-action assertions
        assertEq(IERC20(TEST_ERC20_TOKEN).balanceOf(address(proxy)), 0);
        assertEq(IERC20(TEST_ERC20_TOKEN).balanceOf(CONTRACT_DEPLOYER), amount);
    }

    function testFail_ExtractERC20Unauthorized(uint256 amount, address invalidExtractor) public {
        // Assumptions
        vm.assume(amount > 0 && amount <= 1e6 * 1e5);
        vm.assume(invalidExtractor != CONTRACT_DEPLOYER);

        // Setup: give the contract ERC20 tokens
        deal(TEST_ERC20_TOKEN, address(proxy), amount);

        // Act
        vm.prank(invalidExtractor);
        IPredictiveDeployerAdmin(address(proxy)).extractERC20(TEST_ERC20_TOKEN);
    }
}
