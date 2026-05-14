const fs = require('fs');
const path = require('path');
const solc = require('solc');

const CONTRACT_SOURCE_PATH = path.resolve(__dirname, '../../../hardhat/contracts/TontineManager.sol');

let cachedCompilation = null;

function compileTontineManager() {
  if (cachedCompilation) {
    return cachedCompilation;
  }

  const source = fs.readFileSync(CONTRACT_SOURCE_PATH, 'utf8');
  const input = {
    language: 'Solidity',
    sources: {
      'TontineManager.sol': {
        content: source
      }
    },
    settings: {
      optimizer: {
        enabled: true,
        runs: 80
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

  const contractOutput = output.contracts?.['TontineManager.sol']?.TontineManager;
  if (!contractOutput) {
    throw new Error('Unable to compile TontineManager contract');
  }

  cachedCompilation = {
    abi: contractOutput.abi,
    bytecode: `0x${contractOutput.evm.bytecode.object}`
  };

  return cachedCompilation;
}

module.exports = {
  compileTontineManager
};