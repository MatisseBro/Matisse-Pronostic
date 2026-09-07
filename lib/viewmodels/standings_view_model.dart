import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/standing_entry.dart';
import '../repositories/football_repository.dart';
import '../services/football_api_service.dart';

// Championnat sélectionné dans la page Classements
final selectedStandingsLeagueProvider = StateProvider<String>(
  (ref) => FootballApiService.leagueOrder.first,
);

final standingsProvider =
    AsyncNotifierProvider<StandingsNotifier, List<StandingEntry>>(
  StandingsNotifier.new,
);

class StandingsNotifier extends AsyncNotifier<List<StandingEntry>> {
  @override
  Future<List<StandingEntry>> build() {
    final league = ref.watch(selectedStandingsLeagueProvider);
    final leagueId = FootballApiService.leagueIds[league]!;
    return ref.read(footballRepositoryProvider).getStandings(leagueId);
  }
}
