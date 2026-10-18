# What changed (priority fixes and additions)

## 1. Voltage / sensor labelling (app + web)
- `voltage`/`current` are the **battery** measurements (power-management firmware). Cards and rules are now named "Battery Voltage", "Load Current"; rule "Low Solar Voltage" is now "Low Battery Voltage" with a user setting (default 10.5 V).
- New **Solar Power** card (from `powerStatus`). Solar Panel on the Solar System screen now shows solar V/A.
- Status words (Low/OK, Idle/In use, Normal/High) are now computed instead of fixed text.
- Temperature is **optional**: firmware omits it when no sensor is fitted and the app shows "N/A / No sensor" and skips the alert.

## 2. Security
- New per-system rules (`database.rules.json`); old rules kept as `database.rules.legacy-open.json`.
- ESP32 secrets moved to `secrets.h` (see `secrets.h.example`), git-ignored.
- App "Add system" claims the system and can authorise the device UID. MQTT login + TLS option.
- Read `docs/security.md` and follow the migration steps BEFORE deploying the rules.

## 3. Automatic load control (firmware + Settings)
- Rule R1: on inverter and battery below the shed level -> channel 2 off; restores when battery recovers or mains returns.
- Rule R2: battery >= 95 % and strong solar -> channel 2 on (not if the user switched it off by hand).
- Off by default; enable in Settings. A manual command always wins. Channel 1 is never switched automatically.
- Also fixes: commands sent over MQTT were reverted by the device's Firebase poll; the app now also writes the Firebase desired state, and the firmware mirrors MQTT/auto changes.

## 4. Server-side alerts and push (`functions/`)
- Threshold alerts with cooldown, push notifications, offline watchdog, history pruning. See `docs/cloud-functions.md`.
- `lib/config.dart`: set `kClientSideAlerts = false` after deploying.

## 5. Evidence for Chapter 6
- `tools/simulate_device.js`, `docs/testing-guide.md`, "Updated N s ago" label on the dashboard.

## 6. Energy totals and cost
- Cloud Function aggregates daily/hourly kWh (used and solar); Analytics shows today's totals, a 7-day chart and cost in ZMW from a tariff you enter in Settings. Without the functions it shows an estimate from recent readings.

## 7. React dashboard
- Reads `systems/<id>/...` (set `VITE_SYSTEM_ID`), same labels/rules as the app. Note: the `frontend` folder in the zip was missing `package.json`, `index.html`, `SystemOverview` and `AboutUs`, so I could not build it.

## 8. Automated tests
- `test/` (Dart) and `functions/test/` (Node, 22 tests, passing).

## 9. Bug fix: Systems / Settings items appearing and disappearing
- Cause: screens called `dataService.someStream()` inside `build()` (and inside other StreamBuilders). Every rebuild, e.g. each new reading every few seconds, made a brand-new Firebase listener, so the data was thrown away and the widget fell back to "no data" until the first event arrived. That is the appear / vanish / appear loop.
- Fix: `lib/services/shared_stream.dart` gives each stream one shared listener per system that replays the latest value; all `SolarDataService` streams and `SystemManager.knownSystems()` use it. Systems screen now shows "Loading..." and a clear error instead of "No systems registered" when data is not ready or access is denied.
- Related fixes found on the way: leaked listeners in Dashboard/Settings (now cancelled), alert cooldown was per screen instance so duplicate alerts piled up (now shared), device online/offline now re-checks every 3 s and uses a 30 s limit (`kDeviceStaleMs`) so a slow upload cycle does not flip it, Settings "Last seen" text updates live. Streams are cleared on sign-out.

## Not verified (no Flutter/Arduino/Firebase tools in my environment)
- Dart code was not compiled and Dart tests not run; firmware was not compiled; rules and functions were not deployed. Node tests were run and pass.
- First steps for you: `flutter pub get`, `flutter analyze`, `flutter test`; create `secrets.h`; compile the sketch; then follow docs/security.md.
