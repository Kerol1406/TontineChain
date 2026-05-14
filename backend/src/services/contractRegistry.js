const { db, admin } = require('./firebase');
const { config } = require('./config');

const CONTRACTS_COLLECTION = 'contracts';

async function registerContract({ tontineId, contractAddress, creatorWallet, backendAddress, network, callMembersEnabled = true, invitationRequired = false }) {
  const normalizedAddress = String(contractAddress || config.centralContractAddress || '').toLowerCase();
  const ref = db.collection(CONTRACTS_COLLECTION).doc(tontineId);
  await ref.set(
    {
      tontineId,
      contractAddress: normalizedAddress,
      creatorWallet: creatorWallet.toLowerCase(),
      backendAddress: backendAddress.toLowerCase(),
      network,
      callMembersEnabled: Boolean(callMembersEnabled),
      invitationRequired: Boolean(invitationRequired),
      active: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    },
    { merge: true }
  );
}

async function getContractByTontineId(tontineId) {
  const snap = await db.collection(CONTRACTS_COLLECTION).doc(tontineId).get();
  if (!snap.exists) {
    if (config.centralContractAddress) {
      return {
        tontineId,
        contractAddress: config.centralContractAddress.toLowerCase(),
        backendAddress: null,
        creatorWallet: null,
        network: config.networkName,
        active: true,
        centralized: true
      };
    }
    return null;
  }

  const data = snap.data();
  return {
    ...data,
    contractAddress: String(data.contractAddress || config.centralContractAddress || '').toLowerCase()
  };
}

async function updateContractPolicy(tontineId, patch) {
  await db
    .collection(CONTRACTS_COLLECTION)
    .doc(tontineId)
    .set(
      {
        ...patch,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      },
      { merge: true }
    );
}

async function listActiveContracts(network) {
  let query = db.collection(CONTRACTS_COLLECTION).where('active', '==', true);
  if (network) {
    query = query.where('network', '==', network);
  }
  const snap = await query.get();
  const seen = new Set();
  const contracts = [];

  for (const doc of snap.docs) {
    const data = doc.data();
    const contractAddress = String(data.contractAddress || '').toLowerCase();
    if (!contractAddress || seen.has(contractAddress)) continue;
    seen.add(contractAddress);
    contracts.push({ id: doc.id, ...data, contractAddress });
  }

  if (!contracts.length && config.centralContractAddress) {
    contracts.push({
      id: 'central-contract',
      tontineId: 'central-contract',
      contractAddress: config.centralContractAddress.toLowerCase(),
      network: config.networkName,
      active: true,
      centralized: true
    });
  }

  return contracts;
}

module.exports = {
  registerContract,
  getContractByTontineId,
  listActiveContracts,
  updateContractPolicy
};
