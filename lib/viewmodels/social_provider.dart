import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shared_prediction.dart';
import '../models/user_profile.dart';
import '../services/social_service.dart';
import '../services/user_service.dart';
import 'auth_view_model.dart';

/// Profil de l'utilisateur connecté — null si non authentifié ou pas encore créé.
final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return UserService.profileStream(user.uid);
});

/// Liste d'amis de l'utilisateur connecté.
final friendsProvider = StreamProvider<List<UserProfile>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return SocialService.friendsStream(user.uid);
});

/// Pronostics reçus par l'utilisateur connecté.
final receivedPredictionsProvider = StreamProvider<List<SharedPrediction>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return SocialService.receivedStream(user.uid);
});
