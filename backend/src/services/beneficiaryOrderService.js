const { db, admin } = require('./firebase');
const { getContract, sendTx } = require('./blockchain');
const { getContractByTontineId } = require('./contractRegistry');
const { ensureGlobalScore, getGlobalScore, setCurrentBeneficiaryScore, clampScore } = require('./scoreService');
const { appendTimelineEvent } = require('./historyService');

function normalizeWallet(wallet) {
  return String(wallet || '').toLowerCase();
}

function extractTimestamp(value) {
  if (!value) return 0;
  if (typeof value.toMillis === 'function') return value.toMillis();
  if (value.seconds) return value.seconds * 1000;
  const parsed = Number(value);
  return Number.isNaN(parsed) ? 0 : parsed;
}

function stableTieBreaker(wallet) {
  return normalizeWallet(wallet).split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
}

async function loadEligibleMembers(tontineId) {
  const snap = await db.collection('tontines').doc(tontineId).collection('members').get();
  const members = [];

  for (const doc of snap.docs) {
    const member = { id: doc.id, ...doc.data() };
    const wallet = normalizeWallet(member.wallet || doc.id);
    const scoreRecord = await ensureGlobalScore(wallet, { source: 'order_service', tontineId });
    members.push({
      wallet,
      pseudo: member.pseudo || null,
      status: member.status || 'ACTIVE',
      joinedAt: extractTimestamp(member.joinedAt || member.createdAt || member.updatedAt),
      score: clampScore(scoreRecord.score),
      orderSeed: stableTieBreaker(wallet)
    });
  }

  return members.filter((member) => !['SUSPENDED', 'EXCLUDED', 'BLOCKED'].includes(String(member.status).toUpperCase()));
}

async function computeBeneficiaryOrder(tontineId) {
  const members = await loadEligibleMembers(tontineId);
  members.sort((left, right) => {
    if (right.score !== left.score) return right.score - left.score;
    if (left.joinedAt !== right.joinedAt) return left.joinedAt - right.joinedAt;
    if (left.orderSeed !== right.orderSeed) return left.orderSeed - right.orderSeed;
    return left.wallet.localeCompare(right.wallet);
  });
  return members;
}

async function persistOrder(tontineId, order) {
  await db.collection('tontines').doc(tontineId).collection('runtime').doc('beneficiaryOrder').set(
    {
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      order
    },
    { merge: true }
  );

  if (order.length) {
    await setCurrentBeneficiaryScore(tontineId, order[0].wallet, order[0].score, {
      rank: 0,
      source: 'beneficiary_order_service'
    });
  }

  await appendTimelineEvent({
    tontineId,
    type: 'order.recomputed',
    title: 'Ordre des bénéficiaires recalculé',
    message: `Ordre recalculé avec ${order.length} membre(s)`,
    payload: { order }
  });

  return order;
}

async function reorderBeneficiaries(tontineId, { contractAddress, contract } = {}) {
  const order = await computeBeneficiaryOrder(tontineId);
  const persisted = await persistOrder(tontineId, order);

  if ((contractAddress || contract) && persisted.length) {
    const instance = contract || getContract(contractAddress);
    const addresses = persisted.map((member) => member.wallet);
    await sendTx(instance.setOrdreBeneficiaires(addresses), `setOrdreBeneficiaires(${tontineId})`);
  }

  return persisted;
}

async function moveMemberDown(tontineId, wallet, reason = 'manual_reorder', penalty = 5) {
  const { applyScoreDelta } = require('./scoreService');
  const result = await applyScoreDelta({
    tontineId,
    wallet,
    delta: -Math.abs(Number(penalty || 0)),
    reason,
    metadata: { source: 'moveMemberDown' }
  });

  await appendTimelineEvent({
    tontineId,
    type: 'order.member_moved_down',
    title: 'Membre déplacé vers le bas',
    message: `${normalizeWallet(wallet)} a été pénalisé dans l'ordre`,
    actor: normalizeWallet(wallet),
    payload: result,
    severity: 'warning'
  });

  return result;
}

async function getCurrentBeneficiary(tontineId) {
  const order = await computeBeneficiaryOrder(tontineId);
  return order[0] || null;
}

async function loadContractForTontine(tontineId) {
  const contractMeta = await getContractByTontineId(tontineId);
  if (!contractMeta) {
    throw new Error(`No contract registered for tontineId=${tontineId}`);
  }
  return { contractMeta, contract: getContract(contractMeta.contractAddress) };
}

/**
 * Check if we should reorder beneficiaries for a specific wallet in a specific tontine
 * Conditions: wallet hasn't received yet AND is not already last
 * Important: Even if it's their turn this cycle, if score drops (late payment) → reorder immediately
 */
async function shouldReorderForWallet(tontineId, wallet) {
  const normalizedWallet = normalizeWallet(wallet);
  
  // Check 1: Has member already received?
  const memberSnap = await db.collection('tontines').doc(tontineId).collection('members').doc(normalizedWallet).get();
  if (!memberSnap.exists) {
    return false; // Not a member
  }
  
  const member = memberSnap.data();
  if (member.aRecu === true) {
    return false; // Already received, can't reorder
  }

  // Check 2: Is member already last in the order? (can't go lower)
  const orderSnap = await db
    .collection('tontines')
    .doc(tontineId)
    .collection('runtime')
    .doc('beneficiaryOrder')
    .get();
  
  if (orderSnap.exists) {
    const { order } = orderSnap.data();
    if (order && order.length > 0) {
      const lastMember = order[order.length - 1];
      if (lastMember.wallet === normalizedWallet) {
        return false; // Already last, can't go lower
      }
    }
  }

  // Can reorder (even if it's their turn this cycle - score drop overrides)
  return true;
}

/**
 * Reorder beneficiaries in all tontines where wallet is a member and eligible
 * This is called when wallet's score drops (late payment, etc.)
 */
async function reorderIfEligibleInAllTontines(wallet) {
  const normalizedWallet = normalizeWallet(wallet);

  // Find all tontines where this wallet is a member
  const memberSnapshots = await db.collectionGroup('members')
    .where(admin.firestore.FieldPath.documentId(), '==', normalizedWallet)
    .get();

  if (memberSnapshots.empty) {
    return []; // No tontines found
  }

  const reorderedTontines = [];

  for (const memberDoc of memberSnapshots.docs) {
    const tontineId = memberDoc.ref.parent.parent.id;

    try {
      const canReorder = await shouldReorderForWallet(tontineId, normalizedWallet);
      
      if (canReorder) {
        // Reorder this tontine
        await reorderBeneficiaries(tontineId);
        reorderedTontines.push(tontineId);

        console.log(`[reorder] ${normalizedWallet} reordered down in tontine ${tontineId} due to score drop`);
      }
    } catch (error) {
      console.error(`[reorder] error reordering ${normalizedWallet} in ${tontineId}:`, error);
    }
  }

  return reorderedTontines;
}

module.exports = {
  computeBeneficiaryOrder,
  reorderBeneficiaries,
  moveMemberDown,
  getCurrentBeneficiary,
  loadContractForTontine,
  persistOrder,
  shouldReorderForWallet,
  reorderIfEligibleInAllTontines
};