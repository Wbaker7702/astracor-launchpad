import { network } from "hardhat";

async function main() {
  const { ethers } = await network.connect();
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  const fs = await import("fs");
  const params = JSON.parse(fs.readFileSync("deployment.json", "utf-8"));

  // Deploy Token
  const Token = await ethers.getContractFactory(params.contractName);
  const token = await Token.deploy(
    deployer.address,
    params.tokenName,
    params.tokenSymbol,
    params.decimals
  );
  await token.waitForDeployment();
  const tokenAddr = await token.getAddress();
  console.log("Token:", tokenAddr);

  const supplyBase = ethers.parseUnits(
    params.initialSupply.toString(),
    params.decimals
  );

  await (await token.mint(deployer.address, supplyBase)).wait();

  const now = Math.floor(Date.now() / 1000);
  const start = now + params.saleStartDelaySec;
  const end = start + params.saleDurationSec;

  const Sale = await ethers.getContractFactory("LaunchpadSale");

  const sale = await Sale.deploy(
    deployer.address,
    tokenAddr,
    params.usdcAddress,
    params.decimals,
    params.priceUSDCPerToken,
    params.saleCapTokens,
    start,
    end
  );

  await sale.waitForDeployment();
  const saleAddr = await sale.getAddress();

  console.log("Sale:", saleAddr);

  const capBase = ethers.parseUnits(
    params.saleCapTokens.toString(),
    params.decimals
  );

  await (await token.transfer(saleAddr, capBase)).wait();

  console.log("Sale funded.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
