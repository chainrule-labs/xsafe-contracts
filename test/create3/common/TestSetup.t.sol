// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

// TODO: Address this
import { Test } from "forge-std/Test.sol";
import { ICreate2Factory } from "../../../src/create2/interfaces/ICreate2Factory.sol";
import { Create2Factory } from "../../../src/create2/Create2Factory.sol";
import { ERC1967Proxy } from "../../../src/dependencies/proxy/ERC1967Proxy.sol";
import { ChildA, ChildB } from "../../common/Child.t.sol";
import { CONTRACT_DEPLOYER } from "../../common/Constants.t.sol";

abstract contract TestSetup is Test {
    Create2Factory public implementation;
    ERC1967Proxy public proxy;
    ChildA public childA;
    ChildB public childB;
    bytes public bytecodeChildA;
    bytes public bytecodeChildB;
    bytes32 public hashedBytecodeChildA;
    bytes32 public hashedBytecodeChildB;

    // Events
    event Deploy(address indexed sender, address indexed childA, bytes32 hashedBytecode, uint256 nonce);

    function setUp() public {
        implementation = new Create2Factory();
        vm.prank(CONTRACT_DEPLOYER);
        proxy = new ERC1967Proxy(address(implementation), abi.encodeWithSignature("initialize()"));
        childA = new ChildA(address(this));
        childB = new ChildB();

        // Get Bytecode
        bytecodeChildA = abi.encodePacked(type(ChildA).creationCode, abi.encode(address(this)));
        hashedBytecodeChildA = keccak256(bytecodeChildA);
        bytecodeChildB = abi.encodePacked(type(ChildB).creationCode, abi.encode(address(this)));
        hashedBytecodeChildB = keccak256(bytecodeChildB);
    }
}
