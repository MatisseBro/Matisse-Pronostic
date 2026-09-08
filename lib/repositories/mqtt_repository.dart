import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import '../models/football_match.dart';
import '../services/mqtt_service.dart';

class MqttRepository {
  final MqttService _service;
  MqttRepository(this._service);

  static const topicMatch  = 'matimatch/device/match';
  static const topicStatus = 'matimatch/device/status';
  static const topicButton = 'matimatch/device/button';

  Stream<MqttState> get stateStream => _service.stateStream;
  bool get isConnected => _service.isConnected;

  Future<bool> connect() async {
    final ok = await _service.connect();
    if (ok) {
      _service.subscribe(topicStatus);
      _service.subscribe(topicButton);
    }
    return ok;
  }

  // Flutter → ESP32 : envoyer un match à afficher sur l'OLED
  void sendMatch(FootballMatch match) {
    final payload = jsonEncode({
      'homeTeam':  match.homeTeam,
      'awayTeam':  match.awayTeam,
      'homeScore': match.homeScore ?? 0,
      'awayScore': match.awayScore ?? 0,
      'status':    match.status.toUpperCase(),
      'kickoff':   match.matchTime,
    });
    _service.publish(topicMatch, payload);
  }

  // ESP32 → Flutter : statut ONLINE / OFFLINE (topic retain)
  Stream<String> get deviceStatusStream => _allMessages
      .where((m) => m.topic == topicStatus)
      .map((m) => _extractPayload(m));

  // ESP32 → Flutter : appui bouton (true = appuyé)
  Stream<bool> get buttonEventStream => _allMessages
      .where((m) => m.topic == topicButton)
      .map((_) => true);

  Stream<MqttReceivedMessage<MqttMessage?>> get _allMessages {
    final updates = _service.updates;
    if (updates == null) return const Stream.empty();
    return updates.expand((list) => list);
  }

  static String _extractPayload(MqttReceivedMessage<MqttMessage?> msg) {
    final pub = msg.payload as MqttPublishMessage;
    return MqttPublishPayload.bytesToStringAsString(pub.payload.message);
  }

  void disconnect() => _service.disconnect();
}
