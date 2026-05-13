import hre from 'hardhat';
import 'dotenv/config';

function readArg(args, index, envName, fallback) {
  const value = args[index];
  if (value && !value.startsWith('--')) return value;
  return process.env[envName] || fallback;
}

async function main() {
  const args = process.argv.slice(2);
  const [deployer] = await hre.ethers.getSigners();

  const name = readArg(args, 0, 'TONTINE_NAME', 'Tontine Amoy Test');
  const cotisationWei = readArg(args, 1, 'COTISATION_WEI', '10000');
  const frequenceIndex = Number(readArg(args, 2, 'FREQUENCE_INDEX', '2'));
  const maxMembers = Number(readArg(args, 3, 'MAX_MEMBERS', '3'));
  const pseudo = readArg(args, 4, 'PSEUDO', 'CreatorAmoy');
  const callMembersEnabled = readArg(args, 5, 'CALL_MEMBERS_ENABLED', 'true') === 'true';
  const backendAddress = readArg(args, 6, 'BACKEND_ADDRESS', deployer.address);
  const guaranteeMode = false;

  const cotisation = hre.ethers.parseUnits(cotisationWei, 'wei');

  const deployerBalance = await hre.ethers.provider.getBalance(deployer.address);

  console.log('Deploying TontineGroup with:', {
    deployer: deployer.address,
    name,
    cotisationWei,
    frequenceIndex,
    maxMembers,
    pseudo,
    callMembersEnabled,
    guaranteeMode,
    backendAddress
  });
  console.log('Deployer balance (wei):', deployerBalance.toString());

  if (deployerBalance < hre.ethers.parseUnits('150000000000000000', 'wei')) {
    throw new Error(
      `Solde insuffisant pour déployer sur ${hre.network.name}. ` +
      `Balance actuelle: ${deployerBalance.toString()} wei. ` +
      `Il faut au moins environ 0.15 MATIC/ETH pour ce contrat sur ce réseau. ` +
      `Faucet ou autre compte financé requis.`
    );
  }

  const Factory = await hre.ethers.getContractFactory('TontineGroup');
  const contract = await Factory.deploy(name, cotisation, frequenceIndex, maxMembers, pseudo, callMembersEnabled, guaranteeMode, backendAddress);
  await contract.waitForDeployment();

  const address = contract.target || (await contract.getAddress());
  const deploymentTransaction = contract.deploymentTransaction();

  console.log('TontineGroup deployed at:', address);
  if (deploymentTransaction) {
    console.log('Txn hash:', deploymentTransaction.hash);
  }

  console.log(JSON.stringify({
    contractName: 'TontineGroup',
    address,
    network: hre.network.name,
    deployer: deployer.address,
    transactionHash: deploymentTransaction?.hash || null
  }));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
