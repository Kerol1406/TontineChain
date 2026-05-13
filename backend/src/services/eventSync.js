const { db, admin } = require('./firebase');
const { ensureGlobalScore, recordOnTimePayment, recordAllocationReceived } = require('./scoreService');
const { appendTimelineEvent } = require('./historyService');

async function persistChainEvent({ tontineId, contractAddress, network, eventName, txHash, blockNumber, args }) {
  const docId = `${txHash}_${eventName}`;
  await db
    .collection('tontines')
    .doc(tontineId)
    .collection('chainEvents')
    .doc(docId)
    .set(
      {
        tontineId,
        contractAddress: contractAddress.toLowerCase(),
        network,
        eventName,
        txHash,
        blockNumber,
        args,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      },
      { merge: true }
    );
}

async function updateMemberProjection({ tontineId, wallet, patch }) {
  await db
    .collection('tontines')
    .doc(tontineId)
    .collection('members')
    .doc(wallet.toLowerCase())
    .set(
      {
        wallet: wallet.toLowerCase(),
        ...patch,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      },
      { merge: true }
    );
}

async function updateCycleProjection({ tontineId, cycleId, patch }) {
  await db
    .collection('tontines')
    .doc(tontineId)
    .collection('cycles')
    .doc(String(cycleId))
    .set(
      {
        cycleId: Number(cycleId),
        ...patch,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      },
      { merge: true }
    );
}

async function recordOffchainHistory({ tontineId, type, title, message, actor, payload, severity }) {
  await appendTimelineEvent({ tontineId, type, title, message, actor, payload, severity });
}

module.exports = {
  persistChainEvent,
  updateMemberProjection,
  updateCycleProjection,
  recordOffchainHistory
};
