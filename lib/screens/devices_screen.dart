
import "dart:async";

import "package:flutter/material.dart";

import "../models/sensor_models.dart";
import "../services/mqtt_service.dart";
import "../services/solar_data_service.dart";
import "../theme.dart";
import "../widgets/power_status_panel.dart";
import "../widgets/status_states.dart";

const _icons = {
  "ESP32 Controller": Icons.router_rounded,
  "Battery Voltage Sensor": Icons.battery_charging_full_rounded,
  "Battery Current Sensor": Icons.electric_bolt_rounded,
  "Temperature Sensor": Icons.thermostat_rounded,
  "Battery Monitor": Icons.battery_full_rounded,
};

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final _dataService = SolarDataService();
  final _mqttService = MqttService();

  StreamSubscription? _settingsSubscription;

  @override
  void initState() {
    super.initState();

    _settingsSubscription = _dataService.settings().listen((settings) {
      if (settings.mqttBrokerHost.isNotEmpty &&
          !_mqttService.isConnected) {
        _mqttService.connectFromSettings(settings);
      }
    });
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    _mqttService.dispose();
    super.dispose();
  }

  void _toggleChannel(int channel, bool on) {
    // Preserve both MQTT control and Firebase desired-state updates.
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

  String _valueFor(String deviceName, Reading? latest) {
    if (latest == null) return "--";

    switch (deviceName) {
      case "Battery Voltage Sensor":
        return "${latest.voltage.toStringAsFixed(1)} V";

      case "Battery Current Sensor":
        return "${latest.current.toStringAsFixed(1)} A";

      case "Temperature Sensor":
        return latest.hasTemperature
            ? "${latest.temperature.toStringAsFixed(0)}°C"
            : "No sensor";

      case "Battery Monitor":
        return "${latest.batteryPercent.toStringAsFixed(0)}%";

      default:
        return "—";
    }
  }

  String _unitFor(String deviceName) {
    switch (deviceName) {
      case "Battery Voltage Sensor":
        return "Battery voltage";
      case "Battery Current Sensor":
        return "Battery current";
      case "Temperature Sensor":
        return "System temperature";
      case "Battery Monitor":
        return "Estimated charge";
      case "ESP32 Controller":
        return "System controller";
      default:
        return "Sensor reading";
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataService = _dataService;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _DevicesHeader(
          onRefresh: () {
            setState(() {});
          },
        ),

        const SizedBox(height: 26),

        const _SectionHeading(
          title: "Connected hardware",
          subtitle: "Monitor the sensors and controller in your system.",
          icon: Icons.memory_rounded,
        ),

        const SizedBox(height: 16),

        StreamBuilder<Reading?>(
          stream: dataService.latestReading(),
          builder: (context, latestSnap) {
            return StreamBuilder<List<DeviceStatus>>(
              stream: dataService.devices(),
              builder: (context, devicesSnap) {
                final devices = devicesSnap.data ?? [];

                if (devices.isEmpty) {
                  return const Panel(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: EmptyState(
                        message: "No devices reporting yet.",
                      ),
                    ),
                  );
                }

                final onlineCount = devices
                    .where(
                      (device) =>
                          device.status == DeviceOnlineStatus.online,
                    )
                    .length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _SummaryChip(
                          icon: Icons.devices_rounded,
                          label: "${devices.length} devices",
                        ),
                        const SizedBox(width: 8),
                        _SummaryChip(
                          icon: Icons.check_circle_outline_rounded,
                          label: "$onlineCount online",
                          color: AppColors.online,
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns =
                            constraints.maxWidth >= 850 ? 3 :
                            constraints.maxWidth >= 540 ? 2 : 1;

                        final cardWidth =
                            (constraints.maxWidth -
                                    (columns - 1) * 12) /
                                columns;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: devices.map((device) {
                            return SizedBox(
                              width: cardWidth,
                              child: _DeviceCard(
                                name: device.name,
                                value: _valueFor(
                                  device.name,
                                  latestSnap.data,
                                ),
                                description: _unitFor(device.name),
                                icon: _icons[device.name] ??
                                    Icons.settings_input_component_rounded,
                                online: device.status ==
                                    DeviceOnlineStatus.online,
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                );
              },
            );
          },
        ),

        const SizedBox(height: 28),

        const _SectionHeading(
          title: "Power & circuit controls",
          subtitle: "Manage outputs and monitor electrical safety.",
          icon: Icons.electrical_services_rounded,
        ),

        const SizedBox(height: 16),

        StreamBuilder<PowerStatus?>(
          stream: dataService.powerStatus(),
          builder: (context, snap) {
            return PowerStatusPanel(
              status: snap.data,
              onToggleChannel: _toggleChannel,
              onResetSafety: _resetSafety,
            );
          },
        ),

        const SizedBox(height: 20),

        const _MonitoringInfoCard(),
      ],
    );
  }
}

class _DevicesHeader extends StatelessWidget {
  final VoidCallback onRefresh;

  const _DevicesHeader({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.panelBorder),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.panel,
            AppColors.accentIndigo.withOpacity(0.12),
          ],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "SYSTEM HARDWARE",
                  style: TextStyle(
                    color: AppColors.accentIndigoHover,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  "Devices & controls",
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Your sensors, controller, and power management "
                  "in one place.",
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: AppColors.accentIndigo.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.hub_rounded,
              color: AppColors.accentIndigoHover,
              size: 29,
            ),
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
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: AppColors.accentIndigo.withOpacity(0.13),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: AppColors.accentIndigoHover,
            size: 22,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _SummaryChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.accentIndigoHover;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.09),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: chipColor.withOpacity(0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: chipColor),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: chipColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final String name;
  final String value;
  final String description;
  final IconData icon;
  final bool online;

  const _DeviceCard({
    required this.name,
    required this.value,
    required this.description,
    required this.icon,
    required this.online,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor =
        online ? AppColors.online : AppColors.offline;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 6,
                      width: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      online ? "Online" : "Offline",
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            description,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            "Latest reported value",
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonitoringInfoCard extends StatelessWidget {
  const _MonitoringInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.accentIndigo.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.accentIndigo.withOpacity(0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: AppColors.accentIndigo.withOpacity(0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.accentIndigoHover,
              size: 23,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Per-appliance monitoring",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Tracking lights, fans, TVs, and fridges separately "
                  "requires a current sensor on each circuit. "
                  "Your system currently measures total voltage, "
                  "current, temperature, and battery level.",
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
