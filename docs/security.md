# Security setup

This project now uses **per-system access control** instead of "any signed-in user can read and write everything".

## What changed

| Before | Now |
|---|---|
| `database.rules.json`: any authenticated account could read/write all data | Only **members** of a system can read it. Roles: `owner` (the household user) and `device` (the ESP32 account) |
| ESP32 credentials hard-coded in `power_management.ino` | Credentials live in `secrets.h` (git-ignored) |
| MQTT: no login, no encryption | Optional username/password and TLS (app Settings + `secrets.h`) |
| Device could write anywhere | Device can write only readings, circuits, system status, alerts and control of **its own** system |

The old open rules are kept as `database.rules.legacy-open.json` in case you need to roll back quickly.

## Data layout for access control

```
systemsIndex/<systemId>/name
systemsIndex/<systemId>/members/<uid> = "owner" | "device"
users/<uid>/systems/<systemId>/name            (each user's own list, written by the app)
```

Who can write what (inside `systems/<systemId>/`):

| Path | Who |
|---|---|
| `readings`, `circuits`, `system` | device only |
| `settings` | owner only |
| `control` | owner and device (the device clears `resetSafety`) |
| `alerts` | owner and device (Cloud Functions bypass rules) |
| `energy`, `alertState`, `energyState` | nobody from clients (Cloud Functions only) |

A system with **no members yet can be claimed by the first signed-in user who adds it**, so claim your system straight after deploying the rules.

## Migration steps (do these in order, about 10 minutes)

1. **Create the device account.** Firebase console > Authentication > Users > *Add user* (e.g. `device@yourdomain`, a long random password). Copy its **User UID**.
2. **Rotate the old secrets.** If `power_management.ino` with real credentials was ever shared, committed or zipped: change the Wi-Fi password, change the device account password, and consider regenerating/restricting the Firebase API key (Google Cloud Console > APIs & Services > Credentials).
3. **Create `secrets.h`.** Copy `esp32-firmware/power_management/secrets.h.example` to `secrets.h`, fill it in, and re-flash the ESP32.
4. **Deploy the new rules:** `firebase deploy --only database`
5. **Claim your system in the app.** Sign in > More > Systems > Add system. Enter the System ID (`default` if you have been using the default one; your existing data under `systems/default` is kept), a name, and paste the **device UID** from step 1. Tap Add.
   - To add the device later, repeat with the same System ID and the UID.
   - You can also add members by hand in the console: `systemsIndex/<id>/members/<uid>` = `"owner"` or `"device"`.
6. **Turn off public sign-up.** Firebase console > Authentication > Settings > User actions > untick **Enable create (sign-up)**. Create each household login yourself (Authentication > Users > Add user). Without this step, anyone who has your project's public API key can register an account (they still cannot read your system data after step 4, but they could squat unclaimed System IDs).
7. *(Optional)* Turn on **App Check** (Build > App Check) to reject requests that do not come from your app.

## Checking it works

- Signed in as the owner you should see data. A second test account that is **not** a member should see an empty/denied state for your system.
- Unauthenticated read of `https://<db-url>/systems/default.json` must return `Permission denied` (test plan T16).

## MQTT

Use a broker with a username/password (e.g. Mosquitto `password_file`) and, ideally, TLS on port 8883. In the app: Settings > MQTT broker (host, port, *Use TLS*, username, password). The username/password are stored on that phone only. On the ESP32 set `MQTT_USER`/`MQTT_PASS` and optionally `MQTT_USE_TLS` + `MQTT_CA_CERT` in `secrets.h`.

## Known remaining limits

- A claimed system ID cannot currently be released from the app; do it in the console.
- There is no per-user role for household members yet (everyone added as `owner` can change settings).
- Realtime Database rules cannot be unit-tested in this repo; use the Firebase Emulator Suite with `@firebase/rules-unit-testing` if you want automated rule tests.
