// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TontineManager {
    struct Cycle {
        uint256 index;
        uint256 dateDebut;
        uint256 dateLimiteCotisation;
        uint256 dateDistribution;
        uint256 montantAttendu;
        address beneficiaire;
        uint256 montantCollecte;
        uint256 montantReserve;
        bool distributionEffectuee;
    }

    struct Tontine {
        string name;
        uint256 contributionAmount;
        uint256 maxMembers;
        uint256 currentCycle;
        bool started;
        bool finished;
        address creator;
        address[] members;
        address[] beneficiariesOrder;
        uint256 totalPool;
        uint8 frequency;
        bool callMembersEnabled;
        bool guaranteeMode;
        mapping(address => bool) isMember;
        mapping(uint256 => Cycle) cycles;
        mapping(uint256 => mapping(address => bool)) paid;
        mapping(uint256 => mapping(address => bool)) latePayment;
    }

    address public backend;
    mapping(bytes32 => Tontine) private tontines;
    mapping(bytes32 => bool) private tontineExists;

    event TontineCreated(string indexed tontineId, string name, address indexed creator, uint256 contributionAmount, uint256 maxMembers, uint8 frequency, uint256 timestamp);
    event DemandAdhesionEnvoyee(string indexed tontineId, address indexed wallet, string pseudo, uint256 timestamp);
    event DemandAdhesionAcceptee(string indexed tontineId, address indexed wallet, uint256 montantGarantieRequis, uint256 deadlineDepot, uint256 timestamp);
    event DemandAdhesionRefusee(string indexed tontineId, address indexed wallet, uint256 timestamp);
    event GarantieDeposeee(string indexed tontineId, address indexed wallet, uint256 montant, uint256 timestamp);
    event CycleCommence(string indexed tontineId, uint256 indexed cycleId, address indexed beneficiaire, uint256 dateLimiteCotisation, uint256 dateDistribution, uint256 timestamp);
    event CotisationPayee(string indexed tontineId, address indexed wallet, uint256 indexed cycleId, uint256 montant, uint256 timestamp);
    event RetardDetecte(string indexed tontineId, address indexed wallet, uint256 indexed cycleId, uint256 timestamp);
    event AllocationDistribuee(string indexed tontineId, address indexed beneficiaire, uint256 indexed cycleId, uint256 montantTotal, uint256 montantLibere, uint256 montantReserve, uint8 scoreConfiance, uint256 timestamp);

    modifier onlyBackend() {
        require(msg.sender == backend, "Only backend");
        _;
    }

    constructor(address _backend) {
        require(_backend != address(0), "backend required");
        backend = _backend;
    }

    function _key(string memory tontineId) internal pure returns (bytes32) {
        return keccak256(bytes(tontineId));
    }

    function _frequencyToSeconds(uint8 frequency) internal pure returns (uint256) {
        if (frequency == 0) return 1 days;
        if (frequency == 1) return 7 days;
        return 30 days;
    }

    function _initCycle(Tontine storage t, string memory tontineId, uint256 cycleId) internal {
        Cycle storage cycle = t.cycles[cycleId];
        if (cycle.dateDebut != 0) return;

        uint256 beneficiaryIndex = cycleId == 0 ? 0 : cycleId - 1;
        address beneficiary = beneficiaryIndex < t.beneficiariesOrder.length
            ? t.beneficiariesOrder[beneficiaryIndex]
            : address(0);

        cycle.index = cycleId;
        cycle.dateDebut = block.timestamp;
        cycle.dateLimiteCotisation = block.timestamp + _frequencyToSeconds(t.frequency);
        cycle.dateDistribution = cycle.dateLimiteCotisation + 1 days;
        cycle.montantAttendu = t.contributionAmount;
        cycle.beneficiaire = beneficiary;

        emit CycleCommence(tontineId, cycleId, beneficiary, cycle.dateLimiteCotisation, cycle.dateDistribution, block.timestamp);
    }

    function createTontine(
        string calldata tontineId,
        string calldata name,
        uint256 contributionAmount,
        uint8 frequency,
        uint256 maxMembers,
        string calldata pseudo,
        bool callMembersEnabled,
        bool guaranteeMode,
        address creator
    ) external onlyBackend returns (uint256) {
        bytes32 key = _key(tontineId);
        require(!tontineExists[key], "Tontine exists");
        require(creator != address(0), "creator required");

        Tontine storage t = tontines[key];
        tontineExists[key] = true;
        t.name = name;
        t.contributionAmount = contributionAmount;
        t.maxMembers = maxMembers;
        t.creator = creator;
        t.frequency = frequency;
        t.callMembersEnabled = callMembersEnabled;
        t.guaranteeMode = guaranteeMode;
        t.members.push(creator);
        t.beneficiariesOrder.push(creator);
        t.isMember[creator] = true;

        emit TontineCreated(tontineId, name, creator, contributionAmount, maxMembers, frequency, block.timestamp);
        emit DemandAdhesionEnvoyee(tontineId, creator, pseudo, block.timestamp);
        emit DemandAdhesionAcceptee(tontineId, creator, 0, 0, block.timestamp);
        emit GarantieDeposeee(tontineId, creator, 0, block.timestamp);

        if (maxMembers <= 1) {
            t.started = true;
            t.currentCycle = 1;
            _initCycle(t, tontineId, 1);
        }

        return 1;
    }

    function joinTontine(string calldata tontineId, address member, string calldata pseudo) external onlyBackend {
        bytes32 key = _key(tontineId);
        require(tontineExists[key], "Tontine missing");
        require(member != address(0), "member required");

        Tontine storage t = tontines[key];
        require(!t.isMember[member], "Already member");

        t.members.push(member);
        t.beneficiariesOrder.push(member);
        t.isMember[member] = true;

        emit DemandAdhesionEnvoyee(tontineId, member, pseudo, block.timestamp);
        emit DemandAdhesionAcceptee(tontineId, member, 0, 0, block.timestamp);
        emit GarantieDeposeee(tontineId, member, 0, block.timestamp);

        if (!t.started && t.members.length >= t.maxMembers) {
            t.started = true;
            t.currentCycle = 1;
            _initCycle(t, tontineId, 1);
        }
    }

    function setOrdreBeneficiaires(string calldata tontineId, address[] calldata order) external onlyBackend {
        bytes32 key = _key(tontineId);
        require(tontineExists[key], "Tontine missing");

        Tontine storage t = tontines[key];
        delete t.beneficiariesOrder;
        for (uint256 i = 0; i < order.length; i++) {
            t.beneficiariesOrder.push(order[i]);
        }

        if (t.started && t.currentCycle > 0) {
            _initCycle(t, tontineId, t.currentCycle);
        }
    }

    function payContribution(string calldata tontineId, uint256 cycleId, address member) external payable onlyBackend {
        bytes32 key = _key(tontineId);
        require(tontineExists[key], "Tontine missing");

        Tontine storage t = tontines[key];
        require(member != address(0), "member required");
        require(t.isMember[member], "Not a member");

        uint256 effectiveCycle = cycleId == 0 ? t.currentCycle : cycleId;
        require(effectiveCycle > 0, "Invalid cycle");

        Cycle storage cycle = t.cycles[effectiveCycle];
        if (cycle.dateDebut == 0) {
            _initCycle(t, tontineId, effectiveCycle);
            cycle = t.cycles[effectiveCycle];
        }

        require(!t.paid[effectiveCycle][member], "Already paid");
        require(msg.value == t.contributionAmount, "Invalid contribution amount");

        t.paid[effectiveCycle][member] = true;
        cycle.montantCollecte += msg.value;
        t.totalPool += msg.value;

        if (block.timestamp > cycle.dateLimiteCotisation) {
            t.latePayment[effectiveCycle][member] = true;
            emit RetardDetecte(tontineId, member, effectiveCycle, block.timestamp);
        }

        emit CotisationPayee(tontineId, member, effectiveCycle, msg.value, block.timestamp);
    }

    function verifyPaymentsAndHandleDefaults(string calldata tontineId) external onlyBackend {
        bytes32 key = _key(tontineId);
        require(tontineExists[key], "Tontine missing");

        Tontine storage t = tontines[key];
        uint256 cycleId = t.currentCycle;
        if (cycleId == 0) return;

        Cycle storage cycle = t.cycles[cycleId];
        if (cycle.dateLimiteCotisation == 0 || block.timestamp <= cycle.dateLimiteCotisation) return;

        for (uint256 i = 0; i < t.members.length; i++) {
            address member = t.members[i];
            if (!t.paid[cycleId][member]) {
                t.latePayment[cycleId][member] = true;
                emit RetardDetecte(tontineId, member, cycleId, block.timestamp);
            }
        }
    }

    function distributeAllocation(string calldata tontineId, uint8 scoreConfiance) external onlyBackend returns (uint256 montantLibere) {
        bytes32 key = _key(tontineId);
        require(tontineExists[key], "Tontine missing");

        Tontine storage t = tontines[key];
        uint256 cycleId = t.currentCycle;
        require(cycleId > 0, "No active cycle");

        Cycle storage cycle = t.cycles[cycleId];
        if (cycle.dateDebut == 0) {
            _initCycle(t, tontineId, cycleId);
        }

        address beneficiaire = cycle.beneficiaire;
        if (beneficiaire == address(0) && cycleId > 0 && cycleId - 1 < t.beneficiariesOrder.length) {
            beneficiaire = t.beneficiariesOrder[cycleId - 1];
            cycle.beneficiaire = beneficiaire;
        }

        uint256 montantTotal = cycle.montantCollecte;
        bool beneficiaryLate = t.latePayment[cycleId][beneficiaire];
        uint256 montantReserve = beneficiaryLate ? (montantTotal * 20) / 100 : 0;
        montantLibere = montantTotal - montantReserve;
        cycle.montantReserve = montantReserve;
        cycle.distributionEffectuee = true;

        if (montantLibere > 0 && beneficiaire != address(0)) {
            payable(beneficiaire).transfer(montantLibere);
        }

        emit AllocationDistribuee(
            tontineId,
            beneficiaire,
            cycleId,
            montantTotal,
            montantLibere,
            montantReserve,
            scoreConfiance,
            block.timestamp
        );

        if (cycleId < t.beneficiariesOrder.length) {
            t.currentCycle = cycleId + 1;
            _initCycle(t, tontineId, t.currentCycle);
        } else {
            t.finished = true;
        }
    }

    function cycleActuel(string calldata tontineId) external view returns (uint256) {
        bytes32 key = _key(tontineId);
        if (!tontineExists[key]) return 0;
        return tontines[key].currentCycle;
    }

    function cycles(
        string calldata tontineId,
        uint256 cycleId
    ) external view returns (
        uint256 dateDebut,
        uint256 dateLimiteCotisation,
        uint256 dateDistribution,
        uint256 montantAttendu,
        address beneficiaire,
        uint256 montantCollecte,
        uint256 montantReserve,
        bool distributionEffectuee
    ) {
        bytes32 key = _key(tontineId);
        if (!tontineExists[key]) {
            return (0, 0, 0, 0, address(0), 0, 0, false);
        }

        Cycle storage cycle = tontines[key].cycles[cycleId];
        return (
            cycle.dateDebut,
            cycle.dateLimiteCotisation,
            cycle.dateDistribution,
            cycle.montantAttendu,
            cycle.beneficiaire,
            cycle.montantCollecte,
            cycle.montantReserve,
            cycle.distributionEffectuee
        );
    }

    function getTontine(string calldata tontineId) external view returns (
        string memory name,
        uint256 contributionAmount,
        uint256 maxMembers,
        uint256 currentCycle,
        bool started,
        bool finished,
        address creator,
        uint256 totalPool,
        uint256 memberCount,
        uint8 frequency
    ) {
        bytes32 key = _key(tontineId);
        if (!tontineExists[key]) {
            return ('', 0, 0, 0, false, false, address(0), 0, 0, 0);
        }

        Tontine storage t = tontines[key];
        return (
            t.name,
            t.contributionAmount,
            t.maxMembers,
            t.currentCycle,
            t.started,
            t.finished,
            t.creator,
            t.totalPool,
            t.members.length,
            t.frequency
        );
    }
}