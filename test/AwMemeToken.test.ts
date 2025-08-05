import { ethers } from 'hardhat';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { deployUniswapFixture } from './uniswap.fixture';
import { AwMemeToken } from '../typechain-types';
import { BigNumber } from 'ethers';

describe('AwMemeToken', function () {
  async function deployTokenFixture() {
    const {
      owner,
      otherAccount,
      weth9,
      uniswapFactory,
      nonfungiblePositionManager,
      swapRouter,
    } = await loadFixture(deployUniswapFixture);

    const AwMemeTokenFactory = await ethers.getContractFactory('AwMemeToken');
    const token = (await AwMemeTokenFactory.deploy()) as AwMemeToken;
    await token.deployed();

    await token.initialize(
      owner.address,
      swapRouter.address,
      uniswapFactory.address,
      nonfungiblePositionManager.address,
      owner.address, // taxWallet
      3000 // poolFee 0.3%
    );

    return {
      token,
      owner,
      otherAccount,
      weth9,
      uniswapFactory,
      nonfungiblePositionManager,
      swapRouter,
    };
  }

  it('Should deploy and mint initial supply', async function () {
    const { token, owner } = await loadFixture(deployTokenFixture);
    const maxSupply = await token.MAX_SUPPLY();
    await token.mint(owner.address, maxSupply);
    expect(await token.balanceOf(owner.address)).to.equal(maxSupply);
  });

  it('Should create a liquidity pool', async function () {
    const { token, owner, uniswapFactory } =
      await loadFixture(deployTokenFixture);
    const maxSupply = await token.MAX_SUPPLY();
    await token.mint(owner.address, maxSupply);

    // Price: 1 ETH = 1,000,000 AwMT. We need to calculate sqrtPriceX96 off-chain.
    // This is a placeholder value. For a real test, calculate it precisely.
    const sqrtPriceX96 = BigNumber.from('79228162514264337593543950336');
    await token.createPool(sqrtPriceX96);

    const wethAddress = await uniswapFactory.WETH9();
    const poolAddress = await uniswapFactory.getPool(
      token.address,
      wethAddress,
      3000
    );

    expect(poolAddress).to.not.equal(ethers.constants.AddressZero);
    expect(await token.uniswapPool()).to.equal(poolAddress);
  });

  it('Should allow a user to add and remove liquidity', async function () {
    const { token, owner, otherAccount, nonfungiblePositionManager } =
      await loadFixture(deployTokenFixture);

    // 1. Setup: mint tokens and create pool
    const maxSupply = await token.MAX_SUPPLY();
    await token.mint(owner.address, maxSupply);
    const sqrtPriceX96 = BigNumber.from('79228162514264337593543950336'); // 1 ETH = 1M tokens
    await token.createPool(sqrtPriceX96);

    // 2. Add Liquidity
    const tokenAmount = ethers.utils.parseUnits('1000000', 18); // 1M tokens
    const ethAmount = ethers.utils.parseEther('1'); // 1 ETH

    // User (owner) approves the token contract to spend their tokens
    await token.connect(owner).approve(token.address, tokenAmount);

    // Define a wide tick range for simplicity
    const tickLower = -887270;
    const tickUpper = 887270;

    const addLiquidityTx = await token
      .connect(owner)
      .addLiquidity(tokenAmount, tickLower, tickUpper, { value: ethAmount });

    await expect(addLiquidityTx).to.emit(token, 'AddLiquidity');

    const filter = token.filters.AddLiquidity(owner.address);
    const events = await token.queryFilter(filter);
    const tokenId = events[0].args.tokenId;

    expect(tokenId).to.be.gt(0);
    expect(await nonfungiblePositionManager.ownerOf(tokenId)).to.equal(
      owner.address
    );

    // 3. Remove Liquidity
    const liquidity = events[0].args.liquidity;
    expect(liquidity).to.be.gt(0);

    // Before calling removeLiquidity from our contract,
    // the owner of the NFT must approve our contract to manage the NFT.
    await nonfungiblePositionManager
      .connect(owner)
      .approve(token.address, tokenId);

    const removeLiquidityTx = await token
      .connect(owner)
      .removeLiquidity(tokenId, liquidity);
    await expect(removeLiquidityTx).to.emit(token, 'RemoveLiquidity');
  });
});
