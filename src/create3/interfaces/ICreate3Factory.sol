// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

interface ICreate3Factory {
    function userNonces(address _principal, bytes32 hashedCreationCode) external returns (uint256);
    function getTransactionHash(address _principal, bytes memory _creationCode) external returns (bytes32);
    function getAddress(address _principal, bytes memory _creationCode) external returns (address);
    function getBytecodeHash(bytes memory _creationCode) external pure returns (bytes32);
    function getDeploymentHistory(address _principal) external returns (address[] memory);
    function deploy(
        address _principal,
        bytes memory _signature,
        bytes memory _creationCode,
        bytes memory _constructorArgsCode
    ) external payable;
}
