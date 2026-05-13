const { config } = require('../services/config');
const { wallet } = require('../services/blockchain');
const { registerContract } = require('../services/contractRegistry');

async function main() {
  const [tontineId, contractAddress, creatorWallet, callMembersEnabledArg, invitationRequiredArg] = process.argv.slice(2);
  if (!tontineId || !contractAddress || !creatorWallet) {
    throw new Error('Usage: node src/jobs/registerContractCli.js <tontineId> <contractAddress> <creatorWallet> [callMembersEnabled=true] [invitationRequired=false]');
  }

  await registerContract({
    tontineId,
    contractAddress,
    creatorWallet,
    backendAddress: wallet.address,
    network: config.networkName,
    callMembersEnabled: callMembersEnabledArg === undefined ? true : callMembersEnabledArg === 'true',
    invitationRequired: invitationRequiredArg === undefined ? false : invitationRequiredArg === 'true'
  });

  console.log('[registry] contract registered', { tontineId, contractAddress, backendAddress: wallet.address });
}

main().catch((error) => {
  console.error('[registry] fatal', error.message);
  process.exit(1);
});
