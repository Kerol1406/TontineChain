require('dotenv').config();
require('@nomiclabs/hardhat-ethers');

/**
 * Hardhat config for TontineGroup deployment
 */
module.exports = {
  solidity: '0.8.20',
  networks: {
    amoy: {
      url: process.env.RPC_URL || '',
      accounts: process.env.DEPLOYER_PRIVATE_KEY ? [process.env.DEPLOYER_PRIVATE_KEY] : []
    }
  }
};
