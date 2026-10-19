import 'dart:async';
import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../core/logger/app_logger.dart';
import '../core/security/secure_vault_service.dart';

enum MqttState { disconnected, connecting, connected }

class MqttService {
  static const _tag = 'MQTT';

  MqttServerClient? _client;

  final _stateController = StreamController<MqttState>.broadcast();
  Stream<MqttState> get stateStream => _stateController.stream;

  MqttState _state = MqttState.disconnected;
  MqttState get state => _state;
  bool get isConnected => _state == MqttState.connected;

  Future<bool> connect() async {
    final host = dotenv.env['MQTT_HOST'] ?? '';
    final port = int.tryParse(dotenv.env['MQTT_PORT'] ?? '8883') ?? 8883;

    // Identifiants lus depuis le coffre en priorité, dotenv en repli.
    final user     = await SecureVaultService.read(SecureVaultService.kMqttUser)     ?? '';
    final password = await SecureVaultService.read(SecureVaultService.kMqttPassword) ?? '';

    if (host.isEmpty) return false;

    _client = MqttServerClient.withPort(host, 'MatiMatch_Flutter', port);
    _client!.secure = true;
    _client!.securityContext = SecurityContext.defaultContext;
    _client!.keepAlivePeriod = 30;
    _client!.autoReconnect = true;
    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onAutoReconnected = _onAutoReconnected;

    final conn = MqttConnectMessage()
        .withClientIdentifier('MatiMatch_Flutter')
        .authenticateAs(user, password)
        .startClean();
    _client!.connectionMessage = conn;

    _emitState(MqttState.connecting);

    try {
      await _client!.connect();
      AppLogger.d(_tag, 'connect() terminé — état: $_state');
      return isConnected;
    } catch (e) {
      AppLogger.e(_tag, 'Erreur de connexion', e);
      _emitState(MqttState.disconnected);
      return false;
    }
  }

  void subscribe(String topic, {MqttQos qos = MqttQos.atLeastOnce}) {
    _client?.subscribe(topic, qos);
  }

  void publish(String topic, String payload, {bool retain = false}) {
    if (!isConnected) return;
    try {
      final builder = MqttClientPayloadBuilder()..addString(payload);
      _client!.publishMessage(
        topic,
        MqttQos.atLeastOnce,
        builder.payload!,
        retain: retain,
      );
    } catch (e) {
      // Le client mqtt peut lever une ConnectionException si son état interne
      // est 'connecting' alors que notre flag _state vient juste de passer
      // à 'connected' (fenêtre de course avec autoReconnect).
      AppLogger.w(_tag, 'publish ignoré (état transitoire) : $e');
    }
  }

  Stream<List<MqttReceivedMessage<MqttMessage?>>>? get updates => _client?.updates;

  void disconnect() {
    _client?.disconnect();
    _client = null;
  }

  void dispose() {
    disconnect();
    _stateController.close();
  }

  void _onConnected()      => _emitState(MqttState.connected);
  void _onDisconnected()   => _emitState(MqttState.disconnected);
  void _onAutoReconnected() => _emitState(MqttState.connected);

  void _emitState(MqttState s) {
    _state = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }
}
