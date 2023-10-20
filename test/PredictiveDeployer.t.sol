// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { ECDSA } from "../src/dependencies/cryptography/ECDSA.sol";
import { PredictiveDeployer } from "../src/PredictiveDeployer.sol";

import { Test } from "forge-std/Test.sol";
import { PredictiveDeployer } from "../src/PredictiveDeployer.sol";
import { Child } from "./Child.t.sol";
import { VmSafe } from "forge-std/Vm.sol";

contract PredictiveDeployerTest is Test {
    PredictiveDeployer public predictive_deployer;
    Child public child;
    bytes public childBytecode;

    // Events
    event Deploy(address indexed sender, address indexed child, bytes32 hashedBytecode, uint256 nonce);

    function setUp() public {
        predictive_deployer = new PredictiveDeployer();
        child = new Child(address(this));

        // Get Bytecode
        bytes memory bytecode = type(Child).creationCode;
        childBytecode = abi.encodePacked(bytecode, abi.encode(address(this)));
    }

    function test_getAddress_fuzz(uint256 pk_num, address sender) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pk_num)))));

        uint256 currentNonce = predictive_deployer.userNonces(wallet.addr);

        // Get signature information
        bytes32 txHash = predictive_deployer.getTransactionHash(wallet.addr, currentNonce);

        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wallet.privateKey, messageHash);

        bytes memory signature = abi.encodePacked(r, s, v);

        // Expectation
        vm.startPrank(sender);
        uint256 snapShot = vm.snapshot();
        address expectedChild = predictive_deployer.deploy(wallet.addr, signature, childBytecode);

        // Set chain state to what it was before the deployment
        vm.revertTo(snapShot);

        // Act
        address actualChild = predictive_deployer.getAddress(wallet.addr, childBytecode);
        vm.stopPrank();

        // Assertions
        assertEq(actualChild, expectedChild);
    }

    function test_deploy_fuzz(uint256 pk_num, address sender) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pk_num)))));

        uint256 currentNonce = predictive_deployer.userNonces(wallet.addr);

        // Get signature information
        bytes32 txHash = predictive_deployer.getTransactionHash(wallet.addr, currentNonce);

        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wallet.privateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Expectations
        vm.startPrank(sender);
        address expectedChild = predictive_deployer.getAddress(wallet.addr, childBytecode);
        vm.expectEmit(true, true, true, true, address(predictive_deployer));
        emit Deploy(wallet.addr, expectedChild, keccak256(childBytecode), currentNonce);

        // Act
        address actualChild = predictive_deployer.deploy(wallet.addr, signature, childBytecode);
        vm.stopPrank();

        // Assertions
        assertEq(actualChild, expectedChild);
    }
}
