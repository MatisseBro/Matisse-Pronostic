import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

// Écoute en temps réel l'état de connexion Firebase.
final authStateProvider = StreamProvider<User?>((ref) {
  return AuthService.authStateChanges();
});

// True si l'utilisateur connecté est l'administrateur (email défini dans .env).
final isAdminProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(authStateProvider);
  return userAsync.maybeWhen(
    data: (user) {
      final adminEmail = dotenv.env['ADMIN_EMAIL'] ?? '';
      return adminEmail.isNotEmpty && user?.email == adminEmail;
    },
    orElse: () => false,
  );
});
