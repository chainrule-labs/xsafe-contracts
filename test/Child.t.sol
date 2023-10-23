// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

contract Child {
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
