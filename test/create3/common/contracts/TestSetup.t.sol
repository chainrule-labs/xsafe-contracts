// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { ICreate3Factory } from "../../../../src/create3/interfaces/ICreate3Factory.sol";
import { Create3Factory } from "../../../../src/create3/Create3Factory.sol";
import { ERC1967Proxy } from "../../../../src/dependencies/proxy/ERC1967Proxy.sol";
import { ChildNoArgs } from "./Child.noargs.t.sol";
import { ChildrenWithConstructorArgs } from "./Children.args.t.sol";

import { CONTRACT_DEPLOYER } from "../Constants.t.sol";

abstract contract TestSetup is Test {
    Create3Factory public implementation;
    ERC1967Proxy public proxy;

    ChildrenWithConstructorArgs public childrenWithConstructorArgs;
    bytes public noArgsChildCreationCode;

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

        noArgsChildCreationCode = type(ChildNoArgs).creationCode;
        childrenWithConstructorArgs = new ChildrenWithConstructorArgs();
    }
}
