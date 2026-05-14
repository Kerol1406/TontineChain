require('dotenv').config();

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
}

const config = {
  port: Number(process.env.PORT || 8787),
  networkName: process.env.NETWORK_NAME || 'polygon-amoy',
  rpcUrl: requireEnv('RPC_URL'),
  backendPrivateKey: requireEnv('BACKEND_PRIVATE_KEY'),
  centralContractAddress: (process.env.CENTRAL_CONTRACT_ADDRESS || '').trim(),
  firebaseProjectId: requireEnv('FIREBASE_PROJECT_ID'),
  firebaseClientEmail: requireEnv('FIREBASE_CLIENT_EMAIL'),
  firebasePrivateKey: requireEnv('FIREBASE_PRIVATE_KEY').replace(/\\n/g, '\n'),
  walletEncryptionKey: (process.env.WALLET_ENCRYPTION_KEY || '').trim(),
  defaultScore: Number(process.env.DEFAULT_SCORE || 40)
};

module.exports = { config };
