const crypto = require('crypto');
const { db, admin } = require('./firebase');
const { getContractByTontineId, updateContractPolicy } = require('./contractRegistry');
const { appendTimelineEvent } = require('./historyService');

function normalizeCode(code) {
  return String(code || '').trim().toUpperCase();
}

function invitationsCollection(tontineId) {
  return db.collection('tontines').doc(tontineId).collection('invites');
}

async function getJoinPolicy(tontineId) {
  const contractMeta = await getContractByTontineId(tontineId);
  const policySnap = await db.collection('tontines').doc(tontineId).collection('runtime').doc('joinPolicy').get();
  const policy = policySnap.exists ? policySnap.data() : {};

  return {
    invitationRequired: Boolean(policy.invitationRequired ?? contractMeta?.invitationRequired ?? !contractMeta?.callMembersEnabled),
    callMembersEnabled: Boolean(policy.callMembersEnabled ?? contractMeta?.callMembersEnabled ?? true)
  };
}

async function setJoinPolicy(tontineId, patch) {
  await db.collection('tontines').doc(tontineId).collection('runtime').doc('joinPolicy').set(
    {
      ...patch,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    },
    { merge: true }
  );

  await updateContractPolicy(tontineId, patch);

  await appendTimelineEvent({
    tontineId,
    type: 'invite.policy_updated',
    title: 'Politique d’invitation mise à jour',
    message: `Politique d’invitation modifiée pour ${tontineId}`,
    payload: patch
  });
}

async function generateInvitationCode({ tontineId, issuedBy, expiresInHours = 72, maxUses = 1, note = '' }) {
  const code = `TC-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
  const now = Date.now();
  const expiresAt = new Date(now + expiresInHours * 60 * 60 * 1000);

  await invitationsCollection(tontineId).doc(code).set({
    code,
    normalizedCode: normalizeCode(code),
    issuedBy: issuedBy ? String(issuedBy).toLowerCase() : null,
    maxUses: Number(maxUses || 1),
    usedCount: 0,
    note,
    active: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt,
    usedBy: []
  });

  await appendTimelineEvent({
    tontineId,
    type: 'invite.generated',
    title: 'Code d’invitation généré',
    message: `Nouveau code généré pour ${tontineId}`,
    actor: issuedBy ? String(issuedBy).toLowerCase() : null,
    payload: { code, expiresAt: expiresAt.toISOString(), maxUses }
  });

  return { code, expiresAt: expiresAt.toISOString(), maxUses };
}

async function validateInvitationCode(tontineId, code) {
  const normalizedCode = normalizeCode(code);
  const snap = await invitationsCollection(tontineId).doc(normalizedCode).get();
  if (!snap.exists) {
    return { valid: false, reason: 'not_found' };
  }

  const data = snap.data();
  if (!data.active) {
    return { valid: false, reason: 'inactive' };
  }
  if (data.usedCount >= data.maxUses) {
    return { valid: false, reason: 'exhausted' };
  }
  if (data.expiresAt && data.expiresAt.toDate && data.expiresAt.toDate() < new Date()) {
    return { valid: false, reason: 'expired' };
  }

  return { valid: true, code: data.code, data };
}

async function markInvitationUsed(tontineId, code, wallet) {
  const normalizedCode = normalizeCode(code);
  const ref = invitationsCollection(tontineId).doc(normalizedCode);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new Error(`Invitation code not found: ${normalizedCode}`);
    }

    const data = snap.data();
    const usedBy = Array.isArray(data.usedBy) ? data.usedBy.slice() : [];
    usedBy.push(String(wallet).toLowerCase());

    tx.set(
      ref,
      {
        usedCount: (data.usedCount || 0) + 1,
        usedBy,
        lastUsedAt: admin.firestore.FieldValue.serverTimestamp(),
        active: (data.usedCount || 0) + 1 < (data.maxUses || 1)
      },
      { merge: true }
    );
  });
}

module.exports = {
  getJoinPolicy,
  setJoinPolicy,
  generateInvitationCode,
  validateInvitationCode,
  markInvitationUsed
};