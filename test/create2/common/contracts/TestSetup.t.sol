// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { ICreate2Factory } from "../../../../src/create2/interfaces/ICreate2Factory.sol";
import { Create2Factory } from "../../../../src/create2/Create2Factory.sol";
import { ERC1967Proxy } from "../../../../src/dependencies/proxy/ERC1967Proxy.sol";
import { ChildArgs } from "./Child.args.t.sol";
import { ChildNoArgs } from "./Child.noargs.t.sol";
import { CONTRACT_DEPLOYER } from "../../common/Constants.t.sol";

abstract contract TestSetup is Test {
    Create2Factory public implementation;
    ERC1967Proxy public proxy;
    ChildArgs public childWithArgs;
    ChildNoArgs public childNoArgs;
    bytes public bytecodeChildWithArgs;
    bytes public bytecodeChildNoArgs;
    bytes32 public hashedBytecodeChildWithArgs;
    bytes32 public hashedBytecodeChildNoArgs;

    // Events
    event Deploy(address indexed sender, address indexed childA, bytes32 hashedBytecode, uint256 nonce);

    function setUp() public {
        implementation = new Create2Factory();
        vm.prank(CONTRACT_DEPLOYER);
        proxy = new ERC1967Proxy(address(implementation), abi.encodeWithSignature("initialize()"));

        // Get Bytecode
        bytecodeChildWithArgs = abi.encodePacked(type(ChildArgs).creationCode, abi.encode(address(this)));
        hashedBytecodeChildWithArgs = keccak256(bytecodeChildWithArgs);
        bytecodeChildNoArgs = abi.encodePacked(type(ChildNoArgs).creationCode, "");
        hashedBytecodeChildNoArgs = keccak256(bytecodeChildNoArgs);
    }
}
