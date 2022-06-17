// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

interface IDenoswapFactory {
  function createPair(address tokenA, address tokenB) external returns(address pair);
}
