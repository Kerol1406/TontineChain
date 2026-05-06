import 'package:flutter/material.dart';
import '../models/index.dart';
import '../services/index.dart';

/// Provider pour la gestion des tontines
class TontineProvider extends ChangeNotifier {
  final FirestoreDatabaseService _service = FirestoreDatabaseService.instance;
  final MockTontineService _fallbackService = MockTontineService();

  TontineProvider() {
    // Charger automatiquement les tontines seed au démarrage
    loadTontines();
  }

  List<Tontine> _tontines = [];
  List<Tontine> _userTontines = [];
  Tontine? _nextDueTontine;
  DateTime? _nextDueDate;
  double? _nextDueAmount;
  double? _patrimoineTotal;
  double? _totalEpargne;
  double? _totalRecu;
  bool _hasReceivedAny = false;
  bool _homeSummaryLoading = false;
  String? _homeSummaryError;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Tontine> get tontines => _tontines;
    List<Tontine> get userTontines => _userTontines;
  List<Tontine> get activeUserTontines =>
      _userTontines.where(_isActiveTontine).toList(growable: false);
    Tontine? get nextDueTontine => _nextDueTontine;
    DateTime? get nextDueDate => _nextDueDate;
    double? get nextDueAmount => _nextDueAmount;
    String get patrimoineTotalDisplay => _patrimoineTotal == null
      ? '--'
      : _formatAmount(_patrimoineTotal!);
    String get totalEpargneDisplay =>
      _hasReceivedAny && _totalEpargne != null ? _formatAmount(_totalEpargne!) : '--';
    String get totalRecuDisplay =>
      _hasReceivedAny && _totalRecu != null ? _formatAmount(_totalRecu!) : '--';
    bool get hasReceivedAny => _hasReceivedAny;
    bool get homeSummaryLoading => _homeSummaryLoading;
    String? get homeSummaryError => _homeSummaryError;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Tontine> get activeTontines =>
      _tontines.where(_isActiveTontine).toList(growable: false);

  double get patrimoineTotal => activeTontines.fold<double>(
        0,
        (sum, tontine) => sum + tontine.monthlyAmount * (tontine.maxMembers ?? tontine.memberCount),
      );

  double get totalEpargne => activeTontines.fold<double>(
        0,
        (sum, tontine) => sum + tontine.monthlyAmount * tontine.memberCount,
      );

  double get totalRecu => activeTontines.fold<double>(
        0,
        (sum, tontine) => sum + tontine.monthlyAmount,
      );

  bool isDiscoverable(String tontineId) {
    final index = _tontines.indexWhere((tontine) => tontine.id == tontineId);
    if (index == -1) return true;
    return _tontines[index].isDiscoverable;
  }

  void _upsertTontine(Tontine tontine) {
    final existingIndex = _tontines.indexWhere((item) => item.id == tontine.id);
    if (existingIndex == -1) {
      _tontines.add(tontine);
      return;
    }
    _tontines[existingIndex] = tontine;
  }

  /// Charger toutes les tontines
  Future<void> loadTontines() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('[DEBUG] loadTontines: Refreshing all tontines from Firestore...');
      _tontines = await _service.getTontines();
      if (_tontines.isEmpty) {
        print('[DEBUG] loadTontines: No Firestore data, loading fallback mock data');
        _tontines = await _fallbackService.getTontines();
      }
      _upsertAll(_tontines);
      print('[DEBUG] loadTontines: Successfully loaded ${_tontines.length} tontines');
    } catch (e) {
      print('[ERROR] loadTontines failed: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charge la synthèse d'accueil d'un utilisateur.
  Future<void> loadHomeSummary(String userId) async {
    print('[DEBUG] loadHomeSummary called for userId=$userId');
    _homeSummaryLoading = true;
    _homeSummaryError = null;
    notifyListeners();

    try {
      _userTontines = await _service.getUserTontinesAsModels(userId);
      print('[DEBUG] loadHomeSummary: Loaded ${_userTontines.length} user tontines');
      print('[DEBUG] User tontines: ${_userTontines.map((t) => '${t.name} (${t.status})').join(', ')}');
      
      final activeUserTontines = _userTontines.where(_isActiveTontine).toList(growable: false);

      _patrimoineTotal = _userTontines.fold<double>(
        0,
        (sum, tontine) => sum + tontine.monthlyAmount * (tontine.maxMembers ?? tontine.memberCount),
      );

      final transactions = await _service.getUserTransactions(userId);
      _totalRecu = _sumTransactions(transactions, 'GAIN');
      _totalEpargne = _sumTransactions(transactions, 'COTISATION');
      _hasReceivedAny = (_totalRecu ?? 0) > 0;
      if (!_hasReceivedAny) {
        _totalRecu = null;
        _totalEpargne = null;
      }

      final nextDue = await _service.getNextDueTontineForUser(userId);
      if (nextDue == null) {
        _nextDueTontine = null;
        _nextDueDate = null;
        _nextDueAmount = null;
      } else {
        _nextDueTontine = nextDue['tontine'] as Tontine?;
        _nextDueDate = nextDue['dueDate'] as DateTime?;
        _nextDueAmount = (nextDue['amount'] as num?)?.toDouble();
      }

      _patrimoineTotal = activeUserTontines.fold<double>(
        0,
        (sum, tontine) => sum + tontine.monthlyAmount * (tontine.maxMembers ?? tontine.memberCount),
      );
    } catch (e) {
      print('[ERROR] loadHomeSummary failed: $e');
      _homeSummaryError = e.toString();
    } finally {
      _homeSummaryLoading = false;
      notifyListeners();
    }
  }

  /// Créer une nouvelle tontine
  Future<Tontine?> createTontine({
    required String name,
    required String description,
    required double monthlyAmount,
    required String creatorId,
    required int maxMembers,
    String? frequency,
    bool isDiscoverable = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('[DEBUG] createTontine: Starting creation for creatorId=$creatorId, maxMembers=$maxMembers');
      final selectedFrequency = frequency ?? 'Mensuel';
      final tontineId = await _service.createTontine(
        name: name,
        description: description,
        amount: monthlyAmount,
        nombreMaxMembres: maxMembers,
        createur: creatorId,
        isPublic: isDiscoverable,
        frequency: selectedFrequency,
      );
      print('[DEBUG] createTontine: Successfully created tontineId=$tontineId');
      
      final tontine = Tontine(
        id: tontineId,
        name: name,
        description: description,
        memberCount: 1,
        monthlyAmount: monthlyAmount,
        status: maxMembers <= 1 ? 'EN_COURS' : 'EN_ATTENTE',
        createdAt: DateTime.now(),
        creatorId: creatorId,
        frequency: selectedFrequency,
        isDiscoverable: isDiscoverable,
        maxMembers: maxMembers,
      );
      _upsertTontine(tontine);
      print('[DEBUG] createTontine: Tontine added to local cache');
      
      // Reload user's tontines to ensure it appears in the list
      print('[DEBUG] createTontine: Reloading user tontines...');
      await loadHomeSummary(creatorId);
      
      notifyListeners();
      return tontine;
    } catch (e) {
      print('[ERROR] createTontine failed: $e');
      _error = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
    }
  }

  void _upsertAll(List<Tontine> tontines) {
    final uniqueById = <String, Tontine>{};
    for (final tontine in tontines) {
      uniqueById[tontine.id] = tontine;
    }
    _tontines = uniqueById.values.toList();
  }

  bool _isActiveTontine(Tontine tontine) {
    final status = tontine.status.trim();
    return status.toLowerCase() == 'active' ||
        status.toUpperCase() == 'EN_COURS';
  }

  double _sumTransactions(List<Map<String, dynamic>> transactions, String type) {
    return transactions.fold<double>(0, (sum, transaction) {
      final currentType = (transaction['type'] ?? '').toString().toUpperCase();
      if (currentType != type.toUpperCase()) {
        return sum;
      }
      final amount = (transaction['montant'] as num?)?.toDouble() ?? 0;
      return sum + amount;
    });
  }

  String _formatAmount(double amount) {
    final rounded = amount.round();
    final text = rounded.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(text[i]);
    }
    return buffer.toString();
  }
}
