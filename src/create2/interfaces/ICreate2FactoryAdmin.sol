// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { ICreate2Factory } from "./ICreate2Factory.sol";

interface ICreate2FactoryAdmin is ICreate2Factory {
    error UUPSUnauthorizedCallContext();

    function upgradeToAndCall(address newImplementation, bytes memory data) external;
    function extractNative() external;
    function extractERC20(address _token) external;
}
