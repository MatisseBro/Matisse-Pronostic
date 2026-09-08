import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/football_match.dart';
import '../models/standing_entry.dart';
import '../services/football_api_service.dart';
import '../services/cache_service.dart';

class MatchesResult {
  final Map<String, List<FootballMatch>> data;
  final DateTime? cacheTimestamp;
  final bool isFromCache;

  const MatchesResult({
    required this.data,
    this.cacheTimestamp,
    this.isFromCache = false,
  });
}

class FootballRepository {
  Future<MatchesResult> getMatchesForDate(DateTime date) async {
    // 1. Cache valide → on l'utilise directement
    final fresh = CacheService.getMatchesEntry(date);
    if (fresh != null && !fresh.isStale) {
      return MatchesResult(
        data: fresh.data,
        cacheTimestamp: fresh.timestamp,
        isFromCache: true,
      );
    }

    // 2. Appel API
    try {
      final apiData = await FootballApiService.fetchMatchesFromApi(date);
      await CacheService.setMatches(date, apiData);
      return MatchesResult(data: apiData);
    } catch (e) {
      // 3. API échouée → fallback sur le cache expiré s'il existe
      final stale = CacheService.getMatchesEntry(date, allowStale: true);
      if (stale != null) {
        return MatchesResult(
          data: stale.data,
          cacheTimestamp: stale.timestamp,
          isFromCache: true,
        );
      }
      rethrow;
    }
  }

  Future<List<StandingEntry>> getStandings(int leagueId) async {
    return FootballApiService.fetchStandings(leagueId);
  }
}

final footballRepositoryProvider = Provider<FootballRepository>(
  (ref) => FootballRepository(),
);
