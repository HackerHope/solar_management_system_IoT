import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "../models/ai_insight.dart";
import "../theme.dart";
import "status_states.dart";

/// "Energy Advisor" card for the dashboard. Read-only text written daily by the
/// `dailyInsights` Cloud Function. It never controls anything.
class InsightsCard extends StatelessWidget {
  final AiInsight? insight;
  const InsightsCard({super.key, required this.insight});

  @override
  Widget build(BuildContext context) {
    final i = insight;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text("Energy Advisor", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (i != null) _SourceChip(isAi: i.isAi),
            ],
          ),
          const SizedBox(height: 12),
          if (i == null || (i.headline.isEmpty && i.summary.isEmpty))
            const EmptyState(
              message: "Your first daily insight appears after 06:00, once the system has about a day of data.",
            )
          else ...[
            Text(i.headline, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(i.summary, style: const TextStyle(color: AppColors.textBody, fontSize: 13.5, height: 1.35)),
            if (i.dataWarnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Bullets(icon: "⚠️", items: i.dataWarnings.take(2).toList(), color: AppColors.warning),
            ],
            if (i.watch.isNotEmpty) ...[
              const SizedBox(height: 12),
              const _SectionLabel("Keep an eye on"),
              _Bullets(icon: "👀", items: i.watch),
            ],
            if (i.tips.isNotEmpty) ...[
              const SizedBox(height: 12),
              const _SectionLabel("Tips"),
              _Bullets(icon: "💡", items: i.tips),
            ],
            const SizedBox(height: 12),
            Text(
              _footer(i),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  String _footer(AiInsight i) {
    final when = i.generatedAt > 0
        ? DateFormat("d MMM, HH:mm").format(DateTime.fromMillisecondsSinceEpoch(i.generatedAt))
        : "";
    final what = i.isAi ? "AI-generated, advisory only." : "Automatic summary (AI was unavailable).";
    return when.isEmpty ? what : "Updated $when · $what Check the readings before acting.";
  }
}

class _SourceChip extends StatelessWidget {
  final bool isAi;
  const _SourceChip({required this.isAi});

  @override
  Widget build(BuildContext context) {
    final color = isAi ? AppColors.accentIndigoHover : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        isAi ? "AI · advisory only" : "Summary · no AI",
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _Bullets extends StatelessWidget {
  final String icon;
  final List<String> items;
  final Color color;
  const _Bullets({required this.icon, required this.items, this.color = AppColors.textBody});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(t, style: TextStyle(color: color, fontSize: 13, height: 1.3))),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
