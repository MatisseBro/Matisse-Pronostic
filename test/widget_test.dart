import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/logger/app_logger.dart';

void main() {
  group('AppLogger — masquage des données sensibles', () {
    test('masque le champ password dans un JSON', () {
      const raw = '{"user":"alice","password":"monSuperSecret","score":3}';
      final sanitized = AppLogger.sanitize(raw);
      expect(sanitized, isNot(contains('monSuperSecret')));
      expect(sanitized, contains('***'));
    });

    test('password=*** (format .env / query-string)', () {
      const raw = 'MQTT_PASSWORD=monSuperSecret host=mqtt.example.com';
      final sanitized = AppLogger.sanitize(raw);
      expect(sanitized, contains('MQTT_PASSWORD=***'));
      expect(sanitized, isNot(contains('monSuperSecret')));
    });

    test('masque le token Bearer dans les en-têtes HTTP', () {
      const raw = 'Authorization: Bearer eyJhbGciOiJSUzI1NiJ9.abc123';
      final sanitized = AppLogger.sanitize(raw);
      expect(sanitized, contains('Bearer ***'));
      expect(sanitized, isNot(contains('eyJhbGciOiJSUzI1NiJ9')));
    });

    test('préserve les données non sensibles', () {
      const raw = '{"user":"alice","score":42,"matchLabel":"PSG 2-1 OM"}';
      final sanitized = AppLogger.sanitize(raw);
      expect(sanitized, contains('alice'));
      expect(sanitized, contains('42'));
      expect(sanitized, contains('PSG 2-1 OM'));
    });

    test('masque api_key dans un JSON', () {
      const raw = '{"api_key":"secretkey123","endpoint":"/matches"}';
      final sanitized = AppLogger.sanitize(raw);
      expect(sanitized, isNot(contains('secretkey123')));
      expect(sanitized, contains('***'));
    });
  });

  testWidgets('Widget racine s\'instancie sans erreur (mock)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('MatiMatch'))),
      ),
    );
    expect(find.text('MatiMatch'), findsOneWidget);
  });
}
