import hardhatEthers from "@nomicfoundation/hardhat-ethers";
import { defineConfig } from "hardhat/config";
import * as dotenv from "dotenv";
dotenv.config();

const PRIVATE_KEY = process.env.DEPLOYER_PRIVATE_KEY || "";
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL || "";

const hasSepoliaConfig = SEPOLIA_RPC_URL !== "" && PRIVATE_KEY !== "";

// Safety: only include sepolia when both env vars are present.
export default defineConfig({
  plugins: [hardhatEthers],
  solidity: {
    version: "0.8.24",
    settings: { optimizer: { enabled: true, runs: 200 } },
  },
  networks: {
    ...(hasSepoliaConfig
      ? {
          sepolia: {
            type: "http",
            chainType: "l1",
            url: SEPOLIA_RPC_URL,
            accounts: [PRIVATE_KEY],
          },
        }
      : {}),
  },
});
