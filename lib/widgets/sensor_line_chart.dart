import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";
import "../models/sensor_models.dart";
import "../theme.dart";
import "status_states.dart";

class SensorLineChart extends StatelessWidget {
  final List<Reading> data;
  const SensorLineChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Voltage & Current", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    _line(data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.voltage)).toList(), AppColors.voltageLine),
                    _line(data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.current)).toList(), AppColors.currentLine),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              _legendDot(AppColors.voltageLine, "Voltage"),
              const SizedBox(width: 16),
              _legendDot(AppColors.currentLine, "Current"),
            ],
          ),
        ],
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 3,
      dotData: const FlDotData(show: false),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }
}
