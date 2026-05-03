import 'package:flutter/material.dart';
import '../models/index.dart';
import '../services/index.dart';

/// Provider pour la gestion des tontines
class TontineProvider extends ChangeNotifier {
  final MockTontineService _service = MockTontineService();

  TontineProvider() {
    // Charger automatiquement les tontines seed au démarrage
    loadTontines();
  }

  List<Tontine> _tontines = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Tontine> get tontines => _tontines;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool isDiscoverable(String tontineId) => _service.isDiscoverable(tontineId);

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
      _tontines = await _service.getTontines();
      _upsertAll(_tontines);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Créer une nouvelle tontine
  Future<Tontine?> createTontine({
    required String name,
    required String description,
    required double monthlyAmount,
    required String creatorId,
    String? frequency,
    bool isDiscoverable = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final tontine = await _service.createTontine(
        name: name,
        description: description,
        monthlyAmount: monthlyAmount,
        creatorId: creatorId,
        frequency: frequency,
        isDiscoverable: isDiscoverable,
      );
      _upsertTontine(tontine);
      notifyListeners();
      return tontine;
    } catch (e) {
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
}
