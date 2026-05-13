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
npm run deploy -- --network sepolia
# or: npx hardhat run scripts/deploy.js --network sepolia
```

Notes
- The deploy script reads constructor values from environment variables when provided:
	- `TONTINE_NAME`
	- `COTISATION_WEI`
	- `FREQUENCE_INDEX`
	- `MAX_MEMBERS`
	- `PSEUDO`
	- `CALL_MEMBERS_ENABLED`
	- `BACKEND_ADDRESS`
- The script forces `guaranteeMode = false` for the current business rules.
- After deployment, register the address in the backend with `npm run register-contract -- <tontineId> <contractAddress> <creatorWallet> [callMembersEnabled=true] [invitationRequired=false]` from the `backend` folder.
- Do NOT commit your real `.env` to the repository.
