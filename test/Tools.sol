// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/core/Pair.sol";

contract Tools {
    function getCreate2Address(address factoryAddr, address[] memory tokens, bytes memory bytecode) external pure returns(address pair) {
        (address token0, address token1) = tokens[0] < tokens[1] ? (tokens[0], tokens[1]) : (tokens[1], tokens[0]);
        
        require(token0 != address(0), "invalid address token0");

        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        pair = address(uint160(uint(keccak256(abi.encodePacked(
            bytes1(0xff),
            factoryAddr,
            salt,
            keccak256(bytecode)             // 注意：这里是bytecode的哈希值
        )))));
    }
}