require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-gas-reporter");
require("dotenv").config();
require("solidity-coverage");
require("hardhat-contract-sizer");

const PRIVATE_KEY = process.env.PRIVATE_KEY;
const BNBT_RPC_URL = process.env.BNBT_RPC_URL;
const BNB_MAINNET_RPC_URL = process.env.BNB_MAINNET_RPC_URL;
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY;

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    bnb_testnet: {
      url: BNBT_RPC_URL,
      accounts: [PRIVATE_KEY],
      chainId: 97,
    },
    bnb_mainnet: {
      url: BNB_MAINNET_RPC_URL,
      accounts: [PRIVATE_KEY],
      chainId: 56,
    },
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
  gasReporter: {
    enabled: true,
    outputFile: "gasreporter.txt",
    noColors: true,
  },
  coverage: {
    exclude: ["test/", "node_modules/"],
  },
  solidity: {
    version: "0.8.18",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
  },
};
