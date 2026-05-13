import hre from 'hardhat';
import 'dotenv/config';

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log('Deploying contracts with:', deployer.address);

  const Tontine = await hre.ethers.getContractFactory('TontineGroup');

  // Constructor args
  const _nom = 'Tontine Amoy Test';
  const _cotisation = 10000; // unit used by contract (raw uint)
  const _frequence = 2; // 0=DAILY,1=WEEKLY,2=MONTHLY
  const _nombreMaxMembres = 3;
  const _pseudo = 'CreatorAmoy';
  const _callMembersEnabled = true;
  const _guaranteeMode = true;
  const _backend = process.env.BACKEND_ADDRESS || deployer.address;

  // If guaranteeMode true the constructor expects a payable value >= _calculateGarantie(_cotisation).
  // The contract works with raw integer units, so a bigint is sufficient here.
  const valueForGuarantee = BigInt(_cotisation);

  console.log('Constructor args:', { _nom, _cotisation, _frequence, _nombreMaxMembres, _pseudo, _callMembersEnabled, _guaranteeMode, _backend });
  console.log('Sending value (wei) for guarantee:', valueForGuarantee.toString());

  const tontine = await Tontine.deploy(_nom, _cotisation, _frequence, _nombreMaxMembres, _pseudo, _callMembersEnabled, _guaranteeMode, _backend, { value: valueForGuarantee });

  await tontine.waitForDeployment();

  console.log('TontineGroup deployed to:', await tontine.getAddress());
  const deploymentTransaction = tontine.deploymentTransaction();
  if (deploymentTransaction) {
    console.log('Txn hash:', deploymentTransaction.hash);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
