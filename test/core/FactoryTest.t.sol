// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import "../../src/core/Factory.sol";
import "../../src/core/Pair.sol";

import "../Tools.sol";

contract FactoryTest is Test {
    Factory public factory;
    Tools public tools;
    address public owner;
    address public other;
    address[] public TEST_ADDRESSES;
    bytes public bytecode;

    function setUp() public {
        owner = makeAddr("owner");
        other = makeAddr("other");
        TEST_ADDRESSES.push(makeAddr("test1"));
        TEST_ADDRESSES.push(makeAddr("test2"));

        bytecode = type(Pair).creationCode;

        factory = new Factory(owner);
        tools = new Tools();
    }

    function testInitialState() public view {
        assertEq(factory.feeTo(), address(0));
        assertEq(factory.feeToSetter(), owner);
        assertEq(factory.allPairsLength(), 0);
    }

    function testCreatePair() public {

        address create2Address = tools.getCreate2Address(address(factory), TEST_ADDRESSES, bytecode);

        // factory.createPair()  返回了 Pair 合约对象的地址，使用 abi.decode 进行解码
        (bool success, bytes memory encodePair) = address(factory).call(
            abi.encodeWithSignature("createPair(address,address)", TEST_ADDRESSES[0], TEST_ADDRESSES[1])
        );
        
        require(success, "Pair creation failed");

        address getPair = factory.getPair(TEST_ADDRESSES[0], TEST_ADDRESSES[1]);
        address decodePair = abi.decode(encodePair, (address));               

        
        assertEq(getPair, decodePair);
        assertEq(getPair, create2Address);
        assertEq(factory.allPairs(0), create2Address);
        assertEq(factory.allPairsLength(), 1);

        Pair pair = Pair(create2Address);
        assertEq(pair.factory(), address(factory));
        assertEq(pair.token0(), TEST_ADDRESSES[0]);
        assertEq(pair.token1(), TEST_ADDRESSES[1]);
    }

    function testfuzzCreatePair(address tokenA, address tokenB) public {
        // 跳过无效输入
        if (tokenA == address(0) || tokenB == address(0) || tokenA == tokenB) {
            return; 
        }

        address[] memory tempArr = new address[](2);
        tempArr[0] = tokenA;
        tempArr[1] = tokenB;

        address create2Address = tools.getCreate2Address(address(factory), tempArr, bytecode);

        (bool success, bytes memory encodePair) = address(factory).call(
            abi.encodeWithSelector(
                bytes4(keccak256("createPair(address,address)")),
                tempArr[0],
                tempArr[1]
            )
        );

        require(success, "Pair creation failed");

        address getPair = factory.getPair(tempArr[0], tempArr[1]);
        address decodePair = abi.decode(encodePair, (address));     

        assertEq(getPair, decodePair);
        assertEq(getPair, create2Address);
    }

    function testMultipleCreate() public {
       factory.createPair( TEST_ADDRESSES[0], TEST_ADDRESSES[1]);

       vm.expectRevert("pair has already existed");
       factory.createPair( TEST_ADDRESSES[0], TEST_ADDRESSES[1]);
    }

    function testSetFeeTo() public {
        vm.expectRevert("you are not the owner!");
        factory.setFeeTo(other);

        vm.prank(owner);
        factory.setFeeTo(other);                    // 只是修改了收款地址，没有更改pair所有权
        assertEq(factory.feeTo(), other);
        assertEq(factory.feeToSetter(), owner);

        vm.prank(owner);
        factory.setFeeToSetter(other);              // 更改了pair的所有权
        assertEq(factory.feeTo(), other);
        assertEq(factory.feeToSetter(), other);
    }
}