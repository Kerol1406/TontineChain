// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title TontineChain — Contrat principal de gestion de tontine
/// @notice Gère le cycle de vie complet d'une tontine décentralisée avec adhésion progressive,
/// garanties variables, et allocation progressive des fonds selon le score de confiance.
contract TontineGroup {

    // ══════════════════════════════════════════════════════════════
    // ÉNUMÉRATIONS
    // ══════════════════════════════════════════════════════════════

    enum TontineStatus {
        WAITING_MEMBERS, READY_TO_START, ACTIVE, DISTRIBUTION_IN_PROGRESS, COMPLETED, FAILED, CANCELLED
    }

    enum MemberStatus {
        PENDING, ACTIVE, LATE, SUSPENDED, EXCLUDED, COMPLETED
    }

    enum CycleStatus {
        PENDING, COLLECTING, VERIFYING, DISTRIBUTING, FINISHED, FAILED
    }

    enum Frequence {
        DAILY, WEEKLY, MONTHLY
    }

    enum JoinRequestStatus {
        PENDING, ACCEPTED, REJECTED
    }

    enum ActionType {
        JOIN, GUARANTEE_DEPOSIT, CONTRIBUTION, LATE_PAYMENT, GUARANTEE_USED, GUARANTEE_RECHARGE, 
        DISTRIBUTION, WITHDRAWAL, SUSPENSION, EXCLUSION, COMPLETION
    }

    // ══════════════════════════════════════════════════════════════
    // STRUCTURES
    // ══════════════════════════════════════════════════════════════

    struct JoinRequest {
        address wallet;
        string pseudo;
        uint256 timestamp;
        JoinRequestStatus status;
        uint256 acceptanceDeadline;
    }

    struct Member {
        address wallet;
        string pseudo;
        uint256 garantieBloquee;
        uint256 totalCotise;
        uint256 incidents;
        uint256 positionOrdre;
        bool aRecu;
        uint256 montantRecu;
        MemberStatus statut;
    }

    struct MemberDates {
        uint256 dateAdhesion;
        uint256 derniereCotisation;
        uint256 dateSuspension;
        uint256 dateExclusion;
    }

    struct Cycle {
        uint256 id;
        address beneficiaire;
        uint256 dateDebut;
        uint256 dateLimiteCotisation;
        uint256 dateFinDelaiGrace;
        uint256 dateDistribution;
        uint256 dateFinRetrait;
        uint256 montantAttendu;
        uint256 montantCollecte;
        address[] membresAyantPaye;
        address[] membresDefaillants;
        CycleStatus statut;
        bool distributionEffectuee;
    }

    struct EventLog {
        uint256 id;
        ActionType typeAction;
        address utilisateur;
        uint256 montant;
        uint256 timestamp;
        uint256 cycleId;
        string details;
    }

    struct Withdrawal {
        uint256 id;
        address utilisateur;
        uint256 montant;
        uint256 date;
        string typeRetrait;
        bool valide;
    }

    // ══════════════════════════════════════════════════════════════
    // VARIABLES D'ÉTAT
    // ══════════════════════════════════════════════════════════════

    string public nom;
    address public createur;
    Frequence public frequence;

    uint256 public montantCotisation;
    uint256 public garantieMinimum;
    uint256 public montantCotisationRef;

    uint256 public constant MIN_MEMBRES = 1;
    uint256 public constant MAX_MEMBRES = 40;
    uint256 public constant DELAI_GRACE_DAILY = 12 hours;
    uint256 public constant DELAI_GRACE_WEEKLY = 48 hours;
    uint256 public constant DELAI_GRACE_MONTHLY = 72 hours;
    uint256 public constant PERIODE_RETRAIT = 12 hours;
    uint256 public constant DELAI_ACCEPTATION_DEMANDE = 24 hours;
    uint256 public constant SEUIL_EXCLUSION_INCIDENTS = 5;
    uint256 public constant SEUIL_SUSPENSION_INCIDENTS = 3;

    bool public callMembersEnabled;
    bool public guaranteeMode;
    uint256 public nombreMaxMembres;
    uint256 public nombreMembresActuels;
    uint256 public seuilEchec;

    bool public ordreVerrouille;
    uint256 public nombreExclus;

    mapping(uint256 => uint256) public baremeGarantie;
    mapping(address => uint256) public soldesRetirables;
    mapping(address => uint256) public soldesReserve;
    mapping(address => uint256) public dateDeblockageReserve;
    mapping(uint256 => mapping(address => bool)) public aPaye;
    mapping(uint256 => mapping(address => bool)) public aPayeATemps;
    uint256 public totalGarantiesBloquees;

    TontineStatus public statut;
    uint256 public dateDemarrage;
    uint256 public cycleActuel;

    address[] public ordreBeneficiaires;
    address[] public listeMembres;
    mapping(address => Member) public membres;
    mapping(address => MemberDates) public membresDates;
    mapping(address => bool) public estMembre;
    mapping(address => bool) public blacklist;

    JoinRequest[] public joinRequests;
    mapping(address => uint256) public joinRequestIndex;
    mapping(address => bool) public hasJoinRequest;

    mapping(uint256 => Cycle) public cycles;
    uint256 public nombreCycles;

    EventLog[] public historique;
    uint256 public nombreEvenements;

    Withdrawal[] public retraits;

    address public backend;
    bool public locked;

    // ══════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════

    event TontineCreee(string nom, uint256 montantCotisation, Frequence frequence, uint256 maxMembres, bool callMembersEnabled, bool guaranteeMode, uint256 timestamp);
    event DemandAdhesionEnvoyee(address indexed wallet, string pseudo, uint256 timestamp);
    event DemandAdhesionAcceptee(address indexed wallet, uint256 montantGarantieRequis, uint256 deadlineDepot, uint256 timestamp);
    event DemandAdhesionRefusee(address indexed wallet, uint256 timestamp);
    event GarantieDeposeee(address indexed wallet, uint256 montant, uint256 timestamp);
    event MembreRejoint(address indexed wallet, string pseudo, uint256 garantieDeposee, uint256 timestamp);
    event CotisationPayee(address indexed wallet, uint256 indexed cycleId, uint256 montant, uint256 timestamp);
    event RetardDetecte(address indexed wallet, uint256 indexed cycleId, uint256 timestamp);
    event GarantieUtilisee(address indexed wallet, uint256 indexed cycleId, uint256 montant, uint256 garantieRestante, uint256 timestamp);
    event GarantieRechargee(address indexed wallet, uint256 montant, uint256 nouvelleGarantie, uint256 timestamp);
    event IncidentComptabilise(address indexed wallet, uint256 nombreIncidents, string raison, uint256 timestamp);
    event MembreSuspendu(address indexed wallet, uint256 indexed cycleId, string raison, uint256 timestamp);
    event MembreExclu(address indexed wallet, uint256 indexed cycleId, string raison, uint256 timestamp);
    event AllocationDistribuee(address indexed beneficiaire, uint256 indexed cycleId, uint256 montantTotal, uint256 montantLibere, uint256 montantReserve, uint8 scoreConfiance, uint256 timestamp);
    event ReserveDebloquee(address indexed wallet, uint256 montant, uint256 timestamp);
    event TontineDemarree(uint256 dateDemarrage, address[] ordreBeneficiaires, uint256 timestamp);
    event CycleCommence(uint256 indexed cycleId, address indexed beneficiaire, uint256 dateLimiteCotisation, uint256 dateDistribution, uint256 timestamp);
    event TontineTerminee(uint256 dateFinale, uint256 nombreCyclesTotal, uint256 timestamp);
    event TontineEchouee(string raison, uint256 nombreMembresExclus, uint256 timestamp);

    // ══════════════════════════════════════════════════════════════
    // MODIFIERS
    // ══════════════════════════════════════════════════════════════

    modifier seulementBackend() {
        require(msg.sender == backend, "Seul le backend peut appeler");
        _;
    }

    modifier seulementCreateur() {
        require(msg.sender == createur, "Seul le createur peut appeler");
        _;
    }

    modifier seulementMembre() {
        require(estMembre[msg.sender], "Vous n'etes pas membre");
        require(membres[msg.sender].statut != MemberStatus.EXCLUDED, "Membre exclu");
        _;
    }

    modifier tontineActive() {
        require(statut == TontineStatus.ACTIVE, "Tontine non active");
        _;
    }

    modifier nonReentrant() {
        require(!locked, "Appel reentrant detecte");
        locked = true;
        _;
        locked = false;
    }

    // ══════════════════════════════════════════════════════════════
    // CONSTRUCTEUR
    // ══════════════════════════════════════════════════════════════

    constructor(
        string memory _nom,
        uint256 _cotisation,
        Frequence _frequence,
        uint256 _nombreMaxMembres,
        string memory _pseudo,
        bool _callMembersEnabled,
        bool _guaranteeMode,
        address _backend
    ) payable {
        require(_cotisation > 0, "Cotisation invalide");
        require(_nombreMaxMembres >= MIN_MEMBRES, "Minimum 1 membre");
        require(_nombreMaxMembres <= MAX_MEMBRES, "Maximum 40 membres");
        require(_backend != address(0), "Backend invalide");

        nom = _nom;
        createur = msg.sender;
        montantCotisation = _cotisation;
        montantCotisationRef = _cotisation;
        frequence = _frequence;
        nombreMaxMembres = _nombreMaxMembres;
        callMembersEnabled = _callMembersEnabled;
        guaranteeMode = false;
        backend = _backend;
        statut = TontineStatus.WAITING_MEMBERS;
        seuilEchec = (nombreMaxMembres * 50) / 100;
        if (seuilEchec == 0) seuilEchec = 1;

        _initializeGarantieBareme();
        _registerMember(msg.sender, _pseudo, MemberStatus.ACTIVE);

        if (guaranteeMode) {
            uint256 montantGarantieRequis = _calculateGarantie(_cotisation);
            require(msg.value >= montantGarantieRequis, "Garantie createur insuffisante");

            Member storage m = membres[msg.sender];
            m.garantieBloquee = msg.value;
            totalGarantiesBloquees += msg.value;
            membresDates[msg.sender].dateAdhesion = block.timestamp;

            emit GarantieDeposeee(msg.sender, msg.value, block.timestamp);
        }

        emit TontineCreee(_nom, _cotisation, _frequence, _nombreMaxMembres, _callMembersEnabled, guaranteeMode, block.timestamp);
        emit MembreRejoint(msg.sender, _pseudo, msg.value, block.timestamp);
    }

    // ══════════════════════════════════════════════════════════════
    // BARÈME DE GARANTIE
    // ══════════════════════════════════════════════════════════════

    function _initializeGarantieBareme() internal {
        baremeGarantie[5000] = 10000;
        baremeGarantie[25000] = 7000;
        baremeGarantie[100000] = 5000;
        baremeGarantie[500000] = 3500;
        baremeGarantie[type(uint256).max] = 2000;
    }

    function _calculateGarantie(uint256 _cotisation) internal view returns (uint256) {
        if (_cotisation <= 5000) {
            return (_cotisation * baremeGarantie[5000]) / 10000;
        } else if (_cotisation <= 25000) {
            return (_cotisation * baremeGarantie[25000]) / 10000;
        } else if (_cotisation <= 100000) {
            return (_cotisation * baremeGarantie[100000]) / 10000;
        } else if (_cotisation <= 500000) {
            return (_cotisation * baremeGarantie[500000]) / 10000;
        } else {
            return (_cotisation * baremeGarantie[type(uint256).max]) / 10000;
        }
    }

    // ══════════════════════════════════════════════════════════════
    // ADHÉSION — Flux 2-étapes
    // ══════════════════════════════════════════════════════════════

    function _registerMember(address _wallet, string memory _pseudo, MemberStatus _initialStatus) internal {
        require(!estMembre[_wallet], "Deja membre");

        membres[_wallet] = Member({
            wallet: _wallet,
            pseudo: _pseudo,
            garantieBloquee: 0,
            totalCotise: 0,
            incidents: 0,
            positionOrdre: nombreMembresActuels,
            aRecu: false,
            montantRecu: 0,
            statut: _initialStatus
        });

        membresDates[_wallet] = MemberDates({
            dateAdhesion: block.timestamp,
            derniereCotisation: 0,
            dateSuspension: 0,
            dateExclusion: 0
        });

        listeMembres.push(_wallet);
        estMembre[_wallet] = true;
        nombreMembresActuels++;
    }

    function requestToJoin(string memory _pseudo) external {
        require(statut == TontineStatus.WAITING_MEMBERS, "Tontine non ouverte a l'adhesion");
        require(!blacklist[msg.sender], "Adresse blacklistee");
        require(!estMembre[msg.sender], "Deja membre");
        require(!hasJoinRequest[msg.sender], "Demande deja envoyee");
        require(nombreMembresActuels < nombreMaxMembres, "Groupe complet");
        require(bytes(_pseudo).length > 0, "Pseudo vide");

        JoinRequest memory req = JoinRequest({
            wallet: msg.sender,
            pseudo: _pseudo,
            timestamp: block.timestamp,
            status: JoinRequestStatus.PENDING,
            acceptanceDeadline: 0
        });

        joinRequests.push(req);
        joinRequestIndex[msg.sender] = joinRequests.length;
        hasJoinRequest[msg.sender] = true;

        emit DemandAdhesionEnvoyee(msg.sender, _pseudo, block.timestamp);
    }

    function acceptJoinRequest(address _wallet) external seulementCreateur {
        require(hasJoinRequest[_wallet], "Demande non trouvee");
        require(statut == TontineStatus.WAITING_MEMBERS, "Tontine non ouverte");

        uint256 idx = joinRequestIndex[_wallet];
        require(idx > 0, "Index invalide");
        require(idx <= joinRequests.length, "Index hors limites");

        JoinRequest storage req = joinRequests[idx - 1];
        require(req.status == JoinRequestStatus.PENDING, "Demande non en attente");

        req.status = JoinRequestStatus.ACCEPTED;
        req.acceptanceDeadline = block.timestamp + DELAI_ACCEPTATION_DEMANDE;

        _registerMember(_wallet, req.pseudo, MemberStatus.PENDING);

        uint256 montantGarantie = 0;
        if (guaranteeMode) {
            montantGarantie = _calculateGarantie(montantCotisation);
        }

        emit DemandAdhesionAcceptee(_wallet, montantGarantie, req.acceptanceDeadline, block.timestamp);
    }

    function rejectJoinRequest(address _wallet) external seulementCreateur {
        require(hasJoinRequest[_wallet], "Demande non trouvee");

        uint256 idx = joinRequestIndex[_wallet];
        require(idx > 0, "Index invalide");

        JoinRequest storage req = joinRequests[idx - 1];
        require(req.status == JoinRequestStatus.PENDING, "Demande non en attente");

        req.status = JoinRequestStatus.REJECTED;

        emit DemandAdhesionRefusee(_wallet, block.timestamp);
    }

    function depositGuarantee() external payable nonReentrant {
        require(estMembre[msg.sender], "Pas membre");
        require(membres[msg.sender].statut == MemberStatus.PENDING, "Statut invalide");

        uint256 idx = joinRequestIndex[msg.sender];
        require(idx > 0, "Pas de demande");

        JoinRequest storage req = joinRequests[idx - 1];
        require(req.status == JoinRequestStatus.ACCEPTED, "Demande non acceptee");
        require(block.timestamp <= req.acceptanceDeadline, "Delai expire");

        if (guaranteeMode) {
            uint256 montantRequired = _calculateGarantie(montantCotisation);
            require(msg.value >= montantRequired, "Garantie insuffisante");

            Member storage memberData = membres[msg.sender];
            memberData.garantieBloquee = msg.value;
            totalGarantiesBloquees += msg.value;
        }

        Member storage memberData2 = membres[msg.sender];
        memberData2.statut = MemberStatus.ACTIVE;
        membresDates[msg.sender].dateAdhesion = block.timestamp;

        emit GarantieDeposeee(msg.sender, msg.value, block.timestamp);
        emit MembreRejoint(msg.sender, req.pseudo, msg.value, block.timestamp);

        uint256 membresActifs = 0;
        for (uint256 i = 0; i < listeMembres.length; i++) {
            if (membres[listeMembres[i]].statut == MemberStatus.ACTIVE) {
                membresActifs++;
            }
        }
        if (membresActifs == nombreMaxMembres) {
            statut = TontineStatus.READY_TO_START;
        }
    }

    // ══════════════════════════════════════════════════════════════
    // DÉMARRAGE TONTINE
    // ══════════════════════════════════════════════════════════════

    function setOrdreBeneficiaires(address[] calldata _ordre) external seulementBackend {
        require(statut == TontineStatus.READY_TO_START, "Tontine pas prete");
        require(!ordreVerrouille, "Ordre deja verrouille");
        require(_ordre.length == nombreMembresActuels, "Taille ordre invalide");

        for (uint256 i = 0; i < _ordre.length; i++) {
            require(estMembre[_ordre[i]], "Adresse non membre");
            require(membres[_ordre[i]].statut == MemberStatus.ACTIVE, "Membre non actif");

            for (uint256 j = i + 1; j < _ordre.length; j++) {
                require(_ordre[i] != _ordre[j], "Doublon dans l'ordre");
            }
        }

        delete ordreBeneficiaires;
        for (uint256 i = 0; i < _ordre.length; i++) {
            ordreBeneficiaires.push(_ordre[i]);
            membres[_ordre[i]].positionOrdre = i;
        }
    }

    function startTontine() external seulementBackend nonReentrant {
        require(statut == TontineStatus.READY_TO_START, "Statut invalide");
        require(ordreBeneficiaires.length == nombreMembresActuels, "Ordre incomplet");
        require(!ordreVerrouille, "Ordre deja verrouille");

        ordreVerrouille = true;
        dateDemarrage = block.timestamp;
        statut = TontineStatus.ACTIVE;
        cycleActuel = 0;

        _createCycle();

        emit TontineDemarree(dateDemarrage, ordreBeneficiaires, block.timestamp);
    }

    // ══════════════════════════════════════════════════════════════
    // GESTION CYCLES
    // ══════════════════════════════════════════════════════════════

    function _createCycle() internal {
        require(statut == TontineStatus.ACTIVE, "Tontine non active");
        require(cycleActuel < ordreBeneficiaires.length, "Tous les cycles termines");

        address beneficiaire = ordreBeneficiaires[cycleActuel];
        require(estMembre[beneficiaire], "Beneficiaire inconnu");
        require(!membres[beneficiaire].aRecu, "Beneficiaire deja servi");

        uint256 periodeCycle;
        if (frequence == Frequence.DAILY) {
            periodeCycle = 1 days;
        } else if (frequence == Frequence.WEEKLY) {
            periodeCycle = 7 days;
        } else {
            periodeCycle = 30 days;
        }

        uint256 dateDebut = block.timestamp;
        uint256 dateEcheance = dateDebut + periodeCycle;

        uint256 delaiGrace;
        if (frequence == Frequence.DAILY) {
            delaiGrace = DELAI_GRACE_DAILY;
        } else if (frequence == Frequence.WEEKLY) {
            delaiGrace = DELAI_GRACE_WEEKLY;
        } else {
            delaiGrace = DELAI_GRACE_MONTHLY;
        }

        uint256 dateGrace = dateEcheance + delaiGrace;
        uint256 dateDistribution = dateGrace + 1 hours;
        uint256 dateRetrait = dateDistribution + PERIODE_RETRAIT;

        Cycle storage c = cycles[cycleActuel];
        c.id = cycleActuel;
        c.beneficiaire = beneficiaire;
        c.dateDebut = dateDebut;
        c.dateLimiteCotisation = dateEcheance;
        c.dateFinDelaiGrace = dateGrace;
        c.dateDistribution = dateDistribution;
        c.dateFinRetrait = dateRetrait;

        uint256 membresActifs = 0;
        for (uint256 i = 0; i < listeMembres.length; i++) {
            Member storage m = membres[listeMembres[i]];
            if (m.statut == MemberStatus.ACTIVE || m.statut == MemberStatus.LATE) {
                membresActifs++;
            }
        }

        c.montantAttendu = montantCotisation * membresActifs;
        c.montantCollecte = 0;
        c.statut = CycleStatus.COLLECTING;
        c.distributionEffectuee = false;

        nombreCycles++;

        emit CycleCommence(cycleActuel, beneficiaire, dateEcheance, dateDistribution, block.timestamp);
    }

    // ══════════════════════════════════════════════════════════════
    // COTISATIONS
    // ══════════════════════════════════════════════════════════════

    function _calculateLatePenaltyBps(Cycle storage c) internal view returns (uint256) {
        if (block.timestamp <= c.dateLimiteCotisation) {
            return 0;
        }

        uint256 maxDelay = c.dateFinDelaiGrace - c.dateLimiteCotisation;
        if (maxDelay == 0) {
            return 0;
        }

        uint256 delayDuration = block.timestamp - c.dateLimiteCotisation;
        uint256 delayRatioBps = (delayDuration * 10000) / maxDelay;

        if (delayRatioBps <= 2500) {
            return 300; // +3%
        } else if (delayRatioBps <= 5000) {
            return 700; // +7%
        } else if (delayRatioBps <= 7500) {
            return 1200; // +12%
        } else if (delayRatioBps <= 10000) {
            return 1800; // +18%
        } else if (delayRatioBps <= 12500) {
            return 3000; // +30%
        } else if (delayRatioBps <= 15000) {
            return 4500; // +45%
        }

        return 6000; // +60%
    }

    function payContribution() external payable seulementMembre tontineActive nonReentrant {
        require(cycleActuel < nombreCycles, "Pas de cycle actif");

        Cycle storage c = cycles[cycleActuel];
        require(c.statut == CycleStatus.COLLECTING, "Cycle non collectant");
        require(!aPaye[cycleActuel][msg.sender], "Deja paye ce cycle");

        uint256 penaltyBps = _calculateLatePenaltyBps(c);
        uint256 montantRequis = montantCotisation + ((montantCotisation * penaltyBps) / 10000);
        require(msg.value == montantRequis, "Montant exact requis (penalite incluse)");

        Member storage m = membres[msg.sender];
        require(m.statut == MemberStatus.ACTIVE || m.statut == MemberStatus.LATE, "Statut non eligible");

        aPaye[cycleActuel][msg.sender] = true;
        aPayeATemps[cycleActuel][msg.sender] = block.timestamp <= c.dateLimiteCotisation;
        c.membresAyantPaye.push(msg.sender);
        c.montantCollecte += msg.value;
        m.totalCotise += msg.value;
        membresDates[msg.sender].derniereCotisation = block.timestamp;

        if (m.statut == MemberStatus.LATE) {
            m.statut = MemberStatus.ACTIVE;
        }

        emit CotisationPayee(msg.sender, cycleActuel, msg.value, block.timestamp);

        if (c.montantCollecte >= c.montantAttendu) {
            c.statut = CycleStatus.VERIFYING;
        }
    }

    // ══════════════════════════════════════════════════════════════
    // VÉRIFICATION RETARDS ET INCIDENTS
    // ══════════════════════════════════════════════════════════════

    function verifyPaymentsAndHandleDefaults() external seulementBackend tontineActive nonReentrant {
        require(cycleActuel < nombreCycles, "Pas de cycle");

        Cycle storage c = cycles[cycleActuel];
        require(c.statut == CycleStatus.VERIFYING, "Cycle non verifiable");

        for (uint256 i = 0; i < listeMembres.length; i++) {
            address memberAddr = listeMembres[i];
            Member storage m = membres[memberAddr];

            if (!estMembre[memberAddr]) continue;
            if (aPaye[cycleActuel][memberAddr]) continue;
            if (m.statut == MemberStatus.EXCLUDED || m.statut == MemberStatus.SUSPENDED || m.statut == MemberStatus.COMPLETED) {
                continue;
            }

            emit RetardDetecte(memberAddr, cycleActuel, block.timestamp);
            m.statut = MemberStatus.LATE;

            m.incidents++;
            emit IncidentComptabilise(memberAddr, m.incidents, "Retard de cotisation", block.timestamp);

            if (guaranteeMode && m.garantieBloquee >= montantCotisation) {
                m.garantieBloquee -= montantCotisation;
                totalGarantiesBloquees -= montantCotisation;
                c.montantCollecte += montantCotisation;

                emit GarantieUtilisee(memberAddr, cycleActuel, montantCotisation, m.garantieBloquee, block.timestamp);
            }

            if (m.incidents >= SEUIL_SUSPENSION_INCIDENTS && m.incidents < SEUIL_EXCLUSION_INCIDENTS) {
                if (m.statut != MemberStatus.SUSPENDED) {
                    m.statut = MemberStatus.SUSPENDED;
                    membresDates[memberAddr].dateSuspension = block.timestamp;
                    emit MembreSuspendu(memberAddr, cycleActuel, "Incidents progressifs", block.timestamp);
                }
            }

            if (m.incidents >= SEUIL_EXCLUSION_INCIDENTS) {
                m.statut = MemberStatus.EXCLUDED;
                membresDates[memberAddr].dateExclusion = block.timestamp;
                nombreExclus++;
                emit MembreExclu(memberAddr, cycleActuel, "Trop d'incidents", block.timestamp);
            }
        }

        if (nombreExclus > seuilEchec) {
            _failTontineInternal();
            return;
        }

        c.statut = CycleStatus.DISTRIBUTING;
    }

    function suspendMember(address _member) external seulementBackend {
        require(estMembre[_member], "Membre inconnu");

        Member storage m = membres[_member];
        require(m.statut != MemberStatus.EXCLUDED, "Deja exclu");

        m.statut = MemberStatus.SUSPENDED;
        membresDates[_member].dateSuspension = block.timestamp;

        emit MembreSuspendu(_member, cycleActuel, "Suspension manuelle", block.timestamp);
    }

    function excludeMember(address _member) external seulementBackend {
        require(estMembre[_member], "Membre inconnu");

        Member storage m = membres[_member];
        require(m.statut != MemberStatus.EXCLUDED, "Deja exclu");

        m.statut = MemberStatus.EXCLUDED;
        membresDates[_member].dateExclusion = block.timestamp;
        nombreExclus++;

        emit MembreExclu(_member, cycleActuel, "Exclusion manuelle", block.timestamp);
    }

    // ══════════════════════════════════════════════════════════════
    // RÉORGANISATION DYNAMIQUE
    // ══════════════════════════════════════════════════════════════

    function reorderBeneficiaries(address[] calldata _newOrder) external seulementBackend {
        require(ordreVerrouille, "Ordre non verrouille");
        require(_newOrder.length == ordreBeneficiaires.length, "Taille ordre invalide");

        for (uint256 i = 0; i < _newOrder.length; i++) {
            require(estMembre[_newOrder[i]], "Adresse non membre");

            for (uint256 j = i + 1; j < _newOrder.length; j++) {
                require(_newOrder[i] != _newOrder[j], "Doublon dans l'ordre");
            }
        }

        ordreBeneficiaires = new address[](_newOrder.length);
        for (uint256 i = 0; i < _newOrder.length; i++) {
            ordreBeneficiaires[i] = _newOrder[i];
            membres[_newOrder[i]].positionOrdre = i;
        }
    }

    // ══════════════════════════════════════════════════════════════
    // DISTRIBUTION ALLOCATION
    // ══════════════════════════════════════════════════════════════

    function distributeAllocation(uint8 _scoreConfiance) external seulementBackend tontineActive nonReentrant {
        require(cycleActuel < nombreCycles, "Pas de cycle");
        require(_scoreConfiance <= 100, "Score invalide");

        Cycle storage c = cycles[cycleActuel];
        require(c.statut == CycleStatus.DISTRIBUTING, "Cycle non distribuable");
        require(!c.distributionEffectuee, "Distribution deja effectuee");

        address beneficiaire = c.beneficiaire;
        Member storage m = membres[beneficiaire];

        require(estMembre[beneficiaire], "Beneficiaire inconnu");
        require(!m.aRecu, "Beneficiaire deja servi");
        require(c.montantCollecte > 0, "Montant nul");

        require(address(this).balance >= c.montantCollecte, "Solde contrat insuffisant");
        require(address(this).balance - c.montantCollecte >= totalGarantiesBloquees, "Garanties doivent etre protegees");

        bool beneficiairePayeATemps = aPayeATemps[cycleActuel][beneficiaire];
        uint256 montantReserve = beneficiairePayeATemps ? 0 : (c.montantCollecte * 2000) / 10000;
        uint256 montantLibere = c.montantCollecte - montantReserve;

        c.distributionEffectuee = true;
        c.statut = CycleStatus.FINISHED;
        m.aRecu = true;
        m.montantRecu = montantLibere;

        soldesRetirables[beneficiaire] += montantLibere;
        if (montantReserve > 0) {
            soldesReserve[beneficiaire] += montantReserve;
            dateDeblockageReserve[beneficiaire] = block.timestamp + 30 days;
        }

        emit AllocationDistribuee(beneficiaire, cycleActuel, c.montantCollecte, montantLibere, montantReserve, _scoreConfiance, block.timestamp);

        cycleActuel++;
        if (cycleActuel >= ordreBeneficiaires.length) {
            statut = TontineStatus.COMPLETED;
            emit TontineTerminee(block.timestamp, nombreCycles, block.timestamp);
        } else {
            _createCycle();
        }
    }

    // ══════════════════════════════════════════════════════════════
    // RECHARGES ET RETRAITS
    // ══════════════════════════════════════════════════════════════

    function rechargeGarantie() external payable seulementMembre nonReentrant {
        require(estMembre[msg.sender], "Membre inconnu");
        require(msg.value > 0, "Montant nul");

        Member storage m = membres[msg.sender];
        require(m.statut == MemberStatus.SUSPENDED, "Recharge non necessaire");

        m.garantieBloquee += msg.value;
        totalGarantiesBloquees += msg.value;

        uint256 montantMinRequired = _calculateGarantie(montantCotisation);
        if (m.garantieBloquee >= montantMinRequired) {
            m.statut = MemberStatus.ACTIVE;
        }

        emit GarantieRechargee(msg.sender, msg.value, m.garantieBloquee, block.timestamp);
    }

    function withdrawAllocated(uint256 _montant) external nonReentrant {
        require(_montant > 0, "Montant nul");
        require(soldesRetirables[msg.sender] >= _montant, "Fonds insuffisants");
        require(address(this).balance >= _montant, "Solde contrat insuffisant");

        soldesRetirables[msg.sender] -= _montant;

        (bool success, ) = payable(msg.sender).call{value: _montant}("");
        require(success, "Transfert echoue");
    }

    function withdrawReserve(uint256 _montant) external nonReentrant {
        require(_montant > 0, "Montant nul");
        require(block.timestamp >= dateDeblockageReserve[msg.sender], "Reserve non debloquee");
        require(soldesReserve[msg.sender] >= _montant, "Reserve insuffisante");
        require(address(this).balance >= _montant, "Solde contrat insuffisant");

        soldesReserve[msg.sender] -= _montant;

        if (soldesReserve[msg.sender] == 0) {
            dateDeblockageReserve[msg.sender] = 0;
        }

        emit ReserveDebloquee(msg.sender, _montant, block.timestamp);

        (bool success, ) = payable(msg.sender).call{value: _montant}("");
        require(success, "Transfert reserve echoue");
    }

    function withdrawGuarantee() external nonReentrant {
        require(estMembre[msg.sender], "Pas membre");

        Member storage m = membres[msg.sender];
        uint256 montantGarantie = m.garantieBloquee;

        require(montantGarantie > 0, "Pas de garantie");
        require(statut == TontineStatus.COMPLETED || statut == TontineStatus.FAILED || m.statut == MemberStatus.EXCLUDED, "Tontine active");
        require(address(this).balance >= montantGarantie, "Solde contrat insuffisant");

        m.garantieBloquee = 0;
        totalGarantiesBloquees -= montantGarantie;

        (bool success, ) = payable(msg.sender).call{value: montantGarantie}("");
        require(success, "Transfert garantie echoue");
    }

    // ══════════════════════════════════════════════════════════════
    // CLÔTURE ET DISSOLUTION
    // ══════════════════════════════════════════════════════════════

    function closeTontine() external seulementBackend nonReentrant {
        require(
            statut == TontineStatus.ACTIVE ||
            statut == TontineStatus.DISTRIBUTION_IN_PROGRESS ||
            statut == TontineStatus.COMPLETED,
            "Statut invalide pour cloturer"
        );

        for (uint256 i = 0; i < listeMembres.length; i++) {
            address memberAddr = listeMembres[i];
            Member storage m = membres[memberAddr];

            if (!estMembre[memberAddr]) continue;

            uint256 garantieALiberer = m.garantieBloquee;
            if (garantieALiberer > 0) {
                m.garantieBloquee = 0;
                totalGarantiesBloquees -= garantieALiberer;
                soldesRetirables[memberAddr] += garantieALiberer;
            }
        }

        statut = TontineStatus.COMPLETED;
        emit TontineTerminee(block.timestamp, nombreCycles, block.timestamp);
    }

    function dissolveGroup() external seulementBackend nonReentrant {
        require(nombreExclus * 100 / nombreMembresActuels >= 50, "Seuil dissolution non atteint");
        _failTontineInternal();
    }

    function _failTontineInternal() internal {
        statut = TontineStatus.FAILED;

        for (uint256 i = 0; i < listeMembres.length; i++) {
            address memberAddr = listeMembres[i];
            Member storage m = membres[memberAddr];

            if (!estMembre[memberAddr]) continue;

            uint256 garantieALiberer = m.garantieBloquee;
            if (garantieALiberer > 0) {
                m.garantieBloquee = 0;
                totalGarantiesBloquees -= garantieALiberer;
                soldesRetirables[memberAddr] += garantieALiberer;
            }
        }

        emit TontineEchouee("Trop d'exclusions - dissolution", nombreExclus, block.timestamp);
    }

    // ══════════════════════════════════════════════════════════════
    // HELPERS & GETTERS
    // ══════════════════════════════════════════════════════════════

    function getCycleStatus() external view returns (CycleStatus) {
        if (cycleActuel >= nombreCycles) return CycleStatus.FINISHED;
        return cycles[cycleActuel].statut;
    }

    function getMontantCollecte() external view returns (uint256) {
        if (cycleActuel >= nombreCycles) return 0;
        return cycles[cycleActuel].montantCollecte;
    }

    function getNombreAyantPaye() external view returns (uint256) {
        if (cycleActuel >= nombreCycles) return 0;
        return cycles[cycleActuel].membresAyantPaye.length;
    }

    function getBeneficiareActuel() external view returns (address) {
        if (cycleActuel >= ordreBeneficiaires.length) return address(0);
        return ordreBeneficiaires[cycleActuel];
    }

    function getSoldeRetiable(address _membre) external view returns (uint256) {
        return soldesRetirables[_membre];
    }

    function getSoldeReserve(address _membre) external view returns (uint256, uint256) {
        return (soldesReserve[_membre], dateDeblockageReserve[_membre]);
    }

    function getInfoMembre(address _membre)
        external
        view
        returns (
            bool exists,
            string memory pseudo,
            uint256 garantieBloquee,
            uint256 totalCotise,
            uint256 incidents,
                MemberStatus memberStatus,
            bool aRecu
        )
    {
        if (!estMembre[_membre]) {
            return (false, "", 0, 0, 0, MemberStatus.ACTIVE, false);
        }

        Member storage m = membres[_membre];
        return (true, m.pseudo, m.garantieBloquee, m.totalCotise, m.incidents, m.statut, m.aRecu);
    }

    function calculateGuarantieRequis(uint256 _cotisation) external view returns (uint256) {
        return _calculateGarantie(_cotisation);
    }

    function getJoinRequestsCount() external view returns (uint256) {
        return joinRequests.length;
    }

    function getJoinRequest(uint256 _index)
        external
        view
        returns (
            address wallet,
            string memory pseudo,
            uint256 timestamp,
            JoinRequestStatus status,
            uint256 acceptanceDeadline
        )
    {
        require(_index < joinRequests.length, "Index invalide");
        JoinRequest storage req = joinRequests[_index];
        return (req.wallet, req.pseudo, req.timestamp, req.status, req.acceptanceDeadline);
    }
}
