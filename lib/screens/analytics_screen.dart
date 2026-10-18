import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";
import "../models/sensor_models.dart";
import "../services/solar_data_service.dart";
import "../theme.dart";
import "../widgets/energy_panel.dart";
import "../widgets/power_chart.dart";
import "../widgets/sensor_line_chart.dart";
import "../widgets/status_states.dart";

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = SolarDataService();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Analytics", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text("Study voltage, current, and power trends.", style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 16),

        const Text("Solar Output Data", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        StreamBuilder<List<Reading>>(
          stream: dataService.history(),
          builder: (context, snap) {
            final history = snap.data ?? [];
            return Column(
              children: [
                SensorLineChart(data: history),
                const SizedBox(height: 16),
                PowerChart(data: history),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        EnergyPanel(dataService: dataService),
        const SizedBox(height: 20),

        const Text("Device Usage Data", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        StreamBuilder<List<CircuitsReading>?>(
          stream: dataService.circuitsHistory(),
          builder: (context, snap) {
            final circuitHistory = snap.data; // null = not wired up yet
            return _CircuitUsageChart(history: circuitHistory);
          },
        ),
      ],
    );
  }
}

const _simulatedCircuits = [
  {"device": "Lights", "total": 300.0},
  {"device": "Fan", "total": 650.0},
  {"device": "TV", "total": 900.0},
  {"device": "Fridge", "total": 1200.0},
];

class _CircuitUsageChart extends StatelessWidget {
  final List<CircuitsReading>? history;
  const _CircuitUsageChart({required this.history});

  List<Map<String, Object>> _summarize(List<CircuitsReading> history) {
    if (history.length < 2) return [];
    final totals = {"lights": 0.0, "fan": 0.0, "tv": 0.0, "fridge": 0.0};
    for (var i = 1; i < history.length; i++) {
      final hours = (history[i].timestamp - history[i - 1].timestamp) / (1000 * 60 * 60);
      totals["lights"] = totals["lights"]! + (history[i].lights?.power ?? 0) * hours;
      totals["fan"] = totals["fan"]! + (history[i].fan?.power ?? 0) * hours;
      totals["tv"] = totals["tv"]! + (history[i].tv?.power ?? 0) * hours;
      totals["fridge"] = totals["fridge"]! + (history[i].fridge?.power ?? 0) * hours;
    }
    return [
      {"device": "Lights", "total": totals["lights"]!},
      {"device": "Fan", "total": totals["fan"]!},
      {"device": "TV", "total": totals["tv"]!},
      {"device": "Fridge", "total": totals["fridge"]!},
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isSimulated = history == null;
    final data = isSimulated ? _simulatedCircuits : _summarize(history!);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text("Total Device Power Usage",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (isSimulated) ...[
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "(simulated - no per-circuit sensors wired up yet)",
                    style: TextStyle(fontSize: 11, color: AppColors.warning),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (data.isEmpty)
            const EmptyState(message: "Waiting for enough circuit readings to estimate usage...")
          else
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= data.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(data[i]["device"] as String,
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: data.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value["total"] as double,
                          color: AppColors.accentIndigo,
                          width: 28,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
