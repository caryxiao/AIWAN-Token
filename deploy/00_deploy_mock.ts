import { HardhatRuntimeEnvironment } from 'hardhat/types';

const deployMock = async (hre: HardhatRuntimeEnvironment) => {
  const { ethers } = hre;

  const [deployerSigner] = await ethers.getSigners();
};

export default deployMock;
deployMock.tags = ['Mock'];
