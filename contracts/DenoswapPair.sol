// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import './interfaces/IDenoswapPair.sol';
import './interfaces/IDenoswapFactory.sol';
import './interfaces/IERC20.sol';
import './interfaces/IDenoswapERC20.sol';
import './libraries/UQ112x112.sol';
import './libraries/Math.sol';
import './DenoswapERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

contract DenoswapPair is IDenoswapPair, DenoswapERC20 {
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

  // 价格最后累计，是用于Uniswap v2所提供的价格预言机上，该数值会在每个区块的第一笔交易进行更新。
  uint public price0CumulativeLast;
  uint public price1CumulativeLast;

  // 最新的流动性k值; kLast = reserve0 * reserve1
  uint public kLast;

  uint private unlocked = 1;
  // 避免多方法同时执行
  modifier lock() {
    require(unlocked == 1, 'Locked');
    unlocked = 0;
    _;
    unlocked = 1;
  }

  constructor() public {
    // msg.sender 等于工厂合约的地址
    factory = msg.sender;
  }

  // 用于获取两个 token 在池子中的数量和最后更新的时间
  function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
    _reserve0 = reserve0;
    _reserve1 = reserve1;
    _blockTimestampLast = blockTimestampLast;
  }

  // 初始化方法，部署时由工厂合约调用一次
  function initialize(address _token0, address _token1) external {
      require(msg.sender == factory, 'sender not factory');
      token0 = _token0;
      token1 = _token1;
  }

  function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns(bool feeOn) {
    // 1. 查询工厂合约的 feeTo 收税地址
    address feeTo = IDenoswapFactory(factory).feeTo;

    feeOn = feeTo != address(0);

    uint _kLast = kLast;

    if (feeOn) {
      if (_kLast != 0) {
        uint rootK = Math.sqrt(uint(_reserve0).mul(_reserve1));
        uint rootKLast = Math.sqrt(_kLast);

        if (rootK > rootKLast) {
          uint numerator = totalSupply.mul(rootK.sub(rootKLast));
          uint denominator = rootK.mul(5).add(rootKLast);

          uint liquidity = numerator / denominator;
          if (liquidity > 0) _mint(feeTo, liquidity);
        }
      }
    } else if (_kLast != 0) {
      kLast = 0;
    }
  }

  // 输入为一个地址to, 输出为该地址所提供的流动性, 流动性也被体现成token即LP token
  // 铸币流程发生在router合约向pair合约发送代币之后。因此此次的储备量和合约的token余额是不相等的，中间的差值就是需要铸币的token金额，即amount0和amount1。
  function mint(address to) external lock returns(uint liquidity) {
    // 1. 获取池子中储备量
    (uint112 _reserve0, uint112 _reserve1,) = getReserves();

    // 2. 配对合约的地址在 token 合约内的余额
    uint balance0 = IERC20(token0).balanceOf(address(this));
    uint balance1 = IERC20(token1).balanceOf(address(this));

    // 3. 余额 - 储备量
    uint amount0 = balance0.sub(_reserve0);
    uint amount1 = balance1.sub(_reserve1);

    // 返回铸造费开关
    bool feeOn = _mintFee(_reserve0, _reserve1);
    uint _totalSupply = totalSupply;

    // 如果 totalSupply 为0， 代表是首次铸币
    // 首次铸币的流动性为 (数量0 * 数量1)的平方根
    // 非首次的流动性公式为 
    if (_totalSupply == 0) {
        // 流动性 = (数量0 * 数量1)的平方根 - 最小流动性
        // 减去最小流动性的目的是为了防止攻击
        liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
        // 在总量为0的初始状态，永久锁定最低流动性
        _mint(address(0), MINIMUM_LIQUIDITY);
    } else {
        // 否则: 流动性 = 最小值(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1)
        liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
    }

    // 确认流动性大于0
    require(liquidity > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED');
    // 铸造流动性给to地址
    _mint(to, liquidity);

    // 更新储备量
    _update(balance0, balance1, _reserve0, _reserve1);
    // 如果铸造费开关为true, k值 = 储备量0 * 储备量1
    if (feeOn) kLast = uint(reserve0).mul(reserve1);

    // 触发铸造事件
    emit Mint(msg.sender, amount0, amount1);
  }

  function burn(address to) external returns(uint amount0, uint amount1) {}

  function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external {}

  function sync() external {}
}
