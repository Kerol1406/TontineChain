const { config } = require('../services/config');
const { getContract } = require('../services/blockchain');
const { db, admin } = require('../services/firebase');
const { listActiveContracts } = require('../services/contractRegistry');
const { persistChainEvent, updateMemberProjection, updateCycleProjection, recordOffchainHistory } = require('../services/eventSync');
const { ensureGlobalScore, recordOnTimePayment, recordLatePayment, recordAllocationReceived } = require('../services/scoreService');
const { queueLatePaymentAlert } = require('../services/notificationService');

async function findUserDocByWallet(wallet) {
  const target = String(wallet || '').trim();
  if (!target) return null;

  const candidates = Array.from(new Set([target, target.toLowerCase(), target.toUpperCase()]));
  const fields = ['walletAddress', 'wallet'];

  for (const field of fields) {
    for (const candidate of candidates) {
      const snap = await db.collection('users').where(field, '==', candidate).limit(1).get();
      if (!snap.empty) return snap.docs[0];
    }
  }

  const fallback = await db.collection('users').limit(500).get();
  const lowerTarget = target.toLowerCase();
  for (const doc of fallback.docs) {
    const data = doc.data() || {};
    const rawWallet = String(data.walletAddress || data.wallet || '').toLowerCase();
    if (rawWallet && rawWallet === lowerTarget) return doc;
  }

  return null;
}

async function creditBeneficiaryWallet({ tontineId, beneficiaryWallet, montantLibere, txHash, cycleId }) {
  const amount = Number(montantLibere || 0);
  if (!Number.isFinite(amount) || amount <= 0) {
    return { credited: false, reason: 'NO_AMOUNT' };
  }

  const userDoc = await findUserDocByWallet(beneficiaryWallet);
  if (!userDoc) {
    return { credited: false, reason: 'USER_NOT_FOUND' };
  }

  const userData = userDoc.data() || {};
  const currentSolde = Number(userData.solde || 0);
  const safeCurrentSolde = Number.isFinite(currentSolde) ? currentSolde : 0;
  const newSolde = safeCurrentSolde + amount;

  await userDoc.ref.update({
    solde: newSolde,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  await db.collection('transactions').add({
    type: 'GAIN',
    tontineId,
    userId: userDoc.id,
    toUserId: userDoc.id,
    montant: amount,
    description: `Distribution cagnotte cycle ${cycleId}`,
    blockchainHash: txHash || null,
    deleted: false,
    date: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  return {
    credited: true,
    userId: userDoc.id,
    previousSolde: safeCurrentSolde,
    newSolde
  };
}

async function createGlobalNotification({ userId, tontineId, type, title, message, metadata = {} }) {
  if (!userId) return;

  await db.collection('notifications').add({
    userId,
    tontineId,
    type,
    title,
    message,
    metadata,
    read: false,
    deleted: false,
    date: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
}

async function attachListenersForContract(contractMeta) {
  const { tontineId, contractAddress, network } = contractMeta;
  const contract = getContract(contractAddress);

  console.log(`[listener] attaching ${tontineId} @ ${contractAddress}`);

  contract.on('DemandAdhesionEnvoyee', async (eventTontineId, wallet, pseudo, timestamp, event) => {
    const args = {
      tontineId: eventTontineId,
      wallet: wallet.toLowerCase(),
      pseudo,
      timestamp: timestamp.toString()
    };

    await persistChainEvent({
      tontineId: eventTontineId,
      contractAddress,
      network,
      eventName: 'DemandAdhesionEnvoyee',
      txHash: event.log.transactionHash,
      blockNumber: event.log.blockNumber,
      args
    });

    await updateMemberProjection({
      tontineId: eventTontineId,
      wallet,
      patch: { pseudo, status: 'REQUESTED' }
    });

    await ensureGlobalScore(wallet, { pseudo, source: 'DemandAdhesionEnvoyee', tontineId: eventTontineId });
    await recordOffchainHistory({
      tontineId: eventTontineId,
      type: 'member.requested',
      title: 'Demande d’adhésion reçue',
      message: `${wallet.toLowerCase()} a demandé à rejoindre la tontine`,
      actor: wallet.toLowerCase(),
      payload: args
    });
  });

  contract.on('GarantieDeposeee', async (eventTontineId, wallet, montant, timestamp, event) => {
    const args = {
      tontineId: eventTontineId,
      wallet: wallet.toLowerCase(),
      montant: montant.toString(),
      timestamp: timestamp.toString()
    };

    await persistChainEvent({
      tontineId: eventTontineId,
      contractAddress,
      network,
      eventName: 'GarantieDeposeee',
      txHash: event.log.transactionHash,
      blockNumber: event.log.blockNumber,
      args
    });

    await updateMemberProjection({
      tontineId: eventTontineId,
      wallet,
      patch: { status: 'ACTIVE', garantieBloquee: montant.toString() }
    });

    await recordOffchainHistory({
      tontineId: eventTontineId,
      type: 'member.guarantee_deposited',
      title: 'Garantie déposée',
      message: `${wallet.toLowerCase()} a déposé une garantie`,
      actor: wallet.toLowerCase(),
      payload: args
    });
  });

  contract.on('CotisationPayee', async (eventTontineId, wallet, cycleId, montant, timestamp, event) => {
    const args = {
      tontineId: eventTontineId,
      wallet: wallet.toLowerCase(),
      cycleId: cycleId.toString(),
      montant: montant.toString(),
      timestamp: timestamp.toString()
    };

    await persistChainEvent({
      tontineId: eventTontineId,
      contractAddress,
      network,
      eventName: 'CotisationPayee',
      txHash: event.log.transactionHash,
      blockNumber: event.log.blockNumber,
      args
    });

    await updateCycleProjection({
      tontineId: eventTontineId,
      cycleId,
      patch: {
        lastContributionAt: new Date().toISOString(),
        lastContributor: wallet.toLowerCase()
      }
    });

    await recordOnTimePayment(eventTontineId, wallet, { cycleId: cycleId.toString(), montant: montant.toString() });
  });

  contract.on('RetardDetecte', async (eventTontineId, wallet, cycleId, timestamp, event) => {
    const args = {
      tontineId: eventTontineId,
      wallet: wallet.toLowerCase(),
      cycleId: cycleId.toString(),
      timestamp: timestamp.toString()
    };

    await persistChainEvent({
      tontineId: eventTontineId,
      contractAddress,
      network,
      eventName: 'RetardDetecte',
      txHash: event.log.transactionHash,
      blockNumber: event.log.blockNumber,
      args
    });

    await updateMemberProjection({
      tontineId: eventTontineId,
      wallet,
      patch: { status: 'LATE' }
    });

    // Record late payment AND trigger score drop + reorder in all eligible tontines
    await recordLatePayment(eventTontineId, wallet, { 
      cycleId: cycleId.toString(),
      source: 'RetardDetecte_event'
    });

    // Send alert notification to the member
    await queueLatePaymentAlert(eventTontineId, wallet, {
      cycleId: cycleId.toString(),
      blockNumber: event.log.blockNumber.toString()
    });

    await recordOffchainHistory({
      tontineId: eventTontineId,
      type: 'payment.late_detected',
      title: 'Retard de paiement détecté',
      message: `${wallet.toLowerCase()} a un retard de paiement au cycle ${cycleId}`,
      actor: wallet.toLowerCase(),
      payload: args,
      severity: 'warning'
    });

    console.log(`[listener] late payment detected for ${wallet.toLowerCase()} in cycle ${cycleId}`);
  });

  contract.on('AllocationDistribuee', async (...raw) => {
    const event = raw[raw.length - 1];
    const [eventTontineId, beneficiaire, cycleId, montantTotal, montantLibere, montantReserve, scoreConfiance, timestamp] = raw;

    const args = {
      tontineId: eventTontineId,
      beneficiaire: beneficiaire.toLowerCase(),
      cycleId: cycleId.toString(),
      montantTotal: montantTotal.toString(),
      montantLibere: montantLibere.toString(),
      montantReserve: montantReserve.toString(),
      scoreConfiance: scoreConfiance.toString(),
      timestamp: timestamp.toString()
    };

    await persistChainEvent({
      tontineId: eventTontineId,
      contractAddress,
      network,
      eventName: 'AllocationDistribuee',
      txHash: event.log.transactionHash,
      blockNumber: event.log.blockNumber,
      args
    });

    await updateMemberProjection({
      tontineId: eventTontineId,
      wallet: beneficiaire,
      patch: {
        aRecu: true,
        dernierMontantLibere: montantLibere.toString(),
        dernierMontantReserve: montantReserve.toString()
      }
    });

    await updateCycleProjection({
      tontineId: eventTontineId,
      cycleId,
      patch: {
        status: 'FINISHED',
        beneficiaire: beneficiaire.toLowerCase(),
        montantTotal: montantTotal.toString(),
        montantLibere: montantLibere.toString(),
        montantReserve: montantReserve.toString(),
        scoreConfiance: Number(scoreConfiance)
      }
    });

    await recordAllocationReceived(eventTontineId, beneficiaire, {
      tontineId: eventTontineId,
      cycleId: cycleId.toString(),
      montantTotal: montantTotal.toString(),
      montantLibere: montantLibere.toString(),
      montantReserve: montantReserve.toString(),
      scoreConfiance: Number(scoreConfiance)
    });

    const creditResult = await creditBeneficiaryWallet({
      tontineId: eventTontineId,
      beneficiaryWallet: beneficiaire,
      montantLibere: montantLibere.toString(),
      txHash: event.log.transactionHash,
      cycleId: cycleId.toString()
    });

    if (!creditResult.credited) {
      console.warn(
        `[listener] wallet credit skipped for ${beneficiaire.toLowerCase()} ` +
        `(${creditResult.reason}) on tontine ${eventTontineId}`
      );
    } else {
      await createGlobalNotification({
        userId: creditResult.userId,
        tontineId: eventTontineId,
        type: 'allocation_ready',
        title: 'Cagnotte libérée',
        message: `Votre cagnotte a été ajoutée à votre portefeuille pour le cycle ${cycleId}.`,
        metadata: {
          txHash: event.log.transactionHash,
          cycleId: cycleId.toString(),
          montantLibere: montantLibere.toString(),
          montantReserve: montantReserve.toString()
        }
      });
    }
  });
}

async function main() {
  const contracts = await listActiveContracts(config.networkName);
  if (!contracts.length) {
    console.log(`[listener] no active contracts for network ${config.networkName}`);
    process.exit(0);
  }

  await Promise.all(contracts.map(attachListenersForContract));
  console.log(`[listener] watching ${contracts.length} contract(s)`);
}

main().catch((error) => {
  console.error('[listener] fatal error', error);
  process.exit(1);
});
