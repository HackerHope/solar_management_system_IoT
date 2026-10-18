# Cloud Functions: alerts, push notifications, energy totals

Folder: `functions/`. Needs the **Blaze (pay-as-you-go)** plan; one household stays inside the free monthly allowance.

| Function | Trigger | What it does |
|---|---|---|
| `onReading` | every write to `readings/latest` | raises threshold alerts (5-minute cooldown per alert type) and adds the energy used/generated to `energy/daily/<date>` and `energy/hourly/<date-hour>` |
| `pushOnAlert` | every new alert | sends a push notification (warning and error only) to topic `system_<id>` |
| `deviceWatchdog` | every 5 minutes | "Device offline" after 3 minutes without a heartbeat, "Device back online" afterwards |
| `pruneHistory` | daily 03:00 (Africa/Lusaka) | deletes `readings/history` and `circuits/history` older than 7 days so the database does not grow forever |

## Deploy

```bash
npm install -g firebase-tools
firebase login
cd functions && npm install && npm test && cd ..
firebase deploy --only functions,database
```

Check the region at the top of `functions/index.js` (`REGION`). It must match your Realtime Database region (the project's RTDB URL is in `europe-west1`). If you see "region mismatch" errors, change it.

## Switch the app over

1. In `lib/config.dart` set `kClientSideAlerts = false` (otherwise every alert is created twice: once by the app and once by the server).
2. Run `flutter pub get` (the app now uses `firebase_messaging`). If version resolution complains, run `flutter pub add firebase_messaging`.
3. **Android:** on Android 13+ the app asks for notification permission at start. If notifications do not show, make sure `android/app/src/main/AndroidManifest.xml` contains `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`.
4. **iOS:** enable *Push Notifications* and *Background Modes > Remote notifications* in Xcode and upload an APNs key in Firebase console > Project settings > Cloud Messaging.
5. Web push is not set up in this version.

## Test it

- Run `node tools/simulate_device.js low-battery` (see the file header for the environment variables). Within a few seconds a "Low Battery" alert appears in the app and, with the app closed, a push notification arrives.
- `node tools/simulate_device.js stop` then wait about 5 to 8 minutes: "Device offline" is raised by the watchdog.
- Logs: `firebase functions:log`.

## Unit tests

`cd functions && npm test` runs the pure rule code (`alerts.js`, `energy.js`).
