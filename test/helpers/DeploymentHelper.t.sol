// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { IPredictiveDeployer } from "../../src/interfaces/IPredictiveDeployer.sol";

abstract contract DeploymentHelper is Test {
    /**
     * @dev Reusable function for deploying childA contracts.
     * @param _contract The address of the PredictveDeployer proxy contract.
     * @param _wallet The principal's evm account that signs off on a childA contract deployment.
     * @param _bytecode The to-be-deployed contract bytecode.
     */
    function deployChild(address _contract, VmSafe.Wallet memory _wallet, bytes memory _bytecode)
        internal
        returns (address)
    {
        uint256 currentNonce = IPredictiveDeployer(_contract).userNonces(_wallet.addr, keccak256(_bytecode));
        bytes32 txHash = IPredictiveDeployer(_contract).getTransactionHash(_wallet.addr, _bytecode, currentNonce);
        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_wallet.privateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        return IPredictiveDeployer(_contract).deploy(_wallet.addr, signature, _bytecode);
    }
}
