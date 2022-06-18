// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import './interfaces/IDenoswapPair.sol';

contract DenoswapPair is IDenoswapPair {
    // 工厂合约地址
    address public factory;
    // token0地址
    address public token0;
    // token1地址
    address public token1;

  // 初始化方法，部署时由工厂合约调用一次
  function initialize(address _token0, address _token1) external {
      require(msg.sender == factory, 'sender not factory');
      token0 = _token0;
      token1 = _token1;
  }
}
