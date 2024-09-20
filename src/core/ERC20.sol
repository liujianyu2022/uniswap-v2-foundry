// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IERC20.sol";
import "./libraries/SafeMath.sol";

contract ERC20 is IERC20 {
    using SafeMath for uint;

    string public constant override name = "Uniswap V2 Token";
    string public constant override symbol = "UNISWAP-V2-TOKEN";
    uint8 public constant override decimals = 18;
    uint public override totalSupply;

    address public owner;

    mapping(address owner => uint balance) public override balanceOf;
    mapping(address owner => mapping(address spender => uint amount)) public override allowance;

    modifier onlyOwner {
        require(msg.sender == owner, "you are not the owner!");
        _;
    }

    constructor(){
        owner = msg.sender;
    }

    // 用户调用 approve，授权给第三方 spender
    // 调用者 msg.sender  -->   用户    
    function approve(address spender, uint value) external override returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    // 已经被授权的第三方 spender 调用该函数进行转账
    // from         -->   被扣款的用户地址，该用户授权了第三方 spender
    // msg.sender   -->   第三方 spender  
    function transferFrom(address from, address to, uint value) external override returns (bool) {
        // 在早期的 solidity (0.8.x之前)， uint(-1) 表示 uint256 的最大值，即 2^256 - 1
        // 在 solidity 0.8.x 之后，type(uint256).max 表示 uint256 的最大值
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }

    function mint(address to, uint value) external onlyOwner {
        _mint(to, value);
    }

    function burn(address from, uint value) external onlyOwner {
        _burn(from, value);
    }

    function _mint(address to, uint value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint value) internal {
        totalSupply = totalSupply.sub(value);
        balanceOf[from] = balanceOf[from].sub(value);
        emit Transfer(from, address(0), value);
    }

    function _approve(address owner, address spender, uint value) internal {
        allowance[owner][spender] = value;             // 这里只授权了，并没有进行扣费
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

}
