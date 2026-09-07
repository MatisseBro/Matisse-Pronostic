import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/football_match.dart';
import '../models/standing_entry.dart';

class FootballApiService {
  static const String _baseUrl = 'https://api.5dollarfootballapi.com/v1';

  static String get _apiKey => dotenv.env['API_FOOTBALL_KEY'] ?? '';

  static Map<String, String> get headers => {
    'Authorization': 'Bearer $_apiKey',
    'Content-Type': 'application/json',
  };

  static const List<String> leagueOrder = [
    'Ligue 1',
    'Premier League',
    'Liga',
    'Serie A',
    'Bundesliga',
  ];

  // IDs des championnats sur l'API 5dollarfootballapi.com
  static const Map<String, int> leagueIds = {
    'Ligue 1':        3614399544,
    'Premier League': 4160026622,
    'Liga':           4212821298,
    'Serie A':        3405541143,
    'Bundesliga':      686337048,
  };

  static String? _mapLeagueName(String name, String? country) {
    final n = name.toLowerCase();
    if (n.contains('ligue 1'))        return 'Ligue 1';
    if (n.contains('premier league')) return 'Premier League';
    if (n.contains('la liga') || n.contains('primera')) return 'Liga';
    if (n.contains('serie a'))        return 'Serie A';
    if (n.contains('bundesliga'))     return 'Bundesliga';
    return null;
  }

  static Future<({double? home, double? draw, double? away})> _fetchOdds(
    int fixtureId,
  ) async {
    const none = (home: null, draw: null, away: null);
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/fixtures/$fixtureId/odds'),
        headers: headers,
      );
      if (response.statusCode != 200) return none;

      final body      = jsonDecode(response.body) as Map<String, dynamic>;
      final data      = body['data'] as Map<String, dynamic>?;
      if (data == null) return none;

      final bookmakers = data['bookmakers'] as List?;
      if (bookmakers == null || bookmakers.isEmpty) return none;

      final bm      = bookmakers.first as Map<String, dynamic>;
      final oddsMap = bm['odds'] as Map<String, dynamic>?;
      final x12     = oddsMap?['1x2'] as Map<String, dynamic>?;
      if (x12 == null) return none;

      final closing = x12['closing'] as Map<String, dynamic>?;
      if (closing == null) return none;

      return (
        home: (closing['home'] as num?)?.toDouble(),
        draw: (closing['draw'] as num?)?.toDouble(),
        away: (closing['away'] as num?)?.toDouble(),
      );
    } catch (_) {
      return none;
    }
  }

  static Future<Map<String, List<FootballMatch>>> fetchMatchesFromApi(
    DateTime date,
  ) async {
    final start = DateTime(date.year, date.month, date.day).toUtc();
    final end   = DateTime(date.year, date.month, date.day, 23, 59, 59).toUtc();

    final uri = Uri.parse('$_baseUrl/fixtures').replace(
      queryParameters: {
        'start_time': (start.millisecondsSinceEpoch ~/ 1000).toString(),
        'end_time':   (end.millisecondsSinceEpoch   ~/ 1000).toString(),
        'per_page':   '200',
      },
    );

    try {
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 429) {
        final retryAfter = int.tryParse(response.headers['retry-after'] ?? '') ?? 60;
        throw RateLimitException(retryAfter);
      }
      if (response.statusCode != 200) {
        throw ApiException('Erreur serveur (${response.statusCode}).');
      }

      final data     = jsonDecode(response.body);
      final fixtures = data is List ? data : (data['data'] as List? ?? []);

      final toProcess = <({Map<String, dynamic> json, String displayName})>[];
      for (final f in fixtures) {
        final json       = f as Map<String, dynamic>;
        final leagueJson = json['league'] as Map<String, dynamic>?;
        if (leagueJson == null) continue;

        final leagueName  = leagueJson['name'] as String? ?? '';
        final countryName =
            (leagueJson['country'] as Map<String, dynamic>?)?['name'] as String?;
        final displayName = _mapLeagueName(leagueName, countryName);
        if (displayName == null) continue;

        toProcess.add((json: json, displayName: displayName));
      }

      final oddsResults = await Future.wait(
        toProcess.map((item) => _fetchOdds(item.json['id'] as int)),
      );

      final result = <String, List<FootballMatch>>{
        for (final name in leagueOrder) name: [],
      };

      for (var i = 0; i < toProcess.length; i++) {
        final item = toProcess[i];
        final odds = oddsResults[i];
        result[item.displayName]!.add(
          FootballMatch.fromJson(
            item.json,
            leagueName: item.displayName,
            homeOdds: odds.home,
            drawOdds: odds.draw,
            awayOdds: odds.away,
          ),
        );
      }

      result.removeWhere((_, matches) => matches.isEmpty);
      return result;
    } on SocketException {
      throw NoInternetException();
    }
  }

  // Retourne '1', 'N', '2' si le match est terminé, null sinon
  static Future<String?> fetchFixtureResult(int fixtureId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/fixtures/$fixtureId'),
        headers: headers,
      );
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = (body['data'] as Map<String, dynamic>?) ?? body;

      final status = (data['status'] as String? ?? '').toLowerCase();
      final finished = status == 'finished' ||
          status == 'ft' ||
          status == 'aet' ||
          status == 'pen' ||
          status.contains('finish') ||
          status.contains('complete');
      if (!finished) return null;

      final goals = data['goals'] as Map<String, dynamic>?;
      final home = goals?['home'] as int?;
      final away = goals?['away'] as int?;
      if (home == null || away == null) return null;

      if (home > away) return '1';
      if (home == away) return 'N';
      return '2';
    } catch (_) {
      return null;
    }
  }

  static Future<List<StandingEntry>> fetchStandings(int leagueId) async {
    final uri = Uri.parse('$_baseUrl/standings').replace(
      queryParameters: {'league': leagueId.toString()},
    );

    try {
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 429) {
        final retryAfter = int.tryParse(response.headers['retry-after'] ?? '') ?? 60;
        throw RateLimitException(retryAfter);
      }
      if (response.statusCode != 200) {
        final err = jsonDecode(response.body);
        final msg = (err['error']?['message'] as String?) ?? 'Erreur ${response.statusCode}';
        throw ApiException(msg);
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      final table = data?['table'] as List? ?? [];
      return table.cast<Map<String, dynamic>>().map(StandingEntry.fromJson).toList();
    } on SocketException {
      throw NoInternetException();
    }
  }
}

// ── Exceptions métier ──────────────────────────────────────────────────────────

class NoInternetException implements Exception {
  @override
  String toString() => 'Pas de connexion Internet. Vérifiez votre réseau.';
}

class RateLimitException implements Exception {
  final int retryAfterSeconds;
  const RateLimitException(this.retryAfterSeconds);
  @override
  String toString() =>
      'Quota API dépassé. Réessayez dans $retryAfterSeconds secondes.';
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}
