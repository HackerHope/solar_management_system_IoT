import "dart:async";
import "package:flutter/material.dart";

/// Rebuilds its child every [interval], so text that depends on the current
/// time ("Last seen 20 sec ago", connected / not connected) stays correct even
/// when no new data arrives.
class PeriodicRebuild extends StatefulWidget {
  final Duration interval;
  final WidgetBuilder builder;
  const PeriodicRebuild({super.key, this.interval = const Duration(seconds: 3), required this.builder});

  @override
  State<PeriodicRebuild> createState() => _PeriodicRebuildState();
}

class _PeriodicRebuildState extends State<PeriodicRebuild> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
