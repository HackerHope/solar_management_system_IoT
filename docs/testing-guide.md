# Testing guide (fills in Chapter 6 of the report)

## 1. Automated tests

```bash
flutter test                 # models, alert rules, energy maths (test/*.dart)
cd functions && npm test     # server-side alert, cooldown, watchdog and energy rules
```

Record the pass counts in Chapter 6 (section 6.2/6.3). Run `flutter analyze` as well and note the result.

## 2. Test without the hardware: the device simulator

`tools/simulate_device.js` signs in as the device account and writes readings like the ESP32 does.

```bash
export FIREBASE_API_KEY=...            # Project settings > Web API key
export FIREBASE_DB_URL=https://<project>-default-rtdb.<region>.firebasedatabase.app
export DEVICE_EMAIL=...  DEVICE_PASSWORD=...  SYSTEM_ID=default
node tools/simulate_device.js normal        # also: low-battery | fault | stop
```

The device account must be a `device` member of the system (docs/security.md, step 5).

## 3. How to run each test case in Table 6.1

| ID | How |
|---|---|
| T1-T3 | Sign in with a valid account, a wrong password, then Sign out |
| T4 | Run the simulator `normal`; watch cards and charts move without refreshing |
| T5 | Select a new empty System ID in Systems; the dashboard shows the "Waiting for sensor data" message |
| T6 | Stop the simulator (or power off the ESP32); Devices shows Offline after about 30 s (kDeviceStaleMs in lib/config.dart) |
| T7 | `low-battery` scenario for more than 5 minutes; one "Low Battery" alert, no repeat within 5 minutes |
| T8 | `low-battery` scenario; "Low Battery" alert (and "Low Battery Voltage") |
| T9 | Change a limit in Settings, Save; restart the app and confirm it persisted |
| T10-T11 | Toggle Channel 1/2 with and without an MQTT broker connected (needs the real device) |
| T12 | `fault` scenario shows TRIPPED; the Reset button writes `control/resetSafety` (real device needed to clear it) |
| T13 | Systems > Add system with a new ID; switch between systems; restart |
| T14 | Analytics with no circuit data shows the "simulated" label |
| T15 | Settings > MQTT with a wrong host > Test Connection |
| T16 | Open `https://<db-url>/systems/default.json` in a browser: must say Permission denied |
| New T17 | Automatic load control: enable it, run `low-battery` with the real device on inverter power; channel 2 switches off, "Load shed automatically" alert; recovers and switches back on |
| New T18 | Run `normal` for a few minutes, then check Analytics shows today's kWh (Cloud Functions deployed) |
| New T19 | With the app closed, run `low-battery`; a push notification arrives |
| New T20 | Not-a-member account cannot read your system data |

## 3b. AI Energy Advisor tests (Gemini)

Follow `docs/ai-insights.md`. In short: `node tools/check_gemini.js` (keys and models work), `node tools/try_insights.js bad-sensors` (the AI refuses to give advice on wrong readings), then force-run the `dailyInsights` job and confirm `insights/latest.source` is `gemini` and the dashboard chip says "AI · advisory only".

## 4. Latency measurements (Table 6.2)

- **M1**: the dashboard shows "Updated N s ago" under the system name. Compare it with the simulator's printed timestamp, or record the screen next to the terminal.
- **M2/M3**: screen-record pressing a switch until the switch reflects the device's reported state (real device).
- **M5**: stop the simulator and time how long until Devices turns Offline (about 30 s by design, plus up to 3 s for the re-check timer).

Repeat each at least 20 times and report mean and range. Do not invent numbers: write only what you measured.
