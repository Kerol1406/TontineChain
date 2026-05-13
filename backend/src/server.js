const express = require('express');
const cors = require('cors');
const { config } = require('./services/config');
const { wallet } = require('./services/blockchain');
const { orchestrationRoutes } = require('./routes/orchestrationRoutes');
const { offchainRoutes } = require('./routes/offchainRoutes');
const userRoutes = require('./routes/userRoutes');

const app = express();
app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => {
  res.status(200).json({ ok: true, network: config.networkName, backendAddress: wallet.address });
});

app.use('/api', orchestrationRoutes);
app.use('/api', offchainRoutes);
app.use('/api', userRoutes);

app.listen(config.port, () => {
  console.log(`[server] listening on port ${config.port}`);
  console.log(`[server] network=${config.networkName}`);
  console.log(`[server] backendAddress=${wallet.address}`);
});
