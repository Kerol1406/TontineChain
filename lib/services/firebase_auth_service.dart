import 'dart:io';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_database_service.dart';

/// Service d'authentification Firebase
/// Gère register, login, logout via Firebase Auth
class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();

  factory FirebaseAuthService() {
    return _instance;
  }

  FirebaseAuthService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  /// Récupère l'utilisateur actuellement connecté
  User? get currentUser => _firebaseAuth.currentUser;

  /// Crée un nouveau compte utilisateur avec email et mot de passe
  /// Retourne un Map avec les données utilisateur ou une erreur
  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String password,
    String? identityDocumentPath,
    String? phoneVerificationId,
    String? smsCode,
  }) async {
    try {
      final authEmail = email.isEmpty
          ? 'user_${phone.replaceAll(RegExp(r'[^0-9+]'), '')}@tontinechain.local'
          : email;

      // Créer l'utilisateur Firebase Auth
      UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return {
          'success': false,
          'error': 'Erreur lors de la création du compte',
        };
      }

      // Mettre à jour le displayName
      await user.updateDisplayName('$firstName $lastName');
      await user.reload();

      // Si on a reçu un code SMS de vérification, lier le numéro au compte
      if (phoneVerificationId != null && smsCode != null && phoneVerificationId.isNotEmpty && smsCode.isNotEmpty) {
        try {
          final phoneCred = PhoneAuthProvider.credential(verificationId: phoneVerificationId, smsCode: smsCode);
          await user.linkWithCredential(phoneCred);
        } catch (e) {
          // Ignorer l'erreur de linkage mais la signaler pourrait être utile
        }
      }

      // Normaliser le numéro avant de le sauvegarder (ajoute +229 si nécessaire)
      final normalizedPhone = _normalizePhone(phone);

      String? identityDocumentUrl;
      if (identityDocumentPath != null && identityDocumentPath.isNotEmpty) {
        identityDocumentUrl = await FirestoreDatabaseService.instance.uploadIdentityDocument(
          uid: user.uid,
          documentFile: File(identityDocumentPath),
        );
      }

      await FirestoreDatabaseService.instance.saveUserProfile(
        uid: user.uid,
        firstName: firstName,
        lastName: lastName,
        phone: normalizedPhone,
        email: authEmail,
        identityDocumentUrl: identityDocumentUrl,
        kycStatus: 'PENDING',
        isLookingForTontine: true,
      );

      // Retourner les données utilisateur
      return {
        'success': true,
        'uid': user.uid,
        'email': user.email ?? authEmail,
        'firstName': firstName,
        'lastName': lastName,
        'phone': normalizedPhone,
        'displayName': user.displayName,
        'identityDocumentUrl': identityDocumentUrl,
        'createdAt': user.metadata.creationTime,
      };
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Erreur d\'inscription';
      if (e.code == 'weak-password') {
        errorMessage = 'Le mot de passe est trop faible';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'Cet email est déjà utilisé';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Email invalide';
      } else if (e.code == 'operation-not-allowed') {
        errorMessage = 'L\'inscription est désactivée';
      }
      return {
        'success': false,
        'error': errorMessage,
        'code': e.code,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Erreur inattendue: $e',
      };
    }
  }

  /// Connecte l'utilisateur avec email et mot de passe
  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    try {
      // For login we require phone + password. Resolve phone -> email via Firestore.
      final resolvedEmail = await _resolveEmailFromIdentifier(identifier);
      if (resolvedEmail == null) {
        // Debug: fetch variants to inspect what's in Firestore for this identifier
        final normalized = _normalizePhone(identifier);
        final rawProfile = await FirestoreDatabaseService.instance.getUserProfileByPhoneVariants(identifier);
        final normalizedProfile = await FirestoreDatabaseService.instance.getUserProfileByPhoneVariants(normalized);
        // Print debug info so it appears in the device/emulator logs
        try {
          print('LOGIN DEBUG - identifier: $identifier');
          print('LOGIN DEBUG - normalized: $normalized');
          print('LOGIN DEBUG - rawProfile: ${rawProfile ?? 'null'}');
          print('LOGIN DEBUG - normalizedProfile: ${normalizedProfile ?? 'null'}');
          // Also search users for fragments matching the identifier to locate stored format
          final found = await FirestoreDatabaseService.instance.debugFindUsersByFragment(identifier);
          print('LOGIN DEBUG - foundUsersCount: ${found.length}');
          for (final f in found) {
            print('LOGIN DEBUG - foundUser: ${f['__id']} => phone=${f['phone'] ?? 'null'} telephone=${f['telephone'] ?? 'null'} email=${f['email'] ?? 'null'}');
          }
        } catch (e) {}
        return {
          'success': false,
          'error': 'Utilisateur non trouvé',
          'code': 'user-not-found',
        };
      }

      UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: resolvedEmail,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return {
          'success': false,
          'error': 'Erreur lors de la connexion',
        };
      }

      return {
        'success': true,
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'emailVerified': user.emailVerified,
        'profile': await FirestoreDatabaseService.instance.getUserProfile(user.uid),
      };
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Erreur de connexion';
      if (e.code == 'user-not-found') {
        errorMessage = 'Utilisateur non trouvé';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Mot de passe incorrect';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Email invalide';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'Compte désactivé';
      }
      return {
        'success': false,
        'error': errorMessage,
        'code': e.code,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Erreur inattendue: $e',
      };
    }
  }

  Future<String?> _resolveEmailFromIdentifier(String identifier) async {
    final phone = _normalizePhone(identifier);
    final profile = await FirestoreDatabaseService.instance.getUserProfileByPhoneVariants(phone);
    return profile?['email'] as String?;
  }

  String _normalizePhone(String s) {
    var cleaned = s.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.startsWith('+')) return cleaned;
    if (cleaned.startsWith('229')) return '+$cleaned';
    // Pour les numéros Béninois, garder le 0 initial et ajouter +229
    return '+229$cleaned';
  }

  /// Envoie un code SMS pour vérification du numéro de téléphone.
  /// Retourne la verificationId à utiliser pour la confirmation.
  Future<String> sendPhoneVerificationCode(String phone) async {
    final completer = Completer<String>();

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (PhoneAuthCredential credential) {
        if (credential.verificationId != null && !completer.isCompleted) {
          completer.complete(credential.verificationId!);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      },
      codeSent: (String verificationId, int? forceResendingToken) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      timeout: const Duration(seconds: 60),
    );

    return completer.future;
  }

  /// Ré-authentifie l'utilisateur courant avec le code SMS (vérification téléphone).
  Future<Map<String, dynamic>> reauthenticateWithPhone({
    required String verificationId,
    required String smsCode,
    String? expectedPhone,
  }) async {
    try {
      final cred = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return {'success': false, 'error': 'Aucun utilisateur connecté'};
      }
      // If expectedPhone provided, normalize and check if it's already linked to the current user.
      if (expectedPhone != null && expectedPhone.isNotEmpty) {
        final normalized = _normalizePhone(expectedPhone);
        if (user.phoneNumber == normalized) {
          await user.reauthenticateWithCredential(cred);
          return {'success': true};
        } else {
          // Try to link the phone credential to the current user (if not used by another account).
          try {
            await user.linkWithCredential(cred);
            return {'success': true};
          } on FirebaseAuthException catch (e) {
            // If the credential belongs to another account or cannot be linked, return a clear error.
            if (e.code == 'credential-already-in-use' || e.code == 'provider-already-linked') {
              return {'success': false, 'error': 'Ce numéro est déjà utilisé par un autre compte.'};
            }
            return {'success': false, 'error': e.message ?? 'Erreur de liaison du numéro'};
          }
        }
      }

      await user.reauthenticateWithCredential(cred);
      return {'success': true};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': e.message ?? 'Erreur de vérification'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Déconnecte l'utilisateur
  Future<void> logout() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw Exception('Erreur lors de la déconnexion: $e');
    }
  }

  /// Envoie un email de réinitialisation de mot de passe
  Future<Map<String, dynamic>> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      return {
        'success': true,
        'message': 'Email de réinitialisation envoyé',
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'error': 'Erreur: ${e.message}',
      };
    }
  }

  /// Obtient le token d'authentification pour les appels API
  Future<String?> getIdToken() async {
    try {
      return await _firebaseAuth.currentUser?.getIdToken();
    } catch (e) {
      return null;
    }
  }

  /// Vérifie l'état de l'authentification en temps réel
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
}
