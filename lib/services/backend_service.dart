import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/index.dart';

/// Service pour communiquer avec le backend Node.js
class BackendService {
  static final BackendService instance = BackendService._internal();
  
  late String _baseUrl;
  final String _defaultBaseUrl = 'https://tontinechain-backend.onrender.com';
  
  BackendService._internal() {
    _baseUrl = _defaultBaseUrl;
  }

  void setBaseUrl(String baseUrl) {
    _baseUrl = baseUrl;
  }

  // ═══════════════════════════════════════════════════════════════
  // Profil utilisateur
  // ═══════════════════════════════════════════════════════════════

  /// GET /api/users/:userId/profile
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/users/$userId/profile'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        throw Exception('Utilisateur non trouvé');
      } else {
        throw Exception('Erreur: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('[ERROR] getUserProfile failed: $e');
      rethrow;
    }
  }

  /// PUT /api/users/:userId/profile
  Future<Map<String, dynamic>> updateUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/users/$userId/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode != 200) {
        throw Exception('Erreur: ${response.statusCode} - ${response.body}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return const {};
    } catch (e) {
      print('[ERROR] updateUserProfile failed: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Score global
  // ═══════════════════════════════════════════════════════════════

  /// GET /api/users/:userId/scores
  Future<Map<String, dynamic>> getUserGlobalScore(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/users/$userId/scores'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Erreur: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('[ERROR] getUserGlobalScore failed: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Tontines utilisateur
  // ═══════════════════════════════════════════════════════════════

  /// GET /api/users/:userId/tontines
  Future<List<Map<String, dynamic>>> getUserTontines(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/users/$userId/tontines'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        return [];
      } else {
        throw Exception('Erreur: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('[ERROR] getUserTontines failed: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Stats utilisateur
  // ═══════════════════════════════════════════════════════════════

  /// GET /api/users/:userId/stats
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/users/$userId/stats'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Erreur: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('[ERROR] getUserStats failed: $e');
      rethrow;
    }
  }

  /// GET /api/users/:userId/next-due
  Future<Map<String, dynamic>?> getUserNextDue(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/users/$userId/next-due'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Erreur: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('[ERROR] getUserNextDue failed: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Scores des membres d'une tontine
  // ═══════════════════════════════════════════════════════════════

  /// GET /api/tontines/:tontineId/scores
  Future<Map<String, dynamic>> getTontineScores(String tontineId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/tontines/$tontineId/scores'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Erreur: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('[ERROR] getTontineScores failed: $e');
      rethrow;
    }
  }

  /// POST /api/tontines/deploy
  Future<Map<String, dynamic>> deployTontineContract(Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/tontines/deploy'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final body = response.body.trim();
      final contentType = response.headers['content-type'] ?? '';

      if (response.statusCode == 201 && body.isNotEmpty) {
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        } catch (_) {
          throw Exception(
            'Le backend a répondu avec un contenu non JSON sur /api/tontines/deploy. '
            'Vérifie que le backend Render a bien été redéployé avec le nouvel endpoint. '
            'status=${response.statusCode}, content-type=$contentType, body=${body.substring(0, body.length > 180 ? 180 : body.length)}',
          );
        }
      }

      throw Exception(
        'Erreur déploiement tontine: status=${response.statusCode}, content-type=$contentType, body=${body.substring(0, body.length > 180 ? 180 : body.length)}',
      );
    } catch (e) {
      print('[ERROR] deployTontineContract failed: $e');
      rethrow;
    }
  }

  /// POST /api/tontines/:tontineId/members/join
  Future<Map<String, dynamic>> joinTontineMember(String tontineId, Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/tontines/$tontineId/members/join'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final body = response.body.trim();
      final contentType = response.headers['content-type'] ?? '';

      if ((response.statusCode == 200 || response.statusCode == 201) && body.isNotEmpty) {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }

      throw Exception(
        'Erreur adhésion tontine: status=${response.statusCode}, content-type=$contentType, body=${body.substring(0, body.length > 180 ? 180 : body.length)}',
      );
    } catch (e) {
      print('[ERROR] joinTontineMember failed: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Health check
  // ═══════════════════════════════════════════════════════════════

  /// GET /health
  Future<bool> checkBackendHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('[ERROR] Backend health check failed: $e');
      return false;
    }
  }
}
