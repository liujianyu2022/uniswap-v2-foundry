// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../interfaces/IPair.sol";
import "../interfaces/IFactory.sol";
import "../interfaces/ICallee.sol";
import "../libraries/SafeMath.sol";
import "../libraries/UQ112x112.sol";
import "./ERC20.sol";

import {Test, console} from "forge-std/Test.sol";

contract Pair is IPair, ERC20 {
    using SafeMath for uint;
    using UQ112x112 for uint224;

    uint256 public constant override MINIMUM_LIQUIDITY = 10e3;          // 10^3

    address public override factory;
    address public override token0;
    address public override token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    // 为预言机功能提供时间加权平均价格 (TWAP, Time-Weighted Average Price)。
    // 用来记录自流动性池部署以来两个代币之间的累计价格变动情况，累积价格的主要目的是提供价格预言机功能，能够计算任意两个时间点之间的时间加权平均价格，这样就不需要依赖外部预言机了。
    // TWAP 是通过在两个时刻之间计算价格累积器的差值，并除以时间差来得到。例如，假设在时刻 t1 和 t2，price0CumulativeLast 的值分别为 P1 和 P2，那么这段时间内的平均价格可以通过公式计算
    // TWAP =  (P2 - P1) / (t2 - t1)
    uint256 public override price0CumulativeLast;       // 记录了自流动性池部署以来 token1/token0 的价格累积值
    uint256 public override price1CumulativeLast;       // 记录了自流动性池部署以来 token1/token0 的价格累积值
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

    // 返回的是最近一次更新（无论是 mint添加流动性、burn移除流动性，还是swap发生交易）之后的代币储备量
    function getReserves() public view override returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast){
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

        // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IFactory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = SafeMath.sqrt(uint(_reserve0).mul(_reserve1));
                uint rootKLast = SafeMath.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint denominator = rootK.mul(5).add(rootKLast);
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("transfer(address,uint256)")),
            to,
            value
        );
        (bool success, ) = token.call(data);
        require(success, 'UniswapV2: TRANSFER_FAILED');
    }

    // 用户向流动性池中提供代币并获得流动性凭证（liquidity tokens）
    // to：表示流动性凭证的接收者，通常是添加流动性的一方
    // lock 修饰符：防止重入攻击，这是一种确保在执行完当前函数之前，不允许再次调用该函数的机制
    function mint(address to) external override lock returns (uint liquidity) {

        // 此时调用 getReserves() 获取的储备量对应于：在当前流动性添加操作mint之前的代币数量，尚未包含当前交易中的新代币注入。
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();           // type(uint112) / 1e18 = 5192296858534827

        // 当前合约地址上持有的 token0 和 token1 的余额。等于 流动性提供者新注入的代币数量 加上 现有储备的总和
        uint balance0 = IERC20(token0).balanceOf(address(this));            
        uint balance1 = IERC20(token1).balanceOf(address(this));            

        // 流动性提供者注入的代币量：通过当前合约代币余额减去储备余额，得到了新增的代币量
        uint amount0 = balance0.sub(_reserve0);                             // 新添加的代币数量，即池中余额减去储备量
        uint amount1 = balance1.sub(_reserve1);

        bool feeOn = _mintFee(_reserve0, _reserve1);    // _mintFee 函数用于计算并处理协议费，如果费用开关打开，它会铸造部分费用流动性给合约
        uint _totalSupply = totalSupply;                // gas savings, must be defined here since totalSupply can update in _mintFee

        // 第一次流动性注入，通过恒定乘积公式计算 sqrt(amount0 * amount1) 计算流动性代币数量
        // 初始流动性代币中会永久锁定一部分 (MINIMUM_LIQUIDITY) 作为安全机制，这些代币被铸造给 address(0)，确保流动池永远有一部分不会被提走
        if (_totalSupply == 0) {
            liquidity = SafeMath.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
           _mint(address(0), MINIMUM_LIQUIDITY); 
        } else {

            // 对于后续的流动性提供者，流动性代币按比例分配 
            // 最终取这两个值的最小值，以确保按比例添加的代币数量是平衡的
            liquidity = SafeMath.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        
        // 用户注入的代币数量过少，不足以铸造出流动性代币
        require(liquidity > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED');

        // 使用 _mint 函数将计算好的流动性代币铸造给流动性提供者的地址 to
        _mint(to, liquidity);

        // balance0 和 balance1 是流动池的新代币余额
        // _reserve0 和 _reserve1 是旧的储备。该函数会将新的储备值更新为当前的余额，确保储备数据一致性
        _update(balance0, balance1, _reserve0, _reserve1);

        // 如果协议费开关被打开，函数会更新 kLast, 即 k = reserve0 * reserve1
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date

        emit Mint(msg.sender, amount0, amount1);

    }

    // 当流动性提供者想要移除流动性时，流动性代币（LP tokens）将被销毁，流动性提供者应该按比例从池中取回两种代币
    // 注意：流动性提供者在调用 burn() 前，Router 合约中的 removeLiquidity() 会把他们的 LP Token 转移到合约地址
    // 具体代码：在 periphery 仓库的 Router 合约的  removeLiquidity() 中 
    // IUniswapV2Pair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
    function burn(address to) external override lock returns (uint amount0, uint amount1) {
        
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();        // gas savings
        address _token0 = token0;                                       // gas savings
        address _token1 = token1;                                       // gas savings

        // 当前合约地址上持有的 token0 和 token1 的余额。
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));

        // 当前合约地址上拥有的流动性代币
        // 注意：流动性提供者在调用 burn() 前，已经把他们的 LP Token 转移到合约地址
        // 因此这里使用 balanceOf[address[this]]，而不是 balanceOf[address[to]] 
        uint liquidity = balanceOf[address(this)];
        // uint liquidity = balanceOf[to];

        // _mintFee 函数用于计算并处理协议费，如果费用开关打开，它会铸造部分费用流动性给合约
        bool feeOn = _mintFee(_reserve0, _reserve1);

        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee

        amount0 = liquidity.mul(balance0) / _totalSupply; // 根据储备量和流动性比例计算返还的 token0
        amount1 = liquidity.mul(balance1) / _totalSupply; // 根据储备量和流动性比例计算返还的 token0

        require(amount0 > 0 && amount1 > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED');

        // 注意：流动性提供者在调用 burn() 前，已经把他们的 LP Token 转移到合约地址
        // 因此这里使用 balanceOf[address[this]]，而不是 balanceOf[address[to]] 
        _burn(address(this), liquidity);
        // _burn(to, liquidity);

        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);

        // 由于已经返还了 token0 和 token1 给用户，需要重新获取当前合约这两种代币的余额
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        // balance0 和 balance1 是当前池中新的代币余额。
        // _reserve0 和 _reserve1 是先前通过 getReserves() 获取的旧储备量（在此次流动性移除之前）
        _update(balance0, balance1, _reserve0, _reserve1);

        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date

        emit Burn(msg.sender, amount0, amount1, to);
    }

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external override lock {
        require(amount0Out > 0 || amount1Out > 0, 'UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT');

        // 获取当前流动性池中的两个代币的储备量 reserve0 和 reserve1
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings

        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'UniswapV2: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;

        // 避免堆栈过深（Stack Too Deep）错误
        // Solidity 的 EVM 对栈的使用有限制，每个函数中最多只能有 16 个局部变量（包括函数参数）。如果变量过多，可能会导致“stack too deep”错误
        // 在代码中使用局部作用域 {}，可以将一些局部变量的生命周期限制在这个作用域中，一旦退出该作用域，这些局部变量会被销毁，从而释放栈空间。
        // 这样可以在函数内定义更多的局部变量，而不会超出栈的限制

        { // scope for _token{0,1}, avoids stack too deep errors
            address _token0 = token0;
            address _token1 = token1;

            require(to != _token0 && to != _token1, 'UniswapV2: INVALID_TO');

            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens

            if (data.length > 0) ICallee(to).uniswapCall(msg.sender, amount0Out, amount1Out, data);

            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }

        // balance0                             actual balance
        // _reserve0 - amount0Out               new internal balance

        // example: in --> token0   reserve0 = 1000             out --> token1
        // amount0Out = 0                                       amount1Out = 100
        // amount0In = 10
        // balance0 = 1000 + 10 = 1010

        //                  1010  >   1000    -     0               1010-(1000-0) = 10
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;

        //                 
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'UniswapV2: INSUFFICIENT_INPUT_AMOUNT');

        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
            uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));

            // 检查 (X0 + ΔX*(1-f)) * (Y0 - ΔY) >= X0 * Y0 = k
            require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000**2), 'UniswapV2: K');
        }

        _update(balance0, balance1, _reserve0, _reserve1);

        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }



    function skim(address to) external override lock {

    }

    function sync() external override lock {

    }

    // 更新流动性池中的代币储备（reserves）
    // 更新价格累积器（price accumulators） 用于跟踪两个代币间的相对价格，以便提供价格预言机功能。两代币的储备都不为零且上次更新到当前的时间间隔大于 0，累积的价格根据时间的推移而更新
    // _update 函数的主要作用是更新流动池的储备量，并在每个区块的首次调用时更新价格累加器
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, 'UniswapV2: OVERFLOW');

        uint32 blockTimestamp = uint32(block.timestamp % 2**32);            // 将时间戳转换为 32 位整数，以避免溢出

        uint32 timeElapsed = blockTimestamp - blockTimestampLast;           // 自上一次更新（blockTimestampLast）以来经过的时间。overflow is desired

        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // 假设   _reserve0 = 3000（token0 的储备量）     _reserve1 = 2000（token1 的储备量）        timeElapsed = 15s
            // UQ112x112.encode(_reserve1).uqdiv(_reserve0) = ( 2000 * 2^112 ) / 3000 = 3461531239023218419020330886146730666
            price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;  // ( 2000 * 2^112 ) / 3000 * 15，由于放大了 2^112，可以解决除法时的精度损失
            price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }

        // 更新池中的代币储备量     
        // balance0 和 balance1 是函数的输入参数，表示当前池中 token0 和 token1 的实际余额
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;

        emit Sync(reserve0, reserve1);

    }

    // 注意：下面的update函数仅是为了在测试的时候能够更新reserve0和reserve1而添加的
    function update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) external {
        _update(balance0, balance1, _reserve0, _reserve1);
    }
}