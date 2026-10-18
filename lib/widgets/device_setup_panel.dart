import "package:firebase_core/firebase_core.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "../config.dart";
import "../theme.dart";
import "status_states.dart";

class DeviceSetupPanel extends StatelessWidget {
  final int? lastSeenMs;
  final String deviceName;
  final String systemId;

  const DeviceSetupPanel({
    super.key,
    required this.lastSeenMs,
    required this.deviceName,
    required this.systemId,
  });

  bool get _isOnline =>
      lastSeenMs != null &&
      DateTime.now().millisecondsSinceEpoch - lastSeenMs! < kDeviceStaleMs;

  String get _lastSeenLabel {
    if (lastSeenMs == null) return "Never connected";
    final diff = DateTime.now().millisecondsSinceEpoch - lastSeenMs!;
    if (diff < kDeviceStaleMs) return "Just now";
    final seconds = (diff / 1000).round();
    if (seconds < 60) return "$seconds sec ago";
    final minutes = (seconds / 60).round();
    if (minutes < 60) return "$minutes min ago";
    final hours = (minutes / 60).round();
    return "$hours hr ago";
  }

  @override
  Widget build(BuildContext context) {
    final options = Firebase.app().options;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Device Setup", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text(
            "The ESP32 talks to your app through Firebase, not directly. "
            "There's no pairing step in-app - you connect it by flashing your "
            "WiFi and Firebase details into the firmware once.",
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _isOnline ? AppColors.online : AppColors.offline,
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                _isOnline ? "$deviceName connected" : "$deviceName not connected",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text("Last seen: $_lastSeenLabel",
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),

          const SizedBox(height: 16),
          const Divider(color: AppColors.panelBorder),
          const SizedBox(height: 12),

          const Text("Your Firebase project", style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _copyableField(context, "Project ID", options.projectId),
          const SizedBox(height: 8),
          _copyableField(context, "Database URL", options.databaseURL ?? "--"),
          const SizedBox(height: 8),
          _copyableField(context, "System ID", systemId),

          const SizedBox(height: 16),
          const Divider(color: AppColors.panelBorder),
          const SizedBox(height: 12),

          const Text("To connect the ESP32", style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _step(1, "Open power_management.ino in the Arduino IDE."),
          _step(2, "Set WIFI_SSID and WIFI_PASSWORD to your WiFi network."),
          _step(
            3,
            "Set DATABASE_URL to the Database URL above, and API_KEY to your "
            "Firebase project's Web API key (Firebase Console > Project "
            "Settings > General).",
          ),
          _step(
            4,
            "Set USER_EMAIL / USER_PASSWORD to a Firebase Authentication user "
            "for the device (Firebase Console > Authentication > Users - "
            "create one if you haven't).",
          ),
          _step(
            5,
            "Set SYSTEM_ID to the System ID above - this is what keeps this "
            "board's data separate if you ever add a second system.",
          ),
          _step(
            6,
            "(Optional) Set MQTT_BROKER_HOST/PORT if you're running a local "
            "broker for faster control - see the MQTT section below.",
          ),
          _step(7, "Flash the ESP32 and power it on."),
          _step(
            8,
            "Once it joins WiFi it starts writing to your database automatically - "
            "the status above will flip to \"connected\" within a few seconds.",
          ),
        ],
      ),
    );
  }

  Widget _step(int n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text("$n.", style: const TextStyle(color: AppColors.textMuted)),
          ),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _copyableField(BuildContext context, String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 16, color: AppColors.textMuted),
          tooltip: "Copy",
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text("Copied $label"), duration: const Duration(seconds: 1)));
          },
        ),
      ],
    );
  }
}
