import "package:flutter/material.dart";
import "../models/sensor_models.dart";
import "../services/system_manager.dart";
import "../theme.dart";
import "../widgets/status_states.dart";

class SystemsScreen extends StatelessWidget {
  const SystemsScreen({super.key});

  Future<void> _showAddSystemDialog(BuildContext context) async {
    final idController = TextEditingController();
    final nameController = TextEditingController();
    final deviceUidController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text("Add System"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              decoration: const InputDecoration(
                labelText: "System ID",
                helperText: "Must match SYSTEM_ID in the firmware",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Display name"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: deviceUidController,
              decoration: const InputDecoration(
                labelText: "Device account UID (optional)",
                helperText: "Firebase console > Authentication > the ESP32 user > User UID",
                helperMaxLines: 2,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final id = idController.text.trim();
              final name = nameController.text.trim();
              final messenger = ScaffoldMessenger.of(context);
              if (!SystemManager.isValidSystemId(id)) {
                messenger.showSnackBar(const SnackBar(
                    content: Text("System ID: use letters, numbers, - or _ (max 40 characters).")));
                return;
              }
              try {
                await SystemManager.instance.registerSystem(
                  id,
                  name.isEmpty ? id : name,
                  deviceUid: deviceUidController.text,
                );
                await SystemManager.instance.setCurrentSystem(id);
                if (context.mounted) Navigator.pop(context);
              } catch (_) {
                messenger.showSnackBar(const SnackBar(
                    content: Text("Could not add the system. It may already belong to another account.")));
              }
            },
            child: const Text("Add & Switch"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Systems", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text(
          "Switch between solar systems, or register a new ESP32.",
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),

        StreamBuilder<List<SolarSystem>>(
          stream: SystemManager.instance.knownSystems(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const ErrorStateWidget(
                  message: "Could not load your systems. Check your connection, and that your account has access (see docs/security.md).");
            }
            if (!snap.hasData) {
              return const LoadingState(label: "Loading systems...");
            }
            final systems = snap.data ?? [];
            if (systems.isEmpty) {
              return const EmptyState(message: "No systems registered yet. Add one below.");
            }
            return AnimatedBuilder(
              animation: SystemManager.instance,
              builder: (context, _) {
                final activeId = SystemManager.instance.currentSystemId;
                return Column(
                  children: systems.map((s) {
                    final isActive = s.id == activeId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Panel(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(s.id, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              ],
                            ),
                            isActive
                                ? const Text("Active", style: TextStyle(color: AppColors.online, fontWeight: FontWeight.bold))
                                : TextButton(
                                    onPressed: () => SystemManager.instance.setCurrentSystem(s.id),
                                    child: const Text("Switch"),
                                  ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            );
          },
        ),

        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => _showAddSystemDialog(context),
          icon: const Icon(Icons.add),
          label: const Text("Add System"),
        ),
      ],
    );
  }
}
