// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { ICreate3Factory } from "../../../src/create3/interfaces/ICreate3Factory.sol";
import { Create3Factory } from "../../../src/create3/Create3Factory.sol";
import { ERC1967Proxy } from "../../../src/dependencies/proxy/ERC1967Proxy.sol";
import { ChildA, ChildB } from "../../common/Child.t.sol";
import { CONTRACT_DEPLOYER } from "../../common/Constants.t.sol";

abstract contract TestSetup is Test {
    Create3Factory public implementation;
    ERC1967Proxy public proxy;
    ChildA public childA;
    ChildA public childAVariant;
    ChildB public childB;
    bytes public strippedBytecodeChildA;
    bytes public strippedBytecodeChildB;
    bytes32 public hashedStrippedBytecodeChildA;
    bytes32 public hashedStrippedBytecodeChildB;

    // Events
    event Deploy(
        address indexed principal,
        address indexed child,
        bytes32 indexed hashedStrippedBytecode,
        bytes constructorArgsBytecode,
        uint256 nonce
    );

    function setUp() public {
        implementation = new Create3Factory();
        vm.prank(CONTRACT_DEPLOYER);
        proxy = new ERC1967Proxy(address(implementation), abi.encodeWithSignature("initialize()"));
        childA = new ChildA(address(this));
        childAVariant = new ChildA(CONTRACT_DEPLOYER); // different constructor args
        childB = new ChildB();

        strippedBytecodeChildA = type(ChildA).creationCode;
        hashedStrippedBytecodeChildA = keccak256(strippedBytecodeChildA);
        strippedBytecodeChildB = type(ChildB).creationCode;
        hashedStrippedBytecodeChildB = keccak256(strippedBytecodeChildB);
    }
}
