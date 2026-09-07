import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/prediction.dart';
import '../services/football_api_service.dart';
import '../storage/preferences_service.dart';

final predictionsProvider = AsyncNotifierProvider<PredictionsNotifier, List<Prediction>>(
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
    final list = await PreferencesService.getPredictions();
    return list
        .map((s) => Prediction.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> add(Prediction prediction) async {
    final current = await future;
    final updated = [...current, prediction];
    await _persist(updated);
    state = AsyncData(updated);
  }

  Future<void> remove(String id) async {
    final current = await future;
    final updated = current.where((p) => p.id != id).toList();
    await _persist(updated);
    state = AsyncData(updated);
  }

  Future<void> setResult(String id, String? result) async {
    final current = await future;
    final updated = current.map((p) {
      if (p.id != id) return p;
      return result == null ? p.copyWith(clearResult: true) : p.copyWith(result: result);
    }).toList();
    await _persist(updated);
    state = AsyncData(updated);
  }

  // Vérifie automatiquement les résultats des pronostics en attente via l'API.
  // Retourne le nombre de résultats mis à jour.
  Future<int> autoCheckResults() async {
    final current = await future;
    final now = DateTime.now().toUtc();
    final toCheck = current
        .where((p) =>
            p.result == null &&
            p.fixtureId != null &&
            p.kickoffUtc != null &&
            now.difference(p.kickoffUtc!).inMinutes >= 90)
        .toList();

    if (toCheck.isEmpty) return 0;

    var updated = List<Prediction>.from(current);
    int count = 0;

    for (int i = 0; i < toCheck.length; i++) {
      if (i > 0) await Future.delayed(const Duration(milliseconds: 400));
      final pred = toCheck[i];
      final matchResult = await FootballApiService.fetchFixtureResult(pred.fixtureId!);
      if (matchResult != null) {
        final outcome = matchResult == pred.selection ? 'won' : 'lost';
        final idx = updated.indexWhere((p) => p.id == pred.id);
        if (idx != -1) {
          updated[idx] = updated[idx].copyWith(result: outcome);
          count++;
        }
      }
    }

    if (count > 0) {
      await _persist(updated);
      state = AsyncData(updated);
    }
    return count;
  }

  Future<void> clear() async {
    await _persist([]);
    state = const AsyncData([]);
  }

  Future<void> _persist(List<Prediction> list) async {
    await PreferencesService.setPredictions(
      list.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }
}
