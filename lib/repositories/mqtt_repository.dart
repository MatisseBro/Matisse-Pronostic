import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../models/football_match.dart';
import '../models/prediction.dart';
import '../models/shared_prediction.dart';
import '../services/mqtt_service.dart';

class MqttRepository {
  final MqttService _service;
  MqttRepository(this._service);

  static const topicMatch       = 'matimatch/device/match';
  static const topicPrediction  = 'matimatch/device/prediction';
  static const topicStatus      = 'matimatch/device/status';
  static const topicButton      = 'matimatch/device/button';
  // Préfixe pour les topics ciblés par appareil
  static const topicDeviceBase  = 'matimatch/device';

  // Contrôleur créé dès le constructeur — valide AVANT connect().
  // Sans ça, deviceStatusStream retourne Stream.empty() si le listener
  // est attaché avant que _client existe (cas de main.dart).
  final _msgCtrl =
      StreamController<MqttReceivedMessage<MqttMessage?>>.broadcast();

  StreamSubscription<MqttReceivedMessage<MqttMessage?>>? _updatesSub;

  Stream<MqttState> get stateStream => _service.stateStream;
  bool get isConnected => _service.isConnected;

  Future<bool> connect() async {
    // Annule l'abonnement précédent au cas où connect() est rappelé.
    await _updatesSub?.cancel();
    _updatesSub = null;

    final ok = await _service.connect();
    if (ok) {
      _service.subscribe(topicStatus);
      _service.subscribe(topicButton);

      // Pipe les messages SDK vers _msgCtrl.
      // Les streams dérivés (deviceStatusStream, buttonEventStream) les reçoivent
      // quel que soit le moment où leurs listeners ont été attachés.
      final updates = _service.updates;
      if (updates != null) {
        _updatesSub = updates.expand((list) => list).listen(
          (msg) {
            debugPrint(
              '[MQTT←] topic="${msg.topic}" '
              'payload="${_extractPayload(msg)}"',
            );
            if (!_msgCtrl.isClosed) _msgCtrl.add(msg);
          },
          onError: (e) => debugPrint('[MQTT←] stream error: $e'),
          cancelOnError: false,
        );
      }
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
    debugPrint('[MQTT→] sendMatch: $payload');
    _service.publish(topicMatch, payload);
  }

  // Flutter → ESP32 : envoyer un pronostic à afficher sur l'OLED
  void sendPrediction(Prediction prediction) {
    final payload = jsonEncode({
      'matchLabel': prediction.matchLabel,
      'selection':  prediction.selection,
      'odds':       prediction.odds,
      'confidence': prediction.confidence,
      'comment':    prediction.comment,
    });
    debugPrint('[MQTT→] sendPrediction: $payload');
    _service.publish(topicPrediction, payload);
  }

  // ESP32 → Flutter : statut ONLINE / OFFLINE (retained)
  Stream<String> get deviceStatusStream => _msgCtrl.stream
      .where((m) => m.topic == topicStatus)
      .map((m) => _extractPayload(m));

  // ESP32 → Flutter : appui bouton
  Stream<bool> get buttonEventStream => _msgCtrl.stream
      .where((m) => m.topic == topicButton)
      .map((_) => true);

  static String _extractPayload(MqttReceivedMessage<MqttMessage?> msg) {
    final pub = msg.payload as MqttPublishMessage;
    return MqttPublishPayload.bytesToStringAsString(pub.payload.message);
  }

  /// Envoie un pronostic partagé sur le topic privé d'un appareil.
  /// retain=true : l'ESP32 reçoit le message même s'il était hors ligne.
  void sendToDevice(String deviceId, SharedPrediction prediction) {
    final topic = '$topicDeviceBase/$deviceId/prediction';
    final payload = jsonEncode({
      'matchLabel': prediction.matchLabel,
      'selection':  prediction.selection,
      'odds':       prediction.odds,
      'confidence': prediction.confidence,
      'fromName':   prediction.fromName,
      'comment':    prediction.comment,
    });
    debugPrint('[MQTT→] sendToDevice $deviceId: $payload');
    _service.publish(topic, payload, retain: true);
  }

  void disconnect() => _service.disconnect();

  void dispose() {
    _updatesSub?.cancel();
    _msgCtrl.close();
  }
}
