import 'dotenv/config';
import hardhat from 'hardhat';

const { ethers, network } = hardhat;

async function main() {
  const [deployer] = await ethers.getSigners();
  const backendAddress = (process.env.BACKEND_ADDRESS || deployer.address).toLowerCase();

  console.log(`[deploy-manager] deployer=${deployer.address}`);
  console.log(`[deploy-manager] backendAddress=${backendAddress}`);

  const factory = await ethers.getContractFactory('TontineManager');
  const contract = await factory.deploy(backendAddress);
  await contract.waitForDeployment();

  const address = await contract.getAddress();
  const tx = contract.deploymentTransaction();

  console.log(`[deploy-manager] TontineManager deployed at: ${address}`);
  console.log(`[deploy-manager] txHash: ${tx?.hash || 'n/a'}`);
  console.log(JSON.stringify({
    contractName: 'TontineManager',
    address,
    backendAddress,
    transactionHash: tx?.hash || null,
    network: network.name
  }));
}

main().catch((error) => {
  console.error('[deploy-manager] fatal', error);
  process.exitCode = 1;
});