import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "../models/sensor_models.dart";
import "../services/energy.dart";
import "../services/solar_data_service.dart";
import "../theme.dart";
import "status_states.dart";

/// Daily energy used / generated and estimated cost.
///
/// Daily totals are aggregated on the server by the Cloud Function in
/// /functions (energy/daily/<date>). Until that is deployed, an estimate
/// from the most recent readings is shown instead.
class EnergyPanel extends StatelessWidget {
  final SolarDataService dataService;
  const EnergyPanel({super.key, required this.dataService});

  String _cost(double wh, double tariff) {
    if (tariff <= 0) return "set tariff";
    return "ZMW ${costZmw(wh, tariff).toStringAsFixed(2)}";
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppSettings>(
      stream: dataService.settings(),
      initialData: AppSettings.defaults,
      builder: (context, settingsSnap) {
        final tariff = settingsSnap.data?.tariffZmwPerKwh ?? 0;
        return StreamBuilder<List<DailyEnergy>>(
          stream: dataService.dailyEnergy(),
          builder: (context, snap) {
            final days = snap.data ?? [];
            return Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Energy & Cost", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (days.isEmpty) _fallback(tariff) else _daily(days, tariff),
                  if (tariff <= 0) ...[
                    const SizedBox(height: 10),
                    const Text(
                      "Enter your price per kWh in Settings to see estimated cost.",
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _fallback(double tariff) {
    return StreamBuilder<List<Reading>>(
      stream: dataService.history(),
      builder: (context, snap) {
        final history = snap.data ?? [];
        final totals = integrateEnergy(history);
        if (history.length < 2) {
          return const EmptyState(message: "Waiting for enough readings to estimate energy...");
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "No daily totals yet (deploy the Cloud Functions to enable them). "
              "Estimate from the most recent readings:",
              style: TextStyle(color: AppColors.warning, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(children: [
              _stat("Used", "${totals.usedWh.toStringAsFixed(1)} Wh"),
              _stat("Solar", "${totals.solarWh.toStringAsFixed(1)} Wh"),
              _stat("Cost", _cost(totals.usedWh, tariff)),
            ]),
          ],
        );
      },
    );
  }

  Widget _daily(List<DailyEnergy> days, double tariff) {
    final today = DateFormat("yyyy-MM-dd").format(DateTime.now());
    final latest = days.last;
    final isToday = latest.date == today;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isToday ? "Today" : "Latest day (${latest.date})",
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 6),
        Row(children: [
          _stat("Used", "${(latest.usedWh / 1000).toStringAsFixed(2)} kWh"),
          _stat("Solar", "${(latest.solarWh / 1000).toStringAsFixed(2)} kWh"),
          _stat("Cost", _cost(latest.usedWh, tariff)),
        ]),
        const SizedBox(height: 16),
        const Text("Energy used per day (kWh)", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
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
                      if (i < 0 || i >= days.length) return const SizedBox.shrink();
                      final d = days[i].date;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(d.length >= 10 ? d.substring(5) : d,
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: days.asMap().entries.map((e) {
                return BarChartGroupData(x: e.key, barRods: [
                  BarChartRodData(
                    toY: e.value.usedWh / 1000,
                    color: AppColors.accentIndigo,
                    width: 20,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
