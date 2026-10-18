import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

/// Push notifications for alerts. The Cloud Function in /functions sends a
/// message to the topic "system_<id>" for every warning/error alert, so the
/// phone is notified even when the app is closed.
///
/// Not supported on web/desktop in this version (web needs a service worker + VAPID key).
class PushService {
  static String? _subscribed;

  /// Push is wired for Android and iOS only (not web or desktop).
  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String _topic(String systemId) => "system_$systemId";

  static Future<void> init() async {
    if (!_supported) return;
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (e) {
      debugPrint("Push permission request failed: $e");
    }
  }

  /// Subscribes to the alert topic of [systemId] and leaves the previous one.
  static Future<void> subscribeTo(String systemId) async {
    if (!_supported || _subscribed == systemId) return;
    try {
      final previous = _subscribed;
      if (previous != null) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(_topic(previous));
      }
      await FirebaseMessaging.instance.subscribeToTopic(_topic(systemId));
      _subscribed = systemId;
    } catch (e) {
      debugPrint("Push subscribe failed: $e");
    }
  }

  /// Shows a SnackBar when a push arrives while the app is open.
  static void listenForeground(GlobalKey<ScaffoldMessengerState> messengerKey) {
    if (!_supported) return;
    try {
      FirebaseMessaging.onMessage.listen((message) {
        final n = message.notification;
        if (n == null) return;
        messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text("${n.title ?? "Alert"}: ${n.body ?? ""}")),
        );
      });
    } catch (e) {
      debugPrint("Push listener failed: $e");
    }
  }
}
