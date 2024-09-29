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
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );

        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::transferFrom: transferFrom failed'
        );
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    // input  -->  output      (x+Δx)(y-Δy) = xy      Δy = y * Δx / (x + Δx)
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');

        uint amountInWithFee = amountIn.mul(997);                       // input 先扣除手续费  Δx' = 0.997 * Δx
        uint numerator = amountInWithFee.mul(reserveOut);               // numerator = y * Δx'
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);    // denominator = x + Δx'

        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    // input  <--  output      (x+Δx)(y-Δy) = xy      Δx = x * Δy / (y - Δy)
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) public pure returns (uint amountIn) {
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');

        uint numerator = reserveIn.mul(amountOut).mul(1000);        // numerator = x * Δy
        uint denominator = reserveOut.sub(amountOut).mul(997);      // denominator = y - Δy

        // add(1) 是为了确保返回的输入金额始终向上取整。如果计算出的 amountIn 是一个小数，最终需要向上取整到最近的整数，以确保交易能够完成
        // add(1) 可以避免由于舍入造成的不足以满足交易需求
        amountIn = (numerator / denominator).add(1);
    }

    // performs chained getAmountOut calculations on any number of pairs
    // input  -->  ...  -->  ...  -->  output
    // example: [eth, mkr, dai]        1 eth = 10 mkr    1 mkr = 100 dai
    // path: eth  -->  mkr  -->  dai

    //          path[i]          path[i + 1]
    //                                          amounts[0] = 1
    // i = 0    eth              mkr            amounts[1] = 10     
    // i = 1    mkr              dai            amounts[2] = 1000           amounts = [1, 10, 1000]
    function getAmountsOut(address factory, uint amountIn, address[] memory path) public view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        
        // i <= path.length - 2
        // 循环次数：path.length - 2 次
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    // input  <--  ...  <--  ...  <--  output
    // example: [eth, mkr, dai]        1 eth = 10 mkr    1 mkr = 100 dai
    // path: eth  <--  mkr  <--  dai
    
    //          path[i]          path[i + 1]    
    // i = 1    dai              mkr            amounts[2] = 1000           
    // i = 0    mkr              eth            amounts[1] = 10
    //                                          amounts[0] = 1              amounts = [1, 10, 1000]
    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);

        amounts[amounts.length - 1] = amountOut;
        
        // 循环次数：path.length - 2 次
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}