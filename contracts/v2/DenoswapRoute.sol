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
