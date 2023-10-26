// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { IPredictiveDeployer } from "../../src/interfaces/IPredictiveDeployer.sol";
import { PredictiveDeployer } from "../../src/PredictiveDeployer.sol";
import { ERC1967Proxy } from "../../src/dependencies/proxy/ERC1967Proxy.sol";
import { ChildA, ChildB } from "./Child.t.sol";
import { CONTRACT_DEPLOYER } from "./../common/Constants.t.sol";

abstract contract TestSetup is Test {
    PredictiveDeployer public implementation;
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
        implementation = new PredictiveDeployer();
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
