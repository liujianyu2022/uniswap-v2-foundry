// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../../src/core/ERC20.sol";
import "../Events.sol";

contract ERC20Test is Test {
    ERC20 public erc20;

    address userA;
    address userB;
    address exchange;

    function setUp() public {
        erc20 = new ERC20();

        userA = makeAddr("userA");
        userB = makeAddr("userB");
        exchange = makeAddr("exchange");

        erc20.mint(userA, 100 ether);
        erc20.mint(userB, 200 ether);
    }

    function testMint() public {
        // 注意：vm.expectEmit 必须在触发事件之前调用
        // 第一个参数为 true 表示检查 indexed 参数
        // 第二个参数为 true 表示检查事件的参数。
        // 第三个参数（checkTopic1）: 如果设置为 true，则会检查事件的第一个主题（通常是 indexed 参数）。如果事件的主题值与预期不符，测试将失败。
        // 第四个参数（checkData）: 如果设置为 true，则会检查事件的非 indexed 参数（即事件的额外数据）。如果事件的数据部分与预期不符，测试将失败。
        // 第三、四个参数设置这两个参数为 false 时，意味着只关心事件是否触发以及某些特定参数的值。这在一些情况下可以减少测试的严格性，尤其是当你只关心主要参数时
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), userA, 1000 ether);

        erc20.mint(userA, 1000 ether);
        
        assertEq(erc20.totalSupply(), 1300 ether);
    }

    function testOnlyOwnerCanMint() public {
        vm.startPrank(userA);
        vm.expectRevert();
        erc20.mint(userA, 300 ether);
    }

    function testOnlyOwnerCanBurn() public {
        vm.startPrank(userA);
        vm.expectRevert();
        erc20.burn(userA, 300 ether);
    }

    function testName() public view {
        assertEq(erc20.name(), "Uniswap V2 Token");
    }

    function testSymbol() public view {
        assertEq(erc20.symbol(), "UNISWAP-V2-TOKEN");
    }

    function testDecimals() public view {
        assertEq(erc20.decimals(), 18);
    }

    function testTotalSupply() public view {
        assertEq(erc20.totalSupply(), 300 ether);
    }

    function testTransfer() public {
        vm.startPrank(userA);
        erc20.transfer(userB, 10 ether);

        uint256 balance1 = erc20.balanceOf(userA);
        uint256 balance2 = erc20.balanceOf(userB);

        assertEq(balance1, 90 ether);
        assertEq(balance2, 210 ether);
    }

    function testApprove() public {
        vm.startPrank(userA);
        erc20.approve(exchange, 10 ether);

        uint256 allowance1 = erc20.allowance(userA, exchange);
        uint256 allowance2 = erc20.allowance(userB, exchange);

        assertEq(allowance1, 10 ether);
        assertEq(allowance2, 0);
    }
    
    function testTransferFrom() public {
        vm.startPrank(userA);
        erc20.approve(exchange, 50 ether);              // 授权逻辑中，并没有实际扣费！

        vm.startPrank(exchange);
        erc20.transferFrom(userA, userB, 30 ether);     // 在 transferFrom 中才真正进行扣费！

        uint256 balance1 = erc20.balanceOf(userA);
        uint256 balance2 = erc20.balanceOf(userB);

        assertEq(balance1, 70 ether);
        assertEq(balance2, 230 ether);
    }
}
