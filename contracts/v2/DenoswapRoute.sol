// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import './libraries/DenoswapUtil.sol';
import './libraries/TransferHelper.sol';
import './interfaces/IDenoswapPair.sol';
import './interfaces/IDenoswapFactory.sol';
import './interfaces/IWETH.sol';

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

    // 调用配对合约的mint方法, to是铸造的 lp token 给予的地址
    liquidity = IDenoswapPair(pair).mint(to);
  }

  // 添加ETH交易对流动性
  function addLiquidityETH(
    address token,
    uint amountTokenDesired,
    uint amountTokenMin,
    uint amountETHMin,
    address to,
    uint deadline
  ) external virtual payable ensure(deadline) returns(uint amountToken, uint amountETH, uint liquidity) {
    (amountToken, amountETH) = _addLiquidity(
      token,
      WETH,
      amountTokenDesired,
      msg.value,
      amountTokenMin,
      amountETHMin
    );
    address pair = DenoswapUtil.pairFor(factory, token, WETH);

    // 发送 token 到配对合约账户
    TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);

    // 存入 eth 到 WETH
    IWETH(WETH).deposit{value: amountETH}();

    // 将 WETH 存入配对合约地址
    assert(IWETH(WETH).transfer(pair, amountETH));

    // 铸造 lp token
    liquidity = IDenoswapPair(pair).mint(to);

    if (msg.value > amountETH) {
      TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }
  }

  function _addLiquidity(
    address tokenA,
    address tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin
  ) internal virtual returns (uint amountA, uint amountB) {
    // 判断配对合约是否存在
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
      
      // tokenB 输入数量 > 应提供的数量, 就直接将使用应提供的数量
      if (amountBOptimal <= amountBDesired) {
        require(amountBOptimal >= amountBMin, 'DenoswapRoute: INSUFFICIENT_B_AMOUNT');
        (amountA, amountB) = (amountADesired, amountBOptimal);
      } else {
        // tokenB的输入数量 < 应提供的数量, 则不改变 tokenB 的输入数量,重新计算 tokenA 应提供的数量
        uint amountAOptimal = DenoswapUtil.quote(amountBDesired, reserveB, reserveA);
        assert(amountAOptimal <= amountADesired);
        require(amountAOptimal >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
        (amountA, amountB) = (amountAOptimal, amountBDesired);
      }
    }
  }

  // 移除流动性
  function removeLiquidity(
    address tokenA,
    address tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline
  ) public virtual ensure(deadline) returns (uint amountA, uint amountB) {
    // 获取配对合约地址
    address pair = DenoswapUtil.pairFor(factory, tokenA, tokenB);
    // 将lp token 从用户地址发送到配对合约地址
    IDenoswapPair(pair).transferFrom(msg.sender, pair, liquidity);
    // 配对合约销毁 lp token, 并将配对池中的token发送到to地址
    (uint amount0, uint amount1) = IDenoswapPair(pair).burn(to);

    (address token0,) = DenoswapUtil.sortTokens(tokenA, tokenB);
    (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);

    require(amountA >= amountAMin, 'DenoswapRoute: INSUFFICIENT_A_AMOUNT');
    require(amountB >= amountBMin, 'DenoswapRoute: INSUFFICIENT_B_AMOUNT');
  }

  // 移除ETH流动性
  function removeLiquidityETH(
    address token,
    uint liquidity,
    uint amountTokenMin,
    uint amountETHMin,
    address to,
    uint deadline
  ) public virtual ensure(deadline) returns (uint amountToken, uint amountETH) {
    (amountToken, amountETH) = removeLiquidity(
        token,
        WETH,
        liquidity,
        amountTokenMin,
        amountETHMin,
        address(this),
        deadline
    );
    // 将token发送到 to 地址
    TransferHelper.safeTransfer(token, to, amountToken);
    // 从WERTH取出ETH
    IWETH(WETH).withdraw(amountETH);
    // 将ETH发送到 to 地址
    TransferHelper.safeTransferETH(to, amountETH);
  }

  // 带签名的移除流动性
  function removeLiquidityWithPermit(
      address tokenA,
      address tokenB,
      uint liquidity,
      uint amountAMin,
      uint amountBMin,
      address to,
      uint deadline,
      bool approveMax, uint8 v, bytes32 r, bytes32 s
  ) external virtual returns (uint amountA, uint amountB) {
    // 获取 pair 合约地址
    address pair = DenoswapUtil.pairFor(factory, tokenA, tokenB);

    // 如果全部批准,value 值为最大的 uint256, 否则等于流动性
    uint value = approveMax ? type(uint).max : liquidity;
    // 调用pair合约的许可方法, 批准 address(this) 可以操作 msg.sender 的token(避免两步交易都交gas)
    IDenoswapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);

    // 移除流动性
    (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
  }
  function removeLiquidityETHWithPermit(
    address token,
    uint liquidity,
    uint amountTokenMin,
    uint amountETHMin,
    address to,
    uint deadline,
    bool approveMax, uint8 v, bytes32 r, bytes32 s
  ) external virtual returns (uint amountToken, uint amountETH) {
    address pair = DenoswapUtil.pairFor(factory, token, WETH);
    uint value = approveMax ? type(uint).max : liquidity;
    IDenoswapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
    (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
  }

  // token交换方法
  // amounts 表示交换token的数量
  // path 表示交换经历过的token的地址
  // 如 aDai => WETH => WBTC => EOS
  // 则path = [address(aDai), address(WETH), address(WBTC), address(EOS)]
  function _swap(
    uint[] memory amounts,
    address[] memory path,
    address _to
  ) internal virtual {
    for (uint i; i < path.length - 1; i++) {
      // 获取token
      (address input, address output) = (path[i], path[i + 1]);
      (address token0,) = DenoswapUtil.sortTokens(input, output);

      // 获取输出数量 => (输出金额, 0) 或 (0, 输出金额)
      uint amountOut = amounts[i + 1];
      (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));

      // 获取下一个配对合约地址
      address to = i < path.length - 2 ? DenoswapUtil.pairFor(factory, output, path[i + 2]) : _to;

      // 调用swap方法进行交换
      IDenoswapPair(DenoswapUtil.pairFor(factory, input, output)).swap(amount0Out, amount1Out, to, new bytes(0));
    }
  }

  // 根据一定数量的token交换尽可能多的token(根据输入求输出)
  // 如 aDai => WETH => WBTC => EOS
  // 用 1 个aDai作为输入数额，此时 amountIn = 1
  // 经过计算后返回交换的路径上的token的最大数量
  function swapExactTokensForTokens(
    uint amountIn,
    uint amountOutMin,
    address[] calldata path,
    address to,
    uint deadline
  ) external virtual ensure(deadline) returns(uint[] memory amounts) {
    // 获取路径上 token 的可交换的数量
    amounts = DenoswapUtil.getAmountsOut(factory, amountIn, path);
    require(amounts[amounts.length - 1] >= amountOutMin, 'DenoswapRoute: INSUFFICIENT_OUTPUT_AMOUNT');

    // 将第一个 token 从用户地址转移到 第一个配对合约地址
    TransferHelper.safeTransferFrom(path[0], msg.sender, DenoswapUtil.pairFor(factory, path[0], path[1]), amounts[0]);

    _swap(amounts, path, to);
  }

  // 根据输出求输入
  // 如 aDai => WETH => WBTC => EOS
  // 根据 EOS 的数量去计算前面 token 的数量
  function swapTokensForExactTokens(
    uint amountOut,
    uint amountInMax,
    address[] calldata path,
    address to,
    uint deadline
  ) external virtual ensure(deadline) returns(uint[] memory amounts) {
    // 计算路径上 token 的数量
    amounts = DenoswapUtil.getAmountsIn(factory, amountOut, path);
    require(amounts[0] <= amountInMax, 'DenoswapRoute: EXCESSIVE_INPUT_AMOUNT');

    // 将第一个 token 从用户地址转移到 第一个配对合约地址
    TransferHelper.safeTransferFrom(
      path[0],
      msg.sender,
      DenoswapUtil.pairFor(factory, path[0], path[1]),
      amounts[0]
    );
    _swap(amounts, path, to);
  }
}
