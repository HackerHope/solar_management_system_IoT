import "package:flutter/material.dart";
import "../theme.dart";
import "../widgets/status_states.dart";

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("About Us", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text(
          "SolarIoT is a smart monitoring system designed to track solar power, "
          "battery health, load usage, and environmental sensor readings in real time.",
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text("Project Purpose", style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(
                "This system helps you understand how your solar energy system is "
                "performing and warns you when something needs attention.",
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
