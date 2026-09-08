import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/football_match.dart';
import '../repositories/football_repository.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// null = "Tous les championnats"
final leagueFilterProvider = StateProvider<String?>((ref) => null);

// Onglet actif de HomePage
final selectedTabProvider = StateProvider<int>((ref) => 0);

final matchesProvider =
    AsyncNotifierProvider<MatchesNotifier, MatchesResult>(MatchesNotifier.new);

class MatchesNotifier extends AsyncNotifier<MatchesResult> {
  @override
  Future<MatchesResult> build() {
    final date = ref.watch(selectedDateProvider);
    return ref.read(footballRepositoryProvider).getMatchesForDate(date);
  }
}

// Raccourci pour récupérer uniquement les données groupées (utilisé dans l'UI)
extension MatchesResultX on MatchesResult {
  Map<String, List<FootballMatch>> get grouped => data;
}
