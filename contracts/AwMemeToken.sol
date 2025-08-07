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
import {console} from "forge-std/console.sol";

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
    error InvalidTick(int24 _tickLower, int24 _tickUpper); // 无效的tick
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

    function _chargeTxFeeFromContract(
        uint256 _amount
    ) internal virtual returns (uint256 finalTransferAmount, uint256 txFeeAmount) {
        // 如果手续费率为0, 则不收取
        if (txFeeRate == 0) {
            return (_amount, 0);
        }
        txFeeAmount = (_amount * txFeeRate) / 10000;
        finalTransferAmount = _amount - txFeeAmount;
        super._update(address(this), taxWallet, txFeeAmount); // 从合约转账手续费到taxWallet
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

        // 计算预估手续费（基于期望的代币数量）- 仅用于预留，不实际收取
        uint256 estimatedFee = 0;
        if (txFeeRate > 0 && _amountTokenDesired > 0) {
            estimatedFee = (_amountTokenDesired * txFeeRate) / 10000;
        }

        // 用于流动性的实际代币数量
        uint256 actualTokenAmount = _amountTokenDesired - estimatedFee;
        require(actualTokenAmount > 0, "Insufficient tokens after fee");

        // 添加流动性 - 使用扣除手续费后的代币数量
        _addLiquidity(msg.sender, actualTokenAmount, msg.value, _tickLower, _tickUpper, estimatedFee);
    }

    /**
     * @dev 添加流动性内部逻辑
     */
    function _addLiquidity(
        address _recipient,
        uint256 _amountTokenDesired,
        uint256 _amountETHDesired,
        int24 _tickLower,
        int24 _tickUpper,
        uint256 _estimatedFee
    ) internal virtual {
        _checkAddLiquidity(_amountTokenDesired, _amountETHDesired, _tickLower, _tickUpper);

        // 创建流动性
        (uint256 tokenId, uint256 liquidity, uint256 amount0, uint256 amount1) = _createLiquidityPosition(
            _recipient,
            _amountTokenDesired,
            _amountETHDesired,
            _tickLower,
            _tickUpper
        );

        // 退款和事件
        _handleLiquidityResult(
            _recipient,
            tokenId,
            liquidity,
            amount0,
            amount1,
            _amountTokenDesired,
            _amountETHDesired,
            _tickLower,
            _tickUpper,
            _estimatedFee
        );
    }

    /**
     * @dev 创建流动性头寸
     */
    function _createLiquidityPosition(
        address _recipient,
        uint256 _amountTokenDesired,
        uint256 _amountETHDesired,
        int24 _tickLower,
        int24 _tickUpper
    ) internal virtual returns (uint256 tokenId, uint256 liquidity, uint256 amount0, uint256 amount1) {
        // 获取代币0和代币1
        address token0 = IUniswapV3Pool(uniswapPool).token0();
        address token1 = IUniswapV3Pool(uniswapPool).token1();

        // 计算代币数量
        (uint256 amount0Desired, uint256 amount1Desired) = _calculateTokenAmounts(
            token0,
            _amountTokenDesired,
            _amountETHDesired
        );

        // 计算最小数量（设置为0以避免滑点问题）
        uint256 amount0Min = 0;
        uint256 amount1Min = 0;

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: uint24(poolFee),
            tickLower: _tickLower,
            tickUpper: _tickUpper,
            amount0Desired: amount0Desired,
            amount1Desired: amount1Desired,
            amount0Min: amount0Min,
            amount1Min: amount1Min,
            recipient: _recipient,
            deadline: block.timestamp + 30 minutes
        });

        (tokenId, liquidity, amount0, amount1) = nonfungiblePositionManager.mint(params);

        if (tokenId == 0) revert InvalidTokenId(tokenId);
        if (liquidity == 0) revert InvalidLiquidity(0);
    }

    /**
     * @dev 计算代币数量
     */
    function _calculateTokenAmounts(
        address token0,
        uint256 _amountTokenDesired,
        uint256 _amountETHDesired
    ) internal view returns (uint256 amount0Desired, uint256 amount1Desired) {
        if (address(this) == token0) {
            amount0Desired = _amountTokenDesired;
            amount1Desired = _amountETHDesired;
        } else {
            amount0Desired = _amountETHDesired;
            amount1Desired = _amountTokenDesired;
        }
    }

    /**
     * @dev 处理流动性结果
     */
    function _handleLiquidityResult(
        address _recipient,
        uint256 tokenId,
        uint256 liquidity,
        uint256 amount0,
        uint256 amount1,
        uint256 _amountTokenDesired,
        uint256 _amountETHDesired,
        int24 _tickLower,
        int24 _tickUpper,
        uint256 _estimatedFee
    ) internal virtual {
        // 获取代币地址
        address token0 = IUniswapV3Pool(uniswapPool).token0();
        address token1 = IUniswapV3Pool(uniswapPool).token1();

        // 手续费已经在addLiquidity函数中预先处理，这里不再重复收取

        // 退款未使用的代币
        _refundNonUsedToken(
            _recipient,
            token0,
            token1,
            amount0,
            amount1,
            _amountTokenDesired,
            _amountETHDesired,
            _estimatedFee
        );

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

    function _checkAddLiquidity(
        uint256 _amountTokenDesired,
        uint256 _amountETHDesired,
        int24 _tickLower,
        int24 _tickUpper
    ) internal virtual {
        if (uniswapPool == address(0)) revert InvalidAddress(uniswapPool);
        if (_amountTokenDesired == 0 && _amountETHDesired == 0) revert InvalidAmount(0);

        // 验证tick是否与池子的tickSpacing对齐
        int24 tickSpacing = IUniswapV3Pool(uniswapPool).tickSpacing();
        if (_tickLower % tickSpacing != 0 || _tickUpper % tickSpacing != 0 || _tickLower >= _tickUpper)
            revert InvalidTick(_tickLower, _tickUpper);

        // 授权非同质化代币管理器花费代币
        if (_amountTokenDesired > 0) {
            IERC20(address(this)).approve(address(nonfungiblePositionManager), _amountTokenDesired);
        }

        // 将ETH转换为WETH并授权非同质化代币管理器花费WETH
        if (_amountETHDesired > 0) {
            // 获取WETH地址
            address wethAddress = IPeripheryImmutableState(address(uniswapRouter)).WETH9();
            // 将ETH转换为WETH
            MemeLib.wrapETH(_amountETHDesired, wethAddress);
            IERC20(wethAddress).approve(address(nonfungiblePositionManager), _amountETHDesired);
        }
    }

    function _refundNonUsedToken(
        address _recipient,
        address _token0,
        address _token1,
        uint256 _amount0,
        uint256 _amount1,
        uint256 _amountTokenDesired,
        uint256 _amountETHDesired,
        uint256 _estimatedFee
    ) internal virtual {
        // 退还未使用的代币
        if (_amountTokenDesired > 0) {
            // 计算实际收到的代币数量
            uint256 amountTokenActual = (address(this) == _token0) ? _amount0 : _amount1;

            // 基于实际使用的代币数量计算并收取手续费
            uint256 actualFeeAmount = 0;
            if (amountTokenActual > 0 && txFeeRate > 0) {
                actualFeeAmount = (amountTokenActual * txFeeRate) / 10000;
                // 收取实际手续费
                _transfer(address(this), taxWallet, actualFeeAmount);
            }

            // 计算未使用的代币数量：用户流动性的总token + 根据总额预估的最大手续费额度 - 实际使用 - 实际手续费
            uint256 unusedTokens = _amountTokenDesired + _estimatedFee - amountTokenActual - actualFeeAmount;

            if (unusedTokens > 0) {
                // 检查合约是否有足够的余额进行退款
                uint256 contractBalance = balanceOf(address(this));
                if (contractBalance >= unusedTokens) {
                    // 从合约余额中退还给用户
                    _transfer(address(this), _recipient, unusedTokens);
                }
            }
        }

        // 退还未使用的ETH
        if (_amountETHDesired > 0) {
            uint256 amountETHActual = (address(this) == _token0) ? _amount1 : _amount0;
            address wethAddress = (address(this) == _token0) ? _token1 : _token0;

            if (amountETHActual < _amountETHDesired) {
                // 将WETH转换为ETH
                uint256 refundETH = _amountETHDesired - amountETHActual;

                MemeLib.unwrapWETH(refundETH, wethAddress);
            }
        }

        // 将剩余的ETH余额转回接收者
        if (address(this).balance > 0) {
            payable(_recipient).transfer(address(this).balance);
        }
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

        // 收集代币到合约地址，以便处理WETH转换
        (uint256 amount0, uint256 amount1) = nonfungiblePositionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: _tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        // 获取代币地址
        address token0 = IUniswapV3Pool(uniswapPool).token0();
        address token1 = IUniswapV3Pool(uniswapPool).token1();
        address wethAddress = IPeripheryImmutableState(address(uniswapRouter)).WETH9();

        // 处理token0
        if (token0 == wethAddress && amount0 > 0) {
            // 如果token0是WETH，转换为ETH并发送给用户
            MemeLib.unwrapWETH(amount0, wethAddress);
            payable(_recipient).transfer(amount0);
        } else if (amount0 > 0) {
            // 如果token0是其他代币，直接转移给用户
            IERC20(token0).transfer(_recipient, amount0);
        }

        // 处理token1
        if (token1 == wethAddress && amount1 > 0) {
            // 如果token1是WETH，转换为ETH并发送给用户
            MemeLib.unwrapWETH(amount1, wethAddress);
            payable(_recipient).transfer(amount1);
        } else if (amount1 > 0) {
            // 如果token1是其他代币，直接转移给用户
            IERC20(token1).transfer(_recipient, amount1);
        }

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

    /**
     * @dev Uniswap V3 铸币回调函数
     * @param amount0Owed 需要支付给池子的 token0 数量
     * @param amount1Owed 需要支付给池子的 token1 数量
     */
    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata /* data */) external {
        // 验证调用者是否是我们的池子
        require(msg.sender == uniswapPool, "Invalid caller");

        // 获取代币地址
        address token0 = IUniswapV3Pool(uniswapPool).token0();
        address token1 = IUniswapV3Pool(uniswapPool).token1();

        // 支付 token0 - 直接从合约转移
        if (amount0Owed > 0) {
            if (token0 == address(this)) {
                // 如果是本合约代币，使用内部转移
                _transfer(address(this), msg.sender, amount0Owed);
            } else {
                // 如果是其他代币（如WETH），使用标准转移
                IERC20(token0).transfer(msg.sender, amount0Owed);
            }
        }

        // 支付 token1 - 直接从合约转移
        if (amount1Owed > 0) {
            if (token1 == address(this)) {
                // 如果是本合约代币，使用内部转移
                _transfer(address(this), msg.sender, amount1Owed);
            } else {
                // 如果是其他代币（如WETH），使用标准转移
                IERC20(token1).transfer(msg.sender, amount1Owed);
            }
        }
    }

    /**
     * @dev 接收ETH的函数，用于WETH unwrap操作
     */
    receive() external payable {
        // 允许合约接收ETH，主要用于WETH unwrap
    }
}
