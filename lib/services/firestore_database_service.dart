import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/index.dart';
import 'backend_service.dart';

/// Service Firestore/Storage centralisé pour les données métier.
///
/// Collections principales :
/// - users: profils utilisateurs, KYC, portefeuille
/// - tontines: groupes de tontines avec membres et cycles
/// - contributions: cotisations (PAYE | NON_PAYE) par cycle
/// - transactions: historique des mouvements (COTISATION, GAIN, CREATION_TONTINE, AJOUT_MEMBRE)
/// - notifications: alertes et messages in-app
/// - joinRequests: demandes d'adhésion à une tontine
/// - invitations: invitations à rejoindre une tontine avec score de confiance
///
/// Storage :
/// - ids/{userId}.jpg: pièce d'identité
/// - profiles/{userId}.jpg: photo de profil
class FirestoreDatabaseService {
  FirestoreDatabaseService._();

  static final FirestoreDatabaseService instance = FirestoreDatabaseService._();
  static const double _defaultGlobalScore = 40;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get _tontines =>
      _firestore.collection('tontines');
  CollectionReference<Map<String, dynamic>> get _contributions =>
      _firestore.collection('contributions');
  CollectionReference<Map<String, dynamic>> get _transactions =>
      _firestore.collection('transactions');
  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');
  CollectionReference<Map<String, dynamic>> get _joinRequests =>
      _firestore.collection('joinRequests');
    CollectionReference<Map<String, dynamic>> get _invitations =>
      _firestore.collection('invitations');

  /// Normalize UID to lowercase to match backend normalization and avoid duplicate docs
  String _normalizeUid(String uid) => uid.toLowerCase();

  // ============================================================================
  // USERS
  // ============================================================================

  /// Sauvegarde ou met à jour le profil utilisateur.
  /// Champs: firstName, lastName, phone (normalisé E.164), email, photoProfil, pieceIdentite,
  /// kycStatus (PENDING|APPROVED|REJECTED), isLookingForTontine, fcmToken, solde, tontines.
  Future<void> saveUserProfile({
    required String uid,
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    String? photoProfileUrl,
    String? identityDocumentUrl,
    String kycStatus = 'PENDING',
    bool isLookingForTontine = true,
    String? fcmToken,
    double solde = 0.0,
    List<String> tontines = const [],
    bool deleted = false,
    String? walletAddress,
  }) async {
    final normalizedUid = _normalizeUid(uid);
    await _users.doc(normalizedUid).set({
      'uid': normalizedUid,
      'firstName': firstName,
      'lastName': lastName,
      'nom': '$firstName $lastName',
      'phone': phone, // E.164 format: +2290152683206
      'email': email,
      'photoProfil': photoProfileUrl,
      'pieceIdentite': identityDocumentUrl,
      'kycStatus': kycStatus, // PENDING, APPROVED, REJECTED
      'isLookingForTontine': isLookingForTontine,
        'activeMode': isLookingForTontine,
        'activeSearchStatus': isLookingForTontine
          ? 'Disponible et en recherche'
          : 'Mode actif désactivé',
      'fcmToken': fcmToken,
      'solde': solde, // solde du portefeuille
      'tontines': tontines, // liste des tontineId
      'deleted': deleted,
      if (walletAddress != null) 'walletAddress': walletAddress,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _users.doc(normalizedUid).collection('globalScore').doc('current').set({
      'wallet': normalizedUid,
      'score': _defaultGlobalScore,
      'lastReason': 'initial',
      'totalTontineParticipations': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Récupère un profil utilisateur par UID.
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final normalizedUid = _normalizeUid(uid);
    final doc = await _users.doc(normalizedUid).get();
    if (!doc.exists) {
      return null;
    }

    final data = doc.data() ?? <String, dynamic>{};
    final score = await _getUserGlobalScore(uid);

    return {
      ...data,
      'trustScore': score,
      'globalScore': score,
    };
  }

  /// Récupère le score global d'un utilisateur depuis Firestore.
  /// Si le document n'existe pas encore, on renvoie le score par défaut du produit.
  Future<double> _getUserGlobalScore(String uid) async {
    final normalizedUid = _normalizeUid(uid);
    final doc = await _users.doc(normalizedUid).collection('globalScore').doc('current').get();
    if (!doc.exists) {
      return _defaultGlobalScore;
    }

    final data = doc.data() ?? <String, dynamic>{};
    final score = (data['score'] as num?)?.toDouble();
    return score ?? _defaultGlobalScore;
  }

  /// Recherche un utilisateur par téléphone normalisé (E.164).
  Future<Map<String, dynamic>?> getUserProfileByPhone(String phone) async {
    final query = await _users
        .where('phone', isEqualTo: phone)
        .where('deleted', isEqualTo: false)
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      return null;
    }
    return query.docs.first.data();
  }

  /// Recherche un profil utilisateur par téléphone en essayant plusieurs variantes
  /// (champ `phone`, champ `telephone`, sans préfixe +229, et avec 0 initial).
  Future<Map<String, dynamic>?> getUserProfileByPhoneVariants(String phone) async {
    // 1) exact match on 'phone'
    final exactPhone = await getUserProfileByPhone(phone);
    if (exactPhone != null) return exactPhone;

    // 2) try 'telephone' field exact match
    final queryTelephone = await _users
        .where('telephone', isEqualTo: phone)
        .where('deleted', isEqualTo: false)
        .limit(1)
        .get();
    if (queryTelephone.docs.isNotEmpty) return queryTelephone.docs.first.data();

    // 3) try variants: remove +229 if present
    String withoutPrefix = phone;
    if (withoutPrefix.startsWith('+229')) {
      withoutPrefix = withoutPrefix.substring(4);
    } else if (withoutPrefix.startsWith('229')) {
      withoutPrefix = withoutPrefix.substring(3);
    }

    // try withoutPrefix
    final queryNoPrefix = await _users
        .where('phone', isEqualTo: withoutPrefix)
        .where('deleted', isEqualTo: false)
        .limit(1)
        .get();
    if (queryNoPrefix.docs.isNotEmpty) return queryNoPrefix.docs.first.data();

    final queryNoPrefixTelephone = await _users
        .where('telephone', isEqualTo: withoutPrefix)
        .where('deleted', isEqualTo: false)
        .limit(1)
        .get();
    if (queryNoPrefixTelephone.docs.isNotEmpty) return queryNoPrefixTelephone.docs.first.data();

    // 4) try with leading zero
    String withZero = withoutPrefix;
    if (!withZero.startsWith('0')) withZero = '0$withZero';

    final queryWithZero = await _users
        .where('phone', isEqualTo: withZero)
        .where('deleted', isEqualTo: false)
        .limit(1)
        .get();
    if (queryWithZero.docs.isNotEmpty) return queryWithZero.docs.first.data();

    final queryWithZeroTelephone = await _users
        .where('telephone', isEqualTo: withZero)
        .where('deleted', isEqualTo: false)
        .limit(1)
        .get();
    if (queryWithZeroTelephone.docs.isNotEmpty) return queryWithZeroTelephone.docs.first.data();

    // nothing found
    return null;
  }

  /// Met à jour le token FCM.
  Future<void> updateFcmToken(String uid, String? token) async {
    await _users.doc(_normalizeUid(uid)).set({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Met à jour le solde du portefeuille.
  Future<void> updateSolde(String uid, double newSolde) async {
    await _users.doc(_normalizeUid(uid)).set({
      'solde': newSolde,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Ajoute une tontine à la liste des tontines de l'utilisateur.
  Future<void> addTontineToUser(String uid, String tontineId) async {
    await _users.doc(_normalizeUid(uid)).update({
      'tontines': FieldValue.arrayUnion([tontineId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Retire une tontine de la liste des tontines de l'utilisateur.
  Future<void> removeTontineFromUser(String uid, String tontineId) async {
    await _users.doc(_normalizeUid(uid)).update({
      'tontines': FieldValue.arrayRemove([tontineId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Met à jour le mode actif utilisateur pour la recherche de tontine.
  Future<void> updateUserActiveMode(String uid, bool isActive) async {
    await _users.doc(_normalizeUid(uid)).set({
      'isLookingForTontine': isActive,
      'activeMode': isActive,
      'activeSearchStatus': isActive
          ? 'Disponible et en recherche'
          : 'Mode actif désactivé',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Liste les utilisateurs actuellement actifs pour des suggestions d'invitation.
  Future<List<Map<String, dynamic>>> getUsersLookingForTontine({
    String? excludeUid,
    int limit = 50,
  }) async {
    final query = await _users
        .where('deleted', isEqualTo: false)
        .where('isLookingForTontine', isEqualTo: true)
        .limit(limit)
        .get();

    return query.docs
        .where((doc) => excludeUid == null || doc.id != excludeUid)
        .map((doc) {
          final data = doc.data();
          return {
            'uid': doc.id,
            ...data,
          };
        })
        .toList();
  }

  // ============================================================================
  // TONTINES
  // ============================================================================

  /// Crée une tontine.
  /// Champs: nom, description, montant, frequence (hebdo|mensuel), nombreMaxMembres,
  /// createur (userId), membres, ordre, cycleActuel, statut (EN_ATTENTE|EN_COURS|TERMINE|SUSPENDUE|ARCHIVEE).
  Future<String> createTontine({
    required String name,
    required String description,
    required double amount,
    required String frequency, // "hebdo" ou "mensuel"
    required int nombreMaxMembres,
    required String createur, // userId
    required bool isPublic,
    List<String> membres = const [],
    List<String> ordre = const [],
    int cycleActuel = 0,
    String? statut,
    String? creatorWallet,
    String? creatorPseudo,
  }) async {
    final doc = _tontines.doc();
    final tontineId = doc.id;
    final allMembers = [createur, ...membres];
    final placesRestantes = nombreMaxMembres - allMembers.length;
    final statutAuto = placesRestantes <= 0 ? 'EN_COURS' : 'EN_ATTENTE';
    final initialOrder = ordre.isNotEmpty
        ? List<String>.from(ordre)
        : List<String>.from(allMembers);
    if (placesRestantes <= 0) {
      initialOrder.shuffle(Random());
    }
    final initialOrderIndex = {
      for (int i = 0; i < initialOrder.length; i++) initialOrder[i]: i,
    };
    final startCycle = placesRestantes <= 0 && cycleActuel <= 0 ? 1 : cycleActuel;

    // Charger le profil du créateur pour récupérer son nom
    String creatorFullName = 'Utilisateur';
    try {
      final creatorProfile = await getUserProfile(createur);
      if (creatorProfile != null) {
        final firstName = (creatorProfile['firstName'] ?? '').toString().trim();
        final lastName = (creatorProfile['lastName'] ?? '').toString().trim();
        if (firstName.isNotEmpty || lastName.isNotEmpty) {
          creatorFullName = '$firstName $lastName'.trim();
        }
      }
    } catch (e) {
      print('[ERROR] createTontine: Failed to load creator profile: $e');
    }

    final deployment = await BackendService.instance.deployTontineContract({
      'tontineId': tontineId,
      'name': name,
      'monthlyAmount': amount,
      'frequency': frequency,
      'maxMembers': nombreMaxMembres,
      'creatorId': createur,
      'creatorWallet': creatorWallet ?? createur,
      'creatorPseudo': creatorPseudo ?? creatorFullName,
      'isPublic': isPublic,
      'callMembersEnabled': isPublic,
    });

    await doc.set({
      'nom': name,
      'description': description,
      'montant': amount,
      'frequence': frequency,
      'nombreMaxMembres': nombreMaxMembres,
      'createur': createur,
      'creatorId': createur,
      'creatorName': creatorFullName,
      'uid': createur,
      'userId': createur,
      'membres': allMembers, // le créateur est membre
      'ordre': initialOrder,
      'ordreIndex': initialOrderIndex,
      'calendrierAllocations': _buildAllocationCalendar(initialOrder, frequency),
      'cycleActuel': startCycle,
      'statut': statut ?? statutAuto, // EN_ATTENTE, EN_COURS, TERMINE, SUSPENDUE, ARCHIVEE
      'isPublic': isPublic,
      'placesRestantes': placesRestantes,
      'deleted': false,
      'contractAddress': deployment['result']?['contractAddress'],
      'contractTransactionHash': deployment['result']?['contractTransactionHash'],
      'blockchainNetwork': deployment['result']?['network'],
      'deploymentStatus': 'DEPLOYED',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'creatorWallet': creatorWallet ?? createur,
      'creatorPseudo': creatorPseudo ?? creatorFullName,
    }, SetOptions(merge: true));
    return doc.id;
  }

  /// Récupère les tontines stockées en base et les convertit en modèle applicatif.
  Future<List<Tontine>> getTontines() async {
    try {
      print('[DEBUG] getTontines: Fetching all tontines from Firestore...');
      final snapshot = await _tontines.get();
      final tontines = snapshot.docs
          .where((doc) => (doc.data()['deleted'] ?? false) == false)
          .map(_tontineFromDoc)
          .toList();
      tontines.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      print('[DEBUG] getTontines: Found ${tontines.length} public tontines');
      for (var t in tontines) {
        print('[DEBUG]   - ${t.name} (${t.status})');
      }
      return tontines;
    } catch (e) {
      print('[ERROR] getTontines failed: $e');
      return [];
    }
  }

  /// Récupère les tontines auxquelles appartient un utilisateur.
  Future<List<Tontine>> getUserTontinesAsModels(String userId) async {
    try {
      print('[DEBUG] getUserTontinesAsModels: Querying for userId=$userId');
      
      // First, debug: fetch ALL tontines to see what exists
      final allSnapshot = await _tontines.get();
      print('[DEBUG] Total tontines in Firestore: ${allSnapshot.docs.length}');
      for (var doc in allSnapshot.docs) {
        final data = doc.data();
        final membres = data['membres'] ?? [];
        print('[DEBUG]   - Tontine: ${data['nom']} | createur: ${data['createur']} | creatorId: ${data['creatorId']} | uid: ${data['uid']} | userId: ${data['userId']} | membres: $membres | deleted: ${data['deleted']}');
      }

      final tontines = allSnapshot.docs
          .where((doc) {
            final data = doc.data();
            final deleted = (data['deleted'] ?? false) == true;
            if (deleted) return false;

            final membres = List<String>.from(data['membres'] ?? const []);
            final createur = (data['createur'] ?? data['creatorId'] ?? data['uid'] ?? data['userId'] ?? '').toString();
            return membres.contains(userId) || createur == userId;
          })
          .map(_tontineFromDoc)
          .toList();

      tontines.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      print('[DEBUG] getUserTontinesAsModels: Found ${tontines.length} tontines for userId=$userId');

      return tontines;
    } catch (e) {
      print('[ERROR] getUserTontinesAsModels failed: $e');
      rethrow;
    }
  }

  Tontine _tontineFromData(String id, Map<String, dynamic> data) {
    final createdAtRaw = data['createdAt'];
    final createdAt = createdAtRaw is Timestamp
        ? createdAtRaw.toDate()
        : createdAtRaw is String
            ? DateTime.tryParse(createdAtRaw) ?? DateTime.now()
            : DateTime.now();

    final members = List<String>.from(data['membres'] ?? const []);
    final maxMembers = (data['nombreMaxMembres'] as num?)?.toInt();

    return Tontine(
      id: id,
      name: (data['nom'] ?? data['name'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      memberCount: members.isNotEmpty ? members.length : (data['memberCount'] as num?)?.toInt() ?? 0,
      monthlyAmount: ((data['montant'] ?? data['monthlyAmount'] ?? 0) as num).toDouble(),
      status: (data['statut'] ?? data['status'] ?? 'EN_COURS') as String,
      createdAt: createdAt,
      creatorId: (data['createur'] ?? data['creatorId'] ?? '') as String,
      currentCycle: (data['cycleActuel'] as num?)?.toInt() ??
          (data['currentCycle'] as num?)?.toInt() ??
          0,
      frequency: data['frequence'] as String?,
      isDiscoverable: data['isPublic'] as bool? ?? true,
      creatorName: data['creatorName'] as String?,
      maxMembers: maxMembers,
      memberIds: members,
    );
  }

  Tontine _tontineFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return _tontineFromData(doc.id, doc.data());
  }

  /// Récupère une tontine par ID.
  Future<Map<String, dynamic>?> getTontine(String tontineId) async {
    final doc = await _tontines.doc(tontineId).get();
    if (!doc.exists) {
      return null;
    }
    return doc.data();
  }

  /// Récupère une tontine par ID et la convertit en modèle applicatif.
  Future<Tontine?> getTontineAsModel(String tontineId) async {
    final doc = await _tontines.doc(tontineId).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return _tontineFromData(doc.id, data);
  }

  /// Récupère le calendrier d'allocations d'une tontine avec noms d'affichage.
  /// Retour: [{rang, userId, displayName, dateAllocation}]
  /// Récupère les membres d'une tontine avec leur statut de paiement.
  /// Retour: [{userId, displayName, photoUrl, role, isPaid, phone}]
  Future<List<Map<String, dynamic>>> getTontineMembersWithPayments(String tontineId) async {
    final tontine = await getTontine(tontineId);
    if (tontine == null) return const [];

    final memberIds = List<String>.from(tontine['membres'] ?? <String>[]);
    final creatorId = (tontine['creatorId'] ?? '').toString();
    // Utiliser 1 comme cycle par défaut pour rester cohérent avec la
    // simulation de paiement qui enregistre les contributions sur le cycle 1
    // lorsque la tontine n'a pas encore démarré (cycleActuel absent/0).
    final currentCycle = (tontine['cycleActuel'] as num?)?.toInt() ?? 1;
    final paidMemberIds = <String>{};

    if (currentCycle >= 1) {
      final contributionsQuery = await _contributions
          .where('tontineId', isEqualTo: tontineId)
          .where('cycle', isEqualTo: currentCycle)
          .where('deleted', isEqualTo: false)
          .get();

      for (final doc in contributionsQuery.docs) {
        final data = doc.data();
        final statut = (data['statut'] ?? '').toString().toUpperCase();
        if (statut == 'PAYE') {
          final paidUserId = (data['userId'] ?? '').toString();
          if (paidUserId.isNotEmpty) {
            paidMemberIds.add(paidUserId);
          }
        }
      }
    }

    final result = <Map<String, dynamic>>[];

    for (final memberId in memberIds) {
      final profile = await getUserProfile(memberId);
      if (profile == null) continue;

      final firstName = (profile['firstName'] ?? '').toString().trim();
      final lastName = (profile['lastName'] ?? '').toString().trim();
      final fullName = '$firstName $lastName'.trim().isNotEmpty
          ? '$firstName $lastName'.trim()
          : (profile['name'] ?? 'Membre').toString();
      final phone = (profile['phone'] ?? '').toString();
      final photoUrl = (profile['photoUrl'] ?? '').toString();

      final isCreator = memberId == creatorId;
      final role = isCreator ? 'Créateur' : 'Bénéficiaire';

      // Un membre est considéré comme "payé" uniquement s'il existe une
      // contribution marquée PAYE pour le cycle courant. Ne pas inférer
      // le statut à partir de l'ordre d'allocation (cela provoquait que
      // des membres nouvellement ajoutés apparaissent comme déjà payés).
      final bool isPaid = paidMemberIds.contains(memberId);

      result.add({
        'userId': memberId,
        'displayName': fullName,
        'photoUrl': photoUrl,
        'role': role,
        'isPaid': isPaid,
        'phone': phone,
      });
    }

    return result;
  }

  Future<List<Map<String, dynamic>>> getAllocationCalendar(String tontineId) async {
    final tontine = await getTontine(tontineId);
    if (tontine == null) return const [];

    final rawCalendar = (tontine['calendrierAllocations'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        <Map<String, dynamic>>[];

    final frequency = (tontine['frequence'] ?? '').toString();
    final baseDate = _parseDateTime(tontine['createdAt']) ?? DateTime.now();

    final cycleDocs = await _tontines
        .doc(tontineId)
        .collection('cycles')
        .get();

    final Map<int, Map<String, dynamic>> cycleById = {};
    for (final doc in cycleDocs.docs) {
      final data = doc.data();
      final cycleId = (data['cycleId'] as num?)?.toInt() ?? int.tryParse(doc.id) ?? 0;
      if (cycleId <= 0) continue;
      cycleById[cycleId] = data;
    }

    List<Map<String, dynamic>> normalized = rawCalendar;
    if (normalized.isEmpty) {
      final order = List<String>.from(tontine['ordre'] ?? const []);
      normalized = List.generate(order.length, (index) {
        return {
          'rang': index + 1,
          'userId': order[index],
          'dateAllocation': Timestamp.fromDate(_computeAllocationDate(baseDate, frequency, index)),
        };
      });
    }

    final uniqueUserIds = normalized
        .map((slot) => (slot['userId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final Map<String, String> namesByUid = {};
    for (final uid in uniqueUserIds) {
      final profile = await getUserProfile(uid);
      final firstName = (profile?['firstName'] ?? '').toString().trim();
      final lastName = (profile?['lastName'] ?? '').toString().trim();
      final fullName = '$firstName $lastName'.trim();
      namesByUid[uid] = fullName.isNotEmpty ? fullName : 'Membre ${uid.substring(0, uid.length >= 6 ? 6 : uid.length)}';
    }

    normalized.sort((a, b) {
      final rangA = (a['rang'] as num?)?.toInt();
      final rangB = (b['rang'] as num?)?.toInt();
      if (rangA != null && rangB != null) return rangA.compareTo(rangB);

      final dateA = _parseDateTime(a['dateAllocation']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = _parseDateTime(b['dateAllocation']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateA.compareTo(dateB);
    });

    return normalized.map((slot) {
      final userId = (slot['userId'] ?? '').toString();
      final rang = (slot['rang'] as num?)?.toInt() ?? 0;
      final cycleProjection = cycleById[rang];
      final cycleStatus = (cycleProjection?['status'] ?? cycleProjection?['statut'] ?? '').toString().toUpperCase();
      final beneficiaire = (cycleProjection?['beneficiaire'] ?? '').toString();
      final montantLibere = cycleProjection?['montantLibere'];
      final received = cycleStatus == 'FINISHED' || cycleStatus == 'DONE' || cycleStatus == 'CLOSED';

      return {
        ...slot,
        'displayName': userId.isEmpty ? 'Membre' : (namesByUid[userId] ?? userId),
        'status': received ? 'RECU' : 'A_VENIR',
        'statusLabel': received ? 'Reçu' : 'À venir',
        'isReceived': received,
        'beneficiaire': beneficiaire.isEmpty ? userId : beneficiaire,
        'montantLibere': montantLibere,
        'cycleStatus': cycleStatus,
      };
    }).toList(growable: false);
  }

  /// Récupère toutes les tontines actives (deleted=false).
  Future<List<Map<String, dynamic>>> getAllActiveTontines() async {
    final query = await _tontines
        .where('deleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .get();
    return query.docs.map((doc) => doc.data()).toList();
  }

  /// Récupère les tontines publiques.
  Future<List<Map<String, dynamic>>> getPublicTontines() async {
    final snapshot = await _tontines.get();
    final tontines = snapshot.docs
        .map((doc) => doc.data())
        .where((data) => (data['deleted'] ?? false) == false && (data['isPublic'] ?? false) == true)
        .toList();
    tontines.sort((a, b) {
      final aDate = _parseDateTime(a['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = _parseDateTime(b['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return tontines;
  }

  /// Récupère les tontines d'un utilisateur.
  Future<List<Map<String, dynamic>>> getUserTontines(String userId) async {
    final snapshot = await _tontines.get();
    final tontines = snapshot.docs
        .map((doc) => doc.data())
        .where((data) =>
            (data['deleted'] ?? false) == false &&
            List<String>.from(data['membres'] ?? const []).contains(userId))
        .toList();
    tontines.sort((a, b) {
      final aDate = _parseDateTime(a['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = _parseDateTime(b['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return tontines;
  }

  /// Ajoute un membre à une tontine.
  Future<void> addMemberToTontine(String tontineId, String userId) async {
    final tontine = await getTontine(tontineId);
    if (tontine == null) return;

    final currentMembers = List<String>.from(tontine['membres'] ?? []);
    final ordreList = List<String>.from(tontine['ordre'] ?? []);
    final ordreIndex = Map<String, int>.from(tontine['ordreIndex'] ?? {});

    if (!currentMembers.contains(userId)) {
      currentMembers.add(userId);
      ordreList.add(userId);
      ordreIndex[userId] = ordreList.length - 1;

      final maxMembers = (tontine['nombreMaxMembres'] as num?)?.toInt() ?? 0;
      final placesRestantes = maxMembers - currentMembers.length;
      final statutAuto = placesRestantes <= 0 ? 'EN_COURS' : 'EN_ATTENTE';
      final currentCycle = (tontine['cycleActuel'] as num?)?.toInt() ?? 0;

      List<String> nextOrder = ordreList;
      Map<String, int> nextOrderIndex = ordreIndex;
      if (placesRestantes <= 0) {
        nextOrder = List<String>.from(currentMembers)..shuffle(Random());
        nextOrderIndex = {
          for (int i = 0; i < nextOrder.length; i++) nextOrder[i]: i,
        };
      }

      await _tontines.doc(tontineId).update({
        'membres': currentMembers,
        'ordre': nextOrder,
        'ordreIndex': nextOrderIndex,
        'calendrierAllocations': _buildAllocationCalendar(
          nextOrder,
          (tontine['frequence'] ?? '').toString(),
        ),
        'placesRestantes': placesRestantes,
        'statut': statutAuto,
        'cycleActuel': placesRestantes <= 0 && currentCycle <= 0 ? 1 : currentCycle,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Retire un membre d'une tontine.
  Future<void> removeMemberFromTontine(String tontineId, String userId) async {
    final tontine = await getTontine(tontineId);
    if (tontine == null) return;

    final currentMembers = List<String>.from(tontine['membres'] ?? []);
    final ordreList = List<String>.from(tontine['ordre'] ?? []);
    final ordreIndex = Map<String, int>.from(tontine['ordreIndex'] ?? {});

    currentMembers.remove(userId);
    ordreList.remove(userId);
    ordreIndex.remove(userId);

    // Réindexer les positions
    for (int i = 0; i < ordreList.length; i++) {
      ordreIndex[ordreList[i]] = i;
    }

    final maxMembers = (tontine['nombreMaxMembres'] as num?)?.toInt() ?? 0;
    final placesRestantes = maxMembers - currentMembers.length;
    final statutAuto = placesRestantes <= 0 ? 'EN_COURS' : 'EN_ATTENTE';

    await _tontines.doc(tontineId).update({
      'membres': currentMembers,
      'ordre': ordreList,
      'ordreIndex': ordreIndex,
      'calendrierAllocations': _buildAllocationCalendar(
        ordreList,
        (tontine['frequence'] ?? '').toString(),
      ),
      'placesRestantes': placesRestantes,
      'statut': statutAuto,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  List<Map<String, dynamic>> _buildAllocationCalendar(
    List<String> order,
    String frequency,
  ) {
    final now = DateTime.now();
    final freq = frequency.toLowerCase();
    Duration step = const Duration(days: 30);
    if (freq.contains('heb')) {
      step = const Duration(days: 7);
    } else if (freq.contains('jour')) {
      step = const Duration(days: 1);
    } else if (freq.contains('trime')) {
      step = const Duration(days: 90);
    }

    return List.generate(order.length, (index) {
      final dueDate = now.add(Duration(days: step.inDays * index));
      return {
        'rang': index + 1,
        'userId': order[index],
        'dateAllocation': Timestamp.fromDate(dueDate),
      };
    });
  }

  /// Met à jour le statut d'une tontine.
  Future<void> updateTontineStatus(String tontineId, String newStatus) async {
    await _tontines.doc(tontineId).update({
      'statut': newStatus, // EN_COURS, TERMINE, SUSPENDUE, ARCHIVEE
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Avance au cycle suivant.
  Future<void> advanceCycle(String tontineId) async {
    final tontine = await getTontine(tontineId);
    if (tontine == null) return;

    await _tontines.doc(tontineId).update({
      'cycleActuel': (tontine['cycleActuel'] as int) + 1,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================================
  // CONTRIBUTIONS
  // ============================================================================

  /// Enregistre une contribution/cotisation.
  /// statut: PAYE ou NON_PAYE
  Future<String> addContribution({
    required String tontineId,
    required String userId,
    required double amount,
    required int cycle,
    required String statut, // PAYE ou NON_PAYE
    DateTime? dateEcheance,
  }) async {
    final doc = await _contributions.add({
      'tontineId': tontineId,
      'userId': userId,
      'montant': amount,
      'cycle': cycle,
      'statut': statut,
      'dateEcheance': dateEcheance ?? DateTime.now().add(Duration(days: 7)),
      'deleted': false,
      'date': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Simule un paiement de cotisation et met à jour les statuts liés.
  Future<void> simulateCotisationPayment({
    required String tontineId,
    required String userId,
    required double amount,
    required String phoneNumber,
    required String paymentMode,
    String? provider,
  }) async {
    final tontine = await getTontine(tontineId);
    if (tontine == null) {
      throw Exception('Tontine introuvable');
    }

    final cycle = (tontine['cycleActuel'] as num?)?.toInt() ?? 1;

    final existingContribution = await _contributions
        .where('tontineId', isEqualTo: tontineId)
        .where('userId', isEqualTo: userId)
        .where('cycle', isEqualTo: cycle)
        .where('deleted', isEqualTo: false)
        .limit(1)
        .get();

    if (existingContribution.docs.isNotEmpty) {
      await existingContribution.docs.first.reference.update({
        'montant': amount,
        'statut': 'PAYE',
        'paymentMode': paymentMode,
        'provider': provider,
        'phoneNumber': phoneNumber,
        'datePaiement': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _contributions.add({
        'tontineId': tontineId,
        'userId': userId,
        'montant': amount,
        'cycle': cycle,
        'statut': 'PAYE',
        'paymentMode': paymentMode,
        'provider': provider,
        'phoneNumber': phoneNumber,
        'datePaiement': FieldValue.serverTimestamp(),
        'deleted': false,
        'date': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await addTransaction(
      type: 'COTISATION',
      tontineId: tontineId,
      userId: userId,
      fromUserId: userId,
      amount: amount,
      description: 'Simulation cotisation $paymentMode ($phoneNumber)',
    );
  }

  /// Simule un rechargement de portefeuille.
  Future<void> simulateWalletRecharge({
    required String userId,
    required double amount,
    required String phoneNumber,
    required String paymentMode,
  }) async {
    // Mettre à jour le solde de l'utilisateur
    final userDoc = await _users.doc(userId).get();
    if (!userDoc.exists) {
      throw Exception('Utilisateur introuvable');
    }

    final currentSolde = (userDoc['solde'] as num?)?.toDouble() ?? 0;
    final newSolde = currentSolde + amount;

    await _users.doc(_normalizeUid(userId)).update({
      'solde': newSolde,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Enregistrer une transaction de recharge
    await addTransaction(
      type: 'RECHARGE_PORTEFEUILLE',
      userId: userId,
      fromUserId: userId,
      amount: amount,
      description: 'Recharge portefeuille $paymentMode ($phoneNumber)',
    );
  }

  /// Simule un retrait depuis le portefeuille.
  Future<void> simulateWalletWithdrawal({
    required String userId,
    required double amount,
    required String phoneNumber,
    required String paymentMode,
  }) async {
    final userDoc = await _users.doc(userId).get();
    if (!userDoc.exists) {
      throw Exception('Utilisateur introuvable');
    }

    final currentSolde = (userDoc.data()?['solde'] as num?)?.toDouble() ?? 0;
    if (amount > currentSolde) {
      throw Exception('Solde insuffisant');
    }

    final newSolde = currentSolde - amount;

    await _users.doc(_normalizeUid(userId)).update({
      'solde': newSolde,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await addTransaction(
      type: 'RETRAIT_PORTEFEUILLE',
      userId: userId,
      fromUserId: userId,
      amount: amount,
      description: 'Retrait portefeuille $paymentMode ($phoneNumber)',
    );
  }

  /// Récupère les contributions d'une tontine.
  Future<List<Map<String, dynamic>>> getTontineContributions(String tontineId) async {
    final query = await _contributions
        .where('tontineId', isEqualTo: tontineId)
        .where('deleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .get();
    return query.docs.map((doc) => doc.data()).toList();
  }

  /// Récupère les contributions d'un utilisateur pour une tontine.
  Future<List<Map<String, dynamic>>> getUserContributions(
    String tontineId,
    String userId,
  ) async {
    final query = await _contributions
        .where('tontineId', isEqualTo: tontineId)
        .where('userId', isEqualTo: userId)
        .where('deleted', isEqualTo: false)
        .orderBy('cycle', descending: true)
        .get();
    return query.docs.map((doc) => doc.data()).toList();
  }

  /// Met à jour le statut d'une contribution.
  Future<void> updateContributionStatus(String contributionId, String newStatus) async {
    await _contributions.doc(contributionId).update({
      'statut': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================================
  // TRANSACTIONS
  // ============================================================================

  /// Enregistre une transaction métier.
  /// type: COTISATION, GAIN, CREATION_TONTINE, AJOUT_MEMBRE
  Future<String> addTransaction({
    required String type, // COTISATION, GAIN, CREATION_TONTINE, AJOUT_MEMBRE, RECHARGE_PORTEFEUILLE
    String? tontineId,
    required String userId, // l'utilisateur principal de la transaction
    String? fromUserId, // sender
    String? toUserId, // receiver
    required double amount,
    required String description,
    String? blockchainHash,
  }) async {
    final doc = await _transactions.add({
      'type': type,
      'tontineId': tontineId,
      'userId': userId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'montant': amount,
      'description': description,
      'blockchainHash': blockchainHash,
      'deleted': false,
      'date': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Récupère les transactions d'une tontine.
  Future<List<Map<String, dynamic>>> getTontineTransactions(String tontineId) async {
    final query = await _transactions
        .where('tontineId', isEqualTo: tontineId)
        .where('deleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .get();
    return query.docs.map((doc) => doc.data()).toList();
  }

  /// Récupère les transactions d'un utilisateur.
  Future<List<Map<String, dynamic>>> getUserTransactions(String userId) async {
    try {
      final query = await _transactions
          .where('userId', isEqualTo: userId)
          .where('deleted', isEqualTo: false)
          // Removed .orderBy() to avoid composite index requirement
          .get();
      final results = query.docs.map((doc) => doc.data()).toList();
      // Sort client-side instead
      results.sort((a, b) {
        final dateA = _parseDateTime(a['date']);
        final dateB = _parseDateTime(b['date']);
        if (dateA == null || dateB == null) return 0;
        return dateB.compareTo(dateA);
      });
      return results;
    } catch (e) {
      print('[ERROR] getUserTransactions failed: $e');
      return [];
    }
  }

  /// Récupère le prochain paiement à venir pour un utilisateur, parmi toutes ses tontines.
  Future<Map<String, dynamic>?> getNextDueTontineForUser(String userId) async {
    final userTontines = await getUserTontinesAsModels(userId);
    Map<String, dynamic>? best;

    for (final tontine in userTontines) {
      // Ignore les tontines terminées ou suspendues
      if (tontine.status == 'TERMINE' || tontine.status == 'SUSPENDUE' || tontine.status == 'ARCHIVEA') {
        continue;
      }

      final contributions = await getUserContributions(tontine.id, userId);
      
      // Chercher une contribution NON_PAYEE
      DateTime? candidateDueDate;
      double? candidateAmount;
      
      for (final contribution in contributions) {
        final status = (contribution['statut'] ?? '').toString().toUpperCase();
        if (status == 'PAYE') continue;

        final dueDate = _parseDateTime(contribution['dateEcheance']) ??
            _parseDateTime(contribution['date']);
        if (dueDate == null) continue;

        if (candidateDueDate == null || dueDate.isBefore(candidateDueDate)) {
          candidateDueDate = dueDate;
          candidateAmount = (contribution['montant'] as num?)?.toDouble() ?? tontine.monthlyAmount;
        }
      }

      // Si aucune contribution NON_PAYEE n'existe, créer une hypothétique pour les tontines EN_COURS
      if (candidateDueDate == null && (tontine.status == 'EN_COURS' || tontine.status == 'active')) {
        // Chercher la position de l'utilisateur dans le calendrier d'allocation
        final tontineDoc = await _tontines.doc(tontine.id).get();
        if (tontineDoc.exists) {
          final rawCalendar = (tontineDoc['calendrierAllocations'] as List?)
              ?.cast<Map<String, dynamic>>() ??
              [];
          
          for (final slot in rawCalendar) {
            if ((slot['userId'] ?? '').toString() == userId) {
              final allocationDateValue = slot['dateAllocation'];
              candidateDueDate = _parseDateTime(allocationDateValue);
              break;
            }
          }
        }
        
        // Si on n'a pas trouvé la date d'allocation, générer une hypothétique
        if (candidateDueDate == null) {
          final now = DateTime.now();
          final freq = (tontine.frequency ?? 'Mensuel').toLowerCase();
          int daysOffset = 30;
          if (freq.contains('heb')) {
            daysOffset = 7;
          } else if (freq.contains('jour')) {
            daysOffset = 1;
          } else if (freq.contains('trime')) {
            daysOffset = 90;
          }
          candidateDueDate = now.add(Duration(days: daysOffset));
        }
        
        candidateAmount = tontine.monthlyAmount;
      }

      // Si une date d'échéance candidate a été trouvée, comparer avec le meilleur
      if (candidateDueDate != null) {
        final candidate = {
          'tontine': tontine,
          'dueDate': candidateDueDate,
          'amount': candidateAmount ?? tontine.monthlyAmount,
          'cycle': tontine.currentCycle,
        };

        if (best == null) {
          best = candidate;
        } else {
          final currentBest = best['dueDate'] as DateTime;
          if (candidateDueDate.isBefore(currentBest)) {
            best = candidate;
          }
        }
      }
    }

    return best;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  DateTime _computeAllocationDate(DateTime start, String frequency, int stepIndex) {
    final freq = frequency.toLowerCase();
    int days = 30;
    if (freq.contains('heb')) {
      days = 7;
    } else if (freq.contains('jour')) {
      days = 1;
    } else if (freq.contains('trime')) {
      days = 90;
    }
    return start.add(Duration(days: days * stepIndex));
  }

  // ============================================================================
  // NOTIFICATIONS
  // ============================================================================

  /// Enregistre une notification in-app.
  /// type: INVITATION, NEW_TONTINE, PAYMENT_REMINDER, CYCLE_UPDATE, etc.
  Future<String> addNotification({
    required String userId,
    required String title,
    required String message,
    required String type, // INVITATION, NEW_TONTINE, PAYMENT_REMINDER, etc.
    String? tontineId,
    bool read = false,
  }) async {
    final doc = await _notifications.add({
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'tontineId': tontineId,
      'read': read,
      'deleted': false,
      'date': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Récupère les notifications d'un utilisateur.
  Future<List<Map<String, dynamic>>> getUserNotifications(String userId) async {
    final query = await _notifications
        .where('userId', isEqualTo: userId)
        .where('deleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .get();
    return query.docs.map((doc) => doc.data()).toList();
  }

  /// Récupère les notifications non lues.
  Future<List<Map<String, dynamic>>> getUnreadNotifications(String userId) async {
    final query = await _notifications
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .where('deleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .get();
    return query.docs.map((doc) => doc.data()).toList();
  }

  /// Marque une notification comme lue.
  Future<void> markNotificationAsRead(String notificationId) async {
    await _notifications.doc(notificationId).update({
      'read': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Marque toutes les notifications d'un utilisateur comme lues.
  Future<void> markAllNotificationsAsRead(String userId) async {
    final query = await _notifications
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();

    for (final doc in query.docs) {
      await doc.reference.update({
        'read': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ============================================================================
  // JOIN REQUESTS
  // ============================================================================

  /// Enregistre une demande d'adhésion.
  /// statut: PENDING, ACCEPTED, REFUSED
  Future<String> addJoinRequest({
    required String tontineId,
    required String userId,
    String userName = '',
    String userPhone = '',
    String statut = 'PENDING',
  }) async {
    // Vérifier si la demande existe déjà
    final existing = await _joinRequests
        .where('tontineId', isEqualTo: tontineId)
        .where('userId', isEqualTo: userId)
        .where('statut', isEqualTo: 'PENDING')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final doc = await _joinRequests.add({
      'tontineId': tontineId,
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'statut': statut,
      'deleted': false,
      'date': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Récupère les demandes d'adhésion pour une tontine.
  Future<List<Map<String, dynamic>>> getTontineJoinRequests(String tontineId) async {
    final query = await _joinRequests
        .where('tontineId', isEqualTo: tontineId)
        .where('deleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .get();
    return query.docs.map((doc) => doc.data()).toList();
  }

  /// DEBUG: récupère jusqu'à [limit] utilisateurs et renvoie ceux dont
  /// les champs contiennent la sous-chaîne [fragment]. Utilisé pour debug.
  Future<List<Map<String, dynamic>>> debugFindUsersByFragment(String fragment, {int limit = 500}) async {
    final query = await _users.limit(limit).get();
    final results = <Map<String, dynamic>>[];
    for (final doc in query.docs) {
      final data = doc.data();
      final combined = data.values.map((v) => v?.toString() ?? '').join(' ');
      if (combined.contains(fragment)) {
        final out = Map<String, dynamic>.from(data);
        out['__id'] = doc.id;
        results.add(out);
      }
    }
    return results;
  }

  /// Récupère les demandes d'adhésion d'un utilisateur.
  Future<List<Map<String, dynamic>>> getUserJoinRequests(String userId) async {
    final query = await _joinRequests
        .where('userId', isEqualTo: userId)
        .where('deleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .get();
    return query.docs.map((doc) => doc.data()).toList();
  }

  /// Met à jour le statut d'une demande d'adhésion.
  Future<void> updateJoinRequestStatus(String requestId, String newStatus) async {
    await _joinRequests.doc(requestId).update({
      'statut': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Observe les demandes d'adhésion d'une tontine en temps réel (filtre par tontineId et tri par date).
  Stream<List<Map<String, dynamic>>> watchTontineJoinRequests(String tontineId) {
    return _joinRequests
        .where('tontineId', isEqualTo: tontineId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    ...doc.data(),
                  })
              .toList(),
        );
  }

  /// Accepte une demande d'adhésion et ajoute automatiquement le membre à la tontine.
  Future<void> acceptJoinRequest({
    required String requestId,
    required String handledBy,
  }) async {
    final ref = _joinRequests.doc(requestId);
    final snapshot = await ref.get();
    if (!snapshot.exists) return;

    final data = snapshot.data() ?? const <String, dynamic>{};
    final tontineId = (data['tontineId'] ?? '').toString();
    final userId = (data['userId'] ?? '').toString();

    await ref.update({
      'statut': 'ACCEPTED',
      'handledBy': handledBy,
      'handledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (tontineId.isNotEmpty && userId.isNotEmpty) {
      String memberWallet = userId;
      try {
        final userProfile = await BackendService.instance.getUserProfile(userId);
        memberWallet = (userProfile['profile']?['walletAddress'] ?? userProfile['profile']?['wallet'] ?? userId).toString();
      } catch (_) {
        memberWallet = userId;
      }

      try {
        await BackendService.instance.joinTontineMember(tontineId, {
          'memberWallet': memberWallet,
          'pseudo': (data['pseudo'] ?? '').toString(),
        });
      } catch (e) {
        print('[WARN] on-chain join failed for $tontineId / $userId: $e');
      }

      await addMemberToTontine(tontineId, userId);
      await addTontineToUser(userId, tontineId);
      await addNotification(
        userId: userId,
        title: 'Demande acceptée',
        message: 'Votre demande pour rejoindre la tontine a été acceptée.',
        type: 'JOIN_REQUEST',
        tontineId: tontineId,
      );
      await addNotification(
        userId: handledBy,
        title: 'Membre ajouté',
        message: 'Un membre a été ajouté à votre tontine.',
        type: 'JOIN_REQUEST',
        tontineId: tontineId,
      );
    }
  }

  /// Refuse une demande d'adhésion.
  Future<void> rejectJoinRequest({
    required String requestId,
    required String handledBy,
  }) async {
    final ref = _joinRequests.doc(requestId);
    final snapshot = await ref.get();
    if (!snapshot.exists) return;

    final data = snapshot.data() ?? const <String, dynamic>{};
    final tontineId = (data['tontineId'] ?? '').toString();
    final userId = (data['userId'] ?? '').toString();

    await ref.update({
      'statut': 'REJECTED',
      'handledBy': handledBy,
      'handledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (tontineId.isNotEmpty && userId.isNotEmpty) {
      await addNotification(
        userId: userId,
        title: 'Demande refusée',
        message: 'Votre demande pour rejoindre la tontine a été refusée.',
        type: 'JOIN_REQUEST',
        tontineId: tontineId,
      );
      await addNotification(
        userId: handledBy,
        title: 'Demande refusée',
        message: 'La demande d\'adhésion a été refusée.',
        type: 'JOIN_REQUEST',
        tontineId: tontineId,
      );
    }
  }

  // ============================================================================
  // INVITATIONS
  // ============================================================================

  /// Crée une invitation réelle à rejoindre une tontine.
  /// statut: PENDING, ACCEPTED, REJECTED
  Future<String> createInvitation({
    required String tontineId,
    required String tontineName,
    required String inviterId,
    required String inviteeId,
    required String inviteeName,
    String? inviteePhone,
    String? inviterName,
    double? trustScore,
    String message = '',
    String statut = 'PENDING',
  }) async {
    final existing = await _invitations
        .where('tontineId', isEqualTo: tontineId)
        .where('inviteeId', isEqualTo: inviteeId)
        .where('statut', isEqualTo: 'PENDING')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final doc = await _invitations.add({
      'tontineId': tontineId,
      'tontineName': tontineName,
      'inviterId': inviterId,
      'inviterName': inviterName ?? '',
      'inviteeId': inviteeId,
      'inviteeName': inviteeName,
      'inviteePhone': inviteePhone,
      'trustScore': trustScore ?? 0,
      'message': message,
      'statut': statut,
      'deleted': false,
      'date': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await addNotification(
      userId: inviteeId,
      title: 'Nouvelle invitation',
      message: inviterName == null || inviterName.isEmpty
          ? 'Vous avez reçu une invitation pour rejoindre "$tontineName".'
          : '$inviterName vous a invité à rejoindre "$tontineName".',
      type: 'INVITATION',
      tontineId: tontineId,
    );

    return doc.id;
  }

  /// Récupère les invitations d'une tontine.
  Future<List<Map<String, dynamic>>> getTontineInvitations(
    String tontineId, {
    String? statut,
  }) async {
    Query<Map<String, dynamic>> query = _invitations
        .where('tontineId', isEqualTo: tontineId)
        .where('deleted', isEqualTo: false);

    if (statut != null && statut.isNotEmpty) {
      query = query.where('statut', isEqualTo: statut);
    }

    final snapshot = await query.orderBy('date', descending: true).get();
    return snapshot.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data(),
            })
        .toList();
  }

  /// Observe les invitations d'une tontine en temps réel (filtre par tontineId et tri par date).
  Stream<List<Map<String, dynamic>>> watchTontineInvitations(String tontineId) {
    return _invitations
        .where('tontineId', isEqualTo: tontineId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    ...doc.data(),
                  })
              .toList(),
        );
  }

  /// Récupère les invitations reçues par un utilisateur.
  Future<List<Map<String, dynamic>>> getUserInvitations(String userId) async {
    final snapshot = await _invitations
        .where('inviteeId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data(),
            })
        .toList();
  }

  /// Accepte une invitation et ajoute automatiquement le membre à la tontine.
  Future<void> acceptInvitation({
    required String invitationId,
    required String handledBy,
  }) async {
    final ref = _invitations.doc(invitationId);
    final snapshot = await ref.get();
    if (!snapshot.exists) return;

    final data = snapshot.data() ?? const <String, dynamic>{};
    final tontineId = (data['tontineId'] ?? '').toString();
    final inviteeId = (data['inviteeId'] ?? '').toString();
    final inviteeName = (data['inviteeName'] ?? '').toString();
    final tontineName = (data['tontineName'] ?? '').toString();

    await ref.update({
      'statut': 'ACCEPTED',
      'handledBy': handledBy,
      'handledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (tontineId.isNotEmpty && inviteeId.isNotEmpty) {
      await addMemberToTontine(tontineId, inviteeId);
      await addTontineToUser(inviteeId, tontineId);
      await addNotification(
        userId: inviteeId,
        title: 'Invitation acceptée',
        message: 'Votre invitation pour "$tontineName" a été acceptée.',
        type: 'INVITATION',
        tontineId: tontineId,
      );
      await addNotification(
        userId: handledBy,
        title: 'Membre ajouté',
        message: '$inviteeName a été ajouté à "$tontineName".',
        type: 'INVITATION',
        tontineId: tontineId,
      );
    }
  }

  /// Refuse une invitation.
  Future<void> rejectInvitation({
    required String invitationId,
    required String handledBy,
  }) async {
    final ref = _invitations.doc(invitationId);
    final snapshot = await ref.get();
    if (!snapshot.exists) return;

    final data = snapshot.data() ?? const <String, dynamic>{};
    final tontineId = (data['tontineId'] ?? '').toString();
    final inviteeId = (data['inviteeId'] ?? '').toString();
    final inviteeName = (data['inviteeName'] ?? '').toString();
    final tontineName = (data['tontineName'] ?? '').toString();

    await ref.update({
      'statut': 'REJECTED',
      'handledBy': handledBy,
      'handledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (tontineId.isNotEmpty && inviteeId.isNotEmpty) {
      await addNotification(
        userId: inviteeId,
        title: 'Invitation refusée',
        message: 'Votre invitation pour "$tontineName" a été refusée.',
        type: 'INVITATION',
        tontineId: tontineId,
      );
      await addNotification(
        userId: handledBy,
        title: 'Invitation refusée',
        message: '$inviteeName n’a pas été retenu pour "$tontineName".',
        type: 'INVITATION',
        tontineId: tontineId,
      );
    }
  }

  // ============================================================================
  // STORAGE
  // ============================================================================

  /// Upload une image de profil dans Storage (profiles/{userId}.jpg).
  Future<String> uploadProfileImage({
    required String uid,
    required File imageFile,
  }) async {
    final ref = _storage.ref().child('profiles').child('$uid.jpg');
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }

  /// Upload une pièce d'identité dans Storage (ids/{userId}.jpg).
  Future<String> uploadIdentityDocument({
    required String uid,
    required File documentFile,
  }) async {
    final ref = _storage.ref().child('ids').child('$uid.jpg');
    await ref.putFile(documentFile);
    return await ref.getDownloadURL();
  }

  /// Supprime une image de profil.
  Future<void> deleteProfileImage(String uid) async {
    final ref = _storage.ref().child('profiles').child('$uid.jpg');
    try {
      await ref.delete();
    } catch (e) {
      // Image n'existe pas
    }
  }

  /// Supprime une pièce d'identité.
  Future<void> deleteIdentityDocument(String uid) async {
    final ref = _storage.ref().child('ids').child('$uid.jpg');
    try {
      await ref.delete();
    } catch (e) {
      // Document n'existe pas
    }
  }
}
