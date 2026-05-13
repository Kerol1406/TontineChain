import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_database_service.dart';

class AuthState extends ChangeNotifier {
  Map<String, dynamic>? _currentUser;
  bool _isLoading = false;

  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;

  /// Définit l'utilisateur
  void setUser(Map<String, dynamic> user) {
    _currentUser = user;
    notifyListeners();
  }

  /// Vide la session utilisateur
  void clear() {
    _currentUser = null;
    notifyListeners();
  }

  /// Initialise l'état depuis Firebase Auth puis hydrate le profil Firestore.
  Future<void> initializeFromFirebaseUser(User? user) async {
    if (user != null) {
      final profile = await FirestoreDatabaseService.instance.getUserProfile(user.uid);
      _currentUser = {
        'uid': user.uid,
        'email': profile?['email'] ?? user.email,
        'displayName': profile?['displayName'] ?? user.displayName ?? profile?['nom'],
        'phone': profile?['phone'] ?? user.phoneNumber,
        'phoneNumber': profile?['phone'] ?? user.phoneNumber,
        'role': 'user',
        ...?profile,
      };
    } else {
      _currentUser = null;
    }
    notifyListeners();
  }

  /// Écoute les changements d'authentification Firebase
  void listenToAuthChanges() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      initializeFromFirebaseUser(user);
    });
  }
}

