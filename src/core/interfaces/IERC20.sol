// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

abstract contract IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view virtual returns (string memory);
    function symbol() external view virtual returns (string memory);
    function decimals() external view virtual returns (uint8);
    function totalSupply() external view virtual returns (uint);
    function balanceOf(address owner) external view virtual returns (uint);
    function allowance(address owner, address spender) external view virtual returns (uint);            // 返回授权额度

    function approve(address spender, uint value) external virtual returns (bool);
    function transfer(address to, uint value) external virtual returns (bool);
    function transferFrom(address from, address to, uint value) external virtual returns (bool);
}