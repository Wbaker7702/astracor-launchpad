import { ethers } from "ethers";
import fs from "fs";

async function main() {
  const file = process.argv[2];

  if (!file) {
    console.log("Usage:");
    console.log("  node analytics/stats.js launches/usdc-launch.json");
    process.exit(1);
  }

  const cfg = JSON.parse(fs.readFileSync(file, "utf-8"));

  const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
  if (!process.env.RPC_URL) {
  throw new Error("RPC_URL environment variable not set.");
}
  const saleAddress = cfg.sale;

  if (!saleAddress) {
    throw new Error("No sale address found in launch JSON.");
  }

  const abi = [
    "event Bought(address indexed buyer, uint256 usdcIn, uint256 feeUsdc, uint256 tokensOutBase)",
    "function totalSoldBase() view returns (uint256)"
  ];

  const contract = new ethers.Contract(saleAddress, abi, provider);

  const filter = contract.filters.Bought();
  const events = await contract.queryFilter(filter, 0, "latest");

  let totalUSDC = 0n;
  let totalFees = 0n;
  const buyers = new Set();

  for (const e of events) {
    const usdcIn = e.args.usdcIn;
    const feeUsdc = e.args.feeUsdc;
    const buyer = e.args.buyer;

    totalUSDC += usdcIn;
    totalFees += feeUsdc;
    buyers.add(buyer);
  }

  const soldBase = await contract.totalSoldBase();

  console.log("\n===== Launchpad Stats =====");
  console.log("Sale:", saleAddress);
  console.log("Total USDC Raised:", Number(totalUSDC) / 1e6);
  console.log("Platform Fees (USDC):", Number(totalFees) / 1e6);
  console.log("Unique Buyers:", buyers.size);
  console.log("Tokens Sold (base units):", soldBase.toString());
  console.log("============================\n");

  const output = {
    sale: saleAddress,
    usdcRaised: Number(totalUSDC) / 1e6,
    platformFees: Number(totalFees) / 1e6,
    buyers: buyers.size,
    tokensSoldBase: soldBase.toString()
  };

  fs.writeFileSync("analytics-output.json", JSON.stringify(output, null, 2));
  console.log("Exported analytics-output.json");
}

main().catch(console.error);
