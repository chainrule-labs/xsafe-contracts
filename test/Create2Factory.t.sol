// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {Create2Factory} from "../src/Create2Factory.sol";
import {Child} from "./Child.t.sol";
import {VmSafe} from "forge-std/Vm.sol";

import "forge-std/console.sol";

// create2 inputs: 0xff, bytecode, deployer_address, salt

// Right now, we are only testing with a single:
// - private key
// - salt
// - contract's "userNonce"

// It would be nice to generate a bunch of random things and have it still work

contract Create2FactoryTest is Test {
    Create2Factory public create2_factory;
    Child public child;
    bytes public childBytecode;

    uint256 public constant dummyPrivateKey = 0x5f7bc1ba5fa3f035a5e34bfc399d1db5bd85b39ffac033c9c8929d2b6e7ff335;
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
        uint256 currentNonce = create2_factory.userNonces(signerAddress);

        // Get signature information
        bytes32 txHash = create2_factory.getTransactionHash(currentNonce);

        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 messageHash = keccak256(abi.encodePacked(prefix, txHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(dummyPrivateKey, messageHash);
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
        // Setup
        uint256 currentNonce = create2_factory.userNonces(signerAddress);

        // Get signature information
        bytes32 txHash = create2_factory.getTransactionHash(currentNonce);

        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 messageHash = keccak256(abi.encodePacked(prefix, txHash));

        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(abi.encodePacked(uint256(1)))));

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
}
