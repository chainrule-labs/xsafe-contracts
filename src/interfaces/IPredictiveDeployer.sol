// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

interface IPredictiveDeployer {
    function userNonces(address _principal) external returns (uint256);
    function getTransactionHash(address _principal, uint256 _nonce) external returns (bytes32);
    function getAddress(address _principal, bytes memory _bytecode) external returns (address);
    function deploy(address _principal, bytes memory _signature, bytes memory _bytecode) external returns (address);
}
