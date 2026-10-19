import "dart:async";
import "package:firebase_database/firebase_database.dart";
import "../models/ai_insight.dart";
import "../models/sensor_models.dart";
import "../config.dart";
import "alert_thresholds.dart";
import "shared_stream.dart";
import "system_manager.dart";

const _historyLimit = 50;
const _deviceNames = [
  "ESP32 Controller",
  "Battery Voltage Sensor",
  "Battery Current Sensor",
  "Battery Monitor",
];

class SolarDataService implements AlertRaiser {
  // Live getter (not cached at construction) so every call reflects
  // whichever system SystemManager currently points at.
  DatabaseReference get _root =>
      FirebaseDatabase.instance.ref("systems/${SystemManager.instance.currentSystemId}");

  // One shared, replaying stream per system and name (see shared_stream.dart).
  // Without this every rebuild of a screen created a fresh Firebase listener,
  // which blanked the data for a moment and made the UI flicker.
  static final Map<String, Object> _sharedStreams = {};

  Stream<T> _share<T>(String name, Stream<T> Function(DatabaseReference root) create) {
    final root = _root; // bound to the system that is active right now
    final key = "${SystemManager.instance.currentSystemId}|$name";
    final shared = (_sharedStreams[key] ??= SharedStream<T>(() => create(root))) as SharedStream<T>;
    return shared.stream;
  }

  /// Call on sign-out so one account's data is never replayed to the next.
  static void disposeAllShared() {
    for (final s in _sharedStreams.values) {
      (s as dynamic).dispose();
    }
    _sharedStreams.clear();
  }

  // ---- Readings ----

  Stream<Reading?> latestReading() => _share("latestReading", _latestReading);

  Stream<Reading?> _latestReading(DatabaseReference root) {
    return root.child("readings/latest").onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null) return null;
      return Reading.fromMap(Map<dynamic, dynamic>.from(value as Map));
    });
  }

  Stream<List<Reading>> history() => _share("history", _history);

  Stream<List<Reading>> _history(DatabaseReference root) {
    final query = root.child("readings/history").orderByKey().limitToLast(_historyLimit);
    return query.onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null) return <Reading>[];
      final map = Map<dynamic, dynamic>.from(value as Map);
      final list = map.values
          .map((v) => Reading.fromMap(Map<dynamic, dynamic>.from(v as Map)))
          .toList();
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    });
  }

  // ---- Devices (derived from ESP32 heartbeat) ----

  Stream<List<DeviceStatus>> devices() => _share("devices", _devices);

  // The online/offline state is recalculated every few seconds, not only when a
  // new heartbeat arrives. Otherwise a device that stops sending would keep
  // showing "online" until something else happened to rebuild the screen.
  Stream<List<DeviceStatus>> _devices(DatabaseReference root) {
    late final StreamController<List<DeviceStatus>> controller;
    StreamSubscription<DatabaseEvent>? sub;
    Timer? timer;
    int? lastSeen;
    var gotFirstValue = false;

    void emit() {
      if (!gotFirstValue) return;
      final online = lastSeen != null &&
          DateTime.now().millisecondsSinceEpoch - lastSeen! < kDeviceStaleMs;
      final status = online ? DeviceOnlineStatus.online : DeviceOnlineStatus.offline;
      controller.add(_deviceNames.map((name) => DeviceStatus(name: name, status: status)).toList());
    }

    controller = StreamController<List<DeviceStatus>>(
      onListen: () {
        sub = root.child("system/lastSeen").onValue.listen((event) {
          final value = event.snapshot.value;
          lastSeen = value is num ? value.toInt() : null;
          gotFirstValue = true;
          emit();
        }, onError: controller.addError);
        timer = Timer.periodic(const Duration(seconds: 3), (_) => emit());
      },
      onCancel: () async {
        timer?.cancel();
        await sub?.cancel();
      },
    );
    return controller.stream;
  }

  // ---- Alerts ----

  Stream<List<AppAlert>> alerts() => _share("alerts", _alerts);

  Stream<List<AppAlert>> _alerts(DatabaseReference root) {
    final query = root.child("alerts").orderByKey().limitToLast(50);
    return query.onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null) return <AppAlert>[];
      final map = Map<dynamic, dynamic>.from(value as Map);
      final list = map.entries
          .map((e) => AppAlert.fromMap(e.key as String, Map<dynamic, dynamic>.from(e.value as Map)))
          .toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  // Simple in-memory cooldown so the same threshold breach doesn't spam
  // duplicate alerts every reading - mirrors the web app's raiseAlert().
  // static: every screen creates its own SolarDataService, and a per-instance map
  // let each of them raise the same alert again (duplicates piled up every time
  // the Dashboard was reopened).
  static final Map<String, int> _recentAlertKeys = {};
  static const _alertCooldownMs = 5 * 60 * 1000;

  @override
  Future<void> raiseAlert(String level, String title, String message) async {
    final key = "${SystemManager.instance.currentSystemId}|$level:$title";
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _recentAlertKeys[key];
    if (last != null && now - last < _alertCooldownMs) return;
    _recentAlertKeys[key] = now;

    final alertRef = _root.child("alerts").push();
    await alertRef.set({
      "level": level,
      "title": title,
      "message": message,
      "timestamp": now,
    });
  }

  // ---- Settings ----

  Stream<AppSettings> settings() => _share("settings", _settings);

  Stream<AppSettings> _settings(DatabaseReference root) {
    return root.child("settings").onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null) return AppSettings.defaults;
      return AppSettings.fromMap(Map<dynamic, dynamic>.from(value as Map));
    });
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _root.child("settings").set(settings.toMap());
  }

  // ---- Circuits (per-appliance - only present once CT sensors are wired up) ----

  Stream<CircuitsReading?> circuitsLatest() => _share("circuitsLatest", _circuitsLatest);

  Stream<CircuitsReading?> _circuitsLatest(DatabaseReference root) {
    return root.child("circuits/latest").onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null) return null;
      return CircuitsReading.fromMap(Map<dynamic, dynamic>.from(value as Map));
    });
  }

  // null = no circuit sensors have ever reported - caller should show the
  // clearly-labeled simulated fallback instead of an empty real chart.
  Stream<List<CircuitsReading>?> circuitsHistory() => _share("circuitsHistory", _circuitsHistory);

  Stream<List<CircuitsReading>?> _circuitsHistory(DatabaseReference root) {
    final query = root.child("circuits/history").orderByKey().limitToLast(_historyLimit);
    return query.onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null) return null;
      final map = Map<dynamic, dynamic>.from(value as Map);
      final list = map.values
          .map((v) => CircuitsReading.fromMap(Map<dynamic, dynamic>.from(v as Map)))
          .toList();
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    });
  }

  // ---- Power status (solar/grid source, safety, load channels) ----

  Stream<PowerStatus?> powerStatus() => _share("powerStatus", _powerStatus);

  Stream<PowerStatus?> _powerStatus(DatabaseReference root) {
    return root.child("system/powerStatus").onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null) return null;
      return PowerStatus.fromMap(Map<dynamic, dynamic>.from(value as Map));
    });
  }

  Future<void> setChannel(int channel, bool on) async {
    await _root.child("control/channel$channel").set(on);
  }

  Future<void> resetSafety() async {
    await _root.child("control/resetSafety").set(true);
  }

  // ---- Device connection (for the Settings > Device Setup section) ----

  Stream<int?> lastSeenRaw() => _share("lastSeenRaw", _lastSeenRaw);

  Stream<int?> _lastSeenRaw(DatabaseReference root) {
    return root.child("system/lastSeen").onValue.map((event) {
      final value = event.snapshot.value;
      if (value is num) return value.toInt();
      return null;
    });
  }

  // ---- AI Energy Advisor (written daily by the dailyInsights Cloud Function) ----
  // Read-only: the advisor only produces text and can never send a command to the device.

  Stream<AiInsight?> insights() => _share("insights", _insights);

  Stream<AiInsight?> _insights(DatabaseReference root) {
    return root.child("insights/latest").onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null) return null;
      return AiInsight.fromMap(Map<dynamic, dynamic>.from(value as Map));
    });
  }

  // ---- Daily energy totals (aggregated by Cloud Functions) ----

  Stream<List<DailyEnergy>> dailyEnergy({int days = 7}) =>
      _share("dailyEnergy$days", (root) => _dailyEnergy(root, days));

  Stream<List<DailyEnergy>> _dailyEnergy(DatabaseReference root, int days) {
    final query = root.child("energy/daily").orderByKey().limitToLast(days);
    return query.onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null) return <DailyEnergy>[];
      final map = Map<dynamic, dynamic>.from(value as Map);
      final list = map.entries
          .map((e) => DailyEnergy.fromMap(e.key as String, Map<dynamic, dynamic>.from(e.value as Map)))
          .toList();
      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    });
  }
}
