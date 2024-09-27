// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

abstract contract IRouter {
    // 返回 Uniswap 工厂合约的地址，用于创建和管理流动性池
    function factory() external view virtual returns (address);

    // 返回 Wrapped Ether (WETH) 的地址，便于在以太坊生态中使用 ETH
    function WETH() external view virtual returns (address);

    // 根据给定的输入数量和储备量，计算输出数量，通常用于估算交换结果    input amountA  -->  output amountB
    function quote(uint amountA, uint reserveA, uint reserveB) external pure virtual returns (uint amountB);
    
    // 给定输入数量和储备量下，可以获得的输出数量    input  -->  output
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure virtual returns (uint amountOut);

    // 给定输出数量和储备量下，需要的输入数量        input  <--  output
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure virtual returns (uint amountIn);

    // 通过路径进行多跳交换时，从输入代币到输出代币的每一步数量，用于链式交易    input --> ... ---> ... ---> output
    function getAmountsOut(uint amountIn, address[] calldata path) external view virtual returns (uint[] memory amounts);

    // 在多跳交换时，从输出代币到输入代币的每一步所需数量                       input <-- ... <--- ... <--- output
    function getAmountsIn(uint amountOut, address[] calldata path) external view virtual returns (uint[] memory amounts);

    // 将指定数量的两个代币 tokenA 和 tokenB 添加到流动性池，返回 实际添加的代币数量amountA和amountB 和 流动性代币LP 的数量
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual returns (uint amountA, uint amountB, uint liquidity);

    // 从流动性池中移除流动性，并返回相应的代币数量
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual returns (uint amountA, uint amountB);

    // 进行代币交换，用户提供精确数量的输入代币，并指定最小输出数量     input  -->  output
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual returns (uint[] memory amounts);

    // 进行代币交换，用户指定所需的精确输出代币数量，并设置最大输入代币数量
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual returns (uint[] memory amounts);
}