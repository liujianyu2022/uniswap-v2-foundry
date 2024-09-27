// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IERC20.sol";

abstract contract IPair is IERC20 {
    
    // ...IERC20   

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure virtual returns (uint);
    function factory() external view virtual returns (address);
    function token0() external view virtual returns (address);
    function token1() external view virtual returns (address);
    function getReserves() external view virtual returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view virtual returns (uint);
    function price1CumulativeLast() external view virtual returns (uint);
    function kLast() external view virtual returns (uint);

    function mint(address to) external virtual returns (uint liquidity);
    function burn(address to) external virtual returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external virtual;
    function skim(address to) external virtual;
    function sync() external virtual;

    function initialize(address, address) external virtual;
}