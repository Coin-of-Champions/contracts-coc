import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-web3";
import "@nomiclabs/hardhat-ethers";
import "hardhat-gas-reporter"
import 'hardhat-abi-exporter';
import 'hardhat-docgen';
import 'hardhat-spdx-license-identifier';
import '@openzeppelin/hardhat-upgrades';

import * as dotenv from 'dotenv';

dotenv.config();
const { MNEMONIC } = process.env;
const { ETHERSCAN_API_KEY } = process.env;

module.exports = {
  solidity: "0.8.7",
  networks: {
    mainnet: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      gasPrice: 20000000000,
      accounts: {mnemonic: MNEMONIC, initialIndex: 0}
    },
    testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      gasPrice: 20000000000,
      accounts: {mnemonic: MNEMONIC, initialIndex: 0}
    },
    localhost: {
      chainId: 31337,
      url: "http://127.0.0.1:8545",
      accounts: ["0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"]
    }
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY
  },
  gasReporter: {
    enabled: true,
    gasPrice: 5,
  },
  abiExporter: {
    path: './data/abi',
    clear: true,
    flat: true,
    spacing: 2
  },
  docgen: {
    path: './docs',
    clear: true,
    runOnCompile: true
  },
  spdxLicenseIdentifier: {
    overwrite: true,
    runOnCompile: true,
  }
};

