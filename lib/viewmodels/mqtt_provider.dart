import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/football_match.dart';
import '../repositories/mqtt_repository.dart';
import '../services/mqtt_service.dart';

// ── Services / Repository ─────────────────────────────────────────────────────

final mqttServiceProvider = Provider<MqttService>((ref) {
  final service = MqttService();
  ref.onDispose(service.dispose);
  return service;
});

final mqttRepositoryProvider = Provider<MqttRepository>((ref) {
  final repo = MqttRepository(ref.watch(mqttServiceProvider));
  ref.onDispose(repo.dispose);
  return repo;
});

// ── État de connexion MQTT Flutter ────────────────────────────────────────────

final mqttConnectedProvider = StateProvider<bool>((ref) => false);

// ── Statut de l'objet ESP32 : "ONLINE" | "OFFLINE" | "unknown" ───────────────

final deviceStatusProvider = StateProvider<String>((ref) => 'unknown');

// ── Dernier match envoyé à l'OLED ─────────────────────────────────────────────

final lastSentMatchProvider = StateProvider<FootballMatch?>((ref) => null);

// ── Événements bouton : true quand le bouton Wokwi est appuyé ────────────────

final buttonEventProvider = StreamProvider<bool>((ref) {
  return ref.watch(mqttRepositoryProvider).buttonEventStream;
});
