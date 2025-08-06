import '@nomicfoundation/hardhat-toolbox';
import '@openzeppelin/hardhat-upgrades';
import '@nomicfoundation/hardhat-foundry';
import 'hardhat-deploy';
import { HardhatUserConfig } from 'hardhat/config';
import * as fs from 'fs';
import * as dotenv from 'dotenv';

// 根据 NODE_ENV 自动选择 .env 文件，如果不存在则回退到 .env
const envFile = `.env.${process.env.NODE_ENV || 'development'}`;
if (fs.existsSync(envFile)) {
  dotenv.config({ path: envFile });
} else {
  console.warn(`环境文件 ${envFile} 不存在，使用默认 .env`);
  dotenv.config({ path: '.env' });
}

const { SEPOLIA_RPC_URL, PRIVATE_KEY, ETHERSCAN_API_KEY } = process.env;
console.log('当前环境:', process.env.NODE_ENV || 'development');

const config: HardhatUserConfig = {
  solidity: {
      version: "0.8.28",
      settings: {
          viaIR: true,
          optimizer: {
              enabled: true,
              runs: 200,
              details: {
                  yulDetails: {
                      optimizerSteps: "u"
                  }
              },
          },
      },
  },
  networks: {
    // 本地开发网络
    hardhat: {
      chainId: 31337,
    },
    // Sepolia 测试网
    sepolia: {
      url: SEPOLIA_RPC_URL || '',
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      chainId: 11155111,
      // gasPrice: 2_000_000_000, // 2 Gwei
    },
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY || '',
  },
  namedAccounts: {
    deployer: 0,
    user1: 1,
    user2: 2,
    user3: 3,
    user4: 4,
  },
  typechain: {
    outDir: 'typechain-types',
    target: 'ethers-v6',
  },
};

export default config;
