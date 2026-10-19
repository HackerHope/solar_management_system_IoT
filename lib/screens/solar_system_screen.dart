import "package:flutter/material.dart";
import "../config.dart";
import "../models/sensor_models.dart";
import "../services/solar_data_service.dart";
import "../theme.dart";
import "../widgets/periodic_rebuild.dart";
import "../widgets/status_states.dart";

class SolarSystemScreen extends StatelessWidget {
  const SolarSystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = SolarDataService();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "Solar System Devices",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          "Connection overview of your solar system.",
          style: TextStyle(color: AppColors.textMuted),
        ),
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
                    final connected =
                        (devicesSnap.data ?? []).isNotEmpty &&
                        devicesSnap.data!.every(
                          (d) => d.status == DeviceOnlineStatus.online,
                        );
                    final latest = readingSnap.data;
                    final power = powerSnap.data;

                    return PeriodicRebuild(
                      builder: (_) {
                        final now = DateTime.now().millisecondsSinceEpoch;
                        final readingAge = latest == null
                            ? null
                            : now - latest.timestamp;
                        final readingFresh =
                            readingAge != null &&
                            readingAge >= 0 &&
                            readingAge < kDeviceStaleMs;
                        final powerAge = power?.timestamp == null
                            ? null
                            : now - power!.timestamp!;
                        final powerFresh =
                            powerAge != null &&
                            powerAge >= 0 &&
                            powerAge < kDeviceStaleMs;

                        final solarValue = powerFresh
                            ? "${power!.solarVoltage.toStringAsFixed(1)} V / ${power.solarCurrent.toStringAsFixed(1)} A"
                            : "--";
                        final batteryValue = readingFresh
                            ? "${latest!.voltage.toStringAsFixed(1)} V  •  ${latest.batteryPercent.toStringAsFixed(0)}%"
                            : "--";
                        final loadValue = powerFresh
                            ? "Ch1 ${power!.channel1 ? "ON" : "OFF"}  •  Ch2 ${power.channel2 ? "ON" : "OFF"}"
                            : "--";

                        return Column(
                          children: [
                            _deviceCard(
                              "☀️",
                              "Solar Panel",
                              solarValue,
                              powerFresh ? connected : null,
                              neutralStatusLabel: powerFresh
                                  ? null
                                  : "No recent data",
                            ),
                            // No sensor on the charge controller itself in this prototype
                            _deviceCard(
                              "⚡",
                              "Charge Controller",
                              "Not monitored",
                              null,
                              neutralStatusLabel: "Not monitored",
                            ),
                            _deviceCard(
                              "🔋",
                              "Battery Monitor",
                              batteryValue,
                              readingFresh ? connected : null,
                              neutralStatusLabel: readingFresh
                                  ? null
                                  : "No recent data",
                            ),
                            _deviceCard(
                              "💡",
                              "Load Controller",
                              loadValue,
                              powerFresh ? connected : null,
                              neutralStatusLabel: powerFresh
                                  ? null
                                  : "No recent data",
                            ),
                          ],
                        );
                      },
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
  Widget _deviceCard(
    String icon,
    String name,
    String value,
    bool? status, {
    String? neutralStatusLabel,
  }) {
    final statusLabel = status == null
        ? neutralStatusLabel ?? "Not wired"
        : (status ? "Online" : "Offline");
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
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              statusLabel,
              style: TextStyle(color: statusColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
