const { orchestrateCurrentCycle } = require('../services/orchestrator');

async function main() {
  const tontineId = process.argv[2];
  if (!tontineId) {
    throw new Error('Usage: npm run orchestrate -- <tontineId>');
  }

  const result = await orchestrateCurrentCycle(tontineId);
  console.log('[orchestrate] done', result);
}

main().catch((error) => {
  console.error('[orchestrate] fatal', error.message);
  process.exit(1);
});
