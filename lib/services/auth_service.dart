import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Connexion email/password avec timeout de 15 secondes.
  /// Sans timeout, signInWithEmailAndPassword peut attendre indéfiniment
  /// en cas de réseau lent, laissant le spinner actif sans message d'erreur.
  static Future<void> signIn(String email, String password) async {
    await _auth
        .signInWithEmailAndPassword(email: email, password: password)
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException(
            'La connexion a pris trop de temps (> 15 s). '
            'Vérifie ta connexion internet et réessaie.',
          ),
        );
  }

  static Future<void> register(String email, String password) async {
    await _auth
        .createUserWithEmailAndPassword(email: email, password: password)
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException(
            'La création de compte a pris trop de temps (> 15 s).',
          ),
        );
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  static User? get currentUser => _auth.currentUser;
}
