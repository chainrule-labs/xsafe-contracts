// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

library AddressLib {
    function includes(address[] memory _array, address _address) internal pure returns (bool) {
        for (uint256 i; i < _array.length; i++) {
            if (_array[i] == _address) {
                return true;
            }
        }
        return false;
    }
}
