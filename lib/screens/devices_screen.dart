import "package:flutter/material.dart";
import "../models/sensor_models.dart";
import "../services/mqtt_service.dart";
import "../services/solar_data_service.dart";
import "../theme.dart";
import "../widgets/power_status_panel.dart";
import "../widgets/status_states.dart";

const _icons = {
  "ESP32 Controller": "📡",
  "Battery Voltage Sensor": "🔌",
  "Battery Current Sensor": "⚡",
  "Temperature Sensor": "🌡️",
  "Battery Monitor": "🔋",
};

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final _dataService = SolarDataService();
  final _mqttService = MqttService();

  @override
  void initState() {
    super.initState();
    _dataService.settings().listen((s) {
      if (s.mqttBrokerHost.isNotEmpty && !_mqttService.isConnected) {
        _mqttService.connectFromSettings(s);
      }
    });
  }

  @override
  void dispose() {
    _mqttService.dispose();
    super.dispose();
  }

  void _toggleChannel(int channel, bool on) {
    // Also written to Firebase so the stored desired state matches (see dashboard_screen.dart).
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
        return latest.hasTemperature ? "${latest.temperature.toStringAsFixed(0)}°C" : "No sensor";
      case "Battery Monitor":
        return "${latest.batteryPercent.toStringAsFixed(0)}%";
      default:
        return "—";
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataService = _dataService;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Solar System Devices", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text("Live status of every sensor reporting from your ESP32.",
            style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 16),

        StreamBuilder<Reading?>(
          stream: dataService.latestReading(),
          builder: (context, latestSnap) {
            return StreamBuilder<List<DeviceStatus>>(
              stream: dataService.devices(),
              builder: (context, devicesSnap) {
                final devices = devicesSnap.data ?? [];
                if (devices.isEmpty) return const EmptyState(message: "No devices reporting yet.");

                return Column(
                  children: devices
                      .map((d) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Panel(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(_icons[d.name] ?? "🔧", style: const TextStyle(fontSize: 20)),
                                      const SizedBox(width: 10),
                                      Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(_valueFor(d.name, latestSnap.data),
                                          style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text(
                                        d.status == DeviceOnlineStatus.online ? "Online" : "Offline",
                                        style: TextStyle(
                                          color: d.status == DeviceOnlineStatus.online
                                              ? AppColors.online
                                              : AppColors.offline,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                );
              },
            );
          },
        ),

        const SizedBox(height: 16),
        StreamBuilder<PowerStatus?>(
          stream: dataService.powerStatus(),
          builder: (context, snap) => PowerStatusPanel(
            status: snap.data,
            onToggleChannel: _toggleChannel,
            onResetSafety: _resetSafety,
          ),
        ),

        const SizedBox(height: 8),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text("Per-appliance monitoring", style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(
                "Breaking usage down by individual appliance (lights, fan, TV, fridge) "
                "needs a current sensor on each circuit. Right now this system measures "
                "total system voltage, current, temperature and battery.",
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}