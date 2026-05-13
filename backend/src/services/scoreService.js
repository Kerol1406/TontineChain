const { db, admin } = require('./firebase');
const { config } = require('./config');
const { appendTimelineEvent } = require('./historyService');

const SCORE_RULES = {
  initial: config.defaultScore,
  onTimePayment: 2,
  latePayment: -5,
  guaranteeUsed: -10,
  suspension: -20,
  exclusion: -50,
  invitationAccepted: 3,
  allocationReceived: 1,
  defaultResolved: -8
};

function normalizeWallet(wallet) {
  return String(wallet || '').toLowerCase();
}

function clampScore(score) {
  return Math.max(0, Math.min(100, Number(score)));
}

/**
 * Global score reference for a user (NOT scoped to any tontine)
 * Score follows the individual across all tontines they participate in
 */
function globalScoreRef(wallet) {
  return db.collection('users').doc(normalizeWallet(wallet)).collection('globalScore').doc('current');
}

/**
 * Tontine-specific history reference (for audit trail, but score is global)
 */
function tontineHistoryRef(wallet, tontineId) {
  return db.collection('users').doc(normalizeWallet(wallet)).collection('tontineHistory').doc(normalizeWallet(tontineId));
}

/**
 * Ensure user has a global score initialized
 * This is called once when user first interacts with the system
 */
async function ensureGlobalScore(wallet, seedPatch = {}) {
  const ref = globalScoreRef(wallet);
  const snap = await ref.get();
  if (snap.exists) {
    return { id: snap.id, ...snap.data() };
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  const doc = {
    wallet: normalizeWallet(wallet),
    score: clampScore(SCORE_RULES.initial),
    createdAt: now,
    updatedAt: now,
    lastReason: 'initial',
    totalTontineParticipations: 0,
    ...seedPatch
  };

  await ref.set(doc, { merge: true });

  return { id: ref.id, ...doc };
}

/**
 * Get the global score for a user
 * This score is NOT scoped to any tontine - it's the user's reputation across all tontines
 */
async function getGlobalScore(wallet) {
  const snap = await globalScoreRef(wallet).get();
  if (!snap.exists) {
    return ensureGlobalScore(wallet);
  }
  return { id: snap.id, ...snap.data() };
}

/**
 * Get global scores for all members of a specific tontine
 * Returns each member's global score (not scoped to this tontine, but their overall reputation)
 */
async function getScoresForTontineMembers(tontineId) {
  const membersSnap = await db.collection('tontines').doc(tontineId).collection('members').get();
  const scores = [];

  for (const memberDoc of membersSnap.docs) {
    const wallet = memberDoc.id;
    const globalScore = await getGlobalScore(wallet);
    scores.push({
      wallet,
      score: globalScore.score,
      lastReason: globalScore.lastReason || 'unknown',
      updatedAt: globalScore.updatedAt
    });
  }

  return scores;
}

/**
 * Apply a score delta to the user's GLOBAL score
 * Tontine-specific events are recorded in history but affect the global score
 */
async function applyScoreDelta({ tontineId, wallet, delta, reason, metadata = {} }) {
  const normalizedWallet = normalizeWallet(wallet);
  const globalRef = globalScoreRef(normalizedWallet);
  const historyRef = globalRef.collection('history').doc();

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(globalRef);
    const previousScore = snap.exists ? Number(snap.data().score) : SCORE_RULES.initial;
    const nextScore = clampScore(previousScore + Number(delta || 0));
    const now = admin.firestore.FieldValue.serverTimestamp();

    // Update GLOBAL score
    tx.set(
      globalRef,
      {
        wallet: normalizedWallet,
        score: nextScore,
        lastReason: reason,
        lastDelta: Number(delta || 0),
        lastTontineId: tontineId, // Track which tontine caused the last change
        updatedAt: now,
        createdAt: snap.exists ? snap.data().createdAt : now,
        ...metadata
      },
      { merge: true }
    );

    // Record in global history
    tx.set(historyRef, {
      wallet: normalizedWallet,
      tontineId, // Reference the tontine that caused this change
      scoreBefore: previousScore,
      scoreAfter: nextScore,
      delta: Number(delta || 0),
      reason,
      metadata,
      createdAt: now
    });

    return { wallet: normalizedWallet, scoreBefore: previousScore, scoreAfter: nextScore, reason, tontineId };
  });
}

async function recordOnTimePayment(tontineId, wallet, metadata = {}) {
  const result = await applyScoreDelta({
    tontineId,
    wallet,
    delta: SCORE_RULES.onTimePayment,
    reason: 'on_time_payment',
    metadata
  });

  await appendTimelineEvent({
    tontineId,
    type: 'score.on_time_payment',
    title: 'Paiement à temps',
    message: `${normalizeWallet(wallet)} a payé à temps`,
    actor: normalizeWallet(wallet),
    payload: result
  });

  return result;
}

async function recordLatePayment(tontineId, wallet, metadata = {}) {
  const result = await applyScoreDelta({
    tontineId,
    wallet,
    delta: SCORE_RULES.latePayment,
    reason: 'late_payment',
    metadata
  });

  await appendTimelineEvent({
    tontineId,
    type: 'score.late_payment',
    title: 'Retard de paiement',
    message: `${normalizeWallet(wallet)} a été pénalisé pour retard`,
    actor: normalizeWallet(wallet),
    payload: result,
    severity: 'warning'
  });

  // Score dropped → reorder beneficiaries in all eligible tontines for this wallet
  const { reorderIfEligibleInAllTontines } = require('./beneficiaryOrderService');
  setImmediate(() => {
    reorderIfEligibleInAllTontines(wallet).catch(err => 
      console.error('[scoreService] reorder error after late payment:', err)
    );
  });

  return result;
}

async function recordGuaranteeUse(tontineId, wallet, metadata = {}) {
  const result = await applyScoreDelta({
    tontineId,
    wallet,
    delta: SCORE_RULES.guaranteeUsed,
    reason: 'guarantee_used',
    metadata
  });

  await appendTimelineEvent({
    tontineId,
    type: 'score.guarantee_used',
    title: 'Garantie utilisée',
    message: `${normalizeWallet(wallet)} a utilisé la garantie`,
    actor: normalizeWallet(wallet),
    payload: result,
    severity: 'warning'
  });

  // Score dropped → reorder beneficiaries in all eligible tontines
  const { reorderIfEligibleInAllTontines } = require('./beneficiaryOrderService');
  setImmediate(() => {
    reorderIfEligibleInAllTontines(wallet).catch(err => 
      console.error('[scoreService] reorder error after guarantee use:', err)
    );
  });

  return result;
}

async function recordSuspension(tontineId, wallet, metadata = {}) {
  const result = await applyScoreDelta({
    tontineId,
    wallet,
    delta: SCORE_RULES.suspension,
    reason: 'suspension',
    metadata
  });

  await appendTimelineEvent({
    tontineId,
    type: 'score.suspension',
    title: 'Suspension appliquée',
    message: `${normalizeWallet(wallet)} a été suspendu`,
    actor: 'system',
    payload: result,
    severity: 'danger'
  });

  // Score dropped significantly → reorder beneficiaries in all eligible tontines
  const { reorderIfEligibleInAllTontines } = require('./beneficiaryOrderService');
  setImmediate(() => {
    reorderIfEligibleInAllTontines(wallet).catch(err => 
      console.error('[scoreService] reorder error after suspension:', err)
    );
  });

  return result;
}

async function recordExclusion(tontineId, wallet, metadata = {}) {
  const result = await applyScoreDelta({
    tontineId,
    wallet,
    delta: SCORE_RULES.exclusion,
    reason: 'exclusion',
    metadata
  });

  await appendTimelineEvent({
    tontineId,
    type: 'score.exclusion',
    title: 'Exclusion appliquée',
    message: `${normalizeWallet(wallet)} a été exclu`,
    actor: 'system',
    payload: result,
    severity: 'danger'
  });

  // Score dropped critically → reorder beneficiaries in all eligible tontines
  const { reorderIfEligibleInAllTontines } = require('./beneficiaryOrderService');
  setImmediate(() => {
    reorderIfEligibleInAllTontines(wallet).catch(err => 
      console.error('[scoreService] reorder error after exclusion:', err)
    );
  });

  return result;
}

async function recordAllocationReceived(tontineId, wallet, metadata = {}) {
  return applyScoreDelta({
    tontineId,
    wallet,
    delta: SCORE_RULES.allocationReceived,
    reason: 'allocation_received',
    metadata
  });
}

async function setCurrentBeneficiaryScore(tontineId, wallet, score, metadata = {}) {
  const normalizedWallet = normalizeWallet(wallet);
  const clampedScore = clampScore(score);
  await db
    .collection('tontines')
    .doc(tontineId)
    .collection('runtime')
    .doc('currentBeneficiaryScore')
    .set(
      {
        wallet: normalizedWallet,
        score: clampedScore,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        ...metadata
      },
      { merge: true }
    );
  return { wallet: normalizedWallet, score: clampedScore };
}

async function getCurrentBeneficiaryScore(tontineId) {
  const snap = await db.collection('tontines').doc(tontineId).collection('runtime').doc('currentBeneficiaryScore').get();
  if (!snap.exists) {
    return { wallet: null, score: SCORE_RULES.initial };
  }

  const data = snap.data();
  return {
    wallet: data.wallet || null,
    score: clampScore(data.score ?? SCORE_RULES.initial)
  };
}

/**
 * Get all users' global scores (admin function)
 */
async function getAllGlobalScores() {
  const snap = await db.collectionGroup('globalScore').get();
  return snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
}

module.exports = {
  SCORE_RULES,
  clampScore,
  ensureGlobalScore,
  getGlobalScore,
  getScoresForTontineMembers,
  applyScoreDelta,
  recordOnTimePayment,
  recordLatePayment,
  recordGuaranteeUse,
  recordSuspension,
  recordExclusion,
  recordAllocationReceived,
  setCurrentBeneficiaryScore,
  getCurrentBeneficiaryScore,
  getAllGlobalScores
};