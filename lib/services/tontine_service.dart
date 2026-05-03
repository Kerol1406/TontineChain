import 'dart:math';

import '../models/index.dart';
import 'package:tontinechain/services/mock_auth_service.dart';

/// Service Mock pour simuler les opérations de tontine
class MockTontineService {
  static final MockTontineService _instance = MockTontineService._internal();

  factory MockTontineService() {
    return _instance;
  }

  MockTontineService._internal() {
    _initializeSeedTontines();
  }

  // Mock data
  final List<Tontine> _tontines = [];
  final List<Member> _members = [];
  final List<Payment> _payments = [];
  final Map<String, bool> _discoverableById = {};

  /// Initialiser les tontines de test
  void _initializeSeedTontines() {
    _tontines.addAll([
      Tontine(
        id: 'tontine_001',
        name: 'Les Bâtisseurs de Cotonou',
        description: 'Tontine pour les entrepreneurs et bâtisseurs de Cotonou. Contribution régulière pour les projets d\'expansion.',
        memberCount: 11,
        maxMembers: 15,
        monthlyAmount: 50000,
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(days: 120)),
        creatorId: 'creator_001',
        creatorName: 'Yacine Diallo',
        frequency: 'Mensuel',
        rating: 4.9,
      ),
      Tontine(
        id: 'tontine_002',
        name: 'Solidarité Éducation',
        description: 'Tontine dédiée à l\'accès à l\'éducation de qualité pour les enfants. Chaque contribution aide à financer les bourses.',
        memberCount: 6,
        maxMembers: 10,
        monthlyAmount: 25000,
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
        creatorId: 'creator_002',
        creatorName: 'Aminata Sow',
        frequency: 'Hebdo',
        rating: 4.2,
      ),
      Tontine(
        id: 'tontine_003',
        name: 'Horizon Épargne Or',
        description: 'Tontine d\'investissement à long terme. Placement d\'or et d\'actifs précieux pour la croissance de patrimoine.',
        memberCount: 5,
        maxMembers: 8,
        monthlyAmount: 200000,
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        creatorId: 'creator_003',
        creatorName: 'Kofi Mensah',
        frequency: 'Mensuel',
        rating: 4.8,
      ),
      Tontine(
        id: 'tontine_004',
        name: 'Cercle de Confiance 24',
        description: 'Tontine de solidarité quotidienne. Contribution journalière pour l\'aide mutuelle et l\'entraide communautaire.',
        memberCount: 2,
        maxMembers: 20,
        monthlyAmount: 5000,
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        creatorId: 'creator_004',
        creatorName: 'Mariam Toure',
        frequency: 'Journalier',
        rating: null, // Pas encore de rating
      ),
      Tontine(
        id: 'tontine_005',
        name: 'Femmes Entrepreneures',
        description: 'Tontine solidaire pour les femmes entrepreneurs. Fonds de roulement et microcrédit entre membres.',
        memberCount: 8,
        maxMembers: 12,
        monthlyAmount: 35000,
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
        creatorId: 'creator_005',
        creatorName: 'Fatoumata Diop',
        frequency: 'Mensuel',
        rating: 4.6,
      ),
      Tontine(
        id: 'tontine_tour_reception',
        name: 'Tontine Tour Réception',
        description: 'Tontine de démonstration - C\'est votre tour de recevoir la cagnotte !',
        memberCount: 5,
        maxMembers: 5,
        monthlyAmount: 100000,
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(days: 150)),
        creatorId: 'creator_demo',
        creatorName: 'Tontine Demo',
        frequency: 'Mensuel',
        rating: 4.7,
      ),
    ]);

    // Associer des membres tests provenant du MockAuthService (si disponibles)
    try {
      final users = MockAuthService.instance.users;
      if (users.isNotEmpty) {
        int uIndex = 0;
        for (var i = 0; i < _tontines.length - 1; i++) {
          // assigner 1..3 membres tests par tontine (sauf la dernière)
          final assignCount = 1 + (i % 3);
          for (var j = 0; j < assignCount; j++) {
            final u = users[uIndex % users.length];
            final member = Member(
              id: 'm_${u['id']}_${i}_$j',
              tontineId: _tontines[i].id,
              name: u['name'] ?? 'Utilisateur',
              email: (u['phone'] ?? '') + '@local',
              phone: u['phone'] ?? '',
              profileImageUrl: '',
              role: j == 0 ? 'organizer' : 'participant',
              joinedAt: DateTime.now().subtract(Duration(days: 10 + i + j)),
              isPaid: false,
              allocationOrder: j + 1,
              allocationStatus: 'waiting',
            );
            _members.add(member);
            uIndex++;
          }
        }
      }
    } catch (e) {
      // ignore errors in DEV seed linking
    }

    // Créer les membres pour la tontine "Tour Réception" 
    // Créer directement avec les numéros de test connus - TOUJOURS créé
    final testPhones = [
      (name: 'Admin Test', phone: '+22970000001'),
      (name: 'Utilisateur A', phone: '+22970000002'),
      (name: 'Utilisateur B', phone: '+22970000003'),
      (name: 'Utilisateur C', phone: '+22970000004'),
      (name: 'Utilisateur D', phone: '+22970000005'),
    ];

    for (var j = 0; j < testPhones.length; j++) {
      final testUser = testPhones[j];
      final isCurrentUser = j == 0; // Admin Test reçoit en ce moment
      
      final member = Member(
        id: 'm_reception_admin_$j',
        tontineId: 'tontine_tour_reception',
        name: testUser.name,
        email: '${testUser.phone}@local',
        phone: testUser.phone,
        profileImageUrl: '',
        role: j == 0 ? 'organizer' : 'participant',
        joinedAt: DateTime.now().subtract(const Duration(days: 180)),
        isPaid: true,
        allocationOrder: j + 1,
        allocationStatus: isCurrentUser ? 'current' : (j < 1 ? 'received' : 'waiting'),
      );
      _members.add(member);
    }
  }

  /// Récupérer toutes les tontines
  Future<List<Tontine>> getTontines() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return List<Tontine>.from(_tontines);
  }

  void _upsertTontine(Tontine tontine) {
    final existingIndex = _tontines.indexWhere((item) => item.id == tontine.id);
    if (existingIndex == -1) {
      _tontines.add(tontine);
      return;
    }
    _tontines[existingIndex] = tontine;
  }

  /// Indique si une tontine doit apparaître dans l'écran Découvrir.
  bool isDiscoverable(String tontineId) {
    return _discoverableById[tontineId] ?? true;
  }

  /// Créer une nouvelle tontine
  Future<Tontine> createTontine({
    required String name,
    required String description,
    required double monthlyAmount,
    required String creatorId,
    String? frequency,
    bool isDiscoverable = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final tontine = Tontine(
      id: 'tontine_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      memberCount: 1,
      monthlyAmount: monthlyAmount,
      status: 'active',
      createdAt: DateTime.now(),
      creatorId: creatorId,
      frequency: frequency,
      isDiscoverable: isDiscoverable,
    );
    
    _upsertTontine(tontine);
    _discoverableById[tontine.id] = isDiscoverable;
    return tontine;
  }

  /// Ajouter un membre à une tontine
  Future<Member> addMember({
    required String name,
    required String email,
    required String phone,
    required String tontineId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final member = Member(
      id: 'member_${DateTime.now().millisecondsSinceEpoch}',
      tontineId: tontineId,
      name: name,
      email: email,
      phone: phone,
      profileImageUrl: '',
      role: 'participant',
      joinedAt: DateTime.now(),
      isPaid: false,
    );
    
    _members.add(member);
    return member;
  }

  /// Enregistrer un paiement
  Future<Payment> recordPayment({
    required String tontineId,
    required String memberId,
    required double amount,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final payment = Payment(
      id: 'payment_${DateTime.now().millisecondsSinceEpoch}',
      tontineId: tontineId,
      memberId: memberId,
      amount: amount,
      paymentDate: DateTime.now(),
      status: 'completed',
      transactionId: 'txn_${DateTime.now().millisecondsSinceEpoch}',
    );
    
    _payments.add(payment);
    return payment;
  }

  /// Récupérer les paiements d'une tontine
  Future<List<Payment>> getPayments(String tontineId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _payments.where((p) => p.tontineId == tontineId).toList();
  }

  /// Retourne l'historique des opérations pour une tontine.
  /// Si aucun paiement existant n'est trouvé, génère des entrées d'exemple
  /// contenant des transactionId (hash) pour la démonstration.
  Future<List<Payment>> getHistoricPayments(String tontineId) async {
    await Future.delayed(const Duration(milliseconds: 500));

    var existing = _payments.where((p) => p.tontineId == tontineId).toList();
    if (existing.isNotEmpty) return existing;

    // Générer des paiements d'exemple en utilisant les membres disponibles
    final members = _members.where((m) => m.tontineId == tontineId).toList();
    final rand = Random(42);
    final tontine = _tontines.firstWhere((t) => t.id == tontineId, orElse: () => Tontine(
      id: tontineId,
      name: 'Tontine inconnue',
      description: '',
      memberCount: members.length,
      monthlyAmount: 50000,
      status: 'active',
      createdAt: DateTime.now(),
      creatorId: 'system',
    ));

    final now = DateTime.now();
    final sample = <Payment>[];
    for (var i = 0; i < 6; i++) {
      final member = members.isNotEmpty ? members[i % members.length] : Member(
        id: 'm_demo_$i', tontineId: tontineId, name: 'Membre $i', email: '', phone: '', profileImageUrl: '', role: 'participant', joinedAt: now.subtract(Duration(days: 100 + i)), isPaid: true, allocationOrder: i + 1, allocationStatus: 'waiting'
      );

      final amount = (i % 2 == 0) ? tontine.monthlyAmount : (tontine.monthlyAmount / 2).roundToDouble();
      final date = now.subtract(Duration(days: (i * 7) + rand.nextInt(6)));
      final txHash = _randomHex(rand, 20);

      final p = Payment(
        id: 'hist_${tontineId}_$i',
        tontineId: tontineId,
        memberId: member.id,
        amount: amount,
        paymentDate: date,
        status: 'completed',
        transactionId: txHash,
      );
      sample.add(p);
      _payments.add(p);
    }

    return sample;
  }

  String _randomHex(Random rand, int bytesCount) {
    const hex = '0123456789abcdef';
    final buf = StringBuffer('0x');
    for (var i = 0; i < bytesCount * 2; i++) {
      buf.write(hex[rand.nextInt(hex.length)]);
    }
    return buf.toString();
  }

  /// Récupérer les membres d'une tontine
  Future<List<Member>> getMembers(String tontineId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _members.where((m) => m.tontineId == tontineId).toList();
  }

  /// Confirmer la réception de la cagnotte pour un membre.
  ///
  /// Le membre `memberPhone` passe de `current` à `received`, puis le membre
  /// suivant dans l'ordre de rotation passe à `current` si disponible.
  Future<bool> confirmCagnotteReception({
    required String tontineId,
    required String memberPhone,
    required String receptionMethod,
    required String receiverPhone,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final membersInTontine = _members
        .where((m) => m.tontineId == tontineId)
        .toList()
      ..sort((a, b) => a.allocationOrder.compareTo(b.allocationOrder));

    if (membersInTontine.isEmpty) return false;

    final currentIndex = membersInTontine.indexWhere(
      (m) => m.phone == memberPhone && m.allocationStatus == 'current',
    );

    if (currentIndex == -1) return false;

    final currentMember = membersInTontine[currentIndex];
    final updatedCurrent = Member(
      id: currentMember.id,
      tontineId: currentMember.tontineId,
      name: currentMember.name,
      email: currentMember.email,
      phone: currentMember.phone,
      profileImageUrl: currentMember.profileImageUrl,
      role: currentMember.role,
      joinedAt: currentMember.joinedAt,
      isPaid: currentMember.isPaid,
      allocationOrder: currentMember.allocationOrder,
      allocationStatus: 'received',
    );

    final globalCurrentIndex = _members.indexWhere((m) => m.id == currentMember.id);
    if (globalCurrentIndex != -1) {
      _members[globalCurrentIndex] = updatedCurrent;
    }

    final hasNext = currentIndex + 1 < membersInTontine.length;
    if (hasNext) {
      final nextMember = membersInTontine[currentIndex + 1];
      final updatedNext = Member(
        id: nextMember.id,
        tontineId: nextMember.tontineId,
        name: nextMember.name,
        email: nextMember.email,
        phone: nextMember.phone,
        profileImageUrl: nextMember.profileImageUrl,
        role: nextMember.role,
        joinedAt: nextMember.joinedAt,
        isPaid: nextMember.isPaid,
        allocationOrder: nextMember.allocationOrder,
        allocationStatus: 'current',
      );

      final globalNextIndex = _members.indexWhere((m) => m.id == nextMember.id);
      if (globalNextIndex != -1) {
        _members[globalNextIndex] = updatedNext;
      }
    }

    final receptionPayment = Payment(
      id: 'reception_${DateTime.now().millisecondsSinceEpoch}',
      tontineId: tontineId,
      memberId: updatedCurrent.id,
      amount: _tontines.firstWhere((t) => t.id == tontineId).monthlyAmount,
      paymentDate: DateTime.now(),
      status: 'completed',
      transactionId:
          'rx_${receptionMethod}_${receiverPhone}_${DateTime.now().millisecondsSinceEpoch}',
    );
    _payments.add(receptionPayment);

    return true;
  }

  /// Reset du scénario démo: remet systématiquement le tour à Admin Test.
  /// Utile pour les présentations où il faut rejouer la réception à chaque retour.
  void resetDemoReceptionTour() {
    const demoTontineId = 'tontine_tour_reception';
    const demoCurrentPhone = '+22970000001';

    for (var i = 0; i < _members.length; i++) {
      final member = _members[i];
      if (member.tontineId != demoTontineId) continue;

      final updated = Member(
        id: member.id,
        tontineId: member.tontineId,
        name: member.name,
        email: member.email,
        phone: member.phone,
        profileImageUrl: member.profileImageUrl,
        role: member.role,
        joinedAt: member.joinedAt,
        isPaid: member.isPaid,
        allocationOrder: member.allocationOrder,
        allocationStatus: member.phone == demoCurrentPhone ? 'current' : 'waiting',
      );

      _members[i] = updated;
    }
  }

  /// Récupérer synchronously les tontines auxquelles un téléphone appartient
  List<Tontine> getTontinesForUserSync(String phone) {
    // Debug: afficher ce qu'on cherche et ce qu'on trouve
    // ignore: avoid_print
    print('[TontineService] Searching tontines for phone: $phone');
    // ignore: avoid_print
    print('[TontineService] Total members: ${_members.length}');
    final membersWithPhone = _members.where((m) => m.phone == phone).toList();
    // ignore: avoid_print
    print('[TontineService] Members with this phone: ${membersWithPhone.length}');
    
    final tontineIds = membersWithPhone
        .map((m) => m.tontineId)
        .where((id) => id != null)
        .cast<String>()
        .toSet();
    
    // ignore: avoid_print
    print('[TontineService] Tontine IDs for user: $tontineIds');

    return _tontines.where((t) => tontineIds.contains(t.id)).toList();
  }
}
