// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IPair.sol";
import "./libraries/SafeMath.sol";
import "./ERC20.sol";

contract Pair is IPair, ERC20 {
    using SafeMath for uint;

    uint256 public constant override MINIMUM_LIQUIDITY = 10e3; // 10^3

    address public override factory;
    address public override token0;
    address public override token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 public override price0CumulativeLast;
    uint256 public override price1CumulativeLast;
    uint256 public override kLast;

    bool private unlock = true;
    modifier lock {
        require(unlock, "locked!");
        unlock = false;
        _;
        unlock = true;
    }

    constructor() {
        factory = msg.sender;
    }

    // called once by the factory when deploy.
    function initialize(address _token0, address _token1) external override {
        require(factory == msg.sender, "only the factory can call this function");
        token0 = _token0;
        token1 = _token1;
    }

    function getReserves() public view override returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast){
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    // 用户向流动性池中提供代币并获得流动性凭证（liquidity tokens）
    // address to：表示流动性凭证的接收者，通常是添加流动性的一方
    // lock 修饰符：防止重入攻击，这是一种确保在执行完当前函数之前，不允许再次调用该函数的机制
    function mint(address to) external override lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();

        uint balance0 = IERC20(token0).balanceOf(address(this));            // 当前池中 token0 的余额
        uint balance1 = IERC20(token1).balanceOf(address(this));            // 当前池中 token1 的余额
        uint amount0 = balance0.sub(_reserve0);                             // 新添加的代币数量，即池中余额减去储备量
        uint amount1 = balance1.sub(_reserve1);


    }

    function burn(address to) external override lock returns (uint amount0, uint amount1) {

    }

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external override lock {

    }



    function skim(address to) external override lock {

    }

    function sync() external override lock {

    }

    // 更新流动性池中的代币储备（reserves）
    // 更新价格累积器（price accumulators） 用于跟踪两个代币间的相对价格，以便提供价格预言机功能。两代币的储备都不为零且上次更新到当前的时间间隔大于 0，累积的价格根据时间的推移而更新

    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, 'UniswapV2: OVERFLOW');

    }
}