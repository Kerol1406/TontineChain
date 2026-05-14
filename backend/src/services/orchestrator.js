const { config } = require('./config');
const { db } = require('./firebase');
const { getContract, sendTx } = require('./blockchain');
const { getContractByTontineId } = require('./contractRegistry');
const { reorderBeneficiaries, getCurrentBeneficiary } = require('./beneficiaryOrderService');
const { getCurrentBeneficiaryScore, recordLatePayment } = require('./scoreService');
const { queueAllocationReadyAlert, queueContributionReminder } = require('./notificationService');
const { appendTimelineEvent } = require('./historyService');

function toSafeNumber(value, fallback = 0) {
  if (value == null) return fallback;
  if (typeof value === 'number') return Number.isFinite(value) ? value : fallback;
  if (typeof value === 'bigint') return Number(value);
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function toBigIntSafe(value, fallback = 0n) {
  try {
    if (typeof value === 'bigint') return value;
    if (typeof value === 'number') return BigInt(Math.trunc(value));
    if (typeof value === 'string' && value.trim().length > 0) return BigInt(value);
    return fallback;
  } catch (_) {
    return fallback;
  }
}

async function getCurrentCycleSnapshot(contract, tontineId) {
  const cycleBig = await contract.cycleActuel(tontineId);
  const cycleId = toSafeNumber(cycleBig, 0);
  if (!cycleId) {
    return {
      cycleId: 0,
      dateDebut: 0,
      dateLimiteCotisation: 0,
      dateDistribution: 0,
      montantCollecte: 0n,
      distributionEffectuee: false
    };
  }

  const cycleData = await contract.cycles(tontineId, cycleId);
  return {
    cycleId,
    dateDebut: toSafeNumber(cycleData.dateDebut ?? cycleData[0], 0),
    dateLimiteCotisation: toSafeNumber(cycleData.dateLimiteCotisation ?? cycleData[1], 0),
    dateDistribution: toSafeNumber(cycleData.dateDistribution ?? cycleData[2], 0),
    montantCollecte: toBigIntSafe(cycleData.montantCollecte ?? cycleData[5], 0n),
    distributionEffectuee: Boolean(cycleData.distributionEffectuee ?? cycleData[7] ?? false)
  };
}

async function getScoreForCurrentBeneficiary(tontineId) {
  const currentBeneficiary = await getCurrentBeneficiaryScore(tontineId);
  if (!currentBeneficiary) return config.defaultScore;
  const score = Number(currentBeneficiary.score);
  if (Number.isNaN(score)) return config.defaultScore;
  return Math.max(0, Math.min(100, score));
}

async function orchestrateCurrentCycle(tontineId) {
  const contractMeta = await getContractByTontineId(tontineId);
  if (!contractMeta) {
    throw new Error(`No contract registered for tontineId=${tontineId}`);
  }

  const contract = getContract(contractMeta.contractAddress);
  const nowSec = Math.floor(Date.now() / 1000);
  const cycleSnapshot = await getCurrentCycleSnapshot(contract, tontineId);

  if (!cycleSnapshot.cycleId) {
    return {
      ok: true,
      action: 'SKIP_NO_ACTIVE_CYCLE',
      tontineId,
      contractAddress: contractMeta.contractAddress
    };
  }

  const shouldVerifyDefaults =
    cycleSnapshot.dateLimiteCotisation > 0 && nowSec > cycleSnapshot.dateLimiteCotisation;
  let verifyReceipt = null;
  if (shouldVerifyDefaults) {
    verifyReceipt = await sendTx(
      contract.verifyPaymentsAndHandleDefaults(tontineId),
      `verifyPaymentsAndHandleDefaults(${tontineId})`
    );
  }

  if (cycleSnapshot.distributionEffectuee) {
    return {
      ok: true,
      action: 'SKIP_ALREADY_DISTRIBUTED',
      tontineId,
      cycleId: cycleSnapshot.cycleId,
      contractAddress: contractMeta.contractAddress,
      verifyTriggered: Boolean(verifyReceipt)
    };
  }

  if (cycleSnapshot.dateDistribution > 0 && nowSec < cycleSnapshot.dateDistribution) {
    return {
      ok: true,
      action: 'WAIT_DISTRIBUTION_DATE',
      tontineId,
      cycleId: cycleSnapshot.cycleId,
      contractAddress: contractMeta.contractAddress,
      verifyTriggered: Boolean(verifyReceipt),
      nowSec,
      dateDistribution: cycleSnapshot.dateDistribution,
      dateLimiteCotisation: cycleSnapshot.dateLimiteCotisation
    };
  }

  const reordered = await reorderBeneficiaries(tontineId, { contract });
  const currentBeneficiary = reordered[0] || (await getCurrentBeneficiary(tontineId));
  const score = currentBeneficiary ? currentBeneficiary.score : await getScoreForCurrentBeneficiary(tontineId);

  await appendTimelineEvent({
    tontineId,
    type: 'cycle.orchestrated',
    title: 'Cycle orchestré',
    message: `Cycle lancé pour ${tontineId}`,
    payload: { score, beneficiary: currentBeneficiary?.wallet || null }
  });

  const distributionReceipt = await sendTx(
    contract.distributeAllocation(tontineId, score),
    `distributeAllocation(${tontineId}, score=${score})`
  );

  if (currentBeneficiary?.wallet) {
    await queueAllocationReadyAlert(tontineId, currentBeneficiary.wallet, { score, contractAddress: contractMeta.contractAddress });
  }

  const currentCycle = await contract.cycleActuel(tontineId);

  return {
    ok: true,
    action: 'DISTRIBUTED',
    tontineId,
    contractAddress: contractMeta.contractAddress,
    scoreUsed: score,
    beneficiary: currentBeneficiary?.wallet || null,
    orderSize: reordered.length,
    nextCycle: currentCycle.toString(),
    distributedTxHash: distributionReceipt?.tx?.hash || null,
    verifyTriggered: Boolean(verifyReceipt)
  };
}

module.exports = {
  orchestrateCurrentCycle
};
