// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

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
    (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);

    // 获取配对合约地址
    address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);

    // 
    TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
    TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
    liquidity = IUniswapV2Pair(pair).mint(to);
  }

  function _addLiquidity(
    address tokenA,
    address tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin
  ) internal virtual returns (uint amountA, uint amountB) {
    
  }
}
