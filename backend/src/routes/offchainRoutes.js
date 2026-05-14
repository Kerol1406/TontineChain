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

module.exports = { offchainRoutes: router };