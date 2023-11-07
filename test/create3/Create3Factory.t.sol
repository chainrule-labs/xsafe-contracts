// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { VmSafe } from "forge-std/Vm.sol";
import { Create3Factory } from "../../src/create3/Create3Factory.sol";
import { ERC1967Proxy } from "../../src/dependencies/proxy/ERC1967Proxy.sol";
import { ICreate3Factory } from "../../src/create3/interfaces/ICreate3Factory.sol";
import { TestSetup, ChildrenWithConstructorArgs } from "./common/contracts/TestSetup.t.sol";
import { AddressLib } from "./common/libraries/AddressLib.t.sol";
import { DeploymentHelper } from "./helpers/DeploymentHelper.t.sol";
import { CONTRACT_DEPLOYER } from "./common/Constants.t.sol";

contract Create3FactoryTest is TestSetup, DeploymentHelper {
    /* solhint-disable func-name-mixedcase */

    using AddressLib for address[];

    function testFuzz_GetAddress(uint256 pkNum, address sender) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));

        (bytes memory creationCode, bytes memory constructorArgsCode) = getDeploymentBytecode();

        bytes memory signature = getSignature(address(proxy), wallet, creationCode);

        // Expectation
        vm.startPrank(sender);
        uint256 snapShot = vm.snapshot();
        ICreate3Factory(address(proxy)).deploy(wallet.addr, signature, creationCode, constructorArgsCode);
        address expectedChild = ICreate3Factory(address(proxy)).getDeploymentHistory(wallet.addr)[0];

        // Set chain state to what it was before the deployment
        vm.revertTo(snapShot);

        // Act
        address actualChild = ICreate3Factory(address(proxy)).getAddress(wallet.addr, creationCode);
        vm.stopPrank();

        // Assertions
        assertEq(actualChild, expectedChild, "Equivalence violation: actualChild != expectedChild");
    }

    function testFuzz_Deploy(uint256 pkNum, address sender) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));

        (bytes memory creationCode, bytes memory constructorArgsCode) = getDeploymentBytecode();

        bytes memory signature = getSignature(address(proxy), wallet, creationCode);

        // Expectations
        vm.startPrank(sender);
        uint256 preDeployNonce = ICreate3Factory(address(proxy)).userNonces(wallet.addr, keccak256(creationCode));
        address expectedChild = ICreate3Factory(address(proxy)).getAddress(wallet.addr, creationCode);
        vm.expectEmit(true, true, true, true, address(proxy));
        emit Deploy(wallet.addr, expectedChild, keccak256(creationCode), constructorArgsCode, preDeployNonce);

        // Act
        ICreate3Factory(address(proxy)).deploy(wallet.addr, signature, creationCode, constructorArgsCode);
        address actualChild = ICreate3Factory(address(proxy)).getDeploymentHistory(wallet.addr)[0];

        vm.stopPrank();

        // Assertions
        assertEq(actualChild, expectedChild, "Equivalence violation: actualChild != expectedChild");
    }

    function testFuzz_DeployTwice(uint256 pkNum) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));

        (bytes memory creationCode, bytes memory constructorArgsCode) = getDeploymentBytecode();

        // First Deployment
        deployChild(address(proxy), wallet, creationCode, constructorArgsCode);

        // Second Deployment
        deployChild(address(proxy), wallet, creationCode, constructorArgsCode);

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

        (bytes memory creationCode, bytes memory constructorArgsCode) = getDeploymentBytecode();

        // First deployment set
        uint256 snapShot = vm.snapshot();
        deployChild(address(proxy), wallet, creationCode, constructorArgsCode);
        deployChild(address(proxy), wallet, noArgsChildCreationCode, "");
        address[] memory setOneDeployementHistory = ICreate3Factory(address(proxy)).getDeploymentHistory(wallet.addr);
        address setOneChildWithArgs = setOneDeployementHistory[0];
        address setOneChildWithoutArgs = setOneDeployementHistory[1];

        // Set chain state to what it was before first deployment set
        vm.revertTo(snapShot);

        // Second deployment set (reverse order)
        deployChild(address(proxy), wallet, noArgsChildCreationCode, "");
        deployChild(address(proxy), wallet, creationCode, constructorArgsCode);
        address[] memory setTwoDeployementHistory = ICreate3Factory(address(proxy)).getDeploymentHistory(wallet.addr);
        address setTwoChildWithoutArgs = setTwoDeployementHistory[0];
        address setTwoChildWithArgs = setTwoDeployementHistory[1];

        // Assertions
        assertEq(
            setOneChildWithArgs,
            setTwoChildWithArgs,
            "Equivalence violation: setOneChildWithArgs != setTwoChildWithArgs"
        );
        assertEq(
            setOneChildWithoutArgs,
            setTwoChildWithoutArgs,
            "Equivalence violation: setOneChildWithoutArgs != setTwoChildWithoutArgs"
        );
    }

    function testFuzz_DeployBytecodeVarianceIndependence(uint256 pkNum) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));
        assertTrue(wallet.addr != CONTRACT_DEPLOYER, "Truth Violation: wallet.addr != CONTRACT_DEPLOYER");

        ChildrenWithConstructorArgs.ChildContractData[] memory childrenData =
            childrenWithConstructorArgs.getChildrenData();

        for (uint256 i = 0; i < childrenData.length; i++) {
            // First deployment
            uint256 snapShot = vm.snapshot();
            deployChild(address(proxy), wallet, childrenData[i].creationCode, childrenData[i].constructorArgsCode1);
            address[] memory setOneDeployementHistory =
                ICreate3Factory(address(proxy)).getDeploymentHistory(wallet.addr);
            address childOne = setOneDeployementHistory[0];

            // Set chain state to what it was before first deployment
            vm.revertTo(snapShot);

            // Second deployment (different constructor args)
            deployChild(address(proxy), wallet, childrenData[i].creationCode, childrenData[i].constructorArgsCode2);
            address[] memory setTwoDeployementHistory =
                ICreate3Factory(address(proxy)).getDeploymentHistory(wallet.addr);
            address childTwo = setTwoDeployementHistory[0];

            // Assertions
            assertEq(childOne, childTwo, "Equivalence violation: childOne != childTwo");
        }
    }

    function testFuzz_DeployNonceUpdate(uint256 pkNum) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));

        (bytes memory creationCode, bytes memory constructorArgsCode) = getDeploymentBytecode();
        uint256 preDeployNonce = ICreate3Factory(address(proxy)).userNonces(wallet.addr, keccak256(creationCode));

        // Act
        deployChild(address(proxy), wallet, creationCode, constructorArgsCode);
        uint256 postDeployNonce = ICreate3Factory(address(proxy)).userNonces(wallet.addr, keccak256(creationCode));

        // Assertions
        assertEq(postDeployNonce, preDeployNonce + 1, "Equivalence violation: postDeployNonce != preDeployNonce + 1");
    }

    function testFuzz_DeployHistoryUpdate(uint256 pkNum) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));
        (bytes memory creationCode, bytes memory constructorArgsCode) = getDeploymentBytecode();
        address[] memory deploymentHistory = ICreate3Factory(address(proxy)).getDeploymentHistory(wallet.addr);

        // Pre-act assertions
        assertEq(deploymentHistory.length, 0);

        // Expectation 1
        address child1 = ICreate3Factory(address(proxy)).getAddress(wallet.addr, creationCode);

        // Act 1
        deployChild(address(proxy), wallet, creationCode, constructorArgsCode);
        deploymentHistory = ICreate3Factory(address(proxy)).getDeploymentHistory(wallet.addr);

        // Assertions 1
        assertEq(deploymentHistory.length, 1, "Equivalence violation: deploymentHistory.length != 1");
        assertTrue(deploymentHistory.includes(child1), "Truth Violation: deploymentHistory.includes(child1)");

        // Expectation 2
        address child2 = ICreate3Factory(address(proxy)).getAddress(wallet.addr, creationCode);

        // Act 2
        deployChild(address(proxy), wallet, creationCode, constructorArgsCode);
        deploymentHistory = ICreate3Factory(address(proxy)).getDeploymentHistory(wallet.addr);

        // Assertions 2
        assertEq(deploymentHistory.length, 2, "Equivalence violation: deploymentHistory.length != 2");
        assertTrue(deploymentHistory.includes(child2), "Truth Violation: deploymentHistory.includes(child2)");
    }

    function testFuzz_CannotDeployReplay(uint256 pkNum) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));

        (bytes memory creationCode, bytes memory constructorArgsCode) = getDeploymentBytecode();

        bytes memory signature = getSignature(address(proxy), wallet, creationCode);

        // Deploy once
        ICreate3Factory(address(proxy)).deploy(wallet.addr, signature, creationCode, constructorArgsCode);

        // Act: attempt replay
        vm.expectRevert(Create3Factory.Unauthorized.selector);
        ICreate3Factory(address(proxy)).deploy(wallet.addr, signature, creationCode, constructorArgsCode);
    }

    function testFuzz_CannotDeployWithoutApproval(uint256 pkNum, address invalidPrincipal) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pkNum)))));

        // Failing condition: principal is not the signer
        vm.assume(invalidPrincipal != wallet.addr);

        (bytes memory creationCode, bytes memory constructorArgsCode) = getDeploymentBytecode();

        bytes memory signature = getSignature(address(proxy), wallet, creationCode);

        // Act: attempt with invalid principal
        vm.expectRevert(Create3Factory.Unauthorized.selector);
        ICreate3Factory(address(proxy)).deploy(invalidPrincipal, signature, creationCode, constructorArgsCode);
    }

    function testFuzz_GetBytecodeHash(bytes memory _childCreationCode) public {
        vm.assume(_childCreationCode.length > 0 && _childCreationCode.length <= 24576); // max contract size

        // Act
        bytes32 actualHash = ICreate3Factory(address(proxy)).getBytecodeHash(_childCreationCode);

        // Expected
        bytes32 expectedHash = keccak256(_childCreationCode);

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
