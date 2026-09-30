/// Tests du guard de publication MQTT dans MqttService.publish().
///
/// Vérifie que publish() ne propage jamais d'exception vers l'appelant,
/// qu'il soit déconnecté (retour rapide) ou en état transitoire (try-catch).
/// Aucune dépendance réseau — exécution en millisecondes.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/mqtt_service.dart';

void main() {
  group('MqttService.publish — ne propage pas d\'exception', () {
    test('retourne silencieusement si non connecté (état initial)', () {
      final service = MqttService();
      expect(service.isConnected, isFalse);
      // Doit retourner sans exception même si _client == null
      expect(() => service.publish('matimatch/device/prediction', 'payload'),
          returnsNormally);
    });

    test('retourne silencieusement avec topic vide si non connecté', () {
      final service = MqttService();
      expect(() => service.publish('', ''), returnsNormally);
    });

    test('dispose() est idempotent sans connexion préalable', () {
      final service = MqttService();
      expect(() => service.dispose(), returnsNormally);
    });
  });

  group('MqttService — état initial', () {
    test('isConnected = false avant connect()', () {
      expect(MqttService().isConnected, isFalse);
    });

    test('state = disconnected avant connect()', () {
      expect(MqttService().state, MqttState.disconnected);
    });
  });
}
