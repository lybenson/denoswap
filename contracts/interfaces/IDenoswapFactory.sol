// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

interface IDenoswapFactory {
  function createPair(address tokenA, address tokenB) external returns(address pair);
}
