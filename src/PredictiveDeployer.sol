// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ECDSA} from "./dependencies/cryptography/ECDSA.sol";
import {Initializable} from "./dependencies/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "./dependencies/proxy/utils/UUPSUpgradeable.sol";
import {Ownable} from "./dependencies/access/Ownable.sol";

contract PredictiveDeployer is Initializable, UUPSUpgradeable, Ownable {
    // Private Constants: no SLOAD to save users gas
    address private constant CONTRACT_DEPLOYER = 0x76bd253e7a0FB5896b4ACA4b9ef06E9ee2b74e8E;

    // Storage Variables
    bytes32 internal DOMAIN_SEPARATOR;
    address public trustedDeployer;
    mapping(address => uint256) public userNonces;

    // Events
    event Deploy(address indexed signer, address indexed child, bytes32 hashedBytecode, uint256 nonce);

    /// @dev No constructor, so initialize Ownable explicitly.
    function initialize() public initializer {
        require(msg.sender == CONTRACT_DEPLOYER, "Invalid caller.");
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

    /**
     * @dev This function returns the unique deployment transaction hash to be signed.
     * @param _signer The signer address for whom this factory contract will deploy a child contract for.
     * @param _nonce The signer account's current nonce.
     * @return txHash The unique deployment transaction hash to be signed.
     */
    function getTransactionHash(address _signer, uint256 _nonce) public view returns (bytes32) {
        return keccak256(abi.encodePacked(DOMAIN_SEPARATOR, _signer, _nonce));
    }

    /**
     * @dev This function computes the expected message hash, verified on child contract deployment.
     * @param _signer The signer address, for whom this factory contract will deploy a child contract for.
     * @param _nonce The signer account's current nonce.
     * @return messageHash The address of the deployed contract.
     */
    function _computeMessageHash(address _signer, uint256 _nonce) internal view returns (bytes32) {
        bytes32 txHash = getTransactionHash(_signer, _nonce);
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));
    }

    /**
     * @dev This function returns the predicted address of a contract to be deployed before it's deployed.
     * @param _signer The account that signed the message.
     * @param _bytecode The bytecode of the contract to deploy.
     * @return child The predicted address of the contract to be deployed.
     */
    function getAddress(address _signer, bytes memory _bytecode) public view returns (address) {
        uint256 salt = uint256(uint160(_signer)) + userNonces[_signer];
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(_bytecode)));
        return address(uint160(uint256(hash)));
    }

    /**
     * @dev This function deploys arbitrary child contracts at predictable addresses, derived from account signatures.
     * @param _signer The account that signed the message.
     * @param _signature The signer's signature.
     * @param _bytecode The bytecode of the contract to deploy.
     * @return child The address of the deployed contract.
     */
    function deploy(address _signer, bytes memory _signature, bytes memory _bytecode) public returns (address) {
        uint256 currectNonce = userNonces[_signer];
        bytes32 expectedMessageHash = _computeMessageHash(_signer, currectNonce);

        // Recover signer
        address recoveredSigner = ECDSA.recover(expectedMessageHash, _signature);

        // Ensure the provided signer signed the _expected_ message
        require(recoveredSigner == _signer);

        // Ensure that the sender is the rocovered signer or the trusted deployer
        require(msg.sender == recoveredSigner || msg.sender == trustedDeployer);

        // Calculate salt
        uint256 salt = uint256(uint160(_signer)) + currectNonce;

        userNonces[_signer]++;

        // Deploy contract
        address child;
        assembly {
            child := create2(callvalue(), add(_bytecode, 0x20), mload(_bytecode), salt)
            if iszero(extcodesize(child)) { revert(0, 0) }
        }

        emit Deploy(_signer, child, keccak256(_bytecode), currectNonce);
        return child;
    }

    /* ****************************************************************************
    **
    **  Admin Functions
    **
    ******************************************************************************/

    /**
     * @dev This function allows contract admins to set the address of the feeSetter account.
     * @param _deployer The address of the account that's allowed to deploy on behalf of other accounts.
     */
    function setTrustedDeployer(address _deployer) public onlyOwner {
        trustedDeployer = _deployer;
    }
}
