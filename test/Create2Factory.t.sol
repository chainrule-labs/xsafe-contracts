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
    ) internal view returns (address child) {
        address signer = ECDSA.recover(_hashedMessage, _signature);
        uint256 salt = uint256(uint160(signer)) + _nonce;
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), factoryAddress, salt, keccak256(_bytecode)));
        child = address(uint160(uint256(hash)));
    }
}

contract Create2FactoryTest is Test, FactoryHelper {
    Create2Factory public create2_factory;
    Child public child;

    uint256 public constant testPrivateKey = 0x5f7bc1ba5fa3f035a5e34bfc399d1db5bd85b39ffac033c9c8929d2b6e7ff335;
    address public signerAddress = 0xf1Ec10A28725244E592d2907dEaAcA08d1a72be0;

    function setUp() public {
        create2_factory = new Create2Factory();
        child = new Child(address(this));
    }

    function test_getAddress() public {
        // Setup
        uint256 currentNonce = create2_factory.userNonces(signerAddress);

        // Get signature information
        bytes32 txHash = create2_factory.getTransactionHash(currentNonce);

        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 messageHash = keccak256(abi.encodePacked(prefix, txHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(testPrivateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Get Bytecode
        bytes memory bytecode = address(child).code;

        // Expectations
        address expectedChild =
            getAddressHelper(messageHash, signature, bytecode, currentNonce, address(create2_factory));

        // Act
        address actualChild = create2_factory.getAddress(messageHash, signature, bytecode);

        // Assertions
        assertEq(actualChild, expectedChild);
    }

    function test_deploy() public {}
}
