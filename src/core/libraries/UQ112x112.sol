pragma solidity =0.5.16;

// a library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))

// range: [0, 2**112 - 1]
// resolution: 1 / 2**112

// 固定点数表示法：UQ112x112 表示使用 112 位的整数部分和 112 位的小数部分，共 224 位的固定点数。
// 整数部分：高 112 位
// 小数部分：低 112 位
// 目的：通过使用固定点数表示法，可以在以太坊智能合约中精确地表示小数和进行高精度的数学运算，而不需要浮点数（Solidity 不支持浮点数）
// 固定点数的本质是将整数扩大一定的倍数（比如这里放大了 2^112 倍），以模拟小数部分的存在，在进行除法等运算时不会丢失小数部分

library UQ112x112 {
    uint224 constant Q112 = 2**112;         // 常数 2^112
 

    // 将 uint112 类型的整数编码为 UQ112x112 固定点数
    function encode(uint112 y) internal pure returns (uint224 z) {
        // 相当于将整数部分左移 112 位，小数部分补 0。  如果 y = 5，则 z = 5 * 2^112
        // 因为 y 是 uint112，Q112 是 2^112，那么最大值为 (2^112 - 1) * 2^112 = 2^224 - 2^112 << type(uint224).max = 2^224 - 1
        // 因此z永不溢出，不会达到 type(uint224).max
        z = uint224(y) * Q112; 
    }

    // 将 UQ112x112 固定点数除以 uint112 类型的整数，返回 UQ112x112 固定点数
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        // 将 y 转换为 uint224 类型，以匹配运算的位宽
        // 假设 x = 5.5  -->  5.5 * 2^112
        // 假设 y = 3
        // z = x / y = (5.5 * 2^112) / 2 = 1.83333... * 2^112
        z = x / uint224(y);
    }
}
