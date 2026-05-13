Deployment checklist — Testnet (Hardhat)

1) Go to the Hardhat project:
   - `cd ..\hardhat`

2) Prepare environment (.env):
   - Copy `.env.example` to `.env` and fill values:
     - `RPC_URL` — your testnet RPC (Alchemy/Infura/QuickNode or public Amoy RPC)
     - `DEPLOYER_PRIVATE_KEY` — private key of the deployer (0x...)
     - `BACKEND_PRIVATE_KEY` — key used by backend jobs (optional: same key)
     - Firebase keys as required by backend

3) Compile contracts:
   - `npx hardhat compile`

4) Deploy contract (example):
    - `npm run deploy -- --network amoy`
    - Or with explicit values:
       - `TONTINE_NAME="MaTontine" COTISATION_WEI=1000000000000000000 FREQUENCE_INDEX=0 MAX_MEMBERS=6 PSEUDO="PseudoCreateur" CALL_MEMBERS_ENABLED=true BACKEND_ADDRESS=0xBACKEND_ADDRESS npm run deploy -- --network amoy`
   - Notes:
     - `cotisation` must be provided in wei units (e.g., `1000000000000000000` for 1 ETH/MATIC in wei)
     - `frequenceIndex` is the enum index expected by the contract (check `TontineGroup.sol`)
       - `callMembersEnabled` is `true`/`false`
       - `guaranteeMode` is forced to `false` in the current version

5) Register deployed contract in backend:
   - Start backend (or ensure it's reachable): `npm run start`
   - Run register CLI:
     - `npm run register-contract -- <tontineId> <contractAddress> <creatorWallet> [callMembersEnabled=true] [invitationRequired=false]`
   - Example: `npm run register-contract -- my-tontine-123 0xContractAddress 0xCreatorWallet true false`

6) Start event listener:
   - `npm run listen-events`
   - Ensure listener process runs persistently (PM2, systemd, Docker, etc.)

Additional notes:
- Testnet funds: get test MATIC/ETH via the network's faucet.
- If constructor requires an initial `msg.value` (guarantee on createur), adjust deploy call to send `value` in the deploy transaction: modify `scripts/deploy.js` to include `const contract = await Factory.deploy(..., { value: hre.ethers.parseUnits('0', 'wei') })` and set desired value.
- After registration, the backend will map events to your tontine id and process `RetardDetecte` and others.
