// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { ECDSA } from "../dependencies/cryptography/ECDSA.sol";
import { CREATE3 } from "solmate/utils/CREATE3.sol";
import { SafeTransferLib, ERC20 } from "solmate/utils/SafeTransferLib.sol";
import { Initializable } from "../dependencies/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "../dependencies/proxy/utils/UUPSUpgradeable.sol";
import { Ownable } from "../dependencies/access/Ownable.sol";
import { IERC20 } from "../dependencies/token/interfaces/IERC20.sol";

contract Create3Factory is Initializable, UUPSUpgradeable, Ownable {
    // Private Constants: no SLOAD to save users gas
    address private constant CONTRACT_DEPLOYER = 0x3790e085cD4FC7a12270DaEedc5c208aFc35bB0F; // TODO: Update

    // EIP-712 Storage
    bytes32 internal domainSeparator;

    // Factory Storage
    mapping(address => mapping(bytes32 => uint256)) public userNonces;
    mapping(address => address[]) internal _deploymentHistory;

    // Events
    event Deploy(
        address indexed principal,
        address indexed child,
        bytes32 indexed hashedStrippedBytecode,
        bytes constructorArgsBytecode,
        uint256 nonce
    );

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
                keccak256("Create3Factory"),
                keccak256("1"), // Tracks contract upgrades
                block.chainid,
                address(this)
            )
        );
    }

    /**
     * @dev Computes the expected message hash.
     * @param _principal The address of the account for whom this factory contract will deploy a child contract.
     * @param _strippedBytecode The bytecode of the contract to be deployed without the constructor arguments.
     * @return messageHash The expected signed message hash.
     */
    function _computeMessageHash(address _principal, bytes memory _strippedBytecode) internal view returns (bytes32) {
        bytes32 txHash = getTransactionHash(_principal, _strippedBytecode);
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));
    }

    /**
     * @dev Returns the unique deployment transaction hash to be signed.
     * @param _principal The address of the account for whom this factory contract will deploy a child contract.
     * @param _strippedBytecode The bytecode of the contract to be deployed without the constructor arguments.
     * @return txHash The unique deployment transaction hash to be signed.
     */
    function getTransactionHash(address _principal, bytes memory _strippedBytecode) public view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                domainSeparator, _principal, _strippedBytecode, userNonces[_principal][keccak256(_strippedBytecode)]
            )
        );
    }

    /**
     * @dev Returns the predicted address of a contract to be deployed before it's deployed.
     * @param _principal The address of the account that signed the message hash.
     * @param _strippedBytecode The bytecode of the contract to be deployed without the constructor arguments.
     * @return child The predicted address of the contract to be deployed.
     */
    function getAddress(address _principal, bytes memory _strippedBytecode) public view returns (address) {
        bytes32 salt = keccak256(
            abi.encodePacked(_principal, _strippedBytecode, userNonces[_principal][keccak256(_strippedBytecode)])
        );
        return CREATE3.getDeployed(salt);
    }

    /**
     * @dev Returns the keccak256 hash of the provided stripped bytecode.
     * @param _strippedBytecode The bytecode of the contract to be deployed without the constructor arguments.
     * @return hash The keccak256 hash of the provided stripped bytecode.
     */
    function getBytecodeHash(bytes memory _strippedBytecode) public pure returns (bytes32) {
        return keccak256(_strippedBytecode);
    }

    /**
     * @dev Returns a list of the provided principal's previously deployed child contracts.
     * @param _principal The address of the account that signed the message hash.
     * @return deploymentHistory A list of the provided principal's previously deployed child contracts.
     */
    function getDeploymentHistory(address _principal) public view returns (address[] memory) {
        return _deploymentHistory[_principal];
    }

    /**
     * @dev Deploys arbitrary child contracts at predictable addresses, derived from account signatures.
     * @param _principal The address of the account that signed the message hash.
     * @param _signature The resulting signature from the principal account signing the messahge hash.
     * @param _strippedBytecode The bytecode of the contract to be deployed without the constructor arguments.
     * @param _constructorArgsBytecode The encoded constructor arguments of the contract to be deployed.
     */
    function deploy(
        address _principal,
        bytes memory _signature,
        bytes memory _strippedBytecode,
        bytes memory _constructorArgsBytecode
    ) public payable {
        bytes32 hashedStrippedBytecode = keccak256(_strippedBytecode);
        uint256 currentNonce = userNonces[_principal][hashedStrippedBytecode];
        bytes32 expectedMessageHash = _computeMessageHash(_principal, _strippedBytecode);

        // Ensure the provided principal signed the expected message hash
        if (ECDSA.recover(expectedMessageHash, _signature) != _principal) revert Unauthorized();

        // Update nonce state
        userNonces[_principal][hashedStrippedBytecode]++;

        // Calculate salt
        bytes32 salt = keccak256(abi.encodePacked(_principal, _strippedBytecode, currentNonce));

        // Deploy
        address child = CREATE3.deploy(salt, abi.encodePacked(_strippedBytecode, _constructorArgsBytecode), msg.value);

        // Update deployment history
        _deploymentHistory[_principal].push(child);

        emit Deploy(_principal, child, hashedStrippedBytecode, _constructorArgsBytecode, currentNonce);
    }

    receive() external payable { } // solhint-disable-line no-empty-blocks

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
}
