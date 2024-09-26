// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import "../../src/core/Pair.sol";
import "../../src/core/Factory.sol";
import "../Tools.sol";
import "../MockToken.sol";

contract PairTest is Test {
    Factory factory;
    Pair pair;
    MockToken weth;
    MockToken dai;
    address mockTokenOwner;

    address liquidityProvider1;
    address liquidityProvider2;
    address liquidityProvider3;

    address pairOwner;
    uint256 public constant MINIMUM_LIQUIDITY = 10e3;          // 10^3

    function setUp() public {
        createMockToken();

        pairOwner = makeAddr("pairOwner");
        factory = new Factory(pairOwner);

        vm.startPrank(pairOwner);
        pair = Pair(factory.createPair(address(weth), address(dai)));
    }

    function createMockToken() internal {
        liquidityProvider1 = makeAddr(" liquidityProvider1");
        liquidityProvider2 = makeAddr(" liquidityProvider2");
        liquidityProvider3 = makeAddr(" liquidityProvider3");

        mockTokenOwner = makeAddr("mockTokenOwner");
        vm.startPrank(mockTokenOwner);

        weth = new MockToken("WETH", "WETH");
        dai = new MockToken("DAI", "DAI");

        weth.mint(mockTokenOwner, 1000 ether);          // 初始化 1100 ether
        dai.mint(mockTokenOwner, 10000 ether);          // 初始化 11000 dai

        weth.transfer(liquidityProvider1, 100 ether);    // 给liquidityProvider1 100 ether
        dai.transfer(liquidityProvider1, 1000 ether);    // 给liquidityProvider1 1000 dai

        weth.transfer(liquidityProvider2, 100 ether);    // 给liquidityProvider2 100 ether
        dai.transfer(liquidityProvider2, 1000 ether);    // 给liquidityProvider2 1000 dai

        weth.transfer(liquidityProvider3, 100 ether);    // 给liquidityProvider3 100 ether
        dai.transfer(liquidityProvider3, 1000 ether);    // 给liquidityProvider3 1000 dai

        vm.stopPrank();
    }

    function testBalance() public view {
        assertEq(weth.balanceOf(mockTokenOwner), 700 ether);
        assertEq(dai.balanceOf(mockTokenOwner), 7000 ether);

        assertEq(weth.balanceOf(liquidityProvider1), 100 ether);
        assertEq(dai.balanceOf(liquidityProvider1), 1000 ether);

        assertEq(weth.balanceOf(liquidityProvider2), 100 ether);
        assertEq(dai.balanceOf(liquidityProvider2), 1000 ether);

        assertEq(weth.balanceOf(liquidityProvider3), 100 ether);
        assertEq(dai.balanceOf(liquidityProvider3), 1000 ether);
    }

    function testMint() public {
        vm.startPrank(liquidityProvider1);

        weth.transfer(address(pair), 10 ether);
        dai.transfer(address(pair), 100 ether);

        // 第一次添加流动性：_totalSupply = 0 
        // liquidity = sqrt(10 * 100) - 10e3 = 31622776601683783319 wei
        uint256 totalSupplyBeforeAdd = 0;
        uint256 liquidity = pair.mint(liquidityProvider1); 
        assert(pair.totalSupply() == liquidity + MINIMUM_LIQUIDITY);    
        assert(liquidity >= 31.6 ether);
        assert(liquidity <= 31.7 ether);
        

        // 第二次添加流动性：_totalSupply = 31622776601683783319 wei    31.62 ether
        // 添加之前，池中已经有 weth = 10 ether    dai = 100 ether   x / y = 1 / 10
        // 因此需要按照 Δx / Δy = 1 / 10 的比例添加
        // min(Δx / x = 2, Δy / y = 2) = 2
        // Δliquidity / totalSupply = min(Δx / x = 2, Δy / y = 2) = 2
        weth.transfer(address(pair), 20 ether);
        dai.transfer(address(pair), 200 ether);

        totalSupplyBeforeAdd = pair.totalSupply();
        liquidity = pair.mint(liquidityProvider1);
        assert(liquidity == 2 * totalSupplyBeforeAdd);

        // 第三次添加流动性：
        // 此时池中有 x = weth = 30 ether   y = dai = 300 ether       x / y = 1 / 10
        // 如果这 Δx = 15, Δy = 330 来添加，也就是不满足 Δx / Δy = 1 / 10
        // min(Δx / x = 0.5, Δy / y = 1.1) = 0.5
        // Δliquidity / totalSupply = min(Δx / x = 0.5, Δy / y = 1.1) = 0.5
        weth.transfer(address(pair), 15 ether);
        dai.transfer(address(pair), 330 ether);

        totalSupplyBeforeAdd = pair.totalSupply();
        liquidity = pair.mint(liquidityProvider1);

        // 注意：solidity中没有小数，因此0.5需要写成 1 * totalSupplyBeforeAdd / 2
        assert(liquidity == 1 * totalSupplyBeforeAdd / 2); 
        assertEq(weth.balanceOf(liquidityProvider1), 100 ether - 10 ether - 20 ether - 15 ether);      
        assertEq(dai.balanceOf(liquidityProvider1), 1000 ether - 100 ether - 200 ether - 330 ether);
        assertEq(weth.balanceOf(address(pair)), 10 ether + 20 ether + 15 ether);     
        assertEq(dai.balanceOf(address(pair)), 100 ether + 200 ether + 330 ether);  

        // 注意：如果没有按照池中的比例进行添加，可能会导致多添加的那部分无法正常取回
        // 按照上面第三次添加的情况进行分析：x = 30, y = 300, totalSupplyBeforeAdd = 94.8 
        // 此时 Δx = 15, Δy = 330, min(Δx / x = 0.5, Δy / y = 1.1) = 0.5
        // 第三次添加的时候获得的 liquidity = 0.5 * totalSupplyBeforeAdd = 47.4

        // 此时池中累计：x = 45,   y = 630,   totalSupply = 94.8 + 47.4 = 142.2
        // 第一次liquidity占比：31.6 / 142.2 = 22.2%    Δx = 22.2% * x = 9.99      Δy = 22.2% * y = 139.86
        // 第二次liquidity占比：63.2 / 142.2 = 44.4%    Δx = 44.4% * x = 19.98     Δy = 44.4% * y = 279.72
        // 第三次liquidity占比：47.4 / 142.2 = 33.3%    Δx = 33.3% * x = 15        Δy = 33.3% * y = 210

        // 可以看到对于 x 而言是正确分配了的，但是对于y而言分配出现了错误，第三次存入了 330，但是只分到了 210
        // 这就是因为 第三次没有按照 x / y = Δx / Δy 这个要求来添加流动性，计算liquidity系数的时候 min(Δx / x, Δy / y)
    }

    function testBurn() public {

        // 第一次添加流动性
        vm.startPrank(liquidityProvider1);
        weth.transfer(address(pair), 10 ether);
        dai.transfer(address(pair), 100 ether);
        uint256 liquidity1 = pair.mint(liquidityProvider1);   // 31.6 ether
        vm.stopPrank();

        // 第二次次添加流动性
        vm.startPrank(liquidityProvider2);
        weth.transfer(address(pair), 20 ether);
        dai.transfer(address(pair), 200 ether);
        uint liquidity2 = pair.mint(liquidityProvider2);    // 63.2 ether
        vm.stopPrank();

        // 第三次次添加流动性
        vm.startPrank(liquidityProvider3);
        weth.transfer(address(pair), 30 ether);
        dai.transfer(address(pair), 300 ether);
        uint liquidity3 = pair.mint(liquidityProvider3); 
        vm.stopPrank();

        uint256 totalSupply = pair.totalSupply();

        assert(liquidity1 > 31.622 ether);
        assert(liquidity1 < 31.623 ether);      // 31.62
        assert(liquidity1 == pair.balanceOf(liquidityProvider1));      // 31.62


        assert(liquidity2 > 63.244 ether);  
        assert(liquidity2 < 63.246 ether);      // 63.24

        assert(liquidity3 > 94.866 ether);
        assert(liquidity3 < 94.869 ether);      // 94.86

        assert(totalSupply > 189.732 ether);
        assert(totalSupply < 189.738 ether);    // 189.73

        // liquidityProvider1   31.62 / 189.73 = 16.67%
        // liquidityProvider2   63.24 / 189.73 = 33.33%
        // liquidityProvider3   94.86 / 189.73 = 50.00%

        // 目前池中总量 weth = 60 ether     dai = 600 ether
        // 模拟池中产生的收益，只要不调用 mint() 即可
        vm.startPrank(mockTokenOwner);
        weth.transfer(address(pair), 30 ether);     // weth收益率为50%
        dai.transfer(address(pair), 60 ether);      // dai收益率为10%
        vm.stopPrank();

        // 注意：此时只是在weth和dai合约中记录的余额更新了。在uniswap中是通过内部记录的reserve0和reserve1来进行流动性操作的
        uint256 wethBalance = weth.balanceOf(address(pair));
        uint256 daiBalance =dai.balanceOf(address(pair));
        assertEq(wethBalance, 90 ether);
        assertEq(daiBalance, 660 ether);

        // 目前池中记录的reserve weth = 60 ether     dai = 600 ether
        (uint112 wethReserve, uint112 daiReserve, ) = pair.getReserves();

        // 注意：下面的update函数仅供本次测试使用，目的是为了更新reserve0和reserve1
        pair.update(wethBalance, daiBalance, wethReserve, daiReserve);

        // 获取更新后的 reserve
        (wethReserve, daiReserve, ) = pair.getReserves();

        assertEq(wethReserve, 90 ether);
        assertEq(daiReserve, 660 ether);



        // 接下来进行 burn 操作
        vm.startPrank(liquidityProvider3);
        (uint256 amountWeth, uint256 amountDai) = pair.burn(liquidityProvider3);

        assertEq(amountWeth / 1e18, 330 ether / 1e18);
        assertEq(amountDai / 1e18, 45 ether / 1e18);
        vm.stopPrank();
    }
}

