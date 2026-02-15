import hre from "hardhat";

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deployer:", deployer.address);

  // Sepolia USDC (Circle)
  const USDC = "0x65aFADD39029741B3b8f0756952C74678c9cEC93";
  const USDC_DECIMALS = 6;

  // Your treasury address (can be same as deployer for now)
  const TREASURY = deployer.address;

  // 2% fee
  const FEE_BPS = 200;

  const Factory = await hre.ethers.getContractFactory("LaunchpadFactory");
  const factory = await Factory.deploy(deployer.address, USDC, USDC_DECIMALS, TREASURY, FEE_BPS);
  await factory.waitForDeployment();

  console.log("Factory:", await factory.getAddress());
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
