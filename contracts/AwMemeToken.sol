// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IPositionManagerMinimal as INonfungiblePositionManager} from "./interfaces/uniswapV3/IPositionManagerMinimal.sol";
import {IPeripheryImmutableState} from "@uniswap/v3-periphery/contracts/interfaces/IPeripheryImmutableState.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {MemeLib} from "./MemeLib.sol";

contract AwMemeToken is Initializable, ERC20Upgradeable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 public constant MAX_SUPPLY = 1_000_000_000; // 总发行量， 总计10亿
    address public taxWallet; // 手续费钱包
    uint256 public txFeeRate; // 5%, 10000 = 100%, 转账手续费
    uint256 public dailyMaxTxLimit; // 每日最大转账次数
    uint256 public dailyMaxTxAmount; // 每日最大转账金额, 10亿

    mapping(address user => uint256) public dailyTxCount; // 用户每日转账次数
    mapping(address user => uint256) public dailyTxAmount; // 用户每日转账金额
    mapping(address user => uint256) public lastTxDay; // 用户最后一次转账天数

    //uniswap V3
    ISwapRouter public uniswapRouter; // uniswap V3 路由器
    IUniswapV3Factory public uniswapFactory; // uniswap V3 工厂
    INonfungiblePositionManager public nonfungiblePositionManager; // 非同质化代币管理器
    address public uniswapPool; // uniswap V3 池子
    uint256 public poolFee; // 池子手续费, 3000 = 0.3%, 1_000_000 = 100%

    // 错误
    error InvalidAddress(address _address); // 无效的地址
    error InvalidTxFeeRate(uint256 _txFeeRate); // 无效的转账手续费
    error InvalidDailyTxLimit(uint256 _dailyMaxTxLimit); // 无效的每日最大转账次数
    error InvalidDailyTxAmount(uint256 _dailyMaxTxAmount); // 无效的每日最大转账金额
    error DailyTxLimitExceeded(uint256 _dailyMaxTxLimit); // 每日最大转账次数超出
    error DailyTxAmountExceeded(uint256 _dailyMaxTxAmount); // 每日最大转账金额超出
    error InvalidTokenId(uint256 _tokenId); // 无效的代币ID
    error InvalidLiquidity(uint256 _liquidity); // 无效的流动性
    error InvalidAmount(uint256 _amount); // 无效的金额
    error InvalidRangePct(uint256 _rangePct); // 无效的范围百分比
    error InvalidTick(int24 _tick); // 无效的tick
    error InvalidTickLower(int24 _tickLower); // 无效的tickLower
    error InvalidTickUpper(int24 _tickUpper); // 无效的tickUpper
    error InvalidTickRange(int24 _tickLower, int24 _tickUpper); // 无效的tick范围
    error InvalidDeadline(uint256 _deadline); // 无效的deadline
    error InsufficientBalance(address _user, uint256 _amount); // 余额不足
    error PoolAddressExists(); // 池子地址已存在
    error CallerIsNotOwnerOfToken(uint256 _tokenId, address _caller); // 调用者不是流动性代币的拥有者

    event AddLiquidity(
        address indexed user,
        uint256 amountTokenDesired,
        uint256 amountETHDesired,
        int24 tickLower,
        int24 tickUpper,
        uint256 tokenId,
        uint256 liquidity
    );

    event RemoveLiquidity(address indexed user, uint256 tokenId, uint256 liquidity, uint256 amount0, uint256 amount1);

    /**
     * @dev 初始化合约
     * @param _initialOwner 初始所有者
     * @param _uniswapRouter uniswap V3 路由器
     * @param _uniswapFactory uniswap V3 工厂
     * @param _nonfungiblePositionManager 非同质化代币管理器
     * @param _taxWallet 手续费钱包
     * @param _poolFee 池子手续费
     */
    function initialize(
        address _initialOwner,
        address _uniswapRouter,
        address _uniswapFactory,
        address _nonfungiblePositionManager,
        address _taxWallet,
        uint256 _poolFee
    ) public initializer {
        if (_uniswapRouter == address(0) || _uniswapFactory == address(0) || _nonfungiblePositionManager == address(0))
            revert InvalidAddress(_uniswapRouter);
        __AwMemeToken_init(_initialOwner);
        uniswapRouter = ISwapRouter(_uniswapRouter);
        uniswapFactory = IUniswapV3Factory(_uniswapFactory);
        nonfungiblePositionManager = INonfungiblePositionManager(_nonfungiblePositionManager);
        taxWallet = _taxWallet;
        poolFee = _poolFee;
        txFeeRate = 500;
        dailyMaxTxLimit = 10;
        dailyMaxTxAmount = 1_000_000_000;
    }

    /**
     * @dev 初始化
     * @param _initialOwner 初始所有者
     */
    function __AwMemeToken_init(address _initialOwner) internal onlyInitializing {
        __ERC20_init("AI WAN Meme Token", "AwMT");
        __Ownable_init(_initialOwner);
    }

    /**
     * @dev 设置手续费钱包
     * @param _taxWallet 手续费钱包
     */
    function setTaxWallet(address _taxWallet) external virtual onlyOwner {
        if (_taxWallet == address(0)) revert InvalidAddress(_taxWallet);
        taxWallet = _taxWallet;
    }

    /**
     * @dev 设置转账手续费
     * @param _txFeeRate 转账手续费
     */
    function setTxFeeRate(uint256 _txFeeRate) external virtual onlyOwner {
        if (_txFeeRate > 10000) revert InvalidTxFeeRate(_txFeeRate);
        txFeeRate = _txFeeRate;
    }

    /**
     * @dev 设置每日最大转账次数
     * @param _dailyMaxTxLimit 每日最大转账次数
     */
    function setDailyMaxTxLimit(uint256 _dailyMaxTxLimit) external virtual onlyOwner {
        if (_dailyMaxTxLimit == 0) revert InvalidDailyTxLimit(_dailyMaxTxLimit);
        if (_dailyMaxTxLimit > 100) revert InvalidDailyTxLimit(_dailyMaxTxLimit);
        dailyMaxTxLimit = _dailyMaxTxLimit;
    }

    /**
     * @dev 设置每日最大转账金额
     * @param _dailyMaxTxAmount 每日最大转账金额
     */
    function setDailyMaxTxAmount(uint256 _dailyMaxTxAmount) external virtual onlyOwner {
        if (_dailyMaxTxAmount == 0) revert InvalidDailyTxAmount(_dailyMaxTxAmount);
        if (_dailyMaxTxAmount > MAX_SUPPLY) revert InvalidDailyTxAmount(_dailyMaxTxAmount);
        dailyMaxTxAmount = _dailyMaxTxAmount;
    }

    /**
     * @dev 铸币
     * @param _to 接收者
     * @param _amount 铸币数量
     */
    function mint(address _to, uint256 _amount) external virtual onlyOwner {
        if (_to == address(0)) revert InvalidAddress(_to);
        if (_amount == 0) revert InvalidAmount(_amount);
        if (_amount + totalSupply() > MAX_SUPPLY) revert InvalidAmount(_amount);
        _mint(_to, _amount);
    }

    /**
     * @dev 创建池子
     * @param _sqrtPriceX96 sqrtPriceX96值
     */
    function createPool(uint160 _sqrtPriceX96) external virtual onlyOwner {
        if (uniswapPool != address(0)) revert PoolAddressExists();
        if (_sqrtPriceX96 == 0) revert InvalidAmount(0);
        // weth地址获取
        address weth = IPeripheryImmutableState(address(uniswapRouter)).WETH9();
        // 创建池子
        address newPoolAddress = uniswapFactory.createPool(address(this), weth, uint24(poolFee));
        uniswapPool = newPoolAddress;
        //初始化池子
        IUniswapV3Pool(newPoolAddress).initialize(_sqrtPriceX96);
    }

    /**
     * @dev 检查转账限制
     * @param _user 用户
     * @param _amount 转账金额
     */
    function _checkTxLimit(address _user, uint256 _amount) internal {
        if (_user == owner() || _user == taxWallet || _user == address(this)) {
            return;
        }

        uint256 currentDay = block.timestamp / 1 days;
        if (lastTxDay[_user] != currentDay) {
            dailyTxCount[_user] = 0; // 重置每日转账次数
            dailyTxAmount[_user] = 0; // 重置每日转账金额
            lastTxDay[_user] = currentDay; // 更新最后一次转账天数
        }

        if (dailyTxCount[_user] + 1 > dailyMaxTxLimit) revert DailyTxLimitExceeded(dailyMaxTxLimit); // 检查每日转账次数是否超出
        if (dailyTxAmount[_user] + _amount > dailyMaxTxAmount) revert DailyTxAmountExceeded(dailyMaxTxAmount); // 检查每日转账金额是否超出

        dailyTxCount[_user]++; // 增加每日转账次数
        dailyTxAmount[_user] += _amount; // 增加每日转账金额
    }

    /**
     * @dev 转账
     * @param from 发送者
     * @param to 接收者
     * @param amount 转账金额
     */
    function _update(address from, address to, uint256 amount) internal virtual override {
        _checkTxLimit(from, amount); // 检查转账限制

        // 只有流动性池子交易的时候收取手续费，其他情况不收取手续费
        if (from == uniswapPool || to == uniswapPool) {
            uint256 txFeeAmount = (amount * txFeeRate) / 10000;
            uint256 finalTransferAmount = amount - txFeeAmount;
            if (txFeeAmount > 0) {
                super._update(from, taxWallet, txFeeAmount); // 转账手续费
            }
            super._update(from, to, finalTransferAmount); // 转账
        } else {
            super._update(from, to, amount); // 转账
        }
    }

    /**
     * @dev 添加流动性外部可调用
     * @param _amountTokenDesired 代币数量
     * @param _tickLower 下限tick
     * @param _tickUpper 上限tick
     */
    function addLiquidity(uint256 _amountTokenDesired, int24 _tickLower, int24 _tickUpper) external payable virtual {
        // 从用户地址拉取代币到合约
        if (_amountTokenDesired > 0) {
            IERC20(address(this)).transferFrom(msg.sender, address(this), _amountTokenDesired);
        }

        // 添加流动性
        _addLiquidity(msg.sender, _amountTokenDesired, msg.value, _tickLower, _tickUpper);
    }

    /**
     * @dev 添加流动性内部逻辑
     */
    function _addLiquidity(
        address _recipient,
        uint256 _amountTokenDesired,
        uint256 _amountETHDesired,
        int24 _tickLower,
        int24 _tickUpper
    ) internal virtual {
        if (uniswapPool == address(0)) revert InvalidAddress(uniswapPool);
        if (_amountTokenDesired == 0 && _amountETHDesired == 0) revert InvalidAmount(0);

        // 验证tick是否与池子的tickSpacing对齐
        int24 tickSpacing = IUniswapV3Pool(uniswapPool).tickSpacing();
        if (_tickLower % tickSpacing != 0) revert InvalidTick(_tickLower);
        if (_tickUpper % tickSpacing != 0) revert InvalidTick(_tickUpper);
        if (_tickLower >= _tickUpper) revert InvalidTickRange(_tickLower, _tickUpper);

        // weth地址获取
        address wethAddress = IPeripheryImmutableState(address(uniswapRouter)).WETH9();

        // 授权非同质化代币管理器花费代币
        if (_amountTokenDesired > 0) {
            IERC20(address(this)).approve(address(nonfungiblePositionManager), _amountTokenDesired);
        }

        // 将ETH转换为WETH并授权非同质化代币管理器花费WETH
        if (_amountETHDesired > 0) {
            // 将ETH转换为WETH
            MemeLib.wrapETH(_amountETHDesired, wethAddress);
            IERC20(wethAddress).approve(address(nonfungiblePositionManager), _amountETHDesired);
        }

        // 获取代币0和代币1
        address token0 = IUniswapV3Pool(uniswapPool).token0();
        address token1 = IUniswapV3Pool(uniswapPool).token1();
        // 获取代币0和代币1的数量
        uint256 amount0Desired;
        uint256 amount1Desired;

        // 如果代币是token0，则amount0Desired为代币数量，amount1Desired为ETH数量
        // 如果代币是token1，则amount0Desired为ETH数量，amount1Desired为代币数量
        if (address(this) == token0) {
            amount0Desired = _amountTokenDesired;
            amount1Desired = _amountETHDesired;
        } else {
            amount0Desired = _amountETHDesired;
            amount1Desired = _amountTokenDesired;
        }

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: uint24(poolFee),
            tickLower: _tickLower,
            tickUpper: _tickUpper,
            amount0Desired: amount0Desired,
            amount1Desired: amount1Desired,
            amount0Min: 0,
            amount1Min: 0,
            recipient: _recipient, // 代币持有者是添加流动性的用户
            deadline: block.timestamp + 30 minutes
        });

        (uint256 tokenId, uint256 liquidity, uint256 amount0, uint256 amount1) = nonfungiblePositionManager.mint(
            params
        );

        if (tokenId == 0) revert InvalidTokenId(tokenId);
        if (liquidity == 0) revert InvalidLiquidity(0);

        // 退还未使用的代币
        if (_amountTokenDesired > 0) {
            uint256 amountTokenActual = (address(this) == token0) ? amount0 : amount1;
            if (amountTokenActual < _amountTokenDesired) {
                IERC20(address(this)).transfer(_recipient, _amountTokenDesired - amountTokenActual);
            }
        }

        // 退还未使用的ETH
        if (_amountETHDesired > 0) {
            uint256 amountETHActual = (address(this) == token0) ? amount1 : amount0;
            if (amountETHActual < _amountETHDesired) {
                // 将WETH转换为ETH
                MemeLib.unwrapWETH(_amountETHDesired - amountETHActual, wethAddress);
            }
        }

        // 将剩余的ETH余额转回接收者
        if (address(this).balance > 0) {
            payable(_recipient).transfer(address(this).balance);
        }

        // 添加流动性事件
        emit AddLiquidity(
            _recipient,
            _amountTokenDesired,
            _amountETHDesired,
            _tickLower,
            _tickUpper,
            tokenId,
            liquidity
        );
    }

    /**
     * @dev 移除流动性外部可调用
     * @param _tokenId 代币ID
     * @param _liquidity 流动性
     */
    function removeLiquidity(uint256 _tokenId, uint128 _liquidity) external virtual {
        // 检查调用者是否是流动性代币的拥有者
        if (nonfungiblePositionManager.ownerOf(_tokenId) != msg.sender) {
            revert CallerIsNotOwnerOfToken(_tokenId, msg.sender);
        }

        _removeLiquidity(msg.sender, _tokenId, _liquidity);
    }

    function _removeLiquidity(address _recipient, uint256 _tokenId, uint128 _liquidity) internal virtual {
        // 减少流动性
        nonfungiblePositionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: _tokenId,
                liquidity: _liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );

        // 收集代币
        (uint256 amount0, uint256 amount1) = nonfungiblePositionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: _tokenId,
                recipient: _recipient,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        // 移除流动性事件
        emit RemoveLiquidity(_recipient, _tokenId, _liquidity, amount0, amount1);
    }

    /**
     * @dev 授权升级
     * @param newImplementation 新实现
     */
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        if (newImplementation == address(0)) revert InvalidAddress(newImplementation);
    }
}
