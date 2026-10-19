import "package:flutter/material.dart";
import "../config.dart";
import "../models/sensor_models.dart";
import "../theme.dart";
import "status_states.dart";

class PowerStatusPanel extends StatelessWidget {
  final PowerStatus? status;
  final List<String> channelNames;
  final void Function(int channel, bool on)? onToggleChannel;
  final VoidCallback? onResetSafety;

  const PowerStatusPanel({
    super.key,
    required this.status,
    this.channelNames = const ["Channel 1", "Channel 2"],
    this.onToggleChannel,
    this.onResetSafety,
  });

  static const Color _accent = Color(0xFFB7F36B);
  static const Color _muted = Color(0xFF9CAEC4);
  static const Color _surface = Color(0xFF101A2A);

  @override
  Widget build(BuildContext context) {
    if (status == null) {
      return const Panel(
        child: EmptyState(message: "Waiting for power status..."),
      );
    }

    final s = status!;
    final statusAgeMs = s.timestamp == null
        ? null
        : DateTime.now().millisecondsSinceEpoch - s.timestamp!;
    if (statusAgeMs == null ||
        statusAgeMs < 0 ||
        statusAgeMs >= kDeviceStaleMs) {
      return Panel(
        child: EmptyState(
          message: statusAgeMs == null
              ? "Power status has no update timestamp. Reflash the ESP32 firmware to enable freshness checks."
              : "Power status is stale. Waiting for a fresh update from the ESP32.",
        ),
      );
    }

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel heading
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.electrical_services_rounded,
                  color: _accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Power Status",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Source, protection and outputs",
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: (s.faultTripped ? AppColors.offline : _accent)
                      .withOpacity(0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  s.faultTripped ? "FAULT" : "SAFE",
                  style: TextStyle(
                    color: s.faultTripped ? AppColors.offline : _accent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Existing power and protection information.
          _infoRow(
            icon: Icons.solar_power_rounded,
            label: "Solar input",
            value:
                "${s.solarVoltage.toStringAsFixed(1)} V  /  "
                "${s.solarCurrent.toStringAsFixed(1)} A",
          ),

          _infoRow(
            icon: Icons.power_rounded,
            label: "Power source",
            value: s.source == "inverter" ? "Inverter (on battery)" : "Grid",
          ),

          _infoRow(
            icon: Icons.electrical_services_rounded,
            label: "Mains supply",
            value: s.mainsPresent ? "Present" : "Not present",
            valueColor: s.mainsPresent ? _accent : _muted,
          ),

          _infoRow(
            icon: Icons.shield_outlined,
            label: "Safety protection",
            value: s.faultTripped ? "TRIPPED" : "OK",
            valueColor: s.faultTripped ? AppColors.offline : _accent,
          ),

          _infoRow(
            icon: Icons.auto_mode_rounded,
            label: "Auto load control",
            value: s.autoMode ? "ON" : "OFF",
            valueColor: s.autoMode ? _accent : _muted,
          ),

          if (s.autoShed) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.09),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.warning.withOpacity(0.20)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.warning,
                    size: 19,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Channel 2 was switched off automatically "
                      "because the battery is low. It returns when "
                      "the battery recovers or mains power is back.",
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (s.faultTripped && onResetSafety != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onResetSafety,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text("Reset safety cutoff"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.offline,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 22),

          // Output controls
          const Text(
            "Output channels",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 5),

          const Text(
            "Switch each connected channel on or off.",
            style: TextStyle(color: _muted, fontSize: 12),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _channelCard(
                  title: _channelName(0),
                  isOn: s.channel1,
                  onChanged: onToggleChannel == null
                      ? null
                      : (value) => onToggleChannel!(1, value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _channelCard(
                  title: _channelName(1),
                  isOn: s.channel2,
                  onChanged: onToggleChannel == null
                      ? null
                      : (value) => onToggleChannel!(2, value),
                ),
              ),
            ],
          ),
          if (channelNames.length > 2) ...[
            const SizedBox(height: 10),
            ...channelNames
                .skip(2)
                .map(
                  (name) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _displayOnlyChannelCard(name),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  String _channelName(int index) {
    if (index >= channelNames.length || channelNames[index].trim().isEmpty) {
      return "Channel ${index + 1}";
    }
    return channelNames[index];
  }

  Widget _displayOnlyChannelCard(String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          const Icon(Icons.power_settings_new_rounded, size: 19, color: _muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const Text(
            "Not connected",
            style: TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    Color valueColor = AppColors.textBody,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.035),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: _muted),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _channelCard({
    required String title,
    required bool isOn,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 13, 8, 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isOn
              ? _accent.withOpacity(0.28)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.power_settings_new_rounded,
                size: 19,
                color: isOn ? _accent : _muted,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: Text(
                  isOn ? "ON" : "OFF",
                  style: TextStyle(
                    color: isOn ? _accent : _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Switch(
                value: isOn,
                onChanged: onChanged,
                activeColor: _accent,
                inactiveThumbColor: _muted,
                inactiveTrackColor: Colors.white12,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
