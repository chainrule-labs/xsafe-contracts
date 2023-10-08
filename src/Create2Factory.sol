// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;


contract Create2Factory {
    event Deploy(address indexed sender, address indexed child, uint256 nonce);

    bytes32 constant DOMAIN_SEPARATOR_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    
    // Mapping to keep track of user nonces
    mapping(address => uint256) public userNonces;

    // Computes and returns domain separator hash
    function domainSeparator() public view returns (bytes32) {
        return keccak256(abi.encode(
            DOMAIN_SEPARATOR_TYPEHASH,
            keccak256("Create2Factory"),
            keccak256("1"),
            block.chainid,
            address(this)
        ));
    }

    // Computes the hash to be signed off-chain
    function getTransactionHash(uint256 _nonce) public view returns (bytes32) {
        bytes32 domainHash = domainSeparator();
        return keccak256(abi.encode(domainHash, _nonce));
    }

    // Returns address to be created before actual deployment
    function getAddress(bytes memory signature, bytes memory bytecode) public view returns (address) {
        address userAddress = _recoverSigner(getTransactionHash(userNonces[msg.sender]), signature);
        uint256 salt = uint256(bytes32(uint256(userAddress))) + userNonces[msg.sender];
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode)));
        return address(uint160(uint256(hash)));
    }

    // Deploys a new contract
    function deploy(bytes memory signature, bytes memory bytecode) public returns (address) {
        address userAddress = _recoverSigner(getTransactionHash(userNonces[msg.sender]), signature);
        uint256 salt = uint256(bytes32(uint256(userAddress))) + userNonces[msg.sender];
        address child;

        assembly {
            child := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(child)) { revert(0, 0) }
        }

        userNonces[msg.sender]++;
        emit Deploy(msg.sender, child, userNonces[msg.sender]);
        return child;
    }

    // Recover the signer address from a signature
    function _recoverSigner(bytes32 _hash, bytes memory _sig) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = _splitSignature(_sig);
        return ecrecover(_hash, v, r, s);
    }

    // Splits a signature into (r, s, v)
    function _splitSignature(bytes memory _sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(_sig.length == 65, "Invalid signature length");

        assembly {
            r := mload(add(_sig, 0x20))
            s := mload(add(_sig, 0x40))
            v := byte(0, mload(add(_sig, 0x60)))
        }
    }
}
