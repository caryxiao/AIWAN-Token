import { ethers } from 'hardhat';
import {
  IUniswapV3Factory,
  INonfungiblePositionManager,
  ISwapRouter,
  IWETH9,
} from '../typechain-types';
import WETH9 from '../artifacts/@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.json';

export async function deployUniswapFixture() {
  const [owner, otherAccount] = await ethers.getSigners();

  // Deploy WETH9
  const Weth9 = await ethers.getContractFactory('WETH9');
  const weth9 = (await Weth9.deploy()) as IWETH9;
  await weth9.deployed();

  // Deploy UniswapV3Factory
  const Factory = await ethers.getContractFactory('UniswapV3Factory');
  const factory = await Factory.deploy();
  await factory.deployed();
  const uniswapFactory = (await ethers.getContractAt(
    'IUniswapV3Factory',
    factory.address
  )) as IUniswapV3Factory;

  // Deploy SwapRouter
  const SwapRouter = await ethers.getContractFactory('SwapRouter');
  const swapRouter = (await SwapRouter.deploy(
    factory.address,
    weth9.address
  )) as ISwapRouter;
  await swapRouter.deployed();

  // Deploy NonfungiblePositionManager
  const NftPositionManager = await ethers.getContractFactory(
    'NonfungiblePositionManager'
  );
  const nonfungiblePositionManager = (await NftPositionManager.deploy(
    factory.address,
    weth9.address,
    ethers.constants.AddressZero // This would be the token descriptor in a real deployment
  )) as INonfungiblePositionManager;
  await nonfungiblePositionManager.deployed();

  return {
    owner,
    otherAccount,
    weth9,
    uniswapFactory,
    nonfungiblePositionManager,
    swapRouter,
  };
}
