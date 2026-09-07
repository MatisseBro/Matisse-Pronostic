import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/prediction.dart';
import 'package:flutter_application_1/models/standing_entry.dart';

void main() {
  // ── Prediction ────────────────────────────────────────────────────────────
  group('Prediction', () {
    final base = Prediction(
      id: '1',
      matchLabel: 'Monaco - PSG',
      selection: '1',
      odds: 2.10,
      comment: 'Monaco solide à domicile',
      confidence: 4,
      createdAt: DateTime(2026, 9, 7),
      result: null,
    );

    test('toJson / fromJson round-trip sans résultat', () {
      final json = base.toJson();
      final restored = Prediction.fromJson(json);

      expect(restored.id, base.id);
      expect(restored.matchLabel, base.matchLabel);
      expect(restored.selection, base.selection);
      expect(restored.odds, base.odds);
      expect(restored.comment, base.comment);
      expect(restored.confidence, base.confidence);
      expect(restored.result, isNull);
    });

    test('toJson / fromJson round-trip avec résultat won', () {
      final won = base.copyWith(result: 'won');
      final restored = Prediction.fromJson(won.toJson());
      expect(restored.result, 'won');
    });

    test('toJson / fromJson round-trip avec résultat lost', () {
      final lost = base.copyWith(result: 'lost');
      final restored = Prediction.fromJson(lost.toJson());
      expect(restored.result, 'lost');
    });

    test('copyWith clearResult remet result à null', () {
      final won = base.copyWith(result: 'won');
      final cleared = won.copyWith(clearResult: true);
      expect(cleared.result, isNull);
      expect(cleared.matchLabel, base.matchLabel); // les autres champs intacts
    });

    test('copyWith sans argument préserve le résultat existant', () {
      final won = base.copyWith(result: 'won');
      final same = won.copyWith();
      expect(same.result, 'won');
    });
  });

  // ── StandingEntry ─────────────────────────────────────────────────────────
  group('StandingEntry.fromJson', () {
    test('parse le format réel de l\'API (champs win/draw/lose)', () {
      final json = {
        'position': 1,
        'team': {'id': 123, 'name': 'Monaco'},
        'played': 3,
        'win': 3,
        'draw': 0,
        'lose': 0,
        'goals_for': 5,
        'goals_against': 1,
        'goal_difference': 4,
        'points': 9,
      };

      final entry = StandingEntry.fromJson(json);
      expect(entry.position, 1);
      expect(entry.teamName, 'Monaco');
      expect(entry.points, 9);
      expect(entry.played, 3);
      expect(entry.won, 3);
      expect(entry.drawn, 0);
      expect(entry.lost, 0);
    });

    test('fallback sur won/drawn/lost si win/draw/lose absents', () {
      final json = {
        'position': 2,
        'team': {'name': 'Lyon'},
        'played': 3,
        'won': 2,
        'drawn': 1,
        'lost': 0,
        'points': 7,
      };

      final entry = StandingEntry.fromJson(json);
      expect(entry.won, 2);
      expect(entry.drawn, 1);
      expect(entry.lost, 0);
    });

    test('valeur par défaut 0 si champ manquant', () {
      final json = {
        'position': 5,
        'team': {'name': 'Lens'},
        'points': 4,
      };

      final entry = StandingEntry.fromJson(json);
      expect(entry.played, 0);
      expect(entry.won, 0);
    });
  });

  // ── Calcul taux de réussite ───────────────────────────────────────────────
  group('Calcul win rate', () {
    List<Prediction> makePredictions(List<String?> results) {
      return results.asMap().entries.map((e) => Prediction(
            id: '${e.key}',
            matchLabel: 'Match ${e.key}',
            selection: '1',
            odds: 1.90,
            comment: '',
            confidence: 3,
            createdAt: DateTime(2026, 9, 7),
            result: e.value,
          )).toList();
    }

    test('taux 100% si tout gagné', () {
      final predictions = makePredictions(['won', 'won', 'won']);
      final won = predictions.where((p) => p.result == 'won').length;
      final lost = predictions.where((p) => p.result == 'lost').length;
      final resolved = won + lost;
      expect(won / resolved * 100, 100.0);
    });

    test('taux 50% si moitié gagné moitié perdu', () {
      final predictions = makePredictions(['won', 'lost', 'won', 'lost']);
      final won = predictions.where((p) => p.result == 'won').length;
      final lost = predictions.where((p) => p.result == 'lost').length;
      final resolved = won + lost;
      expect(won / resolved * 100, 50.0);
    });

    test('pas de taux si aucun résultat renseigné', () {
      final predictions = makePredictions([null, null, null]);
      final won = predictions.where((p) => p.result == 'won').length;
      final lost = predictions.where((p) => p.result == 'lost').length;
      final resolved = won + lost;
      expect(resolved, 0);
    });

    test('les pronos en attente n\'affectent pas le taux', () {
      final predictions = makePredictions(['won', 'won', null, null]);
      final won = predictions.where((p) => p.result == 'won').length;
      final lost = predictions.where((p) => p.result == 'lost').length;
      final resolved = won + lost;
      expect(won / resolved * 100, 100.0);
      expect(predictions.length - resolved, 2); // 2 en attente
    });
  });
}
