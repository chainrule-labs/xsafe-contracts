// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { ICreate3Factory } from "../../../src/create3/interfaces/ICreate3Factory.sol";

abstract contract DeploymentHelper is Test {
    /**
     * @dev Reusable function for deploying childA contracts.
     * @param _contract The address of the PredictveDeployer proxy contract.
     * @param _wallet The principal's evm account that signs off on a childA contract deployment.
     * @param _strippedBytecode The to-be-deployed contract bytecode.
     */
    function deployChild(address _contract, VmSafe.Wallet memory _wallet, bytes memory _strippedBytecode) internal {
        bytes32 txHash = ICreate3Factory(_contract).getTransactionHash(_wallet.addr, _strippedBytecode);
        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_wallet.privateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory constructorArgsBytecode = abi.encode(_wallet.addr);
        ICreate3Factory(_contract).deploy(_wallet.addr, signature, _strippedBytecode, constructorArgsBytecode);
    }
}
