const { config } = require('./config');
const { db } = require('./firebase');
const { getContract, sendTx } = require('./blockchain');
const { getContractByTontineId } = require('./contractRegistry');
const { reorderBeneficiaries, getCurrentBeneficiary } = require('./beneficiaryOrderService');
const { getCurrentBeneficiaryScore, recordLatePayment } = require('./scoreService');
const { queueAllocationReadyAlert, queueContributionReminder } = require('./notificationService');
const { appendTimelineEvent } = require('./historyService');

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

  await sendTx(contract.verifyPaymentsAndHandleDefaults(), 'verifyPaymentsAndHandleDefaults');
  await sendTx(contract.distributeAllocation(score), `distributeAllocation(score=${score})`);

  if (currentBeneficiary?.wallet) {
    await queueAllocationReadyAlert(tontineId, currentBeneficiary.wallet, { score, contractAddress: contractMeta.contractAddress });
  }

  const currentCycle = await contract.cycleActuel();

  return {
    tontineId,
    contractAddress: contractMeta.contractAddress,
    scoreUsed: score,
    beneficiary: currentBeneficiary?.wallet || null,
    orderSize: reordered.length,
    nextCycle: currentCycle.toString()
  };
}

module.exports = {
  orchestrateCurrentCycle
};
