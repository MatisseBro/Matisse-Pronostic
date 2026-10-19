import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import '../core/logger/app_logger.dart';
import '../models/football_match.dart';
import '../models/prediction.dart';
import '../models/shared_prediction.dart';
import '../services/mqtt_service.dart';

class MqttRepository {
  static const _tag = 'MQTT';

  final MqttService _service;
  MqttRepository(this._service);

  static const topicMatch       = 'matimatch/device/match';
  static const topicPrediction  = 'matimatch/device/prediction';
  static const topicStatus      = 'matimatch/device/status';
  static const topicButton      = 'matimatch/device/button';
  static const topicDeviceBase  = 'matimatch/device';

  final _msgCtrl =
      StreamController<MqttReceivedMessage<MqttMessage?>>.broadcast();

  StreamSubscription<MqttReceivedMessage<MqttMessage?>>? _updatesSub;

  Stream<MqttState> get stateStream => _service.stateStream;
  bool get isConnected => _service.isConnected;

  Future<bool> connect() async {
    await _updatesSub?.cancel();
    _updatesSub = null;

    final ok = await _service.connect();
    if (ok) {
      _service.subscribe(topicStatus);
      _service.subscribe(topicButton);

      final updates = _service.updates;
      if (updates != null) {
        _updatesSub = updates.expand((list) => list).listen(
          (msg) {
            AppLogger.d(_tag, 'topic="${msg.topic}"');
            if (!_msgCtrl.isClosed) _msgCtrl.add(msg);
          },
          onError: (e) => AppLogger.e(_tag, 'stream error', e),
          cancelOnError: false,
        );
      }
    }
    return ok;
  }

  void sendMatch(FootballMatch match) {
    final payload = jsonEncode({
      'homeTeam':  match.homeTeam,
      'awayTeam':  match.awayTeam,
      'homeScore': match.homeScore ?? 0,
      'awayScore': match.awayScore ?? 0,
      'status':    match.status.toUpperCase(),
      'kickoff':   match.matchTime,
    });
    AppLogger.d(_tag, 'sendMatch → ${match.homeTeam} vs ${match.awayTeam}');
    _service.publish(topicMatch, payload);
  }

  void sendPrediction(Prediction prediction) {
    final payload = jsonEncode({
      'matchLabel': prediction.matchLabel,
      'selection':  prediction.selection,
      'odds':       prediction.odds,
      'confidence': prediction.confidence,
      'comment':    prediction.comment,
    });
    AppLogger.d(_tag, 'sendPrediction → ${prediction.matchLabel}');
    _service.publish(topicPrediction, payload);
  }

  Stream<String> get deviceStatusStream => _msgCtrl.stream
      .where((m) => m.topic == topicStatus)
      .map((m) => _extractPayload(m));

  Stream<bool> get buttonEventStream => _msgCtrl.stream
      .where((m) => m.topic == topicButton)
      .map((_) => true);

  static String _extractPayload(MqttReceivedMessage<MqttMessage?> msg) {
    final pub = msg.payload as MqttPublishMessage;
    return MqttPublishPayload.bytesToStringAsString(pub.payload.message);
  }

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
    AppLogger.d(_tag, 'sendToDevice $deviceId → ${prediction.matchLabel}');
    _service.publish(topic, payload, retain: true);
  }

  void disconnect() => _service.disconnect();

  void dispose() {
    _updatesSub?.cancel();
    _msgCtrl.close();
  }
}
