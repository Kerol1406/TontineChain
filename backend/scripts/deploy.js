const hre = require('hardhat');

async function main() {
  const args = process.argv.slice(2);

  if (args.length < 7) {
    console.log('Usage: node scripts/deploy.js <name> <cotisation> <frequenceIndex> <maxMembers> <pseudo> <callMembersEnabled:true|false> <backendAddress>');
    console.log('Backward compatible: an optional legacy <guaranteeMode:true|false> arg before <backendAddress> is ignored.');
    process.exit(1);
  }

  const [name, cotisationStr, frequenceIndexStr, maxMembersStr, pseudo, callMembersEnabledStr, arg7, arg8] = args;

  const cotisation = hre.ethers.parseUnits(cotisationStr, 'wei');
  const frequenceIndex = Number(frequenceIndexStr);
  const maxMembers = Number(maxMembersStr);
  const callMembersEnabled = callMembersEnabledStr === 'true';
  const guaranteeMode = false;
  const backendAddress = arg8 ? arg8 : arg7;

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
