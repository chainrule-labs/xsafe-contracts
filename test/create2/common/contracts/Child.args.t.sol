// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { IChild } from "../interfaces/IChild.t.sol";

// Value types
contract ChildArgs is IChild {
    address public arg;

    constructor(address _arg) {
        arg = _arg;
    }
}
