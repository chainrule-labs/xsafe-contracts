// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { ChildrenWithConstructorArgs } from "../common/contracts/Children.args.t.sol";
import { TestSetup } from "../common/contracts/TestSetup.t.sol";
import { ICreate3Factory } from "../../../src/create3/interfaces/ICreate3Factory.sol";

abstract contract DeploymentHelper is Test, TestSetup {
    /**
     * @dev Reusable function for deploying childA contracts.
     * @param _contract The address of the PredictveDeployer proxy contract.
     * @param _wallet The principal's evm account that signs off on a childA contract deployment.
     * @param _creationCode The to-be-deployed contract bytecode.
     */
    function deployChild(
        address _contract,
        VmSafe.Wallet memory _wallet,
        bytes memory _creationCode,
        bytes memory _constructorArgsBytecode
    ) internal {
        bytes memory signature = getSignature(_contract, _wallet, _creationCode);
        ICreate3Factory(_contract).deploy(_wallet.addr, signature, _creationCode, _constructorArgsBytecode);
    }

    /**
     * @dev Reusable function for returning generic bytcode contract creation code and constructor args code.
     */
    function getDeploymentBytecode() internal view returns (bytes memory, bytes memory) {
        ChildrenWithConstructorArgs.ChildContractData[] memory childrenData =
            childrenWithConstructorArgs.getChildrenData();
        ChildrenWithConstructorArgs.ChildContractData memory child = childrenData[0];
        return (child.creationCode, child.constructorArgsCode1);
    }

    /**
     * @dev Reusable function for returning a signature to be used for deployment.
     * @param _contract The address of the PredictveDeployer proxy contract.
     * @param _wallet The principal's evm account that signs off on a childA contract deployment.
     * @param _creationCode The to-be-deployed contract bytecode.
     * @return signature The signature to be used for deployment.
     */
    function getSignature(address _contract, VmSafe.Wallet memory _wallet, bytes memory _creationCode)
        internal
        returns (bytes memory)
    {
        bytes32 txHash = ICreate3Factory(_contract).getTransactionHash(_wallet.addr, _creationCode);

        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_wallet.privateKey, messageHash);

        return abi.encodePacked(r, s, v);
    }
}
