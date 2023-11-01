// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

interface ICreate3Factory {
    function userNonces(address _principal, bytes32 hashedStrippedBytecode) external returns (uint256);
    function getTransactionHash(address _principal, bytes memory _strippedBytecode) external returns (bytes32);
    function getAddress(address _principal, bytes memory _strippedBytecode) external returns (address);
    function getBytecodeHash(bytes memory _strippedBytecode) external pure returns (bytes32);
    function getDeploymentHistory(address _principal) external returns (address[] memory);
    function deploy(
        address _principal,
        bytes memory _signature,
        bytes memory _strippedBytecode,
        bytes memory _constructorArgsBytecode
    ) external payable;
}
