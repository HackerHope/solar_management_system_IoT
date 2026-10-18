import "dart:async";
import "package:flutter/material.dart";
import "../theme.dart";

/// "Updated 3 s ago" label. Green when fresh, amber when slow, red when stale.
/// Also handy for measuring end-to-end latency in the test plan (M1).
/// Needs the device's timestamp to be real epoch milliseconds (NTP-synced firmware).
class DataAge extends StatefulWidget {
  final int? timestampMs;
  const DataAge({super.key, required this.timestampMs});

  @override
  State<DataAge> createState() => _DataAgeState();
}

class _DataAgeState extends State<DataAge> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ts = widget.timestampMs;
    if (ts == null || ts < 1000000000000) {
      // No data yet, or a legacy device clock (uptime instead of real time)
      return const SizedBox.shrink();
    }
    final ageSec = ((DateTime.now().millisecondsSinceEpoch - ts) / 1000).round();
    final text = ageSec < 0
        ? "Updated just now"
        : ageSec < 90
            ? "Updated $ageSec s ago"
            : "No update for ${(ageSec / 60).floor()} min";
    final color = ageSec < 15
        ? AppColors.online
        : ageSec < 60
            ? AppColors.warning
            : AppColors.offline;
    return Text(text, style: TextStyle(color: color, fontSize: 11));
  }
}
