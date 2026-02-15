import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";
dotenv.config();

const PRIVATE_KEY = process.env.DEPLOYER_PRIVATE_KEY || "";
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL || "";

// Safety: default to only sepolia in config unless user edits it.
const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: { optimizer: { enabled: true, runs: 200 } }
  },
  networks: {
    sepolia: SEPOLIA_RPC_URL && PRIVATE_KEY ? {
      url: SEPOLIA_RPC_URL,
      accounts: [PRIVATE_KEY],
    } : undefined,
  },
};

export default config;
