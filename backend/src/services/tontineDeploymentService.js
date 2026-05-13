const fs = require('fs');
const path = require('path');
const solc = require('solc');
const { ethers } = require('ethers');

const { wallet } = require('./blockchain');
const { config } = require('./config');
const { registerContract } = require('./contractRegistry');
const { db, admin } = require('./firebase');

const CONTRACT_SOURCE_PATH = path.resolve(__dirname, '../../../hardhat/contracts/TontineGroup.sol');
const COMPILER_VERSION = '0.8.20';

let cachedCompilation = null;

function normalizeFrequencyIndex(value) {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === '0' || normalized.includes('journalier') || normalized.includes('daily')) return 0;
  if (normalized === '1' || normalized.includes('hebdo') || normalized.includes('week')) return 1;
  return 2;
}

function compileContract() {
  if (cachedCompilation) {
    return cachedCompilation;
  }

  const source = fs.readFileSync(CONTRACT_SOURCE_PATH, 'utf8');
  const input = {
    language: 'Solidity',
    sources: {
      'TontineGroup.sol': {
        content: source
      }
    },
    settings: {
      optimizer: {
        enabled: true,
        runs: 50
      },
      viaIR: true,
      outputSelection: {
        '*': {
          '*': ['abi', 'evm.bytecode.object']
        }
      }
    }
  };

  const output = JSON.parse(solc.compile(JSON.stringify(input)));
  if (output.errors?.length) {
    const fatalErrors = output.errors.filter((entry) => entry.severity === 'error');
    if (fatalErrors.length) {
      throw new Error(fatalErrors.map((entry) => entry.formattedMessage).join('\n'));
    }
  }

  const contractOutput = output.contracts?.['TontineGroup.sol']?.TontineGroup;
  if (!contractOutput) {
    throw new Error('Unable to compile TontineGroup contract');
  }

  cachedCompilation = {
    abi: contractOutput.abi,
    bytecode: `0x${contractOutput.evm.bytecode.object}`
  };

  return cachedCompilation;
}

async function deployTontineContract({
  tontineId,
  name,
  monthlyAmount,
  frequency,
  maxMembers,
  creatorId,
  creatorWallet,
  creatorPseudo,
  isPublic,
  callMembersEnabled
}) {
  if (!tontineId) throw new Error('tontineId is required');
  if (!name) throw new Error('name is required');
  if (monthlyAmount == null) throw new Error('monthlyAmount is required');
  if (maxMembers == null) throw new Error('maxMembers is required');
  if (!creatorId) throw new Error('creatorId is required');

  const { abi, bytecode } = compileContract();
  const factory = new ethers.ContractFactory(abi, bytecode, wallet);
  const frequencyIndex = normalizeFrequencyIndex(frequency);
  const monthlyAmountWei = BigInt(Math.round(Number(monthlyAmount)));
  const pseudo = String(creatorPseudo || name || 'Createur').trim() || 'Createur';
  const backendAddress = wallet.address;
  const contract = await factory.deploy(
    name,
    monthlyAmountWei,
    frequencyIndex,
    Number(maxMembers),
    pseudo,
    Boolean(callMembersEnabled),
    false,
    backendAddress
  );

  await contract.waitForDeployment();
  const contractAddress = contract.target || (await contract.getAddress());
  const deploymentTransaction = contract.deploymentTransaction();

  await registerContract({
    tontineId,
    contractAddress,
    creatorWallet: creatorWallet || creatorId,
    backendAddress,
    network: config.networkName,
    callMembersEnabled: Boolean(callMembersEnabled),
    invitationRequired: !Boolean(isPublic)
  });

  await db.collection('tontines').doc(tontineId).set(
    {
      tontineId,
      contractAddress: contractAddress.toLowerCase(),
      contractTransactionHash: deploymentTransaction?.hash || null,
      blockchainNetwork: config.networkName,
      deploymentStatus: 'DEPLOYED',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    },
    { merge: true }
  );

  return {
    tontineId,
    contractAddress,
    contractTransactionHash: deploymentTransaction?.hash || null,
    network: config.networkName,
    backendAddress
  };
}

module.exports = {
  deployTontineContract,
  normalizeFrequencyIndex,
  compileContract
};