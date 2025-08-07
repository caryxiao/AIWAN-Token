# AIWAN Token

## 项目简介

AIWAN Token 是一个基于以太坊的可升级 Meme 代币项目，采用 ERC20 标准，集成了 Uniswap V3 流动性管理、链上税收机制和多重交易限制，旨在实现公平、可持续和高流动性的 Meme 经济生态。

## 项目架构

```
aiwan-token/
├── contracts/                # Solidity 智能合约
│   ├── AwMemeToken.sol       # 主代币合约，集成税收、流动性、限制等功能
│   ├── MemeLib.sol           # ETH/WETH 工具库
│   └── interfaces/           # 外部协议接口
│       └── uniswapV3/
│           └── IPositionManagerMinimal.sol
├── script/                   # Foundry 部署脚本
│   └── DeployAwMemeToken.sol # 主合约部署脚本
├── tests/                    # Foundry 测试
│   └── AwMemeTokenLiquidity.t.sol
├── foundry.toml              # Foundry 配置
├── remappings.txt            # 依赖重映射配置
├── package.json              # Node.js 工程配置（仅用于代码格式化等）
├── MEME_DOCUMENT.md          # 经济模型与机制说明
└── README.md                 # 项目说明文档
```

## 核心功能

### 1. 可升级 ERC20 代币

- 使用 OpenZeppelin Upgrades 实现合约可升级
- 最大供应量 10 亿，支持铸币、转账、授权等标准操作
- 代币名称：AI WAN Meme Token (AwMT)

### 2. 税收机制

- 每笔转账自动收取手续费（默认 5%），手续费进入指定钱包
- 支持动态调整手续费比例和手续费钱包
- 税收机制可有效抑制投机性交易，稳定代币价格

### 3. 交易限制

- 限制每日最大转账次数（默认 10 次）和金额（默认 10 亿）
- 防止机器人和巨鲸操纵市场
- 所有限制参数均可由合约拥有者动态调整

### 4. Uniswap V3 流动性管理

- 支持一键创建 Uniswap V3 池子
- 用户可添加/移除流动性，合约自动处理 ETH/WETH 转换
- 集成 Uniswap V3 Position NFT 管理
- 支持自定义价格范围和流动性参数

### 5. 测试与安全

- 使用 Foundry 进行主网分叉测试
- 覆盖流动性添加、移除、税收分配等核心逻辑
- 详细的错误处理和事件日志，便于链上追踪和调试

## 技术栈

- **智能合约**: Solidity 0.8.28
- **开发框架**: Foundry
- **可升级合约**: OpenZeppelin Upgrades
- **DEX 集成**: Uniswap V3
- **测试框架**: Foundry Test
- **代码质量**: ESLint, Prettier, TypeScript

## 部署与开发

### 环境准备

- Foundry (`forge`, `cast`, `anvil`)
- Node.js >= 16（仅用于代码格式化等工具）

### 安装依赖

```bash
# 安装 Foundry 依赖
forge install

# 安装 Node.js 依赖（可选，用于代码格式化）
pnpm install
```

### 配置环境变量

根目录下新建 `.env`，配置如下：

```bash
SEPOLIA_RPC_URL=你的Sepolia节点
PRIVATE_KEY=你的私钥
ETHERSCAN_API_KEY=你的Etherscan API Key
MAINNET_RPC_URL=主网节点（用于分叉测试）
```

### 编译合约

```bash
forge build
```

### 运行测试

```bash
# 运行所有测试
forge test

# 运行特定测试并显示详细日志
forge test --match-test test_AddLiquidity -vvv

# 运行测试并生成覆盖率报告
forge coverage
```

### 部署合约

```bash
# 部署到本地网络
forge script script/DeployAwMemeToken.sol --rpc-url http://localhost:8545 --broadcast

# 部署到 Sepolia 测试网
forge script script/DeployAwMemeToken.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify

# 模拟部署（不实际执行）
forge script script/DeployAwMemeToken.sol --rpc-url $SEPOLIA_RPC_URL --dry-run
```

### 验证合约

```bash
# 验证合约（部署后）
forge verify-contract <合约地址> contracts/AwMemeToken.sol:AwMemeToken --chain-id 11155111
```

## 调试与常用命令

### Foundry 命令

```bash
# 编译
forge build

# 测试
forge test
forge test --match-test <测试名> -vvv

# 部署
forge script script/DeployAwMemeToken.sol --rpc-url <RPC_URL> --broadcast

# 调用合约
cast call <合约地址> <函数签名> <参数>

# 发送交易
cast send <合约地址> <函数签名> <参数> --private-key <私钥>

# 启动本地节点
anvil
```

### 代码质量

```bash
# 代码格式化
forge fmt

# 代码检查
forge build --sizes

# 生成依赖图
forge tree
```

### Node.js 工具（可选）

```bash
# 代码格式化
pnpm format

# 代码检查
pnpm lint
pnpm typecheck
```

## 合约接口

### 主要函数

#### 管理函数

- `initialize()` - 初始化合约
- `setTaxWallet(address)` - 设置手续费钱包
- `setTxFeeRate(uint256)` - 设置转账手续费率
- `setDailyMaxTxLimit(uint256)` - 设置每日最大转账次数
- `setDailyMaxTxAmount(uint256)` - 设置每日最大转账金额
- `mint(address, uint256)` - 铸币

#### 流动性管理

- `createPool(uint160)` - 创建 Uniswap V3 池子
- `addLiquidity(uint256, int24, int24)` - 添加流动性
- `removeLiquidity(uint256, uint128)` - 移除流动性

#### 查询函数

- `taxWallet()` - 获取手续费钱包地址
- `txFeeRate()` - 获取转账手续费率
- `dailyMaxTxLimit()` - 获取每日最大转账次数
- `dailyMaxTxAmount()` - 获取每日最大转账金额
- `uniswapPool()` - 获取 Uniswap 池子地址

## 经济模型与机制说明

详细的代币经济模型、税收机制、流动性原理和交易限制策略请参考 [MEME_DOCUMENT.md](./MEME_DOCUMENT.md)。

## 安全特性

- **可升级合约**: 支持合约逻辑升级，修复潜在问题
- **权限控制**: 关键函数仅限合约拥有者调用
- **交易限制**: 防止巨鲸操纵和机器人攻击
- **税收机制**: 稳定代币价格，支持项目发展
- **流动性管理**: 自动处理 ETH/WETH 转换，降低用户操作复杂度

## 开发指南

### 添加新功能

1. 在 `contracts/` 目录下创建新的合约文件
2. 在 `tests/` 目录下编写对应的测试
3. 更新 `script/` 目录下的部署脚本（如需要）
4. 运行测试确保功能正常

### 修改现有功能

1. 由于使用可升级合约，大部分逻辑修改可通过升级实现
2. 对于存储布局的修改，需要遵循 OpenZeppelin Upgrades 的规则
3. 修改后需要更新测试用例

## 故障排除

### 常见问题

1. **编译错误**: 检查 `remappings.txt` 中的依赖路径是否正确
2. **测试失败**: 确保环境变量配置正确，特别是 RPC 节点
3. **部署失败**: 检查私钥和网络配置，确保账户有足够的 ETH

### 调试技巧

- 使用 `forge test -vvv` 查看详细的测试日志
- 使用 `cast` 命令直接与合约交互进行调试
- 查看合约事件日志了解执行流程

## 贡献指南

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开 Pull Request

## 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 参考与致谢

- [Foundry Book](https://book.getfoundry.sh/)
- [OpenZeppelin Contracts & Upgrades](https://docs.openzeppelin.com/contracts/)
- [Uniswap V3 Core & Periphery](https://docs.uniswap.org/)

## 联系方式

如有问题或建议，请通过以下方式联系：

- 提交 Issue
- 创建 Pull Request
- 发送邮件至项目维护者

---

**注意**: 这是一个实验性项目，在生产环境使用前请充分测试和审计。
