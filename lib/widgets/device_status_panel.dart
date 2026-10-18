import "package:flutter/material.dart";
import "../models/sensor_models.dart";
import "../theme.dart";
import "status_states.dart";

class DeviceStatusPanel extends StatelessWidget {
  final List<DeviceStatus> devices;
  const DeviceStatusPanel({super.key, required this.devices});

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Device Status", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (devices.isEmpty)
            const EmptyState(message: "No devices reporting yet.")
          else
            ...devices.map((device) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(device.name, style: const TextStyle(color: AppColors.textBody)),
                      Text(
                        device.status == DeviceOnlineStatus.online ? "Online" : "Offline",
                        style: TextStyle(
                          color: device.status == DeviceOnlineStatus.online
                              ? AppColors.online
                              : AppColors.offline,
                          fontWeight: FontWeight.w600,
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
