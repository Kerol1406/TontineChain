const { listActiveContracts } = require('../services/contractRegistry');
const { orchestrateCurrentCycle } = require('../services/orchestrator');
const { config } = require('../services/config');

let schedulerStarted = false;
let schedulerRunning = false;
let tickTimer = null;

async function runSchedulerTick() {
  if (schedulerRunning) return;
  schedulerRunning = true;

  try {
    const contracts = await listActiveContracts(config.networkName);
    for (const contractMeta of contracts) {
      try {
        const result = await orchestrateCurrentCycle(contractMeta.tontineId || contractMeta.id);
        if (result?.action && result.action !== 'WAIT_DISTRIBUTION_DATE' && result.action !== 'SKIP_NO_ACTIVE_CYCLE') {
          console.log(`[scheduler] ${contractMeta.tontineId || contractMeta.id}: ${result.action}`);
        }
      } catch (error) {
        console.warn(`[scheduler] orchestration failed for ${contractMeta.tontineId || contractMeta.id}:`, error.message || error);
      }
    }
  } finally {
    schedulerRunning = false;
  }
}

function startCycleScheduler() {
  if (schedulerStarted) return;
  schedulerStarted = true;

  const intervalMs = Number(process.env.CYCLE_SCHEDULER_INTERVAL_MS || 60000);
  const initialDelayMs = Number(process.env.CYCLE_SCHEDULER_INITIAL_DELAY_MS || 10000);

  setTimeout(() => {
    runSchedulerTick().catch((error) => {
      console.warn('[scheduler] initial tick failed:', error.message || error);
    });
  }, initialDelayMs);

  tickTimer = setInterval(() => {
    runSchedulerTick().catch((error) => {
      console.warn('[scheduler] tick failed:', error.message || error);
    });
  }, intervalMs);

  if (typeof tickTimer.unref === 'function') {
    tickTimer.unref();
  }

  console.log(`[scheduler] cycle scheduler started every ${intervalMs}ms`);
}

module.exports = {
  startCycleScheduler,
  runSchedulerTick
};