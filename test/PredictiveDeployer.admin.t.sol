// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { PredictiveDeployer } from "../src/PredictiveDeployer.sol";
import { Child } from "./Child.t.sol";
import { VmSafe } from "forge-std/Vm.sol";

// TODO: test extract funds
contract PredictiveDeployerTest is Test {
    /* solhint-disable func-name-mixedcase */

    PredictiveDeployer public predictiveDeployer;

    function setUp() public {
        predictiveDeployer = new PredictiveDeployer();
    }
}
