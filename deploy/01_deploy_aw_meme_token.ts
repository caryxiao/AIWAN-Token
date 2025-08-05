import { HardhatRuntimeEnvironment } from 'hardhat/types';

const deployAwMemeToken = async (hre: HardhatRuntimeEnvironment) => {
  const { ethers, upgrades, deployments } = hre;
  const { log, save } = deployments;

  const [deployerSigner] = await ethers.getSigners();

  log('部署者:', deployerSigner.address);

  const AwMemeToken = await ethers.getContractFactory(
    'AwMemeToken',
    deployerSigner
  );
  const awMemeToken = await upgrades.deployProxy(
    AwMemeToken,
    [deployerSigner.address],
    {
      kind: 'uups',
      initializer: 'initialize',
    }
  );

  await awMemeToken.waitForDeployment();

  const awMemeTokenProxyAddress = await awMemeToken.getAddress();

  log('AwMemeToken 部署成功:', awMemeTokenProxyAddress);
  save('AwMemeToken', {
    address: awMemeTokenProxyAddress,
    abi: JSON.parse(AwMemeToken.interface.formatJson()),
  });
};

export default deployAwMemeToken;
deployAwMemeToken.tags = ['AwMemeToken'];
