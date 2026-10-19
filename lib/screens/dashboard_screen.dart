
import "dart:async";

import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../config.dart";
import "../models/sensor_models.dart";
import "../services/alert_thresholds.dart";
import "../services/mqtt_service.dart";
import "../services/solar_data_service.dart";
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

  static const Color _background = Color(0xFF0B1220);
  static const Color _surface = Color(0xFF151F30);
  static const Color _accent = Color(0xFFB7F36B);
  static const Color _muted = Color(0xFF9CAEC4);

  @override
  void initState() {
    super.initState();

    _settingsSub = _dataService.settings().listen((s) {
      if (!mounted) return;

      setState(() => _settings = s);

      if (s.mqttBrokerHost.isNotEmpty &&
          !_mqttService.isConnected) {
        _mqttService.connectFromSettings(s);
      }
    });

    // Preserve the existing client-side alert behavior.
    if (kClientSideAlerts) {
      _alertSub = _dataService.latestReading().listen((reading) {
        if (reading != null) {
          checkThresholds(reading, _settings, _dataService);
        }
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

  // Preserve MQTT control and Firebase desired-state synchronization.
  void _toggleChannel(int channel, bool on) {
    if (_mqttService.isConnected) {
      _mqttService.setChannel(channel, on);
    }

    _dataService.setChannel(channel, on);
  }

  // Preserve the existing safety-reset routing.
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

  String _voltageStatus(Reading r) =>
      r.voltage < _settings.lowVoltageV ? "Low" : "OK";

  String _currentStatus(Reading r) =>
      r.current.abs() < 0.1 ? "Idle" : "In use";

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
          // Kept unchanged: no refresh operation was implemented
          // in the original code.
          onRefresh: () async {},
          color: _accent,
          backgroundColor: _surface,
          child: Container(
            color: _background,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _DashboardHeader(
                  temperature: (latest != null && latest.hasTemperature)
                      ? latest.temperature
                      : null,
                  deviceName: _settings.deviceName,
                  timestampMs: latest?.timestamp,
                ),

                const SizedBox(height: 24),

                const _SectionHeading(
                  title: "Energy overview",
                  subtitle: "Your system at a glance",
                  icon: Icons.bolt_rounded,
                ),

                const SizedBox(height: 14),

                if (latest == null) ...[
                  const EmptyState(
                    message: "Waiting for sensor data from your ESP32...",
                  ),
                  const SizedBox(height: 16),
                ],

                // Keep the existing power status stream and sensor values.
                StreamBuilder<PowerStatus?>(
                  stream: _dataService.powerStatus(),
                  builder: (context, powerSnap) {
                    final power = powerSnap.data;

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final columns =
                            constraints.maxWidth >= 900 ? 4 : 2;

                        return GridView.count(
                          crossAxisCount: columns,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio:
                              constraints.maxWidth >= 900 ? 1.45 : 1.20,
                          children: [
                            StatCard(
                              icon: "🔋",
                              title: "Battery Level",
                              value: latest != null
                                  ? "${latest.batteryPercent.toStringAsFixed(0)}%"
                                  : "--",
                              status: latest != null
                                  ? _batteryStatusLabel(
                                      latest.batteryPercent,
                                    )
                                  : "No data",
                            ),
                            StatCard(
                              icon: "🔌",
                              title: "Battery Voltage",
                              value: latest != null
                                  ? "${latest.voltage.toStringAsFixed(1)} V"
                                  : "--",
                              status: latest != null
                                  ? _voltageStatus(latest)
                                  : "No data",
                            ),
                            StatCard(
                              icon: "⚡",
                              title: "Load Current",
                              value: latest != null
                                  ? "${latest.current.toStringAsFixed(1)} A"
                                  : "--",
                              status: latest != null
                                  ? _currentStatus(latest)
                                  : "No data",
                            ),
                            StatCard(
                              icon: "☀️",
                              title: "Solar Power",
                              value: power != null
                                  ? "${power.solarPower.toStringAsFixed(0)} W"
                                  : "--",
                              status: power == null
                                  ? "No data"
                                  : (power.solarPower > 1
                                      ? "Generating"
                                      : "No sun"),
                            ),
                            StatCard(
                              icon: "🌡️",
                              title: "Temperature",
                              value: (latest != null && latest.hasTemperature)
                                  ? "${latest.temperature.toStringAsFixed(0)}°C"
                                  : "N/A",
                              status: latest != null
                                  ? _temperatureStatus(latest)
                                  : "No data",
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 28),

                const _SectionHeading(
                  title: "Performance analytics",
                  subtitle: "Sensor readings and power trends",
                  icon: Icons.insights_rounded,
                ),

                const SizedBox(height: 14),

                StreamBuilder<List<Reading>>(
                  stream: _dataService.history(),
                  builder: (context, historySnap) {
                    final history = historySnap.data ?? [];

                    return Column(
                      children: [
                        SensorLineChart(data: history),
                        const SizedBox(height: 14),
                        PowerChart(data: history),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 28),

                const _SectionHeading(
                  title: "Alerts",
                  subtitle: "System notifications and warnings",
                  icon: Icons.notifications_active_outlined,
                ),

                const SizedBox(height: 14),

                StreamBuilder<List<AppAlert>>(
                  stream: _dataService.alerts(),
                  builder: (context, snap) {
                    return AlertsPanel(
                      alerts: snap.data ?? [],
                      limit: 3,
                    );
                  },
                ),

                const SizedBox(height: 28),

                const _SectionHeading(
                  title: "Connected devices",
                  subtitle: "Device availability and status",
                  icon: Icons.devices_rounded,
                ),

                const SizedBox(height: 14),

                StreamBuilder<List<DeviceStatus>>(
                  stream: _dataService.devices(),
                  builder: (context, snap) {
                    return DeviceStatusPanel(
                      devices: snap.data ?? [],
                    );
                  },
                ),

                const SizedBox(height: 28),

                const _SectionHeading(
                  title: "Power management",
                  subtitle: "Power source, safety and channel controls",
                  icon: Icons.tune_rounded,
                ),

                const SizedBox(height: 14),

                StreamBuilder<PowerStatus?>(
                  stream: _dataService.powerStatus(),
                  builder: (context, snap) {
                    return PowerStatusPanel(
                      status: snap.data,
                      onToggleChannel: _toggleChannel,
                      onResetSafety: _resetSafety,
                    );
                  },
                ),

                const SizedBox(height: 12),

                Center(
                  child: Text(
                    "Solar monitoring system",
                    style: TextStyle(
                      color: _muted.withOpacity(0.65),
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final double? temperature;
  final String deviceName;
  final int? timestampMs;

  const _DashboardHeader({
    required this.temperature,
    required this.deviceName,
    required this.timestampMs,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateFormat("EEEE, MMM d, yyyy").format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1C2B40),
            Color(0xFF111C2D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFB7F36B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.wb_sunny_rounded,
                  color: Color(0xFFB7F36B),
                  size: 27,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "SOLAR MONITOR",
                      style: TextStyle(
                        color: Color(0xFFB7F36B),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Energy overview",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.dashboard_rounded,
                      color: Color(0xFFB7F36B),
                      size: 14,
                    ),
                    SizedBox(width: 5),
                    Text(
                      "Dashboard",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Text(
            deviceName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 7),

          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                color: Color(0xFF9CAEC4),
                size: 13,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  today,
                  style: const TextStyle(
                    color: Color(0xFF9CAEC4),
                    fontSize: 11,
                  ),
                ),
              ),
              const Icon(
                Icons.thermostat_rounded,
                color: Color(0xFFB7F36B),
                size: 19,
              ),
              const SizedBox(width: 5),
              Text(
                temperature != null
                    ? "${temperature!.toStringAsFixed(0)}°C"
                    : "--°C",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            height: 1,
            color: Colors.white.withOpacity(0.08),
          ),

          const SizedBox(height: 13),

          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: Color(0xFF9CAEC4),
                size: 16,
              ),
              const SizedBox(width: 7),
              const Text(
                "Latest sensor reading",
                style: TextStyle(
                  color: Color(0xFF9CAEC4),
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: DataAge(timestampMs: timestampMs),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionHeading({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFB7F36B).withOpacity(0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFB7F36B),
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF9CAEC4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
