// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "../src/utils/ECDSA.sol";
import {Create2Factory} from "../src/Create2Factory.sol";

import "forge-std/console.sol";

contract Child {
    uint256 number;
    address public admin;

    constructor(address _admin) {
        admin = _admin;
    }

    function increment() public {
        require(msg.sender == admin, "Unauthorized.");
        number++;
    }
}

contract FactoryHelper {
    function getAddressHelper(
        bytes32 _hashedMessage,
        bytes memory _signature,
        bytes memory _bytecode,
        uint256 _nonce,
        address factoryAddress
    ) internal pure returns (address child) {
        address signer = ECDSA.recover(_hashedMessage, _signature);
        uint256 salt = uint256(uint160(signer)) + _nonce;
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), factoryAddress, salt, keccak256(_bytecode)));
        child = address(uint160(uint256(hash)));
    }
}

contract Create2FactoryTest is Test, FactoryHelper {
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
        // childBytecode = address(child).code;
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

        // Expectations
        address expectedChild =
            getAddressHelper(messageHash, signature, childBytecode, currentNonce, address(create2_factory));

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

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(dummyPrivateKey, messageHash);
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
