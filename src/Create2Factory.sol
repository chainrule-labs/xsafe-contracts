// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ECDSA} from "./utils/ECDSA.sol";

contract Create2Factory {
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 constant DOMAIN_SEPARATOR_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    bytes32 internal DOMAIN_SEPARATOR;

    // Mapping to keep track of user nonces
    mapping(address => uint256) public userNonces;

    // Events
    event Deploy(address indexed sender, address indexed child, bytes32 hashedBytecode, uint256 nonce);

    constructor() {
        DOMAIN_SEPARATOR = _computeDomainSeparator();
    }

    // Computes and returns domain separator hash
    function domain_separator() public view returns (bytes32) {
        if (DOMAIN_SEPARATOR != 0) {
            return DOMAIN_SEPARATOR;
        } else {
            return _computeDomainSeparator();
        }
    }

    function _computeDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                DOMAIN_SEPARATOR_TYPEHASH, keccak256("Create2Factory"), keccak256("1"), block.chainid, address(this)
            )
        );
    }

    // Computes the hash to be signed off-chain
    function getTransactionHash(uint256 _nonce) public view returns (bytes32) {
        return keccak256(abi.encodePacked(DOMAIN_SEPARATOR, _nonce));
    }

    // Returns address to be created before actual deployment
    function getAddress(bytes32 _hashedMessage, bytes memory _signature, bytes memory _bytecode)
        public
        view
        returns (address)
    {
        address signer = ECDSA.recover(_hashedMessage, _signature);
        uint256 salt = uint256(uint160(signer)) + userNonces[signer];
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(_bytecode)));
        return address(uint160(uint256(hash)));
    }

    // Deploys a new contract
    function deploy(bytes32 _hashedMessage, bytes memory _signature, bytes memory _bytecode) public returns (address) {
        address signer = ECDSA.recover(_hashedMessage, _signature);
        uint256 currectNonce = userNonces[signer];

        uint256 salt = uint256(uint160(signer)) + currectNonce;

        userNonces[signer]++;

        address child;

        assembly {
            child := create2(callvalue(), add(_bytecode, 0x20), mload(_bytecode), salt)
            if iszero(extcodesize(child)) { revert(0, 0) }
        }

        emit Deploy(msg.sender, child, keccak256(_bytecode), currectNonce);
        return child;
    }
}
