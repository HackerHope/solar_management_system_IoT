
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const _AnalyticsHeader(),
        const SizedBox(height: 28),

        const _SectionHeading(
          title: "Solar performance",
          subtitle: "Track your system's electrical output over time.",
          icon: Icons.solar_power_rounded,
        ),
        const SizedBox(height: 16),

        StreamBuilder<List<Reading>>(
          stream: dataService.history(),
          builder: (context, snap) {
            final history = snap.data ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SensorLineChart(data: history),
                const SizedBox(height: 16),
                PowerChart(data: history),
                if (snap.hasError) ...[
                  const SizedBox(height: 12),
                  const _Notice(
                    message: "Unable to load solar history. Check your connection.",
                    icon: Icons.cloud_off_rounded,
                  ),
                ],
              ],
            );
          },
        ),

        const SizedBox(height: 28),

        const _SectionHeading(
          title: "Energy overview",
          subtitle: "Review the energy information available for your system.",
          icon: Icons.bolt_rounded,
        ),
        const SizedBox(height: 16),
        EnergyPanel(dataService: dataService),

        const SizedBox(height: 28),

        const _SectionHeading(
          title: "Device usage",
          subtitle: "Explore estimated energy usage across your circuits.",
          icon: Icons.devices_other_rounded,
        ),
        const SizedBox(height: 16),

        StreamBuilder<List<CircuitsReading>?>(
          stream: dataService.circuitsHistory(),
          builder: (context, snap) {
            return _CircuitUsageChart(
              history: snap.data,
            );
          },
        ),
      ],
    );
  }
}

class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader();

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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "ANALYTICS & INSIGHTS",
                  style: TextStyle(
                    color: AppColors.accentIndigoHover,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Understand your energy.",
                  style: TextStyle(
                    fontSize: 25,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Explore solar output, energy trends, "
                  "and device usage in one place.",
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: AppColors.accentIndigo.withOpacity(0.16),
              borderRadius: BorderRadius.circular(19),
            ),
            child: const Icon(
              Icons.query_stats_rounded,
              size: 34,
              color: AppColors.accentIndigoHover,
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

class _Notice extends StatelessWidget {
  final String message;
  final IconData icon;

  const _Notice({
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
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

  List<Map<String, Object>> _summarize(
    List<CircuitsReading> history,
  ) {
    if (history.length < 2) return [];

    final totals = {
      "lights": 0.0,
      "fan": 0.0,
      "tv": 0.0,
      "fridge": 0.0,
    };

    for (var i = 1; i < history.length; i++) {
      final hours = (history[i].timestamp -
              history[i - 1].timestamp) /
          (1000 * 60 * 60);

      totals["lights"] =
          totals["lights"]! + (history[i].lights?.power ?? 0) * hours;
      totals["fan"] =
          totals["fan"]! + (history[i].fan?.power ?? 0) * hours;
      totals["tv"] =
          totals["tv"]! + (history[i].tv?.power ?? 0) * hours;
      totals["fridge"] =
          totals["fridge"]! + (history[i].fridge?.power ?? 0) * hours;
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
    final data = isSimulated
        ? _simulatedCircuits
        : _summarize(history!);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: AppColors.accentIndigo.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: AppColors.accentIndigoHover,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Circuit energy usage",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Estimated energy by device",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSimulated)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.25),
                    ),
                  ),
                  child: const Text(
                    "DEMO",
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
            ],
          ),

          if (isSimulated) ...[
            const SizedBox(height: 16),
            const _Notice(
              message:
                  "Showing sample values because per-circuit sensor "
                  "data is not connected yet.",
              icon: Icons.info_outline_rounded,
            ),
          ],

          const SizedBox(height: 22),

          if (data.isEmpty)
            const EmptyState(
              message:
                  "Waiting for enough circuit readings to estimate usage...",
            )
          else
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final device =
                            data[group.x]["device"] as String;

                        return BarTooltipItem(
                          "$device\n${rod.toY.toStringAsFixed(1)} Wh",
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      axisNameWidget: Text(
                        "Energy (Wh)",
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();

                          if (i < 0 || i >= data.length) {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              data[i]["device"] as String,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
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
                          width: 30,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(7),
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: data
                                .map((item) => item["total"] as double)
                                .reduce((a, b) => a > b ? a : b) *
                                1.15,
                            color: AppColors.panelBorder.withOpacity(0.25),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
                duration: const Duration(milliseconds: 350),
              ),
            ),

          const SizedBox(height: 18),
          const Divider(color: AppColors.panelBorder, height: 1),
          const SizedBox(height: 14),

          Row(
            children: [
              const Icon(
                Icons.insights_rounded,
                size: 17,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isSimulated
                      ? "Sample data · Replace with real circuit readings"
                      : "Calculated from recorded circuit power",
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
