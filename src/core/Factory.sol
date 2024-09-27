// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../interfaces/IFactory.sol";
import "./Pair.sol";

contract Factory is IFactory {
    address public override feeTo;              // 用于接收交易费用的地址，它将收集交易的手续费
    address public override feeToSetter;        // 合约所有者的地址，相当于，能够设置 feeTo
    address[] public override allPairs;

    mapping (address tokenA => mapping(address tokenB => address pair)) public override getPair;
    

    // 只有合约的 owner 才能设置 feeTo 和 feeToSetter
    modifier onlyOwner {
        require(msg.sender == feeToSetter, "you are not the owner!");
        _;
    }

    constructor(address _feeToSetter){
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view override returns(uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns(address) {
        require(tokenA != tokenB, "same token address");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);   // 对代币地址进行排序，以保证在映射中存储时的一致性
        require(token0 != address(0), "invalid address token0");
        require(getPair[token0][token1] == address(0), "pair has already existed");


        // create2 是以太坊虚拟机（EVM）中用于动态创建合约的一种指令，它允许开发者在合约创建时指定合约地址的生成方式。
        // 与传统的 create 指令不同，create2 使得合约的地址在创建之前就可以被确定，从而为合约的部署提供了更大的灵活性
        // 通过相同的 salt 和 相同的初始化代码 在任何时候生成相同的合约地址
        // address = keccak256(bytes1(0xff) ++ sender ++ salt ++ keccak256(init_code))[12:]
        //      bytes1(0xff): 一个常量，用于区分使用 create2 创建的合约
        //      sender: 调用 createPair 函数的地址，也就是流动性池的创建者的地址
        //      salt: 提供的随机值，用于确保生成的地址的唯一性
        //      keccak256(init_code): 新合约的初始化代码的哈希，用于确保合约的代码也影响最终地址，init_code 表示新合约的初始化字节码
        //      [12:]表示对计算结果进行切片操作，只保留结果的后 20 字节（160 位），以形成合约地址。在 Solidity 中，合约地址是 20 字节（160 位）的值，因此需要从生成的哈希中提取出这一部分

        
        // salt 是根据 token0 和 token1 生成的哈希值，用于确保合约地址的唯一性
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        // 1. 使用内联汇编的形式：
        // type(Pair).creationCode 返回 Pair 合约在部署时的字节码。这是合约的初始代码，用于创建合约实例，即上面的 init_code
        // bytes memory bytecode = type(Pair).creationCode;                        
        // assembly {
        //     pair := create2(0, add(bytecode, 32), mload(bytecode), salt)         // pair 的数据类型是 address
        // }

        // 2. 使用 new 的形式，也就是 Solidity语法模式：
        // Solidity 自动处理 sender，不需要手动指定 address(this)
        // Solidity 自动处理合约的初始化字节码 init_code ，生成合约实例时不需要手动指定字节码
        Pair pair = new Pair{salt: salt}();
        
        // 调用新创建的流动性池合约的 initialize 函数，以设置代币对
        // Pair(pair).initialize(token0, token1);                   // 如果是内联汇编的方式创建的pair对象，需要进行转换
        pair.initialize(token0, token1);

        getPair[token0][token1] = address(pair);                    // 由于 pair 为 Pair 类型，需要转为 address 类型
        getPair[token1][token0] = address(pair);                    // 如果采用的是 内联汇编形式创建的，pair 为 address 类型，就不需要转换了

        allPairs.push(address(pair));                               // 将新创建的流动性池地址添加到 allPairs 数组中，以便跟踪所有流动性池

        emit PairCreated(token0, token1, address(pair), allPairs.length);

        return address(pair);
    }

    // 仅用于调整交易手续费的收款地址。调用此函数不会改变流动性池的所有权，原来的feeToSetter地址仍然保留对流动性池的管理权限
    function setFeeTo(address _feeTo) external override onlyOwner {
        feeTo = _feeTo;
    }

    // 改变了流动性池的所有权管理者。调用此函数会将权限转移给新的地址，从而让新地址能够管理feeTo的设置
    function setFeeToSetter(address _feeToSetter) external override onlyOwner {
        feeToSetter = _feeToSetter;
    }
}