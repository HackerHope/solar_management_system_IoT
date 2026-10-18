import "package:flutter/material.dart";
import "../models/sensor_models.dart";
import "../theme.dart";
import "status_states.dart";

class PowerStatusPanel extends StatelessWidget {
  final PowerStatus? status;
  final void Function(int channel, bool on)? onToggleChannel;
  final VoidCallback? onResetSafety;

  const PowerStatusPanel({
    super.key,
    required this.status,
    this.onToggleChannel,
    this.onResetSafety,
  });

  @override
  Widget build(BuildContext context) {
    if (status == null) {
      return const Panel(child: EmptyState(message: "Waiting for power status..."));
    }
    final s = status!;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Power Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _row("Solar", "${s.solarVoltage.toStringAsFixed(1)} V  /  ${s.solarCurrent.toStringAsFixed(1)} A"),
          _row("Source", s.source == "inverter" ? "Inverter (on battery)" : "Grid"),
          _row("Mains", s.mainsPresent ? "Present" : "Not present"),
          _row(
            "Safety",
            s.faultTripped ? "TRIPPED" : "OK",
            color: s.faultTripped ? AppColors.offline : AppColors.online,
          ),
          _row(
            "Auto load control",
            s.autoMode ? "ON" : "OFF",
            color: s.autoMode ? AppColors.online : AppColors.textMuted,
          ),
          if (s.autoShed)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                "Channel 2 was switched off automatically because the battery is low. "
                "It returns when the battery recovers or mains power is back.",
                style: TextStyle(color: AppColors.warning, fontSize: 12),
              ),
            ),
          if (s.faultTripped && onResetSafety != null) ...[
            const SizedBox(height: 8),
            ElevatedButton(onPressed: onResetSafety, child: const Text("Reset safety cutoff")),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Channel 1"),
                  value: s.channel1,
                  onChanged: onToggleChannel == null ? null : (v) => onToggleChannel!(1, v),
                ),
              ),
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Channel 2"),
                  value: s.channel2,
                  onChanged: onToggleChannel == null ? null : (v) => onToggleChannel!(2, v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color color = AppColors.textBody}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
