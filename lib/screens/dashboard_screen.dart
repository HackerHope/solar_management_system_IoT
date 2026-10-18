import "dart:async";
import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "../config.dart";
import "../models/sensor_models.dart";
import "../services/alert_thresholds.dart";
import "../services/mqtt_service.dart";
import "../services/solar_data_service.dart";
import "../theme.dart";
import "../widgets/alerts_panel.dart";
import "../widgets/data_age.dart";
import "../widgets/device_status_panel.dart";
import "../widgets/power_chart.dart";
import "../widgets/power_status_panel.dart";
import "../widgets/sensor_line_chart.dart";
import "../widgets/stat_card.dart";
import "../widgets/status_states.dart";

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _dataService = SolarDataService();
  final _mqttService = MqttService();
  AppSettings _settings = AppSettings.defaults;
  StreamSubscription<AppSettings>? _settingsSub;
  StreamSubscription<Reading?>? _alertSub;

  @override
  void initState() {
    super.initState();
    _settingsSub = _dataService.settings().listen((s) {
      if (!mounted) return;
      setState(() => _settings = s);
      if (s.mqttBrokerHost.isNotEmpty && !_mqttService.isConnected) {
        _mqttService.connectFromSettings(s);
      }
    });
    // Side effect (writing alerts) belongs in a subscription, not build().
    // Skipped when the Cloud Functions raise alerts instead (see config.dart).
    if (kClientSideAlerts) {
      _alertSub = _dataService.latestReading().listen((reading) {
        if (reading != null) checkThresholds(reading, _settings, _dataService);
      });
    }
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    _alertSub?.cancel();
    _mqttService.dispose();
    super.dispose();
  }

  // Control commands go over MQTT when connected (faster, local network),
  // falling back to Firebase otherwise (works from anywhere).
  // The command is ALSO written to Firebase so the stored "desired state"
  // matches what the device was told; otherwise the device's periodic
  // Firebase check would switch the relay back.
  void _toggleChannel(int channel, bool on) {
    if (_mqttService.isConnected) {
      _mqttService.setChannel(channel, on);
    }
    _dataService.setChannel(channel, on);
  }

  void _resetSafety() {
    if (_mqttService.isConnected) {
      _mqttService.resetSafety();
    } else {
      _dataService.resetSafety();
    }
  }

  String _batteryStatusLabel(double pct) {
    if (pct < _settings.batteryLowPct) return "Low";
    if (pct < 50) return "Fair";
    return "Healthy";
  }

  String _voltageStatus(Reading r) => r.voltage < _settings.lowVoltageV ? "Low" : "OK";

  String _currentStatus(Reading r) => r.current.abs() < 0.1 ? "Idle" : "In use";

  String _temperatureStatus(Reading r) {
    if (!r.hasTemperature) return "No sensor";
    return r.temperature > _settings.tempLimitC ? "High" : "Normal";
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Reading?>(
      stream: _dataService.latestReading(),
      builder: (context, latestSnap) {
        final latest = latestSnap.data;

        return RefreshIndicator(
          onRefresh: () async {},
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _TopBar(
                temperature: (latest != null && latest.hasTemperature) ? latest.temperature : null,
                deviceName: _settings.deviceName,
                timestampMs: latest?.timestamp,
              ),
              const SizedBox(height: 16),
              if (latest == null)
                const EmptyState(message: "Waiting for sensor data from your ESP32..."),

              StreamBuilder<PowerStatus?>(
                stream: _dataService.powerStatus(),
                builder: (context, powerSnap) {
                  final power = powerSnap.data;
                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      StatCard(
                        icon: "🔋",
                        title: "Battery Level",
                        value: latest != null ? "${latest.batteryPercent.toStringAsFixed(0)}%" : "--",
                        status: latest != null ? _batteryStatusLabel(latest.batteryPercent) : "No data",
                      ),
                      StatCard(
                        icon: "🔌",
                        title: "Battery Voltage",
                        value: latest != null ? "${latest.voltage.toStringAsFixed(1)} V" : "--",
                        status: latest != null ? _voltageStatus(latest) : "No data",
                      ),
                      StatCard(
                        icon: "⚡",
                        title: "Load Current",
                        value: latest != null ? "${latest.current.toStringAsFixed(1)} A" : "--",
                        status: latest != null ? _currentStatus(latest) : "No data",
                      ),
                      StatCard(
                        icon: "☀️",
                        title: "Solar Power",
                        value: power != null ? "${power.solarPower.toStringAsFixed(0)} W" : "--",
                        status: power == null
                            ? "No data"
                            : (power.solarPower > 1 ? "Generating" : "No sun"),
                      ),
                      StatCard(
                        icon: "🌡️",
                        title: "Temperature",
                        value: (latest != null && latest.hasTemperature)
                            ? "${latest.temperature.toStringAsFixed(0)}°C"
                            : "N/A",
                        status: latest != null ? _temperatureStatus(latest) : "No data",
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              StreamBuilder<List<Reading>>(
                stream: _dataService.history(),
                builder: (context, historySnap) {
                  final history = historySnap.data ?? [];
                  return Column(
                    children: [
                      SensorLineChart(data: history),
                      const SizedBox(height: 16),
                      PowerChart(data: history),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              StreamBuilder<List<AppAlert>>(
                stream: _dataService.alerts(),
                builder: (context, snap) => AlertsPanel(alerts: snap.data ?? [], limit: 3),
              ),
              const SizedBox(height: 16),

              StreamBuilder<List<DeviceStatus>>(
                stream: _dataService.devices(),
                builder: (context, snap) => DeviceStatusPanel(devices: snap.data ?? []),
              ),
              const SizedBox(height: 16),

              StreamBuilder<PowerStatus?>(
                stream: _dataService.powerStatus(),
                builder: (context, snap) => PowerStatusPanel(
                  status: snap.data,
                  onToggleChannel: _toggleChannel,
                  onResetSafety: _resetSafety,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  final double? temperature;
  final String deviceName;
  final int? timestampMs;
  const _TopBar({this.temperature, required this.deviceName, this.timestampMs});

  @override
  Widget build(BuildContext context) {
    final today = DateFormat("MMMM d, yyyy").format(DateTime.now());
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Dashboard", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              Text(deviceName, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              DataAge(timestampMs: timestampMs),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF111C30),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(today, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              Text(
                temperature != null ? "${temperature!.toStringAsFixed(0)}°C" : "--°C",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}