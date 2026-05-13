const express = require('express');
const { orchestrateCurrentCycle } = require('../services/orchestrator');

const router = express.Router();

router.post('/orchestrate-cycle', async (req, res) => {
  try {
    const { tontineId } = req.body || {};
    if (!tontineId || typeof tontineId !== 'string') {
      return res.status(400).json({ error: 'Missing tontineId' });
    }

    const result = await orchestrateCurrentCycle(tontineId);
    return res.status(200).json({ ok: true, result });
  } catch (error) {
    console.error('[api] orchestrate-cycle error', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

module.exports = { orchestrationRoutes: router };
