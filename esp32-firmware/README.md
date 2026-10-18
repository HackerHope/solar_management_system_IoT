# ESP32 Firmware - Wiring & Setup

There are two sketches in `esp32-firmware/`:
- **`solar_monitor/`** - the original version, posts to the local Express backend (still works if you go that route)
- **`firebase_solar_monitor/`** - posts straight to Firebase, no backend needed. **Use this one** if you followed `docs/firebase-setup.md`.

This guide covers the Firebase version.

## 1. Install libraries
In Arduino IDE: **Tools > Manage Libraries**
- **ArduinoJson**, version **6.x** (not 7.x - the API used here is v6's `StaticJsonDocument`/`createNestedObject`)
- **Adafruit ADS1X15** - only if you're wiring up per-circuit sensors (see `docs/per-circuit-sensors.md`). Skip it otherwise; the sketch detects its absence automatically.

Install the ESP32 board package via **Tools > Board > Boards Manager** if you haven't already.

## 2. Wiring (main sensors)

| Sensor              | ESP32 Pin | Notes |
|---------------------|-----------|-------|
| Voltage divider (solar/battery voltage) | GPIO34 (ADC) | Two resistors step panel voltage down to ESP32's 0-3.3V range |
| Current sensor (ACS712 or similar)      | GPIO35 (ADC) | Analog output, powered from 5V, output centered at ~2.5V |
| Temperature sensor (e.g. TMP36)         | GPIO32 (ADC) | Or swap for a DS18B20 on OneWire for better accuracy |

**Never feed more than 3.3V into an ESP32 ADC pin directly** — that's what the
voltage divider is for on the panel/battery line.

For per-circuit sensors (lights/fan/TV/fridge), see `docs/per-circuit-sensors.md` -
they use an external ADS1115 over I2C (GPIO21/GPIO22), separate from the pins above.

## 3. Calibrate before trusting the numbers

- **Voltage divider ratio**: measure your actual R1/R2 resistors and set
  `VOLTAGE_DIVIDER_RATIO = (R1 + R2) / R2`. Verify against a multimeter.
- **Current sensor**: check your ACS712 module's rating (5A/20A/30A variants differ) and set `ACS712_MV_PER_AMP`.
- **Temperature sensor**: the sketch assumes a TMP36-style linear analog sensor. Using a DS18B20 instead needs a different read function - ask and I'll swap it in.
- **Battery range**: `BATTERY_EMPTY_V`/`BATTERY_FULL_V` assume 12V lead-acid. Adjust for your battery chemistry.

## 4. Firebase config

Edit the config block at the top of `firebase_solar_monitor.ino`:

```cpp
const char* WIFI_SSID = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";
const char* FIREBASE_API_KEY = "YOUR_FIREBASE_WEB_API_KEY";
const char* FIREBASE_DATABASE_URL = "https://YOUR_PROJECT-default-rtdb.YOUR_REGION.firebasedatabase.app";
const char* FIREBASE_DEVICE_EMAIL = "device@example.com";
const char* FIREBASE_DEVICE_PASSWORD = "YOUR_DEVICE_ACCOUNT_PASSWORD";
```

All of these come from `docs/firebase-setup.md` - the API key and database URL
from your web app config, the device email/password from the Auth account you
created there.

**About `client.setInsecure()`:** the sketch skips TLS certificate validation
for simplicity, which is standard practice in ESP32 hobby projects (cert
pinning on an ESP32 is a bigger lift - storage-constrained, and Google
rotates its certs periodically which would break a pinned cert). It still
uses HTTPS (encrypted), just without verifying the server's identity against
a known root. Fine for a personal project; if you want to harden it later,
look into `WiFiClientSecure::setCACert()` with Google's root CA.

## 5. Upload & verify

Open the Serial Monitor (115200 baud) after uploading. You should see WiFi
connect, "Firebase sign-in OK", then a reading line every 5 seconds. Check
the Firebase console's Realtime Database tab - you should see `/readings/latest`
and `/system/lastSeen` updating live.

If sign-in fails, double check the device email/password match exactly what
you created in Firebase Auth, and that Email/Password sign-in is enabled
under Authentication > Sign-in method.


## Update: power_management sketch and secrets

`power_management/` is the sketch the Flutter app is built around (per-system paths, power status, relays, remote control, automatic load control). `firebase_solar_monitor/` is an older, simpler sketch that writes to the old unnamespaced paths and will not work with the new database rules.

Before compiling `power_management`, copy `power_management/secrets.h.example` to `secrets.h` and fill in your Wi-Fi, Firebase and (optional) MQTT details. `secrets.h` is git-ignored. See `docs/security.md`.
