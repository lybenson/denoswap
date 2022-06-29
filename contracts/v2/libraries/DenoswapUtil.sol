//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import '../interfaces/IDenoswapPair.sol';
import './SafeMath.sol';
import '../interfaces/IDenoswapPair.sol';

// 工具库
library DenoswapUtil {
  using SafeMath for uint;

  // token 从小到大排序
  function sortTokens(address tokenA, address tokenB) internal pure returns(address token0, address token1) {
    require(tokenA != tokenB, 'DenoswapUtil: IDENTICAL_ADDRESSES');
    (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    require(token0 != address(0), 'DenoswapUtil: ZERO_ADDRESS');
  }

  // 获取配对合约地址
  function pairFor(
    address factory,
    address tokenA,
    address tokenB
  ) internal pure returns(address pair) {
    (address token0, address token1) = sortTokens(tokenA, tokenB);

    // 计算create2合约地址
    // TODO 如何计算你的
    pair = address(uint(keccak256(abi.encodePacked(
      hex'ff',
      factory,
      keccak256((abi.encodePacked(token0, token1))),
      // 配对合约的bytecode的keccak256
      hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f'
    ))));
  }

  // 获取token储备量
  function getReserves(address factory, address tokenA, address tokenB) internal returns(uint reserveA, uint reserveB) {
    (address token0,) = sortTokens(tokenA, tokenB);
    // 调用配对合约的 getReserves 方法
    (uint reserve0, uint reserve1,) = IDenoswapPair(pairFor(factory, tokenA, tokenB)).getReserves();
    (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
  }

  // 根据提供的 tokenA 的数量以及 tokenA 和 tokenB 的储备量计算需要提供的 tokenB 的数量
  function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
    require(amountA > 0, 'DenoswapUtil: INSUFFICIENT_AMOUNT');
    require(reserveA > 0 && reserveB > 0, 'DenoswapUtil: INSUFFICIENT_LIQUIDITY');

    // 提供的tokenA数量 * tokenB的储备量 / tokenA的储备量
    // reserveA / reserveB =  amountA / amountB 保证对价关系
    // amountB = amountA * reserveB / reserveA
    amountB = amountA.mul(reserveB) / reserveA;
  }

  // 配对合约中的两个 token 的储备量 reserveIn 和 reserveOut
  // 输入其中一个 token 的 amountIn 数量 , 可以获得另一个 token 的数量
  // 假设有交易对 aDai => WETH, 储备量是 2000 aDai  2 WETH
  // 此时用 1000个 aDai 去兑换 WETH, 可以兑换多少 WETH 则由该方法计算
  function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
    require(amountIn > 0, 'DenoswapUtil: INSUFFICIENT_INPUT_AMOUNT');
    require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');

    // reserveIn * reserveOut = (reserveIn + amountIn) * (reserveOut - amountOut)
    // amountOut = (amountIn * reserveOut) / (reserveIn + amountIn)
    // amountOut = (amountIn * reserveOut) * 1000 / (reserveIn + amountIn) * 1000
    // amountOut = amountIn * 1000 * reserveOut / (reserveIn * 1000 + amountIn * 1000)

    // 计算税后的输入数量 1000 * 0.997 = 997,即实际只能用997个aDai去兑换
    // 此处 乘以 997 是为了小数计算方便 amountInWithFee = 997000
    uint amountInWithFee = amountIn.mul(997);
    // 计算分子: 实际用于兑换的数量 * 储备量, 即 997000 * 2 = 1994000
    uint numerator = amountInWithFee.mul(reserveOut);
    // 计算分母: 储备量In * 1000 + 实际用于兑换的数量, 即 2000 * 1000 + 997 = 2000997
    uint denominator = reserveIn.mul(1000).add(amountInWithFee);

    // 可兑换数量 = 分子 / 分母 = 0.9965032
    amountOut = numerator / denominator;
  }

  // 同 getAmountOut
  // amountOut: 路径上最后一个 token 的数量
  // reserveIn, reserveOut: 交易对的储备量
  function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns(uint amountIn) {
    require(amountOut > 0, 'DenoswapUtil: INSUFFICIENT_OUTPUT_AMOUNT');
    require(reserveIn > 0 && reserveOut > 0, 'DenoswapUtil: INSUFFICIENT_LIQUIDITY');

    // reserveIn * reserveOut = (reserveIn + amountIn) * (reserveOut - amountOut)
    // reserveIn + amountIn = (reserveIn * reserveOut) / (reserveOut - amountOut)
    // amountIn = [(reserveIn * reserveOut) / (reserveOut - amountOut)] - reserveIn
    // amountIn = (reserveIn * amountOut) / (reserveOut - amountOut)

    uint numerator = reserveIn.mul(amountOut).mul(1000);
    uint denominator = reserveOut.sub(amountOut).mul(997);
    amountIn = (numerator / denominator).add(1);
  }

  // 获取路径上token的可交换的数量(从前往后)
  function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
    require(path.length >= 2, 'DenoswapUtil: INVALID_PATH');
    amounts = new uint[](path.length);
    amounts[0] = amountIn;

    // 遍历路径
    for (uint i; i < path.length - 1; i++) {
      // 获取配对合约的交易对token的储备量
      (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
      // 获取token可交换的数量
      // 如 100aDai => ?wETH, ?即是需要getAmountOut计算的值
      amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
    }
  }

  // 获取路径上token的可交换的数量(从后往前)
  function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
    require(path.length >= 2, 'DenoswapUtil: INVALID_PATH');
    amounts = new uint[](path.length);
    amounts[amounts.length - 1] = amountOut;

    for (uint i = path.length - 1; i > 0; i--) {
      (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
      amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
    }
  }
}
