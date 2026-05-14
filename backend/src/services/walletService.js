const crypto = require('crypto');
const { ethers } = require('ethers');
const { config } = require('./config');

function deriveEncryptionKey() {
  const material = config.walletEncryptionKey || config.backendPrivateKey;
  return crypto.createHash('sha256').update(material).digest();
}

function encryptPrivateKey(privateKey) {
  const key = deriveEncryptionKey();
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const encrypted = Buffer.concat([cipher.update(String(privateKey), 'utf8'), cipher.final()]);
  const authTag = cipher.getAuthTag();

  return {
    ciphertext: encrypted.toString('hex'),
    iv: iv.toString('hex'),
    authTag: authTag.toString('hex')
  };
}

function createCustodialWallet() {
  const wallet = ethers.Wallet.createRandom();
  const encrypted = encryptPrivateKey(wallet.privateKey);

  return {
    walletAddress: wallet.address.toLowerCase(),
    walletEncryptedPrivateKey: encrypted.ciphertext,
    walletEncryptedIv: encrypted.iv,
    walletEncryptedAuthTag: encrypted.authTag
  };
}

module.exports = {
  createCustodialWallet,
  encryptPrivateKey
};