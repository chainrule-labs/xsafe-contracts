// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ECDSA} from "./dependencies/cryptography/ECDSA.sol";
import {Initializable} from "./dependencies/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "./dependencies/proxy/utils/UUPSUpgradeable.sol";
import {Ownable} from "./dependencies/access/Ownable.sol";

import "forge-std/console.sol";

contract PredictiveDeployer is Initializable, UUPSUpgradeable, Ownable {
    // Private Constants: no SLOAD to save users gas
    address private constant DEPLOYER = 0x76bd253e7a0FB5896b4ACA4b9ef06E9ee2b74e8E;

    // Storage Variables
    bytes32 internal DOMAIN_SEPARATOR;
    mapping(address => uint256) public userNonces;

    // Events
    event Deploy(address indexed sender, address indexed child, bytes32 hashedBytecode, uint256 nonce);

    /// @dev No constructor, so initialize Ownable explicitly.
    function initialize() public initializer {
        require(msg.sender == DEPLOYER, "Invalid caller.");
        DOMAIN_SEPARATOR = _computeDomainSeparator();
        __Ownable_init();
    }

    /// @dev Required by the UUPS module.
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function _computeDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("PredictiveDeployer"),
                keccak256("1"), // Tracks upgrades
                block.chainid,
                address(this)
            )
        );
    }

    // Computes the hash to be signed off-chain
    function getTransactionHash(uint256 _nonce) public view returns (bytes32) {
        return keccak256(abi.encodePacked(DOMAIN_SEPARATOR, _nonce));
    }

    // Returns address to be created before actual deployment
    function getAddress(bytes32 _messageHash, bytes memory _signature, bytes memory _bytecode)
        public
        view
        returns (address)
    {
        address signer = ECDSA.recover(_messageHash, _signature);
        uint256 salt = uint256(uint160(signer)) + userNonces[signer];
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(_bytecode)));
        return address(uint160(uint256(hash)));
    }

    // Deploys a new contract
    function deploy(bytes32 _messageHash, bytes memory _signature, bytes memory _bytecode) public returns (address) {
        // recompute the hash
        // What is being hashed?

        // address signer = ECDSA.recover(_messageHash, _signature);
        // require(signer == msg.sender);

        // uint256 currectNonce = userNonces[signer];

        // bytes32 txHash = keccak256(abi.encodePacked(DOMAIN_SEPARATOR, currectNonce));
        // bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));

        address signer = ECDSA.recover(_messageHash, _signature);
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
