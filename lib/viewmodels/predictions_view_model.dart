import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/prediction.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/football_api_service.dart';
import 'mqtt_provider.dart';

final predictionsProvider =
    AsyncNotifierProvider<PredictionsNotifier, List<Prediction>>(
  PredictionsNotifier.new,
);

/// Set des matchLabel pour lesquels un pronostic existe — O(1) lookup dans les cartes
final predictedMatchLabelsProvider = Provider<Set<String>>((ref) {
  return ref.watch(predictionsProvider).maybeWhen(
    data: (list) => list.map((p) => p.matchLabel).toSet(),
    orElse: () => const {},
  );
});

class PredictionsNotifier extends AsyncNotifier<List<Prediction>> {
  @override
  Future<List<Prediction>> build() async {
    // Écoute temps réel Firestore
    final sub = FirestoreService.predictionsStream().listen(
      (preds) {
        debugPrint('[FIRESTORE] Stream : ${preds.length} pronostic(s) reçu(s)');
        state = AsyncData(preds);
      },
      onError: (e, st) {
        debugPrint('[FIRESTORE ERROR] Stream : $e');
        debugPrint('[FIRESTORE ERROR] $st');
        state = AsyncError(e, st);
      },
    );
    ref.onDispose(sub.cancel);

    // Chargement initial
    try {
      final list = await FirestoreService.getPredictions();
      debugPrint('[FIRESTORE] Chargement initial : ${list.length} pronostic(s)');
      return list;
    } catch (e, st) {
      debugPrint('[FIRESTORE ERROR] Chargement initial : $e');
      debugPrint('[FIRESTORE ERROR] $st');
      // On laisse la liste vide mais on ne masque pas l'erreur dans les logs
      return [];
    }
  }

  Future<void> add(Prediction prediction) async {
    final user = AuthService.currentUser;
    debugPrint('[FIREBASE] Utilisateur connecté : ${user?.uid} (${user?.email})');

    final withAuthor = Prediction(
      id: prediction.id,
      matchLabel: prediction.matchLabel,
      selection: prediction.selection,
      odds: prediction.odds,
      stake: prediction.stake,
      comment: prediction.comment,
      confidence: prediction.confidence,
      createdAt: prediction.createdAt,
      result: prediction.result,
      fixtureId: prediction.fixtureId,
      kickoffUtc: prediction.kickoffUtc,
      authorUid: user?.uid,
    );

    // 1. Enregistrement Firestore — toute erreur remonte sans être masquée
    await FirestoreService.savePrediction(withAuthor);

    // 2. Publication MQTT directe vers l'ESP32
    final mqttRepo = ref.read(mqttRepositoryProvider);
    if (mqttRepo.isConnected) {
      mqttRepo.sendPrediction(withAuthor);
    }
    // (state mis à jour automatiquement par le stream Firestore)
  }

  Future<void> remove(String id) async {
    await FirestoreService.deletePrediction(id);
  }

  Future<void> setResult(String id, String? result) async {
    await FirestoreService.updateResult(id, result);
  }

  // Vérifie automatiquement les résultats via l'API Football.
  Future<int> autoCheckResults() async {
    final current = state.valueOrNull ?? [];
    final now = DateTime.now().toUtc();
    final toCheck = current
        .where((p) =>
            p.result == null &&
            p.fixtureId != null &&
            p.kickoffUtc != null &&
            now.difference(p.kickoffUtc!).inMinutes >= 90)
        .toList();

    if (toCheck.isEmpty) return 0;

    int count = 0;
    for (int i = 0; i < toCheck.length; i++) {
      if (i > 0) await Future.delayed(const Duration(milliseconds: 400));
      final pred = toCheck[i];
      final matchResult =
          await FootballApiService.fetchFixtureResult(pred.fixtureId!);
      if (matchResult != null) {
        final outcome = matchResult == pred.selection ? 'won' : 'lost';
        await FirestoreService.updateResult(pred.id, outcome);
        count++;
      }
    }
    return count;
  }

  Future<void> clear() async {
    final current = state.valueOrNull ?? [];
    for (final p in current) {
      await FirestoreService.deletePrediction(p.id);
    }
  }
}
