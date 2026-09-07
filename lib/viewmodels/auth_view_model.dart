import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

// Écoute en temps réel l'état de connexion Firebase.
// Retourne null si déconnecté, User si connecté.
final authStateProvider = StreamProvider<User?>((ref) {
  return AuthService.authStateChanges();
});
