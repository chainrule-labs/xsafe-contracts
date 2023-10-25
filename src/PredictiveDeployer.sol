// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { ECDSA } from "./dependencies/cryptography/ECDSA.sol";
import { SafeTransferLib, ERC20 } from "solmate/utils/SafeTransferLib.sol";
import { Initializable } from "./dependencies/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "./dependencies/proxy/utils/UUPSUpgradeable.sol";
import { Ownable } from "./dependencies/access/Ownable.sol";
import { IERC20 } from "./dependencies/token/interfaces/IERC20.sol";

contract PredictiveDeployer is Initializable, UUPSUpgradeable, Ownable {
    // Private Constants: no SLOAD to save users gas
    address private constant CONTRACT_DEPLOYER = 0x76bd253e7a0FB5896b4ACA4b9ef06E9ee2b74e8E; // TODO: Update

    // EIP-712 Storage
    bytes32 internal domainSeparator;

    // Factory Storage
    mapping(address => mapping(bytes32 => uint256)) public userNonces;
    mapping(address => address[]) public deploymentHistory;

    // Events
    event Deploy(address indexed principal, address indexed child, bytes32 hashedBytecode, uint256 nonce);

    // Errors
    error Unauthorized();

    /// @dev No constructor, so initialize Ownable explicitly.
    function initialize() public initializer {
        if (msg.sender != CONTRACT_DEPLOYER) revert Unauthorized();
        domainSeparator = _computeDomainSeparator();
        __Ownable_init();
    }

    /// @dev Required by the UUPS module.
    function _authorizeUpgrade(address) internal override onlyOwner { } // solhint-disable-line no-empty-blocks

    function _computeDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("PredictiveDeployer"),
                keccak256("1"), // Tracks contract upgrades
                block.chainid,
                address(this)
            )
        );
    }

    /**
     * @dev Computes the expected message hash.
     * @param _principal The address of the account for whom this factory contract will deploy a child contract.
     * @param _nonce The principal account's current nonce on this factory contract.
     * @return messageHash The expected signed message hash.
     */
    function _computeMessageHash(address _principal, bytes memory _bytecode, uint256 _nonce)
        internal
        view
        returns (bytes32)
    {
        bytes32 txHash = getTransactionHash(_principal, _bytecode, _nonce);
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));
    }

    /**
     * @dev Returns the unique deployment transaction hash to be signed.
     * @param _principal The address of the account for whom this factory contract will deploy a child contract.
     * @param _bytecode The bytecode of the contract to be deployed.
     * @param _nonce The principal account's current nonce on this factory contract.
     * @return txHash The unique deployment transaction hash to be signed.
     */
    function getTransactionHash(address _principal, bytes memory _bytecode, uint256 _nonce)
        public
        view
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(domainSeparator, _principal, _bytecode, _nonce));
    }

    /**
     * @dev Returns the predicted address of a contract to be deployed before it's deployed.
     * @param _principal The address of the account that signed the message hash.
     * @param _bytecode The bytecode of the contract to be deployed.
     * @return child The predicted address of the contract to be deployed.
     */
    function getAddress(address _principal, bytes memory _bytecode) public view returns (address) {
        uint256 salt = uint256(uint160(_principal)) + userNonces[_principal][keccak256(_bytecode)];
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(_bytecode)));
        return address(uint160(uint256(hash)));
    }

    /**
     * @dev Returns the keccak256 hash of the provided bytecode.
     * @param _bytecode The bytecode of the contract to be deployed.
     * @return hash The keccak256 hash of the provided bytecode.
     */
    function getBytecodeHash(bytes memory _bytecode) public pure returns (bytes32) {
        return keccak256(_bytecode);
    }

    /**
     * @dev Deploys arbitrary child contracts at predictable addresses, derived from account signatures.
     * @param _principal The address of the account that signed the message hash.
     * @param _signature The resulting signature from the principal account signing the messahge hash.
     * @param _bytecode The bytecode of the contract to be deployed.
     * @return child The address of the deployed contract.
     */
    function deploy(address _principal, bytes memory _signature, bytes memory _bytecode) public returns (address) {
        bytes32 hashedByteCode = keccak256(_bytecode);
        uint256 currentNonce = userNonces[_principal][hashedByteCode];
        bytes32 expectedMessageHash = _computeMessageHash(_principal, _bytecode, currentNonce);

        // Recover principal address
        address recoveredSigner = ECDSA.recover(expectedMessageHash, _signature);

        // Ensure the provided principal signed the expected message hash
        if (recoveredSigner != _principal) revert Unauthorized();

        // Calculate salt
        uint256 salt = uint256(uint160(_principal)) + currentNonce;

        // Update nonce state
        userNonces[_principal][hashedByteCode]++;

        // Deploy contract
        address child;
        assembly {
            child := create2(callvalue(), add(_bytecode, 0x20), mload(_bytecode), salt)
            if iszero(extcodesize(child)) { revert(0, 0) }
        }

        // Update deployment history
        deploymentHistory[_principal].push(child);

        emit Deploy(_principal, child, hashedByteCode, currentNonce);
        return child;
    }

    /* ****************************************************************************
    **
    **  Admin Functions
    **
    ******************************************************************************/

    /**
     * @dev Allow contract admin to extract native token.
     */
    function extractNative() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    /**
     * @dev Allow contract admins to extract any ERC20 token.
     * @param _token The address of token to remove.
     */
    function extractERC20(address _token) public onlyOwner {
        uint256 balance = IERC20(_token).balanceOf(address(this));

        SafeTransferLib.safeTransfer(ERC20(_token), msg.sender, balance);
    }

    receive() external payable { } // solhint-disable-line no-empty-blocks
}
