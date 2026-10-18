import "package:flutter/material.dart";
import "../theme.dart";

class LoadingState extends StatelessWidget {
  final String label;
  const LoadingState({super.key, this.label = "Loading..."});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class ErrorStateWidget extends StatelessWidget {
  final String message;
  const ErrorStateWidget({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(message, style: const TextStyle(color: AppColors.offline)),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  const EmptyState({super.key, this.message = "No data yet."});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(message, style: const TextStyle(color: AppColors.textMuted)),
    );
  }
}

// Reusable dark panel matching .panel in the web app's CSS
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: panelDecoration(),
      child: child,
    );
  }
}
