const { ethers } = require('ethers');
const { config } = require('./config');
const tontineAbi = require('../abi/TontineGroup.abi.json');

const provider = new ethers.JsonRpcProvider(config.rpcUrl);
const wallet = new ethers.Wallet(config.backendPrivateKey, provider);

function getContract(contractAddress) {
  return new ethers.Contract(contractAddress, tontineAbi, wallet);
}

async function sendTx(txPromise, label) {
  const tx = await txPromise;
  console.log(`[chain] ${label} submitted: ${tx.hash}`);
  const receipt = await tx.wait();
  console.log(`[chain] ${label} confirmed in block ${receipt.blockNumber}`);
  return { tx, receipt };
}

module.exports = {
  provider,
  wallet,
  getContract,
  sendTx
};
