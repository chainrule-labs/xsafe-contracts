// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { ICreate3Factory } from "./ICreate3Factory.sol";

interface ICreate3FactoryAdmin is ICreate3Factory {
    error UUPSUnauthorizedCallContext();

    function upgradeToAndCall(address newImplementation, bytes memory data) external;
    function extractNative() external;
    function extractERC20(address _token) external;
}
