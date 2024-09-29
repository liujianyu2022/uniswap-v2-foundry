// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../interfaces/IRouter.sol";
import "../core/Factory.sol";
import "../libraries/Tools.sol";

contract Router is IRouter {

    address public immutable override factory;

    address public immutable override WETH;

    modifier hasExpired(uint256 _deadline) {
        require(block.timestamp <= _deadline, "expired");
        _;
    }

    constructor(address _factory, address _WETH){
        factory = _factory;
        WETH = _WETH;
    }

    function quote(uint amountA, uint reserveA, uint reserveB) external pure override returns (uint256 amountB) {
        return Tools.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure override returns (uint amountOut) {
        return Tools.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure override returns (uint amountIn) {
        return Tools.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] calldata path) external view override returns (uint[] memory amounts) {
        return Tools.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] calldata path) external view override returns (uint[] memory amounts) {
        return Tools.getAmountsIn(factory, amountOut, path);
    }

    // 基于 tokenA 和 tokenB 的储量 reserveA 和 reserveB 以及用户意向的 amountADesired 和 amountBDesired
    // 计算出满足 Δx / Δy = x / y，即满足比例关系的 tokenA 和 tokenB 的实际数量 amountA 和 amountB
    // 因为用户意向的 amountADesired 和 amountBDesired 并不一定满足 x / y 的比例关系
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,            // 用户希望添加的 tokenA 数量
        uint amountBDesired,            // 用户希望添加的 tokenB 数量。
        uint amountAMin,                // 最小接受的 tokenA 数量（保护机制）。
        uint amountBMin                 // 最小接受的 tokenB 数量（保护机制）。
    ) internal returns (uint256 amountA, uint256 amountB) {

        if(Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            Factory(factory).createPair(tokenA, tokenB);
        }
        
        (uint256 reserveA, uint256 reserveB) = Tools.getReserves(factory, tokenA, tokenB);

        if(reserveA == 0 && reserveB == 0){
            (amountA, amountB) = (amountADesired, amountBDesired);          // 如果储备量为零，则直接使用用户希望添加的代币数量
        } else {
            // 根据当前储备量，计算最优的 amountBOptimal 和 amountAOptimal，以确保添加流动性时保持比例
            
            // 根据用户想要传入的 amountA，计算此时按照 x / y = Δx / Δy 比例算出的 amountB 的数量
            uint256 amountBOptimal = Tools.quote(amountA, reserveA, reserveB);

            // 如果计算出的 amountBOptimal 小于或等于用户希望添加的 amountBDesired。也就是说用户提供的 tokenB 的数量是足够的，能够完全消耗掉 tokenA
            if (amountBOptimal <= amountBDesired) {
               
                require(amountBOptimal >= amountBMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');   // 检查是否大于等于 amountBMin，确保用户可以接受的最小数量
                
                (amountA, amountB) = (amountADesired, amountBOptimal);                             // tokenA 完全被消耗，但是 tokenB 数量过多，只消耗了 amountBOptimal
            } else {
                // 如果 amountBOptimal 超过了用户的 amountBDesired，也就是说此时提供的 tokenB 的数量不够，tokenA的数量过多

                uint amountAOptimal = Tools.quote(amountBDesired, reserveB, reserveA);              // 根据 tokenB 的数量计算所需要消耗的 tokenA 的数量

                assert(amountAOptimal <= amountADesired);

                require(amountAOptimal >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');

                (amountA, amountB) = (amountAOptimal, amountBDesired);                             // tokenA 数量过多，只消耗了 amountAOptimal，tokenB 完全被消耗了
            }
        }

    }

    // 下面这个函数是用户进行调用的，因此 msg.sender = 用户
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,        // 用户希望添加的 tokenA 数量
        uint amountBDesired,        // 用户希望添加的 tokenB 数量     注意：这是用户意向输入的数量，可能存在 amountADesired / amountBDesired ≠ reserveA / reserveB 的情况
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external override hasExpired(deadline) returns (uint amountA, uint amountB, uint liquidity){
        // 计算出 满足 Δx / Δy = x / y 关系的 tokenA 和 tokenB 的数量
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);

        address pair = Tools.pairFor(factory, tokenA, tokenB);

        Tools.safeTransferFrom(tokenA, msg.sender, pair, amountA);          // 把对应数量的 token 转到 pair 合约
        Tools.safeTransferFrom(tokenB, msg.sender, pair, amountB);

        liquidity = Pair(pair).mint(to);                                    // 获得 流动性LP Token
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external override hasExpired(deadline) returns (uint amountA, uint amountB) {
        address pair = Tools.pairFor(factory, tokenA, tokenB);            // 根据 create2 生成 pair合约地址，获取其地址

        Pair(pair).transferFrom(msg.sender, pair, liquidity);             // send liquidity to pair

        (uint amount0, uint amount1) =  Pair(pair).burn(to);              // burn liquidity and send token to the "to" address

        (address token0,) = Tools.sortTokens(tokenA, tokenB);
        (amountA, amountB) = ( tokenA == token0 ) ? (amount0, amount1) : (amount1, amount0);

        require(amountA >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');
    }

    // requires the initial amount to have already been sent to the first pair

    // input  -->  ...  -->  ...  -->  output
    // example: [eth, mkr, dai]        1 eth = 10 mkr    1 mkr = 100 dai
    // path: eth  -->  mkr  -->  dai   amounts = [1, 10, 1000]

    //          path[i]          path[i + 1]
    //                                          amounts[0] = 1
    // i = 0    eth              mkr            amountOut = 10     
    // i = 1    mkr              dai            amounts[2] = 1000           
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal {
        
        // 循环次数：path.length - 2 次
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);

            (address token0,) = Tools.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = ( input == token0 ) ? (uint(0), amountOut) : (amountOut, uint(0));

            // i = 0    to = Tools.pairFor(factory, mkr, dai);            path[i + 1]
            address to = ( i < path.length - 2 ) ?  Tools.pairFor(factory, output, path[i + 2]) : _to;

            Pair(Tools.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }

    // 进行代币交换，用户提供精确数量的输入代币，并指定最小输出数量     
    // input  -->  output
    function swapExactTokensForTokens(
        uint amountIn,                      // 提供输入的数量
        uint amountOutMin,                  // 指定最小的输出数量
        address[] calldata path,
        address to,
        uint deadline
    ) external override hasExpired(deadline) returns (uint256[] memory amounts) {
        amounts = Tools.getAmountsOut(factory, amountIn, path);

        require(amounts[amounts.length - 1] >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');

        // 确保代币能够从 用户账户 安全地转移到 pair交易对合约。否则的话，pair 合约无法使用用户的 代币的
        // path: [weth, mkr, dai]       pairPath: [(weth, mkr), (mkr, dai)]
        Tools.safeTransferFrom({
            token: path[0], 
            from: msg.sender, 
            to: Tools.pairFor(factory, path[0], path[1]),       // 将amounts0转到pair合约，
            value: amounts[0]
        });

        _swap(amounts, path, to);
    }

    // 进行代币交换，用户指定所需的精确输出代币数量，并设置最大输入代币数量   
    // input  <-- output
    function swapTokensForExactTokens(
        uint amountOut,                     // 提供输入的数量
        uint amountInMax,                   // 指定最大的输入数量
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override hasExpired(deadline) returns (uint[] memory amounts) {
        amounts = Tools.getAmountsIn(factory, amountOut, path);

        require(amounts[0] <= amountInMax, 'UniswapV2Router: EXCESSIVE_INPUT_AMOUNT');

        Tools.safeTransferFrom({
            token: path[0], 
            from: msg.sender,
            to: Tools.pairFor(factory, path[0], path[1]),
            value: amounts[0]
        });

        _swap(amounts, path, to);
    }
}