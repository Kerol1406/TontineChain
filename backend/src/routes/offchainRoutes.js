const express = require('express');
const { computeBeneficiaryOrder, reorderBeneficiaries } = require('../services/beneficiaryOrderService');
const { generateInvitationCode, getJoinPolicy, setJoinPolicy, validateInvitationCode, markInvitationUsed } = require('../services/invitationCodeService');
const { listNotifications, markNotificationRead } = require('../services/notificationService');
const { listTimelineEvents } = require('../services/historyService');
const { getScoresForTontineMembers, getAllGlobalScores } = require('../services/scoreService');
const { getContractByTontineId } = require('../services/contractRegistry');
const { deployTontineContract } = require('../services/tontineDeploymentService');

const router = express.Router();

router.post('/tontines/deploy', async (req, res) => {
  try {
    const {
      tontineId,
      name,
      monthlyAmount,
      frequency,
      maxMembers,
      creatorId,
      creatorWallet,
      creatorPseudo,
      isPublic = false,
      callMembersEnabled = false
    } = req.body || {};

    if (!tontineId || !name || monthlyAmount == null || maxMembers == null || !creatorId) {
      return res.status(400).json({
        ok: false,
        error: 'Missing required fields: tontineId, name, monthlyAmount, maxMembers, creatorId'
      });
    }

    const result = await deployTontineContract({
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
    });

    return res.status(201).json({ ok: true, result });
  } catch (error) {
    console.error('[api] deploy tontine error', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

router.post('/tontines/:tontineId/members/join', async (req, res) => {
  try {
    const { tontineId } = req.params;
    const { memberWallet, pseudo = '' } = req.body || {};

    if (!memberWallet) {
      return res.status(400).json({ ok: false, error: 'memberWallet is required' });
    }

    const contractData = await getContractByTontineId(tontineId);
    if (!contractData?.contractAddress) {
      return res.status(404).json({ ok: false, error: 'Contract not found for this tontine' });
    }

    const { getContract, sendTx } = require('../services/blockchain');
    const contract = getContract(contractData.contractAddress);
    const receipt = await sendTx(contract.joinTontine(tontineId, memberWallet, pseudo), `joinTontine(${tontineId})`);

    return res.status(201).json({ ok: true, result: { txHash: receipt.tx.hash, blockNumber: receipt.receipt.blockNumber } });
  } catch (error) {
    console.error('[api] join tontine error', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

/**
 * POST /api/tontines/:tontineId/pay
 * Trigger payContribution on-chain using the backend wallet.
 * Body: { userId, memberWallet?, cycleId? }
 */
router.post('/tontines/:tontineId/pay', async (req, res) => {
  try {
    const { tontineId } = req.params;
    const { userId, memberWallet, cycleId = 0 } = req.body || {};

    const contractData = await getContractByTontineId(tontineId);
    if (!contractData?.contractAddress) {
      return res.status(404).json({ ok: false, error: 'Contract not found for this tontine' });
    }

    const { getContract, sendTx } = require('../services/blockchain');
    const contract = getContract(contractData.contractAddress);

    let resolvedMember = String(memberWallet || '').trim();
    if (!resolvedMember && userId) {
      const { db } = require('../services/firebase');

      // Firebase UID is not a wallet address; look up the exact user document id first.
      const exactSnap = await db.collection('users').doc(String(userId).trim()).get();
      if (exactSnap.exists) {
        const profile = exactSnap.data() || {};
        resolvedMember = String(profile.walletAddress || profile.wallet || '').trim();
      }

      // Fallback: if a wallet-like identifier was passed as userId, try the existing profile helper.
      if (!resolvedMember) {
        const { getUserProfile } = require('../services/userService');
        const profile = await getUserProfile(userId);
        resolvedMember = String(profile?.walletAddress || profile?.wallet || '').trim();
      }
    }

    if (!resolvedMember || !/^0x[a-fA-F0-9]{40}$/.test(resolvedMember)) {
      return res.status(400).json({ ok: false, error: 'A valid memberWallet or userId is required' });
    }

    const tontineInfo = await contract.getTontine(tontineId);
    const contributionAmount = tontineInfo[1];

    const ensureMemberOnChain = async () => {
      try {
        await sendTx(
          contract.joinTontine(tontineId, resolvedMember, ''),
          `joinTontine(${tontineId}) [auto-repair]`
        );
        return true;
      } catch (joinError) {
        const message = String(joinError?.message || joinError);
        if (/Already member/i.test(message)) {
          return true;
        }
        throw joinError;
      }
    };

    // Determine cycle to pay: prefer explicit cycleId, else contract current cycle, else 1
    let currentCycle = Number(cycleId || 0);
    if (!currentCycle) {
      try {
        const cycleBig = await contract.cycleActuel(tontineId);
        currentCycle = Number(cycleBig || 0);
      } catch (e) {
        currentCycle = 0;
      }
    }
    if (!currentCycle) currentCycle = 1;

    let receipt;
    try {
      receipt = await sendTx(
        contract.payContribution(tontineId, currentCycle, resolvedMember, { value: contributionAmount }),
        `payContribution(${tontineId}, cycle=${currentCycle})`
      );
    } catch (payError) {
      const message = String(payError?.message || payError);
      if (!/Not a member/i.test(message)) {
        throw payError;
      }

      const repaired = await ensureMemberOnChain();
      if (!repaired) {
        throw payError;
      }

      receipt = await sendTx(
        contract.payContribution(tontineId, currentCycle, resolvedMember, { value: contributionAmount }),
        `payContribution(${tontineId}, cycle=${currentCycle}) [retry]`
      );
    }

    try {
      const { db, admin } = require('../services/firebase');
      const contributionSnap = await db.collection('contributions')
        .where('tontineId', '==', tontineId)
        .where('deleted', '==', false)
        .where('userId', '==', userId || resolvedMember)
        .where('cycle', '==', currentCycle)
        .limit(1)
        .get();

      if (!contributionSnap.empty) {
        await contributionSnap.docs[0].ref.update({
          statut: 'PAYE',
          txHash: receipt.tx.hash,
          datePaiement: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }
    } catch (updateError) {
      console.warn('[api] contribution firestore update skipped:', updateError.message || updateError);
    }

    let orchestration = null;
    try {
      const { orchestrateCurrentCycle } = require('../services/orchestrator');
      orchestration = await orchestrateCurrentCycle(tontineId);
    } catch (orchestrationError) {
      console.warn('[api] post-payment orchestration skipped:', orchestrationError.message || orchestrationError);
      orchestration = {
        ok: false,
        error: orchestrationError.message || String(orchestrationError)
      };
    }

    return res.status(200).json({
      ok: true,
      txHash: receipt.tx.hash,
      blockNumber: receipt.receipt.blockNumber,
      cycleId: currentCycle,
      memberWallet: resolvedMember,
      contributionAmount: contributionAmount.toString(),
      orchestration
    });
  } catch (error) {
    console.error('[api] pay contribution error', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

router.get('/tontines/:tontineId/contract', async (req, res) => {
  try {
    const { tontineId } = req.params;
    const contractData = await getContractByTontineId(tontineId);
    
    if (!contractData) {
      return res.status(404).json({ ok: false, error: 'Contract not found for this tontine' });
    }
    
    return res.status(200).json({ 
      ok: true, 
      contractAddress: contractData.contractAddress,
      network: contractData.network,
      creatorWallet: contractData.creatorWallet
    });
  } catch (error) {
    console.error('[api] contract error', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

router.get('/tontines/:tontineId/scores', async (req, res) => {
  try {
    const { tontineId } = req.params;
    const scores = await getScoresForTontineMembers(tontineId);
    return res.status(200).json({ ok: true, scores });
  } catch (error) {
    console.error('[api] scores error', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

router.get('/tontines/:tontineId/order', async (req, res) => {
  try {
    const { tontineId } = req.params;
    const order = await computeBeneficiaryOrder(tontineId);
    return res.status(200).json({ ok: true, order });
  } catch (error) {
    console.error('[api] order error', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

router.post('/tontines/:tontineId/order/recompute', async (req, res) => {
  try {
    const { tontineId } = req.params;
    const result = await reorderBeneficiaries(tontineId);
    return res.status(200).json({ ok: true, result });
  } catch (error) {
    console.error('[api] reorder error', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

router.get('/tontines/:tontineId/join-policy', async (req, res) => {
  try {
    const { tontineId } = req.params;
    const policy = await getJoinPolicy(tontineId);
    return res.status(200).json({ ok: true, policy });
  } catch (error) {
    console.error('[api] join-policy error', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

router.post('/tontines/:tontineId/join-policy', async (req, res) => {
  try {
    const { tontineId } = req.params;
    const patch = {};
    if (typeof req.body?.invitationRequired === 'boolean') patch.invitationRequired = req.body.invitationRequired;
    if (typeof req.body?.callMembersEnabled === 'boolean') patch.callMembersEnabled = req.body.callMembersEnabled;
    await setJoinPolicy(tontineId, patch);
    return res.status(200).json({ ok: true, policy: patch });
  } catch (error) {
    console.error('[api] join-policy update error', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

router.post('/tontines/:tontineId/invites', async (req, res) => {
  try {
    const { tontineId } = req.params;
    const { issuedBy = null, expiresInHours = 72, maxUses = 1, note = '' } = req.body || {};
    const result = await generateInvitationCode({ tontineId, issuedBy, expiresInHours, maxUses, note });
    return res.status(200).json({ ok: true, result });
  } catch (error) {
    console.error('[api] invite create error', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

router.post('/tontines/:tontineId/invites/validate', async (req, res) => {
  try {
    const { tontineId } = req.params;
    const { code } = req.body || {};
    const result = await validateInvitationCode(tontineId, code);
    return res.status(200).json({ ok: true, result });
  } catch (error) {
    console.error('[api] invite validate error', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

router.post('/tontines/:tontineId/invites/use', async (req, res) => {
  try {
    const { tontineId } = req.params;
    const { code, wallet } = req.body || {};
    await markInvitationUsed(tontineId, code, wallet);
    return res.status(200).json({ ok: true });
  } catch (error) {
    console.error('[api] invite use error', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

router.get('/tontines/:tontineId/notifications', async (req, res) => {
  try {
    const { tontineId } = req.params;
    const unreadOnly = String(req.query.unreadOnly || 'false') === 'true';
    const notifications = await listNotifications(tontineId, { unreadOnly });
    return res.status(200).json({ ok: true, notifications });
  } catch (error) {
    console.error('[api] notifications error', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

router.post('/tontines/:tontineId/notifications/:notificationId/read', async (req, res) => {
  try {
    const { tontineId, notificationId } = req.params;
    await markNotificationRead(tontineId, notificationId);
    return res.status(200).json({ ok: true });
  } catch (error) {
    console.error('[api] notification read error', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

router.get('/tontines/:tontineId/timeline', async (req, res) => {
  try {
    const { tontineId } = req.params;
    const timeline = await listTimelineEvents({ tontineId });
    return res.status(200).json({ ok: true, timeline });
  } catch (error) {
    console.error('[api] timeline error', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

router.get('/tontines/:tontineId/history', async (req, res) => {
  try {
    const { tontineId } = req.params;
    const { db } = require('../services/firebase');
    const { getUserProfile } = require('../services/userService');

    const nameCache = new Map();

    const resolveMemberName = async (identifier) => {
      const key = String(identifier || '').trim();
      if (!key) return '';
      if (nameCache.has(key)) return nameCache.get(key);

      try {
        const profile = await getUserProfile(key);
        const firstName = String(profile?.firstName || '').trim();
        const lastName = String(profile?.lastName || '').trim();
        const displayName = [firstName, lastName].filter(Boolean).join(' ').trim()
          || String(profile?.pseudo || profile?.name || profile?.displayName || '').trim()
          || key;
        nameCache.set(key, displayName);
        return displayName;
      } catch (_) {
        nameCache.set(key, key);
        return key;
      }
    };

    const [paymentSnap, transactionSnap, allocationSnap] = await Promise.all([
      db.collection('contributions')
        .where('tontineId', '==', tontineId)
        .where('deleted', '==', false)
        .where('statut', '==', 'PAYE')
        .get(),
      db.collection('transactions')
        .where('tontineId', '==', tontineId)
        .where('deleted', '==', false)
        .get(),
      db.collection('tontines').doc(tontineId).collection('chainEvents')
        .where('eventName', '==', 'AllocationDistribuee')
        .get(),
    ]);

    const history = [];

    for (const doc of paymentSnap.docs) {
      const data = doc.data() || {};
      const memberName = await resolveMemberName(data.userId);
      history.push({
        id: doc.id,
        kind: 'payment',
        date: data.datePaiement || data.updatedAt || data.date || null,
        member: memberName,
        action: 'Cotisation payée',
        amount: data.montant ?? 0,
        currency: 'FCFA',
        source: 'contributions',
        raw: data,
      });
    }

    for (const doc of transactionSnap.docs) {
      const data = doc.data() || {};
      const type = String(data.type || '').toUpperCase();
      if (!['COTISATION', 'GAIN', 'CREATION_TONTINE', 'AJOUT_MEMBRE'].includes(type)) {
        continue;
      }

      const actionByType = {
        COTISATION: 'Cotisation payée',
        GAIN: 'Cagnotte libérée',
        CREATION_TONTINE: 'Tontine créée',
        AJOUT_MEMBRE: 'Membre ajouté',
      };

      const memberName = await resolveMemberName(data.toUserId || data.userId || data.fromUserId);

      history.push({
        id: doc.id,
        kind: type === 'GAIN' ? 'allocation' : 'transaction',
        date: data.date || data.updatedAt || data.createdAt || null,
        member: memberName,
        action: actionByType[type] || type,
        amount: data.montant ?? data.amount ?? 0,
        currency: 'FCFA',
        source: 'transactions',
        raw: data,
      });
    }

    for (const doc of allocationSnap.docs) {
      const data = doc.data() || {};
      const args = data.args || {};
      const memberName = await resolveMemberName(args.beneficiaire);
      history.push({
        id: doc.id,
        kind: 'allocation',
        date: args.timestamp || data.createdAt || null,
        member: memberName,
        action: 'Cagnotte libérée',
        amount: args.montantLibere ?? args.montantTotal ?? 0,
        currency: 'FCFA',
        source: 'chainEvents',
        raw: data,
      });
    }

    history.sort((left, right) => {
      const leftDate = left.date?.toMillis ? left.date.toMillis() : new Date(left.date || 0).getTime();
      const rightDate = right.date?.toMillis ? right.date.toMillis() : new Date(right.date || 0).getTime();
      return rightDate - leftDate;
    });

    return res.status(200).json({ ok: true, history });
  } catch (error) {
    console.error('[api] history error', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

module.exports = { offchainRoutes: router };