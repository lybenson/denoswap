// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import './libraries/DenoswapUtil.sol';
import './libraries/TransferHelper.sol';
import './interfaces/IDenoswapPair.sol';
import './interfaces/IDenoswapFactory.sol';

contract DenoswapRoute {
  address public immutable factory;
  address public immutable WETH;

  modifier ensure(uint deadline) {
    require(deadline >= block.timestamp, 'DenoswapRoute expired');
    _;
  }

  constructor(address _factory, address _WETH) public {
    factory = _factory;
    WETH = _WETH;
  }

  // 添加流动性
  function addLiquidity(
    address tokenA,
    address tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline
  ) external virtual ensure(deadline) returns (uint amountA, uint amountB, uint liquidity){
    // 计算提供流动性需要的token的数量
    (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);

    // 获取配对合约地址
    address pair = DenoswapUtil.pairFor(factory, tokenA, tokenB);

    // 将token转入配对合约的地址
    TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
    TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);

    // 调用配对合约的mint方法
    liquidity = IDenoswapPair(pair).mint(to);
  }

  function _addLiquidity(
    address tokenA,
    address tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin
  ) internal virtual returns (uint amountA, uint amountB) {
    if (IDenoswapFactory(factory).getPair(tokenA, tokenB) == address(0)) {
      IDenoswapFactory(factory).createPair(tokenA, tokenB);
    }
    // 获取流动池中token的数量
    (uint reserveA, uint reserveB) = DenoswapUtil.getReserves(factory, tokenA, tokenB);

    // 首次提供流动性
    if (reserveA == 0 && reserveB == 0) {
      (amountA, amountB) = (amountADesired, amountBDesired);
    } else {
      // 计算tokenB需要提供的数量
      uint amountBOptimal = DenoswapUtil.quote(amountADesired, reserveA, reserveB);

      if (amountBOptimal <= amountBDesired) {
        require(amountBOptimal >= amountBMin, 'DenoswapRoute: INSUFFICIENT_B_AMOUNT');
        (amountA, amountB) = (amountADesired, amountBOptimal);
      } else {
        uint amountAOptimal = DenoswapUtil.quote(amountBDesired, reserveB, reserveA);
        assert(amountAOptimal <= amountADesired);
        require(amountAOptimal >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
        (amountA, amountB) = (amountAOptimal, amountBDesired);
      }
    }
  }
}
