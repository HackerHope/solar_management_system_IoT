import "package:flutter/material.dart";
import "../theme.dart";
import "status_states.dart";

class StatCard extends StatelessWidget {
  final String icon;
  final String title;
  final String value;
  final String status;

  const StatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF1F2D46),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(status, style: const TextStyle(color: AppColors.online, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
