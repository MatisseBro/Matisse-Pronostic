import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/football_match.dart';
import '../repositories/football_repository.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// null = "Tous les championnats"
final leagueFilterProvider = StateProvider<String?>((ref) => null);

// Onglet actif de HomePage (0=Matchs, 1=Pronostics, 2=Classements, 3=Profil)
final selectedTabProvider = StateProvider<int>((ref) => 0);

final matchesProvider = AsyncNotifierProvider<MatchesNotifier, Map<String, List<FootballMatch>>>(
  MatchesNotifier.new,
);

class MatchesNotifier extends AsyncNotifier<Map<String, List<FootballMatch>>> {
  @override
  Future<Map<String, List<FootballMatch>>> build() {
    final date = ref.watch(selectedDateProvider);
    return ref.read(footballRepositoryProvider).getMatchesForDate(date);
  }
}
