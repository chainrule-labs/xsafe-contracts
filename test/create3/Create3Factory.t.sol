// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { VmSafe } from "forge-std/Vm.sol";
import { Create3Factory } from "../../src/create3/Create3Factory.sol";
import { ERC1967Proxy } from "../../src/dependencies/proxy/ERC1967Proxy.sol";
import { ICreate3Factory } from "../../src/create3/interfaces/ICreate3Factory.sol";
import { TestSetup } from "./common/TestSetup.t.sol";
import { AddressLib } from "../common/libraries/AddressLib.t.sol";
import { DeploymentHelper } from "./helpers/DeploymentHelper.t.sol";
import { CONTRACT_DEPLOYER } from "../common/Constants.t.sol";

contract Create3FactoryTest is DeploymentHelper, TestSetup {
    /* solhint-disable func-name-mixedcase */

    using AddressLib for address[];

    function testFuzz_GetAddress(uint256 pkNum, address sender) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));

        // Get signature information
        bytes32 txHash = ICreate3Factory(address(proxy)).getTransactionHash(wallet.addr, strippedBytecodeChildA);

        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wallet.privateKey, messageHash);

        bytes memory signature = abi.encodePacked(r, s, v);

        // Expectation
        vm.startPrank(sender);
        uint256 snapShot = vm.snapshot();
        ICreate3Factory(address(proxy)).deploy(wallet.addr, signature, strippedBytecodeChildA, abi.encode(wallet.addr));
        address expectedChild = ICreate3Factory(address(proxy)).getDeploymentHistory(wallet.addr)[0];

        // Set chain state to what it was before the deployment
        vm.revertTo(snapShot);

        // Act
        address actualChild = ICreate3Factory(address(proxy)).getAddress(wallet.addr, strippedBytecodeChildA);
        vm.stopPrank();

        // Assertions
        assertEq(actualChild, expectedChild, "Equivalence violation: actualChild != expectedChild");
    }

    function testFuzz_Deploy(uint256 pkNum, address sender) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));
        bytes memory constructorArgsBytecodeChildA = abi.encode(wallet.addr);

        uint256 preDeployNonce = ICreate3Factory(address(proxy)).userNonces(wallet.addr, hashedStrippedBytecodeChildA);

        // Get signature information
        bytes32 txHash = ICreate3Factory(address(proxy)).getTransactionHash(wallet.addr, strippedBytecodeChildA);

        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wallet.privateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Expectations
        vm.startPrank(sender);
        address expectedChild = ICreate3Factory(address(proxy)).getAddress(wallet.addr, strippedBytecodeChildA);
        vm.expectEmit(true, true, true, true, address(proxy));
        emit Deploy(
            wallet.addr, expectedChild, keccak256(strippedBytecodeChildA), constructorArgsBytecodeChildA, preDeployNonce
        );

        // Act
        ICreate3Factory(address(proxy)).deploy(
            wallet.addr, signature, strippedBytecodeChildA, constructorArgsBytecodeChildA
        );
        address actualChild = ICreate3Factory(address(proxy)).getDeploymentHistory(wallet.addr)[0];

        vm.stopPrank();

        // Assertions
        assertEq(actualChild, expectedChild, "Equivalence violation: actualChild != expectedChild");
    }

    function testFuzz_DeployTwice(uint256 pkNum) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));
        bytes memory constructorArgsBytecode = abi.encode(wallet.addr);

        // First Deployment
        deployChild(address(proxy), wallet, strippedBytecodeChildA, constructorArgsBytecode);

        // Second Deployment
        deployChild(address(proxy), wallet, strippedBytecodeChildA, constructorArgsBytecode);

        // Fetch Deployment History
        address[] memory deployementHistory = ICreate3Factory(address(proxy)).getDeploymentHistory(wallet.addr);
        address actualChild1 = deployementHistory[0];
        address actualChild2 = deployementHistory[1];

        // Assertions
        assertTrue(
            actualChild1 != address(0) && actualChild2 != address(0),
            "Truth Violation: actualChild1 != address(0) && actualChild2 != address(0)."
        );
        assertTrue(actualChild1 != actualChild2, "Truth Violation: actualChild1 != actualChild2");
    }

    function testFuzz_DeployOrderIndependence(uint256 pkNum) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));
        bytes memory constructorArgsBytecode = abi.encode(wallet.addr);

        // First deployment set
        uint256 snapShot = vm.snapshot();
        deployChild(address(proxy), wallet, strippedBytecodeChildA, constructorArgsBytecode);
        deployChild(address(proxy), wallet, strippedBytecodeChildB, "");
        address[] memory setOneDeployementHistory = ICreate3Factory(address(proxy)).getDeploymentHistory(wallet.addr);
        address setOneChildA = setOneDeployementHistory[0];
        address setOneChildB = setOneDeployementHistory[1];

        // Set chain state to what it was before first deployment set
        vm.revertTo(snapShot);

        // Second deployment set (reverse order)
        deployChild(address(proxy), wallet, strippedBytecodeChildB, "");
        deployChild(address(proxy), wallet, strippedBytecodeChildA, constructorArgsBytecode);
        address[] memory setTwoDeployementHistory = ICreate3Factory(address(proxy)).getDeploymentHistory(wallet.addr);
        address setTwoChildB = setTwoDeployementHistory[0];
        address setTwoChildA = setTwoDeployementHistory[1];

        // Assertions
        assertEq(setOneChildA, setTwoChildA, "Equivalence violation: setOneChildA != setTwoChildA");
        assertEq(setOneChildB, setTwoChildB, "Equivalence violation: setOneChildB != setTwoChildB");
    }

    function testFuzz_DeployBytecodeVarianceIndependence(uint256 pkNum) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));
        assertTrue(wallet.addr != CONTRACT_DEPLOYER, "Truth Violation: wallet.addr != CONTRACT_DEPLOYER");

        bytes memory constructorArgsBytecode1 = abi.encode(wallet.addr);
        bytes memory constructorArgsBytecode2 = abi.encode(CONTRACT_DEPLOYER);

        // First deployment
        uint256 snapShot = vm.snapshot();
        deployChild(address(proxy), wallet, strippedBytecodeChildA, constructorArgsBytecode1);
        address[] memory setOneDeployementHistory = ICreate3Factory(address(proxy)).getDeploymentHistory(wallet.addr);
        address childOne = setOneDeployementHistory[0];

        // Set chain state to what it was before first deployment
        vm.revertTo(snapShot);

        // Second deployment (different constructor args)
        deployChild(address(proxy), wallet, strippedBytecodeChildA, constructorArgsBytecode2);
        address[] memory setTwoDeployementHistory = ICreate3Factory(address(proxy)).getDeploymentHistory(wallet.addr);
        address childTwo = setTwoDeployementHistory[0];

        // Assertions
        assertEq(childOne, childTwo, "Equivalence violation: childOne != childTwo");
    }

    function testFuzz_DeployNonceUpdate(uint256 pkNum) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encode(uint256(pkNum)))));
        bytes memory constructorArgsBytecode = abi.encode(wallet.addr);
        uint256 preDeployNonce = ICreate3Factory(address(proxy)).userNonces(wallet.addr, hashedStrippedBytecodeChildA);

        // Act
        deployChild(address(proxy), wallet, strippedBytecodeChildA, constructorArgsBytecode);
        uint256 postDeployNonce = ICreate3Factory(address(proxy)).userNonces(wallet.addr, hashedStrippedBytecodeChildA);

        // Assertions
        assertEq(postDeployNonce, preDeployNonce + 1, "Equivalence violation: postDeployNonce != preDeployNonce + 1");
    }

    function testFuzz_DeployHistoryUpdate(uint256 pkNum) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));
        bytes memory constructorArgsBytecode = abi.encode(wallet.addr);
        address[] memory deploymentHistory = ICreate3Factory(address(proxy)).getDeploymentHistory(wallet.addr);

        // Pre-act assertions
        assertEq(deploymentHistory.length, 0);

        // Expectation 1
        address child1 = ICreate3Factory(address(proxy)).getAddress(wallet.addr, strippedBytecodeChildA);

        // Act 1
        deployChild(address(proxy), wallet, strippedBytecodeChildA, constructorArgsBytecode);
        deploymentHistory = ICreate3Factory(address(proxy)).getDeploymentHistory(wallet.addr);

        // Assertions 1
        assertEq(deploymentHistory.length, 1, "Equivalence violation: deploymentHistory.length != 1");
        assertTrue(deploymentHistory.includes(child1), "Truth Violation: deploymentHistory.includes(child1)");

        // Expectation 2
        address child2 = ICreate3Factory(address(proxy)).getAddress(wallet.addr, strippedBytecodeChildA);

        // Act 2
        deployChild(address(proxy), wallet, strippedBytecodeChildA, constructorArgsBytecode);
        deploymentHistory = ICreate3Factory(address(proxy)).getDeploymentHistory(wallet.addr);

        // Assertions 2
        assertEq(deploymentHistory.length, 2, "Equivalence violation: deploymentHistory.length != 2");
        assertTrue(deploymentHistory.includes(child2), "Truth Violation: deploymentHistory.includes(child2)");
    }

    function testFuzz_CannotDeployReplay(uint256 pkNum) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));

        // Get signature information
        bytes32 txHash = ICreate3Factory(address(proxy)).getTransactionHash(wallet.addr, strippedBytecodeChildA);

        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wallet.privateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Deploy once
        ICreate3Factory(address(proxy)).deploy(wallet.addr, signature, strippedBytecodeChildA, abi.encode(wallet.addr));

        // Act: attempt replay
        vm.expectRevert(Create3Factory.Unauthorized.selector);
        ICreate3Factory(address(proxy)).deploy(wallet.addr, signature, strippedBytecodeChildA, abi.encode(wallet.addr));
    }

    function testFuzz_CannotDeployWithoutApproval(uint256 pkNum, address invalidPrincipal) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));

        // Failing condition: principal is not the signer
        vm.assume(invalidPrincipal != wallet.addr);

        // Get signature information
        bytes32 txHash = ICreate3Factory(address(proxy)).getTransactionHash(wallet.addr, strippedBytecodeChildA);

        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wallet.privateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Act: attempt with invalid principal
        vm.expectRevert(Create3Factory.Unauthorized.selector);
        ICreate3Factory(address(proxy)).deploy(
            invalidPrincipal, signature, strippedBytecodeChildA, abi.encode(wallet.addr)
        );
    }

    function testFuzz_GetBytecodeHash(bytes memory _childStrippedBytecode) public {
        vm.assume(_childStrippedBytecode.length > 0 && _childStrippedBytecode.length <= 24576); // max contract size

        // Act
        bytes32 actualHash = ICreate3Factory(address(proxy)).getBytecodeHash(_childStrippedBytecode);

        // Expected
        bytes32 expectedHash = keccak256(_childStrippedBytecode);

        // Assertions
        assertEq(actualHash, expectedHash, "Equivalence Violation: actualHash != expectedHash");
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
