// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import { VmSafe } from "forge-std/Vm.sol";
import { Create2Factory } from "../../src/create2/Create2Factory.sol";
import { ERC1967Proxy } from "../../src/dependencies/proxy/ERC1967Proxy.sol";
import { ICreate2Factory } from "../../src/create2/interfaces/ICreate2Factory.sol";
import { TestSetup } from "./common/TestSetup.t.sol";
import { AddressLib } from "../common/libraries/AddressLib.t.sol";
import { DeploymentHelper } from "./helpers/DeploymentHelper.t.sol";
import { CONTRACT_DEPLOYER } from "../common/Constants.t.sol";

contract Create2FactoryTest is DeploymentHelper, TestSetup {
    /* solhint-disable func-name-mixedcase */

    using AddressLib for address[];

    function testFuzz_GetAddress(uint256 pkNum, address sender) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));

        uint256 currentNonce = ICreate2Factory(address(proxy)).userNonces(wallet.addr, hashedBytecodeChildA);

        // Get signature information
        bytes32 txHash = ICreate2Factory(address(proxy)).getTransactionHash(wallet.addr, bytecodeChildA, currentNonce);

        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wallet.privateKey, messageHash);

        bytes memory signature = abi.encodePacked(r, s, v);

        // Expectation
        vm.startPrank(sender);
        uint256 snapShot = vm.snapshot();
        address expectedChild = ICreate2Factory(address(proxy)).deploy(wallet.addr, signature, bytecodeChildA);

        // Set chain state to what it was before the deployment
        vm.revertTo(snapShot);

        // Act
        address actualChild = ICreate2Factory(address(proxy)).getAddress(wallet.addr, bytecodeChildA);
        vm.stopPrank();

        // Assertions
        assertEq(actualChild, expectedChild);
    }

    function testFuzz_Deploy(uint256 pkNum, address sender) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));

        uint256 preDeployNonce = ICreate2Factory(address(proxy)).userNonces(wallet.addr, hashedBytecodeChildA);

        // Get signature information
        bytes32 txHash = ICreate2Factory(address(proxy)).getTransactionHash(wallet.addr, bytecodeChildA, preDeployNonce);

        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wallet.privateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Expectations
        vm.startPrank(sender);
        address expectedChild = ICreate2Factory(address(proxy)).getAddress(wallet.addr, bytecodeChildA);
        vm.expectEmit(true, true, true, true, address(proxy));
        emit Deploy(wallet.addr, expectedChild, keccak256(bytecodeChildA), preDeployNonce);

        // Act
        address actualChild = ICreate2Factory(address(proxy)).deploy(wallet.addr, signature, bytecodeChildA);
        vm.stopPrank();

        // Assertions
        assertEq(actualChild, expectedChild);
    }

    function testFuzz_DeployTwice(uint256 pkNum) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));

        // First Deployment
        address actualChild1 = deployChild(address(proxy), wallet, bytecodeChildA);

        // Second Deployment
        address actualChild2 = deployChild(address(proxy), wallet, bytecodeChildA);

        // Assertions
        assertTrue(actualChild1 != address(0) && actualChild2 != address(0));
        assertTrue(actualChild1 != actualChild2);
    }

    function testFuzz_DeployOrderIndependence(uint256 pkNum) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));

        // First deployment set
        uint256 snapShot = vm.snapshot();
        address setOneChildA = deployChild(address(proxy), wallet, bytecodeChildA);
        address setOneChildB = deployChild(address(proxy), wallet, bytecodeChildB);

        // Set chain state to what it was before first deployment set
        vm.revertTo(snapShot);

        // Second deployment set (reverse order)
        address setTwoChildB = deployChild(address(proxy), wallet, bytecodeChildB);
        address setTwoChildA = deployChild(address(proxy), wallet, bytecodeChildA);

        // Assertions
        assertEq(setOneChildA, setTwoChildA);
        assertEq(setOneChildB, setTwoChildB);
    }

    function testFuzz_DeployNonceUpdate(uint256 pkNum) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));
        uint256 preDeployNonce = ICreate2Factory(address(proxy)).userNonces(wallet.addr, hashedBytecodeChildA);

        // Act
        deployChild(address(proxy), wallet, bytecodeChildA);
        uint256 postDeployNonce = ICreate2Factory(address(proxy)).userNonces(wallet.addr, hashedBytecodeChildA);

        // Assertions
        assertEq(postDeployNonce, preDeployNonce + 1);
    }

    function testFuzz_DeployHistoryUpdate(uint256 pkNum) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));

        address[] memory deploymentHistory = ICreate2Factory(address(proxy)).getDeploymentHistory(wallet.addr);

        // Pre-act assertions
        assertEq(deploymentHistory.length, 0);

        // Act
        address child1 = deployChild(address(proxy), wallet, bytecodeChildA);
        deploymentHistory = ICreate2Factory(address(proxy)).getDeploymentHistory(wallet.addr);

        // Assertions
        assertEq(deploymentHistory.length, 1);
        assertTrue(deploymentHistory.includes(child1));

        address child2 = deployChild(address(proxy), wallet, bytecodeChildA);
        deploymentHistory = ICreate2Factory(address(proxy)).getDeploymentHistory(wallet.addr);

        // Assertions
        assertEq(deploymentHistory.length, 2);
        assertTrue(deploymentHistory.includes(child2));
    }

    function testFuzz_CannotDeployReplay(uint256 pkNum) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));

        uint256 currentNonce = ICreate2Factory(address(proxy)).userNonces(wallet.addr, hashedBytecodeChildA);

        // Get signature information
        bytes32 txHash = ICreate2Factory(address(proxy)).getTransactionHash(wallet.addr, bytecodeChildA, currentNonce);

        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wallet.privateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Deploy once
        ICreate2Factory(address(proxy)).deploy(wallet.addr, signature, bytecodeChildA);

        // Act: attempt replay
        vm.expectRevert(Create2Factory.Unauthorized.selector);
        ICreate2Factory(address(proxy)).deploy(wallet.addr, signature, bytecodeChildA);
    }

    function testFuzz_CannotDeployWithoutApproval(uint256 pkNum, address invalidPrincipal) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));

        // Failing condition: principal is not the signer
        vm.assume(invalidPrincipal != wallet.addr);

        uint256 currentNonce = ICreate2Factory(address(proxy)).userNonces(wallet.addr, hashedBytecodeChildA);

        // Get signature information
        bytes32 txHash = ICreate2Factory(address(proxy)).getTransactionHash(wallet.addr, bytecodeChildA, currentNonce);

        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wallet.privateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Act: attempt with invalid principal
        vm.expectRevert(Create2Factory.Unauthorized.selector);
        ICreate2Factory(address(proxy)).deploy(invalidPrincipal, signature, bytecodeChildA);
    }

    function testFuzz_GetBytecodeHash(bytes memory _childBytecode) public {
        vm.assume(_childBytecode.length > 0 && _childBytecode.length <= 24576); // max contract size

        // Act
        bytes32 actualHash = ICreate2Factory(address(proxy)).getBytecodeHash(_childBytecode);

        // Expected
        bytes32 expectedHash = keccak256(_childBytecode);

        // Assertions
        assertEq(actualHash, expectedHash, "Hash mismatch.");
    }

    function testFuzz_Receive(uint256 transferAmount) public {
        // Assumptions
        vm.assume(transferAmount != 0 && transferAmount <= 1000 ether);

        // Setup: deal transferAmount plus enough for gas
        uint256 gasMoney = 1 ether;
        vm.deal(address(this), transferAmount + gasMoney);

        // Expectations
        assertEq(address(proxy).balance, 0);

        // Act
        (bool sent,) = payable(address(proxy)).call{ value: transferAmount }("");
        require(sent, "Failed to send Ether");

        // Assumptions
        assertEq(address(proxy).balance, transferAmount);
    }
}
