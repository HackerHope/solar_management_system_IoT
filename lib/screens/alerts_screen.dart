import "package:flutter/material.dart";
import "../models/sensor_models.dart";
import "../services/solar_data_service.dart";
import "../theme.dart";
import "../widgets/alerts_panel.dart";

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = SolarDataService();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Alerts", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text("System warnings and notifications.", style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 16),
        StreamBuilder<List<AppAlert>>(
          stream: dataService.alerts(),
          builder: (context, snap) {
            final alerts = snap.data ?? [];
            return AlertsPanel(alerts: alerts, limit: alerts.length);
          },
        ),
      ],
    );
  }
}
