const { ethers } = require('ethers');

const { wallet } = require('./blockchain');
const { config } = require('./config');
const { registerContract } = require('./contractRegistry');
const { db, admin } = require('./firebase');

function normalizeFrequencyIndex(value) {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === '0' || normalized.includes('journalier') || normalized.includes('daily')) return 0;
  if (normalized === '1' || normalized.includes('hebdo') || normalized.includes('week')) return 1;
  return 2;
}

async function deployTontineContract({
  tontineId,
  name,
  monthlyAmount,
  frequency,
  maxMembers,
  creatorId,
  creatorWallet,
  creatorPseudo,
  isPublic,
  callMembersEnabled
}) {
  if (!tontineId) throw new Error('tontineId is required');
  if (!name) throw new Error('name is required');
  if (monthlyAmount == null) throw new Error('monthlyAmount is required');
  if (maxMembers == null) throw new Error('maxMembers is required');
  if (!creatorId) throw new Error('creatorId is required');

  if (!config.centralContractAddress) {
    throw new Error('Missing CENTRAL_CONTRACT_ADDRESS env var. Deploy TontineManager.sol once and set this address before creating tontines.');
  }

  let resolvedCreatorWallet = String(creatorWallet || '').trim();
  if (!ethers.isAddress(resolvedCreatorWallet)) {
    try {
      const { getUserProfile } = require('./userService');
      const creatorProfile = await getUserProfile(creatorId);
      resolvedCreatorWallet = String(creatorProfile?.walletAddress || creatorProfile?.wallet || '').trim();
    } catch (error) {
      resolvedCreatorWallet = '';
    }
  }

  if (!ethers.isAddress(resolvedCreatorWallet)) {
    throw new Error(`Unable to resolve a valid blockchain wallet address for creatorId=${creatorId}`);
  }

  const factory = new ethers.Contract(config.centralContractAddress, [
    'function createTontine(string tontineId, string name, uint256 contributionAmount, uint8 frequency, uint256 maxMembers, string pseudo, bool callMembersEnabled, bool guaranteeMode, address creator) external returns (uint256)',
    'function getTontine(string tontineId) external view returns (string name, uint256 contributionAmount, uint256 maxMembers, uint256 currentCycle, bool started, bool finished, address creator, uint256 totalPool, uint256 memberCount, uint8 frequency)'
  ], wallet);
  const frequencyIndex = normalizeFrequencyIndex(frequency);
  const monthlyAmountWei = BigInt(Math.round(Number(monthlyAmount)));
  const pseudo = String(creatorPseudo || name || 'Createur').trim() || 'Createur';
  const backendAddress = wallet.address;

  const createTxRequest = await factory.createTontine.populateTransaction(
    tontineId,
    name,
    monthlyAmountWei,
    frequencyIndex,
    Number(maxMembers),
    pseudo,
    Boolean(callMembersEnabled),
    false,
    resolvedCreatorWallet
  );
  createTxRequest.from = backendAddress;

  const estimatedGas = await wallet.provider.estimateGas(createTxRequest);
  const feeData = await wallet.provider.getFeeData();
  const gasPrice = feeData.gasPrice ?? feeData.maxFeePerGas ?? feeData.maxPriorityFeePerGas;
  const estimatedCost = gasPrice ? estimatedGas * gasPrice : null;
  const balance = await wallet.provider.getBalance(backendAddress);

  if (estimatedCost && balance < estimatedCost) {
    throw new Error(
      `Solde insuffisant pour créer la tontine avec le wallet backend ${backendAddress}. ` +
      `Balance actuelle: ${balance.toString()} wei. ` +
      `Coût estimé: ${estimatedCost.toString()} wei. ` +
      `Ajoute du MATIC testnet sur ce wallet puis réessaie.`
    );
  }

  const tx = await factory.createTontine(
    tontineId,
    name,
    monthlyAmountWei,
    frequencyIndex,
    Number(maxMembers),
    pseudo,
    Boolean(callMembersEnabled),
    false,
    resolvedCreatorWallet
  );

  const receipt = await tx.wait();
  const contractAddress = config.centralContractAddress;

  await registerContract({
    tontineId,
    contractAddress,
    creatorWallet: resolvedCreatorWallet,
    backendAddress,
    network: config.networkName,
    callMembersEnabled: Boolean(callMembersEnabled),
    invitationRequired: !Boolean(isPublic)
  });

  await db.collection('tontines').doc(tontineId).set(
    {
      tontineId,
      contractAddress: contractAddress.toLowerCase(),
      contractTransactionHash: receipt?.hash || null,
      blockchainNetwork: config.networkName,
      deploymentStatus: 'DEPLOYED',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    },
    { merge: true }
  );

  return {
    tontineId,
    contractAddress,
    contractTransactionHash: receipt?.hash || null,
    network: config.networkName,
    backendAddress
  };
}

module.exports = {
  deployTontineContract,
  normalizeFrequencyIndex
};