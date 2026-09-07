import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/football_match.dart';
import '../models/standing_entry.dart';
import '../services/football_api_service.dart';
import '../services/cache_service.dart';

class FootballRepository {
  Future<Map<String, List<FootballMatch>>> getMatchesForDate(DateTime date) async {
    final cached = CacheService.getMatches(date);
    if (cached != null) return cached;

    final result = await FootballApiService.fetchMatchesFromApi(date);
    await CacheService.setMatches(date, result);
    return result;
  }

  Future<List<StandingEntry>> getStandings(int leagueId) async {
    return FootballApiService.fetchStandings(leagueId);
  }
}

final footballRepositoryProvider = Provider<FootballRepository>(
  (ref) => FootballRepository(),
);
