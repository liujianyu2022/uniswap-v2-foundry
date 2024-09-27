// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

abstract contract IFactory{
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view virtual returns (address);
    function feeToSetter() external view virtual returns (address);

    function getPair(address tokenA, address tokenB) external view virtual returns (address pair);
    function allPairs(uint) external view virtual returns (address pair);
    function allPairsLength() external view virtual returns (uint);

    function createPair(address tokenA, address tokenB) external virtual returns (address pair);

    function setFeeTo(address) external virtual;
    function setFeeToSetter(address) external virtual;
}