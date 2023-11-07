// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {
    AddressChild,
    UintChild,
    IntChild,
    StringChild,
    BytesChild,
    Bytes32Child,
    BoolChild,
    AddressArrayChild,
    UintArrayChild,
    IntArrayChild,
    StringArrayChild,
    BytesArrayChild,
    Bytes32ArrayChild,
    BoolArrayChild
} from "./Child.args.t.sol";
import { IChild } from "../interfaces/IChild.t.sol";
import { CONTRACT_DEPLOYER } from "../Constants.t.sol";

/**
 * @title ChildrenWithConstructorArgs
 * @dev Constructs arrays of children with different types and different construct args for each type.
 */
contract ChildrenWithConstructorArgs {
    struct ChildContractData {
        bytes creationCode;
        bytes constructorArgsCode1;
        bytes constructorArgsCode2;
    }

    ChildContractData[] public childrenData;

    constructor() {
        __constructChildren();
    }

    /// @dev Constructs children with different constructor arguments for testing.
    function __constructChildren() private {
        address defaultAddress = address(this);
        address variantAddress = address(uint160(uint256(keccak256(abi.encodePacked("variant")))));

        // value types
        __addChildData(type(AddressChild).creationCode, abi.encode(defaultAddress), abi.encode(variantAddress));
        __addChildData(type(UintChild).creationCode, abi.encode(uint256(1)), abi.encode(uint256(2)));
        __addChildData(type(IntChild).creationCode, abi.encode(int256(-1)), abi.encode(int256(-2)));
        __addChildData(type(StringChild).creationCode, abi.encode("hello world"), abi.encode("variant"));
        __addChildData(type(BytesChild).creationCode, abi.encode(hex"01"), abi.encode(hex"02"));
        __addChildData(
            type(Bytes32Child).creationCode, abi.encode(bytes32(uint256(1))), abi.encode(bytes32(uint256(2)))
        );
        __addChildData(type(BoolChild).creationCode, abi.encode(true), abi.encode(false));

        // reference types
        // Address Arrays
        address[] memory defaultAddresses = new address[](1);
        defaultAddresses[0] = defaultAddress;
        address[] memory variantAddresses = new address[](1);
        variantAddresses[0] = variantAddress;
        __addChildData(type(AddressArrayChild).creationCode, abi.encode(defaultAddresses), abi.encode(variantAddresses));

        // Uints Arrays
        uint256[] memory defaultUints = new uint256[](1);
        defaultUints[0] = 1;
        uint256[] memory variantUints = new uint256[](1);
        variantUints[0] = 2;
        __addChildData(type(UintArrayChild).creationCode, abi.encode(defaultUints), abi.encode(variantUints));

        // Ints Arrays
        int256[] memory defaultInts = new int256[](1);
        defaultInts[0] = -1;
        int256[] memory variantInts = new int256[](1);
        variantInts[0] = -2;
        __addChildData(type(IntArrayChild).creationCode, abi.encode(defaultInts), abi.encode(variantInts));

        // Strings Arrays
        string[] memory defaultStrings = new string[](1);
        defaultStrings[0] = "hello world";
        string[] memory variantStrings = new string[](1);
        variantStrings[0] = "variant";
        __addChildData(type(StringArrayChild).creationCode, abi.encode(defaultStrings), abi.encode(variantStrings));

        // Bytes Arrays
        bytes[] memory defaultBytes = new bytes[](1);
        defaultBytes[0] = hex"01";
        bytes[] memory variantBytes = new bytes[](1);
        variantBytes[0] = hex"02";
        __addChildData(type(BytesArrayChild).creationCode, abi.encode(defaultBytes), abi.encode(variantBytes));

        // Bytes32 Arrays
        bytes32[] memory defaultBytes32 = new bytes32[](1);
        defaultBytes32[0] = bytes32(uint256(1));
        bytes32[] memory variantBytes32 = new bytes32[](1);
        variantBytes32[0] = bytes32(uint256(2));
        __addChildData(type(Bytes32ArrayChild).creationCode, abi.encode(defaultBytes32), abi.encode(variantBytes32));

        // Bools Arrays
        bool[] memory defaultBools = new bool[](1);
        defaultBools[0] = true;
        bool[] memory variantBools = new bool[](1);
        variantBools[0] = false;
        __addChildData(type(BoolArrayChild).creationCode, abi.encode(defaultBools), abi.encode(variantBools));
    }

    /// @dev Helper function to add child data to the array.
    function __addChildData(
        bytes memory creationCode,
        bytes memory constructorArgsCode1,
        bytes memory constructorArgsCode2
    ) private {
        childrenData.push(
            ChildContractData({
                creationCode: creationCode,
                constructorArgsCode1: constructorArgsCode1,
                constructorArgsCode2: constructorArgsCode2
            })
        );
    }

    function getChildrenData() public view returns (ChildContractData[] memory) {
        return childrenData;
    }
}
