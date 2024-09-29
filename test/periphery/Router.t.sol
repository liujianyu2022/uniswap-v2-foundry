// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../../src/periphery/Router.sol";
import "../../src/core/Factory.sol";
import "../../src/core/Pair.sol";
import "../MockToken.sol";


contract RouterTest is Test {
    Factory factory;
    Router router;

    MockToken weth;
    MockToken tokenA;
    MockToken tokenB;

    address userA;
    address liquidityProvider;

    function setUp() public {
        weth = new MockToken("WETH", "WETH");
        tokenA = new MockToken("TOKENA", "TOKENA");
        tokenB = new MockToken("TOKENB", "TOKENB");
        userA = makeAddr("userA");
        liquidityProvider = makeAddr("liquidityProvider");

        factory = new Factory(liquidityProvider);
        router = new Router(address(factory), address(weth));

        tokenA.mint(userA, 100 ether);
        tokenB.mint(userA, 100 ether)
    }

}