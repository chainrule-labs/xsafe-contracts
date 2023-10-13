// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {Create2Factory} from "../src/Create2Factory.sol";
import {Child} from "./Child.t.sol";
import {VmSafe} from "forge-std/Vm.sol";

import "forge-std/console.sol";


contract Create2FactoryTest is Test {
    Create2Factory public create2_factory;
    Child public child;
    bytes public childBytecode;

    address public signerAddress = 0xf1Ec10A28725244E592d2907dEaAcA08d1a72be0;

    // Events
    event Deploy(address indexed sender, address indexed child, bytes32 hashedBytecode, uint256 nonce);

    function setUp() public {
        create2_factory = new Create2Factory();
        child = new Child(address(this));

        // Get Bytecode
        bytes memory bytecode = type(Child).creationCode;

        childBytecode = abi.encodePacked(bytecode, abi.encode(address(this)));
    }

    function test_getAddress() public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(1)))));

        uint256 currentNonce = create2_factory.userNonces(wallet.addr);

        // Get signature information
        bytes32 txHash = create2_factory.getTransactionHash(currentNonce);

        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 messageHash = keccak256(abi.encodePacked(prefix, txHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wallet.privateKey, messageHash);

        bytes memory signature = abi.encodePacked(r, s, v);

        // Expectation
        uint256 snapShot = vm.snapshot();
        address expectedChild = create2_factory.deploy(messageHash, signature, childBytecode);

        // Set chain state to what it was before the deployment
        vm.revertTo(snapShot);

        // Act
        address actualChild = create2_factory.getAddress(messageHash, signature, childBytecode);

        // Assertions
        assertEq(actualChild, expectedChild);
    }

    function test_deploy() public {
        // Create wallet        
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(1)))));

        uint256 currentNonce = create2_factory.userNonces(wallet.addr);

        // Get signature information
        bytes32 txHash = create2_factory.getTransactionHash(currentNonce);

        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 messageHash = keccak256(abi.encodePacked(prefix, txHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wallet.privateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Expectations
        address expectedChild = create2_factory.getAddress(messageHash, signature, childBytecode);
        vm.expectEmit(true, true, true, true, address(create2_factory));
        emit Deploy(address(this), expectedChild, keccak256(childBytecode), currentNonce);

        // Act
        address actualChild = create2_factory.deploy(messageHash, signature, childBytecode);

        // Assertions
        assertEq(actualChild, expectedChild);
    }

    function test_deploy_fuzz(uint256 pk_num, address sender) public {
        // Setup
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(pk_num)))));

        uint256 currentNonce = create2_factory.userNonces(wallet.addr);

        // Get signature information
        bytes32 txHash = create2_factory.getTransactionHash(currentNonce);

        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 messageHash = keccak256(abi.encodePacked(prefix, txHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wallet.privateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Expectations
        vm.startPrank(sender);
        address expectedChild = create2_factory.getAddress(messageHash, signature, childBytecode);
        vm.expectEmit(true, true, true, true, address(create2_factory));
        emit Deploy(sender, expectedChild, keccak256(childBytecode), currentNonce);

        // Act
        address actualChild = create2_factory.deploy(messageHash, signature, childBytecode);
        vm.stopPrank();

        // Assertions
        assertEq(actualChild, expectedChild);
    }
}
