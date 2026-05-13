const { db, admin } = require('./firebase');
const { getContract } = require('./blockchain');
const { getContractByTontineId } = require('./contractRegistry');
const { getGlobalScore } = require('./scoreService');

function normalizeWallet(wallet) {
  return String(wallet || '').toLowerCase();
}

function normalizeStatus(value) {
  return String(value || '').trim().toUpperCase();
}

function parseDateTime(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (value._seconds !== undefined) {
    return new Date(value._seconds * 1000 + Math.round((value._nanoseconds || 0) / 1e6));
  }
  if (typeof value === 'string') {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? null : new Date(parsed);
  }
  return null;
}

function parseBlockchainTimestamp(value) {
  if (value == null) return null;
  try {
    const raw = typeof value === 'bigint' ? value : BigInt(value.toString());
    return new Date(Number(raw) * 1000);
  } catch (error) {
    return null;
  }
}

async function getOnChainCycleInfo(tontineId) {
  const contractMeta = await getContractByTontineId(tontineId);
  if (!contractMeta?.contractAddress) return null;

  const contract = getContract(contractMeta.contractAddress);
  const currentCycle = await contract.cycleActuel();
  const cycleIndex = Number(currentCycle);
  if (Number.isNaN(cycleIndex)) return null;

  let cycleInfo;
  try {
    cycleInfo = await contract.cycles(cycleIndex);
  } catch (error) {
    return null;
  }

  const dueDate = parseBlockchainTimestamp(cycleInfo.dateLimiteCotisation);
  const startDate = parseBlockchainTimestamp(cycleInfo.dateDebut);
  const amount = cycleInfo.montantAttendu != null
    ? Number(cycleInfo.montantAttendu.toString())
    : null;

  return {
    tontineId,
    contractAddress: contractMeta.contractAddress,
    cycleIndex,
    startDate,
    dueDate,
    amount,
    beneficiary: cycleInfo.beneficiaire || null,
  };
}

/**
 * Get user profile by wallet
 */
async function getUserProfile(wallet) {
  const normalizedWallet = normalizeWallet(wallet);
  const userSnap = await db.collection('users').doc(normalizedWallet).get();
  
  if (!userSnap.exists) {
    return null;
  }

  const profileData = userSnap.data();
  const globalScore = await getGlobalScore(normalizedWallet);

  return {
    wallet: normalizedWallet,
    pseudo: profileData.pseudo || null,
    email: profileData.email || null,
    phone: profileData.phone || null,
    createdAt: profileData.createdAt || null,
    updatedAt: profileData.updatedAt || null,
    globalScore: globalScore.score,
    bio: profileData.bio || null,
    avatar: profileData.avatar || null,
    verified: profileData.verified || false
  };
}

/**
 * Create or update user profile
 */
async function updateUserProfile(wallet, profileData = {}) {
  const normalizedWallet = normalizeWallet(wallet);
  const now = admin.firestore.FieldValue.serverTimestamp();

  const updateData = {
    wallet: normalizedWallet,
    updatedAt: now
  };

  // Allow updating these fields
  const allowedFields = ['pseudo', 'email', 'phone', 'bio', 'avatar'];
  for (const field of allowedFields) {
    if (profileData[field] !== undefined) {
      updateData[field] = String(profileData[field]).trim();
    }
  }

  // On first creation, set createdAt
  const existingSnap = await db.collection('users').doc(normalizedWallet).get();
  if (!existingSnap.exists) {
    updateData.createdAt = now;
    updateData.verified = false;
  }

  await db.collection('users').doc(normalizedWallet).set(updateData, { merge: true });

  return getUserProfile(normalizedWallet);
}

/**
 * Get all tontines where user is a member
 */
async function getUserTontines(wallet) {
  const normalizedWallet = normalizeWallet(wallet);

  const userTontines = [];
  const seen = new Set();

  // Primary source: members subcollection
  try {
    const memberSnapshots = await db.collectionGroup('members')
      .where(admin.firestore.FieldPath.documentId(), '==', normalizedWallet)
      .get();

    for (const memberDoc of memberSnapshots.docs) {
      const tontineId = memberDoc.ref.parent.parent.id;
      const key = String(tontineId);
      if (seen.has(key)) continue;
      seen.add(key);

      const tontineSnap = await db.collection('tontines').doc(tontineId).get();
      if (!tontineSnap.exists) continue;

      const tontineData = tontineSnap.data();
      const memberData = memberDoc.data();
      userTontines.push({
        tontineId,
        name: tontineData.nom || tontineData.name || 'Unknown Tontine',
        status: tontineData.statut || tontineData.status || 'UNKNOWN',
        memberStatus: memberData.status || 'ACTIVE',
        joinedAt: memberData.createdAt || memberData.joinedAt || null,
        aRecu: memberData.aRecu || false,
        montantRecu: memberData.montantRecu || 0,
        montantCotise: memberData.totalCotise || 0,
        pseudo: memberData.pseudo || null,
        frequency: tontineData.frequence || tontineData.frequency || null,
        monthlyAmount: Number(tontineData.montant || tontineData.monthlyAmount || 0),
        maxMembers: tontineData.nombreMaxMembres || tontineData.maxMembers || null,
        currentCycle: Number(tontineData.cycleActuel || tontineData.currentCycle || 0)
      });
    }
  } catch (error) {
    console.error('[userService] members collectionGroup lookup failed:', error);
  }

  // Fallback source: user document array of tontines
  if (userTontines.length === 0) {
    try {
      const userSnap = await db.collection('users').doc(normalizedWallet).get();
      const userData = userSnap.exists ? userSnap.data() : null;
      const linkedTontines = Array.isArray(userData?.tontines) ? userData.tontines : [];

      if (linkedTontines.length > 0) {
        for (const tontineId of linkedTontines) {
          const key = String(tontineId);
          if (seen.has(key)) continue;
          seen.add(key);

          const tontineSnap = await db.collection('tontines').doc(tontineId).get();
          if (!tontineSnap.exists) continue;

          const tontineData = tontineSnap.data();
          const members = Array.isArray(tontineData.membres) ? tontineData.membres : [];
          if (members.length > 0 && !members.map((m) => normalizeWallet(m)).includes(normalizedWallet)) {
            continue;
          }

          userTontines.push({
            tontineId,
            name: tontineData.nom || tontineData.name || 'Unknown Tontine',
            status: tontineData.statut || tontineData.status || 'UNKNOWN',
            memberStatus: 'ACTIVE',
            joinedAt: tontineData.createdAt || null,
            aRecu: false,
            montantRecu: 0,
            montantCotise: 0,
            pseudo: null,
            frequency: tontineData.frequence || tontineData.frequency || null,
            monthlyAmount: Number(tontineData.montant || tontineData.monthlyAmount || 0),
            maxMembers: tontineData.nombreMaxMembres || tontineData.maxMembers || null,
            currentCycle: Number(tontineData.cycleActuel || tontineData.currentCycle || 0)
          });
        }
      }
    } catch (error) {
      console.error('[userService] user document fallback lookup failed:', error);
    }
  }

  // Last fallback: scan tontines collection for creator/member match.
  if (userTontines.length === 0) {
    try {
      const allTontinesSnap = await db.collection('tontines').get();
      for (const doc of allTontinesSnap.docs) {
        const data = doc.data();
        const tontineId = doc.id;
        if (seen.has(tontineId)) continue;

        const creator = normalizeWallet(data.createur || data.creatorId || data.uid || data.userId || '');
        const members = Array.isArray(data.membres) ? data.membres.map(normalizeWallet) : [];
        if (creator !== normalizedWallet && !members.includes(normalizedWallet)) continue;

        seen.add(tontineId);
        userTontines.push({
          tontineId,
          name: data.nom || data.name || 'Unknown Tontine',
          status: data.statut || data.status || 'UNKNOWN',
          memberStatus: creator === normalizedWallet ? 'CREATOR' : 'ACTIVE',
          joinedAt: data.createdAt || null,
          aRecu: false,
          montantRecu: 0,
          montantCotise: 0,
          pseudo: null,
          frequency: data.frequence || data.frequency || null,
          monthlyAmount: Number(data.montant || data.monthlyAmount || 0),
          maxMembers: data.nombreMaxMembres || data.maxMembers || null,
          currentCycle: Number(data.cycleActuel || data.currentCycle || 0)
        });
      }
    } catch (error) {
      console.error('[userService] full tontines scan fallback failed:', error);
    }
  }

  return userTontines;
}

/**
 * Get user's global score
 */
async function getUserGlobalScore(wallet) {
  const globalScore = await getGlobalScore(wallet);
  return {
    wallet: normalizeWallet(wallet),
    score: globalScore.score,
    lastReason: globalScore.lastReason || 'unknown',
    updatedAt: globalScore.updatedAt || null,
    createdAt: globalScore.createdAt || null
  };
}

/**
 * Get user stats (tontines count, score, etc.)
 */
async function getUserStats(wallet) {
  const normalizedWallet = normalizeWallet(wallet);
  const tontines = await getUserTontines(normalizedWallet);
  const globalScore = await getUserGlobalScore(normalizedWallet);

  const stats = {
    wallet: normalizedWallet,
    totalTontinesParticipated: tontines.length,
    tontinesActive: tontines.filter(t => t.status === 'ACTIVE').length,
    tontinesCompleted: tontines.filter(t => t.status === 'COMPLETED').length,
    tontinesFailed: tontines.filter(t => t.status === 'FAILED').length,
    allocationsReceived: tontines.filter(t => t.aRecu === true).length,
    totalReceived: tontines.reduce((sum, t) => sum + Number(t.montantRecu || 0), 0),
    totalContributed: tontines.reduce((sum, t) => sum + Number(t.montantCotise || 0), 0),
    globalScore: globalScore.score
  };

  return stats;
}

module.exports = {
  getUserProfile,
  updateUserProfile,
  getUserTontines,
  getUserGlobalScore,
  getUserStats
};

/**
 * Compute the next due tontine for a user.
 * Returns null when none found.
 */
async function getUserNextDue(wallet) {
  const normalized = normalizeWallet(wallet);

  // 1) collect tontines for user
  const tontines = await getUserTontines(normalized);

  let best = null;

  for (const t of tontines) {
    try {
      // Ignore finished/suspended
      const status = normalizeStatus(t.status);
      if (['TERMINE', 'SUSPENDUE', 'ARCHIVEA', 'COMPLETED', 'FAILED'].includes(status)) continue;

      // 1 bis) use on-chain cycle timing when available
      const onChain = await getOnChainCycleInfo(t.tontineId).catch(() => null);
      if (onChain?.dueDate instanceof Date && !Number.isNaN(onChain.dueDate.getTime())) {
        const candidate = {
          tontine: {
            id: t.tontineId,
            name: t.name,
            monthlyAmount: Number(t.montantCotise || t.monthlyAmount || 0),
            maxMembers: t.maxMembers || null,
            frequency: t.frequency || null,
            status: t.status || t.statut || null,
          },
          dueDate: onChain.dueDate.toISOString(),
          amount: Number(t.monthlyAmount || t.montantCotise || onChain.amount || 0),
          reason: 'onchain_cycle',
          cycle: onChain.cycleIndex,
          blockchain: {
            contractAddress: onChain.contractAddress,
            startDate: onChain.startDate ? onChain.startDate.toISOString() : null,
          }
        };

        if (!best || new Date(candidate.dueDate) < new Date(best.dueDate)) {
          best = candidate;
        }
      }

      // 2) search contributions for this tontine and this user
      const contributionsSnap = await db.collection('contributions')
        .where('tontineId', '==', t.tontineId)
        .where('userId', '==', normalized)
        .get();

      let candidateDueDate = null;
      let candidateAmount = null;
      let reason = null;

      for (const doc of contributionsSnap.docs) {
        const data = doc.data();
        const statut = normalizeStatus(data.statut || data.status);
        if (statut == 'PAYE') continue;

        // prefer dateEcheance then date
        const raw = data.dateEcheance || data.date || data.dateDue;
        const dueDate = parseDateTime(raw);

        if (dueDate == null) continue;

        if (candidateDueDate == null || dueDate < candidateDueDate) {
          candidateDueDate = dueDate;
          candidateAmount = Number(data.montant || data.amount || t.montant || t.monthlyAmount || 0);
          reason = 'contribution_non_payee';
        }
      }

      // 3) if no unpaid contribution, try allocation calendar in tontine doc
      if (candidateDueDate == null) {
        const tontineDoc = await db.collection('tontines').doc(t.tontineId).get();
        if (tontineDoc.exists) {
          const rawCal = tontineDoc.data().calendrierAllocations || tontineDoc.data().calendarAllocations || [];
          if (Array.isArray(rawCal)) {
            for (const slot of rawCal) {
              const userIdInSlot = String(slot.userId || slot.user || slot.wallet || '');
              if (userIdInSlot.toLowerCase() === normalized) {
                const val = slot.dateAllocation || slot.date;
                const d = parseDateTime(val);
                if (d) {
                  candidateDueDate = d;
                  candidateAmount = Number(t.monthlyAmount || t.montant || 0);
                  reason = 'allocation_calendar';
                  break;
                }
              }
            }
          }
        }
      }

      // 4) fallback: estimate next date based on frequency
      if (candidateDueDate == null) {
        const now = new Date();
        const freq = (t.frequency || 'Mensuel').toString().toLowerCase();
        let daysOffset = 30;
        if (freq.includes('heb') || freq.includes('week')) daysOffset = 7;
        else if (freq.includes('jour') || freq.includes('day')) daysOffset = 1;
        else if (freq.includes('trime')) daysOffset = 90;
        candidateDueDate = new Date(now.getTime() + daysOffset * 24 * 3600 * 1000);
        candidateAmount = Number(t.monthlyAmount || t.montant || 0);
        reason = 'estimated';
      }

      if (candidateDueDate) {
        const candidate = {
          tontine: {
            id: t.tontineId,
            name: t.name,
            monthlyAmount: Number(t.montantRecu || t.monthlyAmount || 0),
            maxMembers: t.maxMembers || null,
            frequency: t.frequency || null,
            status: t.status || t.statut || null,
          },
          dueDate: candidateDueDate.toISOString(),
          amount: candidateAmount,
          reason,
          cycle: t.currentCycle || null
        };

        if (!best) best = candidate;
        else if (new Date(candidate.dueDate) < new Date(best.dueDate)) {
          best = candidate;
        }
      }
    } catch (err) {
      console.error('[userService] getUserNextDue error for tontine', t.tontineId, err);
    }
  }

  return best;
}

// export
module.exports.getUserNextDue = getUserNextDue;
