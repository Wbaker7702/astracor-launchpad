# astracor-launchpad — Token Launchpad (MVP)

**What this is:** a testnet-first scaffolding for an ERC-20 + fixed-price sale contract.

## Safety
- Do NOT deploy this to mainnet without a professional audit.
- This MVP delivers tokens immediately and uses a simple fixed price.
- Refunds only return “dust” ETH that can’t buy a whole token.

## Quickstart
```bash
npm install
cp .env.example .env
# edit .env for your Sepolia RPC + private key
npx hardhat compile
npx hardhat run scripts/deploy.ts --network sepolia
```

## Contracts
- `contracts/Token.sol` — owner-mint ERC20
- `contracts/LaunchpadSale.sol` — fixed-price ETH->token sale

## Deployment params
`deployment.json` is created by the CLI at init time.
