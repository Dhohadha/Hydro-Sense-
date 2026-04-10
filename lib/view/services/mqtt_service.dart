import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  late MqttServerClient _client;

  bool isConnected = false;

  // callback to UI
  void Function(Map<String, dynamic> data)? onDataReceived;

  Future<void> connect() async {
    final clientId = 'flutter_gf1_${DateTime.now().millisecondsSinceEpoch}';
    _client = MqttServerClient('broker.emqx.io', clientId);

    _client.port = 1883;
    _client.keepAlivePeriod = 20;
    _client.logging(on: false);

    _client.onConnected = () {
      debugPrint('✅ MQTT Connected');
      isConnected = true;
    };

    _client.onDisconnected = () {
      debugPrint('❌ MQTT Disconnected');
      isConnected = false;
    };

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);

    _client.connectionMessage = connMessage;

    try {
      await _client.connect();
    } catch (e) {
      debugPrint('❗ MQTT connection error: $e');
      _client.disconnect();
      return;
    }

    if (_client.connectionStatus!.state == MqttConnectionState.connected) {
      _client.subscribe('PMS/data', MqttQos.atMostOnce);

      _client.updates!.listen(
        (List<MqttReceivedMessage<MqttMessage>> messages) {
          if (messages.isEmpty) return;

          final recMess = messages[0].payload as MqttPublishMessage;

          final payload = MqttPublishPayload.bytesToStringAsString(
            recMess.payload.message,
          );

          debugPrint('📥 MQTT Received: $payload');

          try {
            final decoded = jsonDecode(payload);
            if (onDataReceived != null) {
              onDataReceived!(decoded);
            }
          } catch (e) {
            debugPrint('❗ Invalid JSON from MQTT: $e');
          }
        },
      );
    }
  }

  void publishCommand(Map<String, dynamic> data) {
    if (!isConnected) {
      debugPrint('⚠ MQTT not connected');
      return;
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(data));

    _client.publishMessage(
      'PMS/cmd',
      MqttQos.atMostOnce,
      builder.payload!,
    );

    debugPrint('📤 MQTT Published: $data');
  }

  void disconnect() {
    _client.disconnect();
  }
}
