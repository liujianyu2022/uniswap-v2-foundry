// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../Token.sol";
import "../../src/core/Pair.sol";
import "../../src/core/Factory.sol";


contract PairTest is Test {
    Pair pair;
    Factory factory;
    Token token0;
    Token token1;

    function setUp() public {
        token0 = new MockToken("token0", "token0");
        token1 = new MockToken("token1", "token1");
    }
}