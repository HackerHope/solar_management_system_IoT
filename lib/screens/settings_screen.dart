import "dart:async";
import "package:flutter/material.dart";
import "../models/sensor_models.dart";
import "../services/mqtt_service.dart";
import "../services/solar_data_service.dart";
import "../services/system_manager.dart";
import "../theme.dart";
import "../widgets/device_setup_panel.dart";
import "../widgets/periodic_rebuild.dart";
import "../widgets/status_states.dart";

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _dataService = SolarDataService();
  final _mqttService = MqttService();
  AppSettings? _settings;
  bool _saving = false;
  DateTime? _savedAt;

  final _nameController = TextEditingController();
  final _tempController = TextEditingController();
  final _batteryController = TextEditingController();
  final _intervalController = TextEditingController();
  final _mqttHostController = TextEditingController();
  final _mqttPortController = TextEditingController();
  final _mqttUserController = TextEditingController();
  final _mqttPassController = TextEditingController();
  final _lowVoltController = TextEditingController();
  final _shedController = TextEditingController();
  final _restoreController = TextEditingController();
  final _tariffController = TextEditingController();
  StreamSubscription<AppSettings>? _settingsSub;
  bool _mqttTls = false;
  bool _autoLoad = false;

  @override
  void initState() {
    super.initState();
    _settingsSub = _dataService.settings().listen((s) {
      if (!mounted) return;
      setState(() {
        _settings = s;
        _nameController.text = s.deviceName;
        _tempController.text = s.tempLimitC.toStringAsFixed(0);
        _batteryController.text = s.batteryLowPct.toStringAsFixed(0);
        _intervalController.text = s.readingIntervalSec.toStringAsFixed(0);
        _mqttHostController.text = s.mqttBrokerHost;
        _mqttPortController.text = s.mqttBrokerPort.toString();
        _mqttTls = s.mqttUseTls;
        _lowVoltController.text = s.lowVoltageV.toStringAsFixed(1);
        _autoLoad = s.autoLoadControl;
        _shedController.text = s.shedBelowPct.toStringAsFixed(0);
        _restoreController.text = s.restoreAbovePct.toStringAsFixed(0);
        _tariffController.text = s.tariffZmwPerKwh == 0 ? "" : s.tariffZmwPerKwh.toString();
      });
    });
    // MQTT username/password live on this device only (never synced to Firebase)
    MqttService.loadCredentials().then((c) {
      if (!mounted) return;
      _mqttUserController.text = c.username;
      _mqttPassController.text = c.password;
    });
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    _nameController.dispose();
    _tempController.dispose();
    _batteryController.dispose();
    _intervalController.dispose();
    _mqttHostController.dispose();
    _mqttPortController.dispose();
    _mqttUserController.dispose();
    _mqttPassController.dispose();
    _lowVoltController.dispose();
    _shedController.dispose();
    _restoreController.dispose();
    _tariffController.dispose();
    _mqttService.dispose();
    super.dispose();
  }

  Future<void> _handleTestMqtt() async {
    final ok = await _mqttService.connect(
      _mqttHostController.text.trim(),
      int.tryParse(_mqttPortController.text) ?? 1883,
      secure: _mqttTls,
      username: _mqttUserController.text.trim(),
      password: _mqttPassController.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? "Connected to broker" : "Could not connect to broker")),
    );
  }

  Future<void> _handleSave() async {
    setState(() => _saving = true);
    try {
      final updated = AppSettings(
        deviceName: _nameController.text.trim().isEmpty
            ? AppSettings.defaults.deviceName
            : _nameController.text.trim(),
        tempLimitC: double.tryParse(_tempController.text) ?? AppSettings.defaults.tempLimitC,
        batteryLowPct: double.tryParse(_batteryController.text) ?? AppSettings.defaults.batteryLowPct,
        readingIntervalSec:
            double.tryParse(_intervalController.text) ?? AppSettings.defaults.readingIntervalSec,
        mqttBrokerHost: _mqttHostController.text.trim(),
        mqttBrokerPort: int.tryParse(_mqttPortController.text) ?? AppSettings.defaults.mqttBrokerPort,
        mqttUseTls: _mqttTls,
        lowVoltageV: double.tryParse(_lowVoltController.text) ?? AppSettings.defaults.lowVoltageV,
        autoLoadControl: _autoLoad,
        shedBelowPct: double.tryParse(_shedController.text) ?? AppSettings.defaults.shedBelowPct,
        restoreAbovePct:
            double.tryParse(_restoreController.text) ?? AppSettings.defaults.restoreAbovePct,
        tariffZmwPerKwh: double.tryParse(_tariffController.text) ?? 0,
      );
      // Keep the shed/restore pair sensible: restore level must be above the shed level
      if (updated.autoLoadControl && updated.restoreAbovePct <= updated.shedBelowPct) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Restore level must be higher than the shed level.")));
        }
        return;
      }
      await MqttService.saveCredentials(_mqttUserController.text.trim(), _mqttPassController.text);
      await _dataService.saveSettings(updated);
      setState(() => _savedAt = DateTime.now());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_settings == null) {
      return const LoadingState(label: "Loading settings...");
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Settings", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text("Configure system preferences.", style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 16),

        StreamBuilder<int?>(
          stream: _dataService.lastSeenRaw(),
          builder: (context, snap) => PeriodicRebuild(
            builder: (_) => DeviceSetupPanel(
              lastSeenMs: snap.data,
              deviceName: _settings?.deviceName ?? AppSettings.defaults.deviceName,
              systemId: SystemManager.instance.currentSystemId,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _settingField("Device Name", _nameController, keyboardType: TextInputType.text),
        const SizedBox(height: 20),

        const Text("MQTT (local network control)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        const Text(
          "Optional. Used alongside Firebase for faster control when your "
          "phone is on the same network as the ESP32 and broker.",
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        _settingField("Broker Host / IP", _mqttHostController, keyboardType: TextInputType.text),
        const SizedBox(height: 12),
        _settingField("Broker Port", _mqttPortController, keyboardType: TextInputType.number),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Use TLS (encrypted)"),
          subtitle: const Text("Needs a broker with TLS, usually port 8883",
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          value: _mqttTls,
          onChanged: (v) => setState(() => _mqttTls = v),
        ),
        _settingField("Broker Username (optional, stored on this phone only)", _mqttUserController,
            keyboardType: TextInputType.text),
        const SizedBox(height: 12),
        _settingField("Broker Password (optional, stored on this phone only)", _mqttPassController,
            keyboardType: TextInputType.text, obscure: true),
        const SizedBox(height: 12),
        StreamBuilder<MqttConnState>(
          stream: _mqttService.connectionState,
          initialData: MqttConnState.disconnected,
          builder: (context, snap) {
            final state = snap.data ?? MqttConnState.disconnected;
            final label = switch (state) {
              MqttConnState.connected => "Connected",
              MqttConnState.connecting => "Connecting...",
              MqttConnState.error => "Connection failed",
              MqttConnState.disconnected => "Not connected",
            };
            final color = state == MqttConnState.connected ? AppColors.online : AppColors.textMuted;
            return Row(
              children: [
                Expanded(child: Text(label, style: TextStyle(color: color))),
                OutlinedButton(onPressed: _handleTestMqtt, child: const Text("Test Connection")),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        const Text("Alert & Reporting Preferences", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),

        _settingField("Temperature Limit (°C)", _tempController),
        const SizedBox(height: 12),
        _settingField("Battery Low Alert (%)", _batteryController),
        const SizedBox(height: 12),
        _settingField("Low Battery Voltage Alert (V)", _lowVoltController),
        const SizedBox(height: 12),
        _settingField("Reading Interval (seconds)", _intervalController),
        const SizedBox(height: 20),

        const Text("Automatic Load Control", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        const Text(
          "Runs on the device. When on mains failure the battery falls below the shed level, "
          "Channel 2 (the non-essential appliance) is switched off, then switched back on once "
          "the battery recovers above the restore level or mains power returns. "
          "Channel 1 is never switched automatically.",
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Enable automatic load control"),
          value: _autoLoad,
          onChanged: (v) => setState(() => _autoLoad = v),
        ),
        _settingField("Shed Channel 2 below battery (%)", _shedController),
        const SizedBox(height: 12),
        _settingField("Restore Channel 2 above battery (%)", _restoreController),
        const SizedBox(height: 20),

        const Text("Energy Cost", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        const Text(
          "Enter your electricity price per kWh (from your ZESCO bill or tariff) to see "
          "estimated cost in Analytics. Leave empty to hide cost.",
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        _settingField("Tariff (ZMW per kWh)", _tariffController),
        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: _saving ? null : _handleSave,
          child: Text(_saving ? "Saving..." : "Save Settings"),
        ),
        if (_savedAt != null) ...[
          const SizedBox(height: 10),
          Text(
            "Saved at ${_savedAt!.hour.toString().padLeft(2, '0')}:${_savedAt!.minute.toString().padLeft(2, '0')}",
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _settingField(String label, TextEditingController controller,
      {TextInputType keyboardType = const TextInputType.numberWithOptions(decimal: true),
      bool obscure = false}) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscure,
          ),
        ],
      ),
    );
  }
}
