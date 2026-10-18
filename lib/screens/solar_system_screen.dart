import "package:flutter/material.dart";
import "../models/sensor_models.dart";
import "../services/solar_data_service.dart";
import "../theme.dart";
import "../widgets/status_states.dart";

class SolarSystemScreen extends StatelessWidget {
  const SolarSystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = SolarDataService();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Solar System Devices", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text("Connection overview of your solar system.", style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 16),
        StreamBuilder<Reading?>(
          stream: dataService.latestReading(),
          builder: (context, readingSnap) {
            return StreamBuilder<PowerStatus?>(
              stream: dataService.powerStatus(),
              builder: (context, powerSnap) {
                return StreamBuilder<List<DeviceStatus>>(
                  stream: dataService.devices(),
                  builder: (context, devicesSnap) {
                    final connected = (devicesSnap.data ?? []).isNotEmpty &&
                        devicesSnap.data!.every((d) => d.status == DeviceOnlineStatus.online);
                    final latest = readingSnap.data;
                    final power = powerSnap.data;

                    // Solar-side numbers come from the power status; the main
                    // reading is the battery side.
                    final solarValue = power != null
                        ? "${power.solarVoltage.toStringAsFixed(1)} V / ${power.solarCurrent.toStringAsFixed(1)} A"
                        : "--";
                    final batteryValue = latest != null
                        ? "${latest.voltage.toStringAsFixed(1)} V  •  ${latest.batteryPercent.toStringAsFixed(0)}%"
                        : "--";
                    final loadValue = power != null
                        ? "Ch1 ${power.channel1 ? "ON" : "OFF"}  •  Ch2 ${power.channel2 ? "ON" : "OFF"}"
                        : "--";
                    final tempValue = latest == null
                        ? "--"
                        : (latest.hasTemperature ? "${latest.temperature.toStringAsFixed(0)}°C" : "No sensor");

                    return Column(
                      children: [
                        _deviceCard("☀️", "Solar Panel", solarValue, connected),
                        // No sensor on the charge controller itself in this prototype
                        _deviceCard("⚡", "Charge Controller", "Not monitored", null),
                        _deviceCard("🔋", "Battery Monitor", batteryValue, connected),
                        _deviceCard("🌡️", "Temperature Sensor", tempValue,
                            (latest != null && !latest.hasTemperature) ? null : connected),
                        _deviceCard("💡", "Load Controller", loadValue, power == null ? null : connected),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  // status: true = online, false = offline, null = not wired / not monitored (neutral color)
  Widget _deviceCard(String icon, String name, String value, bool? status) {
    final statusLabel = status == null ? "Not wired" : (status ? "Online" : "Offline");
    final statusColor = status == null
        ? AppColors.textMuted
        : (status ? AppColors.online : AppColors.offline);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
