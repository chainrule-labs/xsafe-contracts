// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { IPredictiveDeployer } from "./IPredictiveDeployer.sol";

interface IPredictiveDeployerAdmin is IPredictiveDeployer {
    error UUPSUnauthorizedCallContext();

    function upgradeToAndCall(address newImplementation, bytes memory data) external;
    function extractNative() external;
    function extractERC20(address _token) external;
}
