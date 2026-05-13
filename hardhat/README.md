Hardhat deployment for TontineGroup (Sepolia)

Prerequisites
- Node.js 18+ and npm
- An RPC URL for Sepolia (Infura/Alchemy or other)
- A deployer private key with funds on Sepolia

Quick start
1. Copy the example env:

```bash
cd hardhat
cp .env.example .env
# edit .env and set SEPOLIA_RPC_URL and DEPLOYER_PRIVATE_KEY
```

2. Install dependencies:

```bash
npm install
```

3. Compile contracts (Hardhat is configured to use the `contracts` folder in the parent):

```bash
npm run compile
```

4. Deploy to Sepolia:

```bash
npm run deploy --network sepolia
# or: node scripts/deploy.js --network sepolia
```

Notes
- The deploy script sends a minimal "guarantee" value to satisfy the constructor when `guaranteeMode` is true. Adjust `_cotisation` / constructor args in `scripts/deploy.js` if you need different values.
- Do NOT commit your real `.env` to the repository.
