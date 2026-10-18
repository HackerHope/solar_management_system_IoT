import "package:firebase_auth/firebase_auth.dart";
import "package:firebase_database/firebase_database.dart";
import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../models/sensor_models.dart";
import "shared_stream.dart";

// Tracks which system the app is currently pointed at (persisted locally,
// per device) and keeps this user's list of systems.
//
// Security model (see database.rules.json and docs/security.md):
//   systemsIndex/<id>/members/<uid> = "owner" | "device"   who may access a system
//   users/<uid>/systems/<id>/name                          each user's own list
// A system with no members yet can be claimed by the first user who adds it.
class SystemManager extends ChangeNotifier {
  SystemManager._();
  static final instance = SystemManager._();

  static const defaultSystemId = "default";
  static const _prefsKey = "current_system_id";

  /// Firebase keys cannot contain . # $ [ ] /  - keep IDs simple and safe.
  static final _validId = RegExp(r"^[A-Za-z0-9_-]{1,40}$");
  static bool isValidSystemId(String id) => _validId.hasMatch(id);

  String _currentSystemId = defaultSystemId;
  String get currentSystemId => _currentSystemId;

  bool loaded = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _currentSystemId = prefs.getString(_prefsKey) ?? defaultSystemId;
    loaded = true;
    notifyListeners();
  }

  Future<void> setCurrentSystem(String systemId) async {
    if (systemId == _currentSystemId) return;
    _currentSystemId = systemId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, systemId);
    notifyListeners();
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // One shared, replaying stream per user (see shared_stream.dart), so the list
  // does not blank and reappear when the screen rebuilds.
  static final Map<String, SharedStream<List<SolarSystem>>> _known = {};
  static final SharedStream<List<SolarSystem>> _none =
      SharedStream<List<SolarSystem>>(() => Stream.value(<SolarSystem>[]));

  /// Call on sign-out.
  void disposeShared() {
    for (final s in _known.values) {
      s.dispose();
    }
    _known.clear();
  }

  Stream<List<SolarSystem>> knownSystems() {
    final uid = _uid;
    if (uid == null) return _none.stream;
    final shared = _known[uid] ??= SharedStream<List<SolarSystem>>(() {
      return FirebaseDatabase.instance.ref("users/$uid/systems").onValue.map((event) {
        final value = event.snapshot.value;
        if (value == null) return <SolarSystem>[];
        final map = Map<dynamic, dynamic>.from(value as Map);
        final list = map.entries.map((e) {
          final entry = e.value is Map ? Map<dynamic, dynamic>.from(e.value as Map) : <dynamic, dynamic>{};
          return SolarSystem(id: e.key as String, name: entry["name"] as String? ?? e.key as String);
        }).toList();
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      });
    });
    return shared.stream;
  }

  /// Registers (claims) a system for the signed-in user. Optionally authorises
  /// the ESP32's Firebase Auth account (its UID, from the Firebase console)
  /// to write data for this system. Throws if the system belongs to someone else.
  Future<void> registerSystem(String systemId, String name, {String? deviceUid}) async {
    final uid = _uid;
    if (uid == null) throw StateError("Not signed in");
    if (!isValidSystemId(systemId)) throw ArgumentError("Invalid System ID");
    final updates = <String, Object?>{
      "systemsIndex/$systemId/name": name,
      "systemsIndex/$systemId/members/$uid": "owner",
      "users/$uid/systems/$systemId/name": name,
    };
    final dev = deviceUid?.trim() ?? "";
    if (dev.isNotEmpty) {
      updates["systemsIndex/$systemId/members/$dev"] = "device";
    }
    await FirebaseDatabase.instance.ref().update(updates);
  }
}
