// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../core/Pair.sol";
import "./SafeMath.sol";

library Tools {
    using SafeMath for uint256;

    function sortTokens(address tokenA, address tokenB) internal pure returns(address token0, address token1) {
        require(tokenA != tokenB, "tokenA is same with tokenB");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'can not be zero address');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);

        // keccak256 的返回值是 bytes32
        // address 类型是 20 字节，而 uint160 是一个 20 字节的无符号整数。但是注意：bytes32 无法直接转为 uint160，需要先转为 uint256
        // 因此转换路径为：keccak256 
        pair = address(                                         // 4. 转为 address
                    uint160(                                    // 3. 转为 uint160  
                        uint256(                                // 2. 转为 uint256
                            keccak256(                          // 1. 返回结果为 bytes32
                                abi.encodePacked(
                                    hex'ff',
                                    factory,
                                    keccak256(abi.encodePacked(token0, token1)),
                                    hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
                                )
                            )
                        )
                    )
                );
    }

    function getReserves(address factory, address tokenA, address tokenB) public view returns(uint256 reserveA, uint256 reserveB){
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = Pair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = ( tokenA == token0 ) ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // quote(uint256 amountA, uint256 reserveA, uint256 reserveB)
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public pure returns (uint256 amountB) {
        require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
       
        amountB = reserveB.mul(amountA).div(reserveA);           // x / y = Δx / Δy    --->   Δy = y * ( Δx / x )
    }

    function safeTransferFrom(address token, address from, address to, uint256 value) public {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::transferFrom: transferFrom failed'
        );
    }
}