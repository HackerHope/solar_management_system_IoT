import "dart:async";
import "package:mqtt_client/mqtt_client.dart";
import "package:mqtt_client/mqtt_server_client.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../models/sensor_models.dart";
import "system_manager.dart";

enum MqttConnState { disconnected, connecting, connected, error }

// Local-network control path, alongside Firebase (not instead of it).
// Mirrors the same systems/<systemId>/... topic layout the firmware
// publishes to, so switching systems just resubscribes to new topics.
class MqttService {
  MqttServerClient? _client;
  final _stateController = StreamController<MqttConnState>.broadcast();
  Stream<MqttConnState> get connectionState => _stateController.stream;
  MqttConnState _state = MqttConnState.disconnected;

  String _topic(String suffix) => "systems/${SystemManager.instance.currentSystemId}/$suffix";

  // MQTT username/password are stored on THIS device only (not synced to
  // Firebase), so they are never readable by other accounts.
  static const _userKey = "mqtt_username";
  static const _passKey = "mqtt_password";

  static Future<({String username, String password})> loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return (username: prefs.getString(_userKey) ?? "", password: prefs.getString(_passKey) ?? "");
  }

  static Future<void> saveCredentials(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, username);
    await prefs.setString(_passKey, password);
  }

  /// Connects using the broker settings saved for the system plus the local credentials.
  Future<bool> connectFromSettings(AppSettings s) async {
    final creds = await loadCredentials();
    return connect(
      s.mqttBrokerHost,
      s.mqttBrokerPort,
      secure: s.mqttUseTls,
      username: creds.username,
      password: creds.password,
    );
  }

  Future<bool> connect(
    String host,
    int port, {
    bool secure = false,
    String username = "",
    String password = "",
  }) async {
    if (host.isEmpty) return false;
    _setState(MqttConnState.connecting);

    final client = MqttServerClient.withPort(
      host,
      "solar_iot_app_${DateTime.now().millisecondsSinceEpoch}",
      port,
    );
    client.logging(on: false);
    client.keepAlivePeriod = 20;
    client.secure = secure; // TLS - use with port 8883 and a broker certificate
    client.onDisconnected = () => _setState(MqttConnState.disconnected);
    client.onConnected = () => _setState(MqttConnState.connected);
    var message = MqttConnectMessage().withClientIdentifier(client.clientIdentifier);
    if (username.isNotEmpty) {
      message = message.authenticateAs(username, password);
    }
    client.connectionMessage = message.startClean();

    try {
      await client.connect();
    } catch (_) {
      client.disconnect();
      _setState(MqttConnState.error);
      return false;
    }

    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      _setState(MqttConnState.error);
      return false;
    }

    _client = client;
    _setState(MqttConnState.connected);
    return true;
  }

  void disconnect() {
    _client?.disconnect();
    _client = null;
    _setState(MqttConnState.disconnected);
  }

  void _setState(MqttConnState s) {
    _state = s;
    _stateController.add(s);
  }

  bool get isConnected => _state == MqttConnState.connected && _client != null;

  void _publish(String suffix, String payload) {
    final client = _client;
    if (client == null || client.connectionStatus?.state != MqttConnectionState.connected) return;
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    client.publishMessage(_topic(suffix), MqttQos.atLeastOnce, builder.payload!);
  }

  void setChannel(int channel, bool on) => _publish("control/channel$channel", on ? "1" : "0");
  void resetSafety() => _publish("control/resetSafety", "1");

  // Live readings pushed by the firmware over MQTT (lower latency than
  // Firebase on the same network). Returns raw JSON strings; caller parses.
  Stream<String> readings() {
    final client = _client;
    if (client == null) return const Stream.empty();
    client.subscribe(_topic("readings"), MqttQos.atMostOnce);
    return client.updates!
        .where((events) => events.isNotEmpty)
        .map((events) {
          final recMess = events[0].payload as MqttPublishMessage;
          return MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        });
  }

  void dispose() {
    disconnect();
    _stateController.close();
  }
}
