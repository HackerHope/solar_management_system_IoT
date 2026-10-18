import "package:flutter/material.dart";
import "../models/sensor_models.dart";
import "../theme.dart";
import "status_states.dart";

String _iconFor(AlertLevel level) {
  switch (level) {
    case AlertLevel.warning:
      return "⚠️";
    case AlertLevel.error:
      return "🔴";
    case AlertLevel.info:
      return "ℹ️";
  }
}

class AlertsPanel extends StatelessWidget {
  final List<AppAlert> alerts;
  final int limit;
  const AlertsPanel({super.key, required this.alerts, this.limit = 3});

  @override
  Widget build(BuildContext context) {
    final shown = alerts.take(limit).toList();

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Recent Alerts", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            const EmptyState(message: "No alerts. All systems normal.")
          else
            ...shown.map((alert) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_iconFor(alert.level), style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(alert.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(alert.message,
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
