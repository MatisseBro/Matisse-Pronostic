import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/football_match.dart';

class CacheService {
  static const _boxName    = 'matches_cache';
  static const _ttlMinutes = 30;

  static bool _initialized = false;

  static Box get _box => Hive.box(_boxName);

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
    _initialized = true;
  }

  // Retourne null si cache absent ou Hive non disponible.
  // Retourne les données même expirées si [allowStale] = true.
  static ({Map<String, List<FootballMatch>> data, DateTime timestamp, bool isStale})?
      getMatchesEntry(DateTime date, {bool allowStale = false}) {
    if (!_initialized) return null;

    final raw = _box.get(_dateKey(date)) as String?;
    if (raw == null) return null;

    final entry     = jsonDecode(raw) as Map<String, dynamic>;
    final timestamp = DateTime.parse(entry['timestamp'] as String);
    final isStale   = DateTime.now().difference(timestamp).inMinutes > _ttlMinutes;

    if (isStale && !allowStale) {
      _box.delete(_dateKey(date));
      return null;
    }

    final raw2 = entry['data'] as Map<String, dynamic>;
    final data = raw2.map(
      (league, matches) => MapEntry(
        league,
        (matches as List)
            .map((m) => FootballMatch.fromCacheJson(m as Map<String, dynamic>))
            .toList(),
      ),
    );
    return (data: data, timestamp: timestamp, isStale: isStale);
  }

  // Retourne null si cache absent, expiré, ou Hive non disponible.
  static Map<String, List<FootballMatch>>? getMatches(DateTime date) =>
      getMatchesEntry(date)?.data;

  // Ne fait rien si Hive n'est pas disponible.
  static Future<void> setMatches(
    DateTime date,
    Map<String, List<FootballMatch>> matches,
  ) async {
    if (!_initialized) return;

    final entry = {
      'timestamp': DateTime.now().toIso8601String(),
      'data': matches.map(
        (league, list) =>
            MapEntry(league, list.map((m) => m.toJson()).toList()),
      ),
    };
    await _box.put(_dateKey(date), jsonEncode(entry));
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
