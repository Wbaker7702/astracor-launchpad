import { ethers } from "hardhat";
import fs from "fs";

async function main() {
  const cmd = process.argv[2]; // create | fund
  const file = process.argv[3]; // launches/foo.json

  if (!cmd || !file) {
    console.log("Usage:");
    console.log("  npx hardhat run cli/launchpad.ts --network sepolia create launches/yourlaunch.json");
    console.log("  npx hardhat run cli/launchpad.ts --network sepolia fund   launches/yourlaunch.json");
    process.exit(1);
  }

  const cfg = JSON.parse(fs.readFileSync(file, "utf-8"));
  const [deployer] = await ethers.getSigners();

  if (cmd === "create") {
    const Sale = await ethers.getContractFactory("LaunchpadSale");
    const initCode = await Sale.getDeployTransaction(
      deployer.address,
      cfg.token,
      cfg.usdc,
      cfg.tokenDecimals,
      cfg.priceUSDCPerToken,
      cfg.capTokensHuman,
      cfg.startTime,
      cfg.endTime
    );

    const factory = await ethers.getContractAt("LaunchpadFactory", cfg.factory);

    const tx = await factory.createSale(
      deployer.address,
      initCode.data!,
      cfg.token,
      cfg.priceUSDCPerToken,
      cfg.capTokensHuman,
      cfg.startTime,
      cfg.endTime
    );

    const receipt = await tx.wait();
    console.log("Created sale tx:", tx.hash);

    // You’ll see SaleCreated in logs; quick parse:
    const event = receipt?.logs
      .map((l: any) => {
        try {
          return factory.interface.parseLog(l);
        } catch {
          return null;
        }
      })
      .find((e: any) => e && e.name === "SaleCreated");

    if (event) {
      const saleAddr = event.args.sale;
      console.log("Sale address:", saleAddr);
      cfg.sale = saleAddr;
      fs.writeFileSync(file, JSON.stringify(cfg, null, 2));
      console.log("Saved sale address into:", file);
    } else {
      console.log("SaleCreated event not found (but tx may still be fine).");
    }
  }

  else if (cmd === "fund") {
    if (!cfg.sale) throw new Error("No sale address in JSON. Run create first.");
    const token = await ethers.getContractAt("IERC20", cfg.token);
    const capBase = ethers.parseUnits(cfg.capTokensHuman.toString(), cfg.tokenDecimals);

    const tx = await token.transfer(cfg.sale, capBase);
    await tx.wait();
    console.log("Funded sale with cap tokens:", cfg.sale);
  }

  else {
    console.log("Unknown command:", cmd);
    process.exit(1);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
