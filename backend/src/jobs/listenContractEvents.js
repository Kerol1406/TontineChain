const { config } = require('../services/config');
const { getContract } = require('../services/blockchain');
const { listActiveContracts } = require('../services/contractRegistry');
const { persistChainEvent, updateMemberProjection, updateCycleProjection, recordOffchainHistory } = require('../services/eventSync');
const { ensureGlobalScore, recordOnTimePayment, recordLatePayment, recordAllocationReceived } = require('../services/scoreService');
const { queueLatePaymentAlert } = require('../services/notificationService');

async function attachListenersForContract(contractMeta) {
  const { tontineId, contractAddress, network } = contractMeta;
  const contract = getContract(contractAddress);

  console.log(`[listener] attaching ${tontineId} @ ${contractAddress}`);

  contract.on('DemandAdhesionEnvoyee', async (wallet, pseudo, timestamp, event) => {
    const args = {
      wallet: wallet.toLowerCase(),
      pseudo,
      timestamp: timestamp.toString()
    };

    await persistChainEvent({
      tontineId,
      contractAddress,
      network,
      eventName: 'DemandAdhesionEnvoyee',
      txHash: event.log.transactionHash,
      blockNumber: event.log.blockNumber,
      args
    });

    await updateMemberProjection({
      tontineId,
      wallet,
      patch: { pseudo, status: 'REQUESTED' }
    });

    await ensureGlobalScore(wallet, { pseudo, source: 'DemandAdhesionEnvoyee', tontineId });
    await recordOffchainHistory({
      tontineId,
      type: 'member.requested',
      title: 'Demande d’adhésion reçue',
      message: `${wallet.toLowerCase()} a demandé à rejoindre la tontine`,
      actor: wallet.toLowerCase(),
      payload: args
    });
  });

  contract.on('GarantieDeposeee', async (wallet, montant, timestamp, event) => {
    const args = {
      wallet: wallet.toLowerCase(),
      montant: montant.toString(),
      timestamp: timestamp.toString()
    };

    await persistChainEvent({
      tontineId,
      contractAddress,
      network,
      eventName: 'GarantieDeposeee',
      txHash: event.log.transactionHash,
      blockNumber: event.log.blockNumber,
      args
    });

    await updateMemberProjection({
      tontineId,
      wallet,
      patch: { status: 'ACTIVE', garantieBloquee: montant.toString() }
    });

    await recordOffchainHistory({
      tontineId,
      type: 'member.guarantee_deposited',
      title: 'Garantie déposée',
      message: `${wallet.toLowerCase()} a déposé une garantie`,
      actor: wallet.toLowerCase(),
      payload: args
    });
  });

  contract.on('CotisationPayee', async (wallet, cycleId, montant, timestamp, event) => {
    const args = {
      wallet: wallet.toLowerCase(),
      cycleId: cycleId.toString(),
      montant: montant.toString(),
      timestamp: timestamp.toString()
    };

    await persistChainEvent({
      tontineId,
      contractAddress,
      network,
      eventName: 'CotisationPayee',
      txHash: event.log.transactionHash,
      blockNumber: event.log.blockNumber,
      args
    });

    await updateCycleProjection({
      tontineId,
      cycleId,
      patch: {
        lastContributionAt: new Date().toISOString(),
        lastContributor: wallet.toLowerCase()
      }
    });

    await recordOnTimePayment(tontineId, wallet, { cycleId: cycleId.toString(), montant: montant.toString() });
  });

  contract.on('RetardDetecte', async (wallet, cycleId, timestamp, event) => {
    const args = {
      wallet: wallet.toLowerCase(),
      cycleId: cycleId.toString(),
      timestamp: timestamp.toString()
    };

    await persistChainEvent({
      tontineId,
      contractAddress,
      network,
      eventName: 'RetardDetecte',
      txHash: event.log.transactionHash,
      blockNumber: event.log.blockNumber,
      args
    });

    await updateMemberProjection({
      tontineId,
      wallet,
      patch: { status: 'LATE' }
    });

    // Record late payment AND trigger score drop + reorder in all eligible tontines
    await recordLatePayment(tontineId, wallet, { 
      cycleId: cycleId.toString(),
      source: 'RetardDetecte_event'
    });

    // Send alert notification to the member
    await queueLatePaymentAlert(tontineId, wallet, {
      cycleId: cycleId.toString(),
      blockNumber: event.log.blockNumber.toString()
    });

    await recordOffchainHistory({
      tontineId,
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
    const [beneficiaire, cycleId, montantTotal, montantLibere, montantReserve, scoreConfiance, timestamp] = raw;

    const args = {
      beneficiaire: beneficiaire.toLowerCase(),
      cycleId: cycleId.toString(),
      montantTotal: montantTotal.toString(),
      montantLibere: montantLibere.toString(),
      montantReserve: montantReserve.toString(),
      scoreConfiance: scoreConfiance.toString(),
      timestamp: timestamp.toString()
    };

    await persistChainEvent({
      tontineId,
      contractAddress,
      network,
      eventName: 'AllocationDistribuee',
      txHash: event.log.transactionHash,
      blockNumber: event.log.blockNumber,
      args
    });

    await updateMemberProjection({
      tontineId,
      wallet: beneficiaire,
      patch: {
        aRecu: true,
        dernierMontantLibere: montantLibere.toString(),
        dernierMontantReserve: montantReserve.toString()
      }
    });

    await updateCycleProjection({
      tontineId,
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

    await recordAllocationReceived(tontineId, beneficiaire, {
      cycleId: cycleId.toString(),
      montantTotal: montantTotal.toString(),
      montantLibere: montantLibere.toString(),
      montantReserve: montantReserve.toString(),
      scoreConfiance: Number(scoreConfiance)
    });
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
