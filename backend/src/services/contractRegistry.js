const { db, admin } = require('./firebase');

const CONTRACTS_COLLECTION = 'contracts';

async function registerContract({ tontineId, contractAddress, creatorWallet, backendAddress, network, callMembersEnabled = true, invitationRequired = false }) {
  const ref = db.collection(CONTRACTS_COLLECTION).doc(tontineId);
  await ref.set(
    {
      tontineId,
      contractAddress: contractAddress.toLowerCase(),
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
  if (!snap.exists) return null;
  return snap.data();
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
  return snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
}

module.exports = {
  registerContract,
  getContractByTontineId,
  listActiveContracts,
  updateContractPolicy
};
