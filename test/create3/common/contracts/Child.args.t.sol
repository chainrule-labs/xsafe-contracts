// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { IChild } from "../interfaces/IChild.t.sol";

// Value types
contract AddressChild is IChild {
    address public arg;

    constructor(address _arg) {
        arg = _arg;
    }
}

contract UintChild is IChild {
    uint256 public arg;

    constructor(uint256 _arg) {
        arg = _arg;
    }
}

contract IntChild is IChild {
    int256 public arg;

    constructor(int256 _arg) {
        arg = _arg;
    }
}

contract StringChild is IChild {
    string public arg;

    constructor(string memory _arg) {
        arg = _arg;
    }
}

contract BytesChild is IChild {
    bytes public arg;

    constructor(bytes memory _arg) {
        arg = _arg;
    }
}

contract Bytes32Child is IChild {
    bytes32 public arg;

    constructor(bytes32 _arg) {
        arg = _arg;
    }
}

contract BoolChild is IChild {
    bool public arg;

    constructor(bool _arg) {
        arg = _arg;
    }
}

// Referrence types
contract AddressArrayChild is IChild {
    address[] public arg;

    constructor(address[] memory _arg) {
        arg = _arg;
    }
}

contract UintArrayChild is IChild {
    uint256[] public arg;

    constructor(uint256[] memory _arg) {
        arg = _arg;
    }
}

contract IntArrayChild is IChild {
    int256[] public arg;

    constructor(int256[] memory _arg) {
        arg = _arg;
    }
}

contract StringArrayChild is IChild {
    string[] public arg;

    constructor(string[] memory _arg) {
        arg = _arg;
    }
}

contract BytesArrayChild is IChild {
    bytes[] public arg;

    constructor(bytes[] memory _arg) {
        arg = _arg;
    }
}

contract Bytes32ArrayChild is IChild {
    bytes32[] public arg;

    constructor(bytes32[] memory _arg) {
        arg = _arg;
    }
}

contract BoolArrayChild is IChild {
    bool[] public arg;

    constructor(bool[] memory _arg) {
        arg = _arg;
    }
}
