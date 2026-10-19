import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/logger/app_logger.dart';
import '../models/prediction.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/football_api_service.dart';
import 'auth_view_model.dart';
import 'mqtt_provider.dart';

final predictionsProvider =
    AsyncNotifierProvider<PredictionsNotifier, List<Prediction>>(
  PredictionsNotifier.new,
);

final predictedMatchLabelsProvider = Provider<Set<String>>((ref) {
  return ref.watch(predictionsProvider).maybeWhen(
    data: (list) => list.map((p) => p.matchLabel).toSet(),
    orElse: () => const {},
  );
});

class PredictionsNotifier extends AsyncNotifier<List<Prediction>> {
  static const _tag = 'FIRESTORE';

  @override
  Future<List<Prediction>> build() async {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    if (uid == null) return [];

    final sub = FirestoreService.predictionsStream(uid).listen(
      (preds) {
        AppLogger.d(_tag, 'Stream: ${preds.length} pronostic(s)');
        state = AsyncData(preds);
      },
      onError: (e, st) {
        AppLogger.e(_tag, 'Stream error', e);
        state = AsyncError(e, st as StackTrace);
      },
    );
    ref.onDispose(sub.cancel);

    try {
      final list = await FirestoreService.getPredictions(uid);
      AppLogger.d(_tag, 'Chargement initial: ${list.length} pronostic(s)');
      return list;
    } catch (e, st) {
      AppLogger.e(_tag, 'Chargement initial error', e);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<Prediction> add(Prediction prediction) async {
    final user = AuthService.currentUser;
    AppLogger.d(_tag, 'Ajout pronostic pour utilisateur connecté');

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

    await FirestoreService.savePrediction(withAuthor);

    final mqttRepo = ref.read(mqttRepositoryProvider);
    if (mqttRepo.isConnected) {
      mqttRepo.sendPrediction(withAuthor);
    }
    return withAuthor;
  }

  Future<void> remove(String id) async {
    await FirestoreService.deletePrediction(id);
  }

  Future<void> setResult(String id, String? result) async {
    await FirestoreService.updateResult(id, result);
  }

  Future<int> autoCheckResults() async {
    final current = state.valueOrNull ?? [];
    final now = DateTime.now().toUtc();
    final user = AuthService.currentUser;
    final toCheck = current
        .where((p) =>
            p.result == null &&
            p.fixtureId != null &&
            p.kickoffUtc != null &&
            p.authorUid == user?.uid &&
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
