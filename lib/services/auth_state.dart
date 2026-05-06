import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  /// Initialise l'état depuis Firebase Auth
  void initializeFromFirebaseUser(User? user) {
    if (user != null) {
      _currentUser = {
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'phoneNumber': user.phoneNumber,
        'role': 'user',
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

