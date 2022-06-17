// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import './interfaces/IDenoswapFactory.sol';
import './DenoswapPair.sol';

contract DenoswapFactory is IDenoswapFactory{

  // 配对映射
  mapping(address => mapping(address => address)) public getPair;

  // 所有配对合约的地址
  address[] public allPairs;

  constructor() {

  }

  function createPair(address tokenA, address tokenB) external returns(address pair) {
    require(tokenA != address(0) && tokenB != address(0) && tokenA != tokenB, 'invalid token address');

    // sort token
    (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

    require(getPair[token0][token1] == address(0), 'pair exists');
    // 获取配对合约创建的字节码
    bytes memory bytecode = type(DenoswapPair).creationCode;
    // 将 token0 和 token1 打包后创建哈希，用作 create2 的参数
    bytes32 salt = keccak256(abi.encodePacked(token0, token1));

    assembly {
      pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
    }
    // 调用配对合约初始化方法
    IDenoswapPair(pair).initialize(token0, token1);

    // token0 => { token1 => pair }
    // token1 => { token0 => pair }
    getPair[token0][token1] = pair;
    getPair[token1][token0] = pair;

    allPairs.push(pair);
  }
}
