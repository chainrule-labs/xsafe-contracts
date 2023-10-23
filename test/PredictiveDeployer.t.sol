// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { PredictiveDeployer } from "../src/PredictiveDeployer.sol";
import { ERC1967Proxy } from "../src/dependencies/proxy/ERC1967Proxy.sol";
import { Child } from "./Child.t.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { IPredictiveDeployerAdmin } from "../src/interfaces/IPredictiveDeployerAdmin.sol";
import { CONTRACT_DEPLOYER } from "./common/constants.t.sol";

contract PredictiveDeployerTest is Test {
    /* solhint-disable func-name-mixedcase */

    PredictiveDeployer public implementation;
    ERC1967Proxy public proxy;
    Child public child;
    bytes public childBytecode;

    // Events
    event Deploy(address indexed sender, address indexed child, bytes32 hashedBytecode, uint256 nonce);

    function setUp() public {
        implementation = new PredictiveDeployer();
        vm.prank(CONTRACT_DEPLOYER);
        proxy = new ERC1967Proxy(address(implementation), abi.encodeWithSignature("initialize()"));
        child = new Child(address(this));

        // Get Bytecode
        bytes memory bytecode = type(Child).creationCode;
        childBytecode = abi.encodePacked(bytecode, abi.encode(address(this)));
    }

    function testFuzz_GetAddress(uint256 pkNum, address sender) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));

        uint256 currentNonce = IPredictiveDeployerAdmin(address(proxy)).userNonces(wallet.addr);

        // Get signature information
        bytes32 txHash = IPredictiveDeployerAdmin(address(proxy)).getTransactionHash(wallet.addr, currentNonce);

        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wallet.privateKey, messageHash);

        bytes memory signature = abi.encodePacked(r, s, v);

        // Expectation
        vm.startPrank(sender);
        uint256 snapShot = vm.snapshot();
        address expectedChild = IPredictiveDeployerAdmin(address(proxy)).deploy(wallet.addr, signature, childBytecode);

        // Set chain state to what it was before the deployment
        vm.revertTo(snapShot);

        // Act
        address actualChild = IPredictiveDeployerAdmin(address(proxy)).getAddress(wallet.addr, childBytecode);
        vm.stopPrank();

        // Assertions
        assertEq(actualChild, expectedChild);
    }

    function testFuzz_Deploy(uint256 pkNum, address sender) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));

        uint256 currentNonce = IPredictiveDeployerAdmin(address(proxy)).userNonces(wallet.addr);

        // Get signature information
        bytes32 txHash = IPredictiveDeployerAdmin(address(proxy)).getTransactionHash(wallet.addr, currentNonce);

        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wallet.privateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Expectations
        vm.startPrank(sender);
        address expectedChild = IPredictiveDeployerAdmin(address(proxy)).getAddress(wallet.addr, childBytecode);
        vm.expectEmit(true, true, true, true, address(proxy));
        emit Deploy(wallet.addr, expectedChild, keccak256(childBytecode), currentNonce);

        // Act
        address actualChild = IPredictiveDeployerAdmin(address(proxy)).deploy(wallet.addr, signature, childBytecode);
        vm.stopPrank();

        // Assertions
        assertEq(actualChild, expectedChild);
    }

    function test_CannotDeployReplay(uint256 pkNum) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));

        uint256 currentNonce = IPredictiveDeployerAdmin(address(proxy)).userNonces(wallet.addr);

        // Get signature information
        bytes32 txHash = IPredictiveDeployerAdmin(address(proxy)).getTransactionHash(wallet.addr, currentNonce);

        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wallet.privateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Deploy once
        IPredictiveDeployerAdmin(address(proxy)).deploy(wallet.addr, signature, childBytecode);

        // Act: attempt replay
        vm.expectRevert(PredictiveDeployer.Unauthorized.selector);
        IPredictiveDeployerAdmin(address(proxy)).deploy(wallet.addr, signature, childBytecode);
    }

    function test_CannotDeployWithoutApproval(uint256 pkNum, address invalidPrincipal) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));

        // Failing condition: principal is not the signer
        vm.assume(invalidPrincipal != wallet.addr);

        uint256 currentNonce = IPredictiveDeployerAdmin(address(proxy)).userNonces(wallet.addr);

        // Get signature information
        bytes32 txHash = IPredictiveDeployerAdmin(address(proxy)).getTransactionHash(wallet.addr, currentNonce);

        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wallet.privateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Act: attempt replay
        vm.expectRevert(PredictiveDeployer.Unauthorized.selector);
        IPredictiveDeployerAdmin(address(proxy)).deploy(invalidPrincipal, signature, childBytecode);
    }
}
