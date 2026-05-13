const hre = require('hardhat');

async function main() {
  const args = process.argv.slice(2);

  if (args.length < 8) {
    console.log('Usage: node scripts/deploy.js <name> <cotisation> <frequenceIndex> <maxMembers> <pseudo> <callMembersEnabled:true|false> <guaranteeMode:true|false> <backendAddress>');
    process.exit(1);
  }

  const [name, cotisationStr, frequenceIndexStr, maxMembersStr, pseudo, callMembersEnabledStr, guaranteeModeStr, backendAddress] = args;

  const cotisation = hre.ethers.parseUnits(cotisationStr, 'wei');
  const frequenceIndex = Number(frequenceIndexStr);
  const maxMembers = Number(maxMembersStr);
  const callMembersEnabled = callMembersEnabledStr === 'true';
  const guaranteeMode = guaranteeModeStr === 'true';

  console.log('Deploying TontineGroup with:', { name, cotisation: cotisationStr, frequenceIndex, maxMembers, pseudo, callMembersEnabled, guaranteeMode, backendAddress });

  const Factory = await hre.ethers.getContractFactory('TontineGroup');

  const contract = await Factory.deploy(name, cotisation, frequenceIndex, maxMembers, pseudo, callMembersEnabled, guaranteeMode, backendAddress);
  await contract.waitForDeployment();

  console.log('TontineGroup deployed at:', contract.target || contract.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
