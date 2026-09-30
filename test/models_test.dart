import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/prediction.dart';
import 'package:flutter_application_1/models/shared_prediction.dart';
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

  // ── authorUid — ownership ─────────────────────────────────────────────────
  group('Prediction.authorUid', () {
    final predWithAuthor = Prediction(
      id: '42',
      matchLabel: 'Lyon - Rennes',
      selection: '2',
      odds: 3.20,
      comment: '',
      confidence: 2,
      createdAt: DateTime(2026, 9, 30),
      authorUid: 'uid-alice',
    );

    test('authorUid est inclus dans toJson', () {
      final json = predWithAuthor.toJson();
      expect(json['authorUid'], 'uid-alice');
    });

    test('authorUid est préservé dans fromJson', () {
      final restored = Prediction.fromJson(predWithAuthor.toJson());
      expect(restored.authorUid, 'uid-alice');
    });

    test('authorUid null est stocké (pronostic legacy)', () {
      final legacy = Prediction(
        id: '1',
        matchLabel: 'Nantes - Metz',
        selection: '1',
        odds: 1.80,
        comment: '',
        confidence: 3,
        createdAt: DateTime(2026, 1, 1),
      );
      final json = legacy.toJson();
      expect(json.containsKey('authorUid'), isTrue);
      expect(json['authorUid'], isNull);
    });

    test('fromJson accepte authorUid null (legacy)', () {
      final json = predWithAuthor.toJson();
      json['authorUid'] = null;
      final restored = Prediction.fromJson(json);
      expect(restored.authorUid, isNull);
    });

    test('copyWith ne peut pas modifier authorUid (non exposé)', () {
      // copyWith n'expose pas authorUid — l'uid reste celui d'origine
      final copied = predWithAuthor.copyWith(result: 'won');
      expect(copied.authorUid, 'uid-alice');
    });
  });

  // ── SharedPrediction ──────────────────────────────────────────────────────
  group('SharedPrediction', () {
    final shared = SharedPrediction(
      id: 'pred-1',
      fromUid: 'uid-alice',
      fromName: 'Alice',
      matchLabel: 'PSG - Monaco',
      selection: '1',
      odds: 1.65,
      confidence: 4,
      comment: 'PSG à domicile',
      createdAt: DateTime(2026, 9, 30),
      mqttStatus: 'pending',
    );

    test('toJson / fromJson round-trip complet', () {
      final json = shared.toJson();
      final restored = SharedPrediction.fromJson(json);

      expect(restored.id,         shared.id);
      expect(restored.fromUid,    shared.fromUid);
      expect(restored.fromName,   shared.fromName);
      expect(restored.matchLabel, shared.matchLabel);
      expect(restored.selection,  shared.selection);
      expect(restored.odds,       shared.odds);
      expect(restored.confidence, shared.confidence);
      expect(restored.comment,    shared.comment);
      expect(restored.mqttStatus, shared.mqttStatus);
    });

    test('fromUid est inclus dans toJson', () {
      expect(shared.toJson()['fromUid'], 'uid-alice');
    });

    test('mqttStatus par défaut est pending', () {
      final noStatus = SharedPrediction(
        id: 'x', fromUid: 'u', fromName: 'U',
        matchLabel: 'A - B', selection: '1', odds: 1.5,
        confidence: 3, comment: '', createdAt: DateTime.now(),
      );
      expect(noStatus.mqttStatus, 'pending');
    });

    test('fromJson avec fromUid absent utilise chaîne vide', () {
      final json = shared.toJson()..remove('fromUid');
      final restored = SharedPrediction.fromJson(json);
      expect(restored.fromUid, '');
    });

    test('fromJson avec fromName absent utilise Inconnu', () {
      final json = shared.toJson()..remove('fromName');
      final restored = SharedPrediction.fromJson(json);
      expect(restored.fromName, 'Inconnu');
    });
  });
}
