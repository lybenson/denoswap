// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import './interfaces/IDenoswapPair.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import './libraries/UQ112x112.sol';

contract DenoswapPair is IDenoswapPair {
  using SafeMath for uint;
  using UQ112x112 for uint224;

  // 最小流动性
  uint public constant MINIMUM_LIQUIDITY = 10**3;

  bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

  // 工厂合约地址
  address public factory;

  // token地址
  address public token0;
  address public token1;

  // 储备量
  uint112 private reserve0;
  uint112 private reserve1;

  uint32 private blockTimestampLast;

  // 最新价格
  uint public price0CumulativeLast;
  uint public price1CumulativeLast;

  // 最新的流动性k值; kLast = reserve0 * reserve1
  uint public kLast;

  event Mint();
  event Burn();
  event Swap();
  event Sync();

  uint private unlocked = 1;
  // 避免多方法同时执行
  modifier lock() {
    require(unlocked == 1, 'Locked');
    unlocked = 0;
    _;
    unlocked = 1;
  }

  // 初始化方法，部署时由工厂合约调用一次
  function initialize(address _token0, address _token1) external {
      require(msg.sender == factory, 'sender not factory');
      token0 = _token0;
      token1 = _token1;
  }
}
