import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MockAuthService {
  MockAuthService._private();
  static final MockAuthService instance = MockAuthService._private();

  List<Map<String, dynamic>> _users = [];

  /// Chargement du fichier assets/test_users.json — uniquement en DEV
  Future<void> loadSeedUsers() async {
    if (!kDebugMode) return;
    try {
      final raw = await rootBundle.loadString('assets/test_users.json');
      final parsed = json.decode(raw) as List<dynamic>;
      _users = parsed.cast<Map<String, dynamic>>();
    } catch (e) {
      // ignore: avoid_print
      print('Failed to load test users: $e');
      _users = [];
    }
  }

  /// Retourne la liste (pour debug)
  List<Map<String, dynamic>> get users => List.unmodifiable(_users);

  /// Utilisateurs qui ont activé le mode recherche de tontine.
  List<Map<String, dynamic>> get activeUsers => List.unmodifiable(
        _users.where((user) => user['activeMode'] == true),
      );

  /// Met à jour le mode actif d'un utilisateur de test.
  void setActiveMode(String userId, bool active) {
    final index = _users.indexWhere((user) => user['id'] == userId);
    if (index == -1) return;
    _users[index]['activeMode'] = active;
  }

  /// Authentification mock: vérifie téléphone + mot de passe
  /// Renvoie l'utilisateur (Map) si ok, sinon null
  Future<Map<String, dynamic>?> login(String phone, String password) async {
    if (!kDebugMode) return null;
    await Future.delayed(const Duration(milliseconds: 400));
    final u = _users.firstWhere(
      (m) => m['phone'] == phone && m['password'] == password,
      orElse: () => {},
    );
    if (u.isEmpty) return null;
    return Map<String, dynamic>.from(u);
  }

  /// Simule l'envoi d'un OTP (en DEV on renvoie celui du fichier)
  Future<String?> sendOtp(String phone) async {
    if (!kDebugMode) return null;
    final u = _users.firstWhere((m) => m['phone'] == phone, orElse: () => {});
    if (u.isEmpty) return null;
    // Dans un vrai service, on enverrait le code via SMS
    return u['otp'] as String?;
  }

  /// Vérifie le code OTP
  Future<bool> verifyOtp(String phone, String code) async {
    if (!kDebugMode) return false;
    final u = _users.firstWhere((m) => m['phone'] == phone, orElse: () => {});
    if (u.isEmpty) return false;
    return (u['otp'] as String) == code;
  }

  /// Helper: auto-login le premier utilisateur (pour debug)
  Future<Map<String, dynamic>?> autoLoginFirst() async {
    if (!kDebugMode) return null;
    if (_users.isEmpty) await loadSeedUsers();
    if (_users.isEmpty) return null;
    return Map<String, dynamic>.from(_users.first);
  }
}
