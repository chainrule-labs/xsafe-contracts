// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

contract ChildA {
    uint256 public number;
    address public admin;

    constructor(address _admin) {
        admin = _admin;
    }

    function increment() public {
        require(msg.sender == admin, "Unauthorized.");
        number++;
    }
}

contract ChildB {
    uint256 public number;

    function increment() public {
        number++;
    }
}
