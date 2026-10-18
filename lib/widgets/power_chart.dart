import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";
import "../models/sensor_models.dart";
import "../theme.dart";
import "status_states.dart";

class PowerChart extends StatelessWidget {
  final List<Reading> data;
  const PowerChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Power Generation", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (data.isEmpty)
            const EmptyState(message: "Waiting for readings from the ESP32...")
          else
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: const FlTitlesData(
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: data
                          .asMap()
                          .entries
                          .map((e) => FlSpot(e.key.toDouble(), e.value.power))
                          .toList(),
                      isCurved: true,
                      color: AppColors.powerFill,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.powerFill.withOpacity(0.25),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
