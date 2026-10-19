
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

  Color _statusColor() {
    switch (status) {
      case "Healthy":
      case "OK":
      case "Generating":
      case "Normal":
        return const Color(0xFFB7F36B);

      case "Low":
      case "High":
        return const Color(0xFFFFB454);

      case "No data":
      case "No sensor":
        return const Color(0xFF9CAEC4);

      case "Fair":
        return const Color(0xFFFFD166);

      case "Idle":
        return const Color(0xFF9CAEC4);

      case "In use":
        return const Color(0xFF7CC8FF);

      case "No sun":
        return const Color(0xFF9CAEC4);

      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();

    return Panel(
      child: Container(
        constraints: const BoxConstraints(minHeight: 142),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB7F36B).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    icon,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF9CAEC4),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 5),

            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.8,
                ),
              ),
            ),

            const SizedBox(height: 9),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
