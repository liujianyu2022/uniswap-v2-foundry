// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
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
    address liquidityProvider;
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
        liquidityProvider = makeAddr(" liquidityProvider");
        mockTokenOwner = makeAddr("mockTokenOwner");
        vm.startPrank(mockTokenOwner);
        weth = new MockToken("WETH", "WETH");
        dai = new MockToken("DAI", "DAI");
        weth.mint(mockTokenOwner, 1100 ether);          // 初始化 1100 ether
        dai.mint(mockTokenOwner, 11000 ether);          // 初始化 11000 dai
        weth.transfer(liquidityProvider, 100 ether);    // 给liquidityProvider 100 ether
        dai.transfer(liquidityProvider, 1000 ether);    // 给liquidityProvider 1000 dai
        vm.stopPrank();
    }

    function testBalance() public view {
        assertEq(weth.balanceOf(mockTokenOwner), 1000 ether);
        assertEq(dai.balanceOf(mockTokenOwner), 10000 ether);
        assertEq(weth.balanceOf(liquidityProvider), 100 ether);
        assertEq(dai.balanceOf(liquidityProvider), 1000 ether);
    }

    function testMMint() public {
        vm.startPrank(liquidityProvider);

        weth.transfer(address(pair), 10 ether);
        dai.transfer(address(pair), 100 ether);

        // 第一次添加流动性：_totalSupply = 0 
        // liquidity = sqrt(10 * 100) - 10e3 = 31622776601683783319 wei
        uint256 totalSupplyBeforeAdd = 0;
        uint256 liquidity = pair.mint(liquidityProvider); 
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
        liquidity = pair.mint(liquidityProvider);
        assert(liquidity == 2 * totalSupplyBeforeAdd);

        // 第三次添加流动性：
        // 此时池中有 x = weth = 30 ether   y = dai = 300 ether       x / y = 1 / 10
        // 如果这 Δx = 30, Δy = 330 来添加，也就是不满足 Δx / Δy = 1 / 10
        // min(Δx / x = 1, Δy / y = 1.1) = 1
        // Δliquidity / totalSupply = min(Δx / x = 1, Δy / y = 1.1) = 1
        weth.transfer(address(pair), 20 ether);
        dai.transfer(address(pair), 200 ether);

        totalSupplyBeforeAdd = pair.totalSupply();
        liquidity = pair.mint(liquidityProvider);
        assert(liquidity == 1 * totalSupplyBeforeAdd);
    }
}