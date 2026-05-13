Backend Orchestrator (ethers + Firestore)

This service runs blockchain orchestration for TontineGroup contracts:
- listen on-chain events and mirror them into Firestore
- execute backend-only actions for current cycle orchestration

Setup

1. Install dependencies:

```bash
cd backend
npm install
```

2. Create `.env` from `.env.example` and fill values.

3. Register deployed contract in Firestore registry:

```bash
node src/jobs/registerContractCli.js <tontineId> <contractAddress> <creatorWallet>
```

4. Start API server:

```bash
npm start
```

5. Start event listener in another terminal:

```bash
npm run listen-events
```

API

- Health check:

```bash
GET /health
```

- Orchestrate current cycle:

```bash
POST /api/orchestrate-cycle
Content-Type: application/json
{
  "tontineId": "<tontine-id>"
}
```

Firestore collections used

- `contracts/{tontineId}`: contract registry
- `tontines/{tontineId}/chainEvents/{txHash_eventName}`: mirrored on-chain events
- `tontines/{tontineId}/members/{wallet}`: lightweight member projection
- `tontines/{tontineId}/cycles/{cycleId}`: lightweight cycle projection
- `tontines/{tontineId}/runtime/currentBeneficiaryScore`: score input for distribution (`score` field)

Notes

- `acceptJoinRequest` remains a creator-only transaction in current Solidity contract.
- Keep `BACKEND_PRIVATE_KEY` out of Git and production logs.
