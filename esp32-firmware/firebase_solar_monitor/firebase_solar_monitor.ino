/*
  SolarIoT - ESP32 firmware (Firebase Realtime Database edition)

  Reads voltage, current, temperature, battery %, and - optionally - 4
  per-circuit currents via an ADS1115, then writes everything straight to
  Firebase Realtime Database over HTTPS. No local backend server needed.

  Required libraries (Arduino IDE > Tools > Manage Libraries):
    - ArduinoJson, version 6.x (NOT 7.x - the API used here is v6's)
    - Adafruit ADS1X15 - ONLY needed if PER_CIRCUIT_SENSORS_ENABLED is true.
      If you haven't wired up per-circuit sensors yet, skip installing it;
      the code below detects its absence and compiles fine without it.
  WiFi.h, HTTPClient.h, WiFiClientSecure.h, Wire.h ship with the ESP32 board package.

  NOTE: this sketch was written and reviewed carefully but not compiled
  against real hardware - I don't have an ESP32 toolchain available here.
  Double check it compiles before relying on it, and see
  esp32-firmware/README.md for troubleshooting tips.
*/

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Wire.h>

#if __has_include(<Adafruit_ADS1X15.h>)
  #include <Adafruit_ADS1X15.h>
  #define HAS_ADS1115_LIB 1
#else
  #define HAS_ADS1115_LIB 0
#endif

// ================= CONFIG - EDIT THESE =================
const char* WIFI_SSID = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

// Firebase console > Project settings > General > Web API Key
const char* FIREBASE_API_KEY = "YOUR_FIREBASE_WEB_API_KEY";
// Firebase console > Realtime Database (top of page), e.g.
// https://xxx-default-rtdb.europe-west1.firebasedatabase.app
const char* FIREBASE_DATABASE_URL = "https://YOUR_PROJECT-default-rtdb.YOUR_REGION.firebasedatabase.app";
// The device account you created in Firebase Auth - see docs/firebase-setup.md step 3
const char* FIREBASE_DEVICE_EMAIL = "esp32-device@solariot.local";
const char* FIREBASE_DEVICE_PASSWORD = "YOUR_DEVICE_ACCOUNT_PASSWORD";

// Set to true only once you've wired up the CT sensors + ADS1115 from
// docs/per-circuit-sensors.md. Leave false to just run the main sensors.
const bool PER_CIRCUIT_SENSORS_ENABLED = false;
const float MAINS_VOLTAGE = 230.0; // change to 120.0 if that's your region
const float CT_RATIO = 30.0;       // SCT-013-030: 30A -> 1V RMS output

// Main sensor ADC pins
const int VOLTAGE_PIN = 34;
const int CURRENT_PIN = 35;
const int TEMP_PIN = 32;

const float VOLTAGE_DIVIDER_RATIO = 5.0;
const float ACS712_MV_PER_AMP = 100.0;
const float ACS712_ZERO_OFFSET_V = 2.5;
const float BATTERY_EMPTY_V = 11.8;
const float BATTERY_FULL_V = 12.7;

unsigned long SEND_INTERVAL_MS = 5000; // overwritten by /settings if present
const unsigned long SETTINGS_POLL_MS = 30000;
// =========================================================

const float ADC_REF_VOLTAGE = 3.3;
const int ADC_RESOLUTION = 4095;

String idToken;
String refreshToken;
unsigned long tokenExpiresAt = 0; // millis()-relative deadline

unsigned long lastSend = 0;
unsigned long lastSettingsPoll = 0;

#if HAS_ADS1115_LIB
Adafruit_ADS1115 ads;
#endif

const char* CIRCUIT_NAMES[4] = { "lights", "fan", "tv", "fridge" };

// ---------------- WiFi ----------------

void connectWiFi() {
  Serial.print("Connecting to WiFi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 20000) {
    delay(400);
    Serial.print(".");
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi connected. IP: " + WiFi.localIP().toString());
  } else {
    Serial.println("\nWiFi connect failed, will retry in loop()");
  }
}

// ---------------- Firebase Auth (REST API, no extra library) ----------------
// https://firebase.google.com/docs/reference/rest/auth

bool firebaseSignIn() {
  WiFiClientSecure client;
  client.setInsecure(); // skips TLS cert validation - simplest option for a
                         // hobby project; see esp32-firmware/README.md for
                         // how to harden this with a pinned root CA later.
  HTTPClient http;
  String url = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=" + String(FIREBASE_API_KEY);
  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");

  StaticJsonDocument<256> body;
  body["email"] = FIREBASE_DEVICE_EMAIL;
  body["password"] = FIREBASE_DEVICE_PASSWORD;
  body["returnSecureToken"] = true;
  String payload;
  serializeJson(body, payload);

  int code = http.POST(payload);
  bool ok = false;

  if (code == 200) {
    StaticJsonDocument<1536> res;
    deserializeJson(res, http.getStream());
    idToken = res["idToken"].as<String>();
    refreshToken = res["refreshToken"].as<String>();
    long expiresIn = res["expiresIn"].as<long>(); // seconds, usually 3600
    tokenExpiresAt = millis() + (unsigned long)((expiresIn - 120) * 1000L); // refresh 2 min early
    Serial.println("Firebase sign-in OK");
    ok = true;
  } else {
    Serial.printf("Firebase sign-in failed: %d\n", code);
    Serial.println(http.getString());
  }

  http.end();
  return ok;
}

bool firebaseRefreshToken() {
  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient http;
  String url = "https://securetoken.googleapis.com/v1/token?key=" + String(FIREBASE_API_KEY);
  http.begin(client, url);
  http.addHeader("Content-Type", "application/x-www-form-urlencoded");

  String body = "grant_type=refresh_token&refresh_token=" + refreshToken;
  int code = http.POST(body);
  bool ok = false;

  if (code == 200) {
    StaticJsonDocument<1536> res;
    deserializeJson(res, http.getStream());
    idToken = res["id_token"].as<String>();
    refreshToken = res["refresh_token"].as<String>();
    long expiresIn = res["expires_in"].as<long>();
    tokenExpiresAt = millis() + (unsigned long)((expiresIn - 120) * 1000L);
    ok = true;
  } else {
    Serial.printf("Token refresh failed: %d, re-signing in\n", code);
    ok = firebaseSignIn();
  }

  http.end();
  return ok;
}

void ensureFreshToken() {
  if (idToken.length() == 0) {
    firebaseSignIn();
  } else if ((long)(millis() - tokenExpiresAt) >= 0) {
    firebaseRefreshToken();
  }
}

// ---------------- Realtime Database REST helpers ----------------

bool rtdbPut(const String& path, const String& jsonBody) {
  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient http;
  String url = String(FIREBASE_DATABASE_URL) + path + ".json?auth=" + idToken;
  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  int code = http.PUT(jsonBody);
  if (code < 200 || code >= 300) {
    Serial.printf("PUT %s -> %d\n", path.c_str(), code);
  }
  http.end();
  return code >= 200 && code < 300;
}

bool rtdbPost(const String& path, const String& jsonBody) {
  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient http;
  String url = String(FIREBASE_DATABASE_URL) + path + ".json?auth=" + idToken;
  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  int code = http.POST(jsonBody);
  if (code < 200 || code >= 300) {
    Serial.printf("POST %s -> %d\n", path.c_str(), code);
  }
  http.end();
  return code >= 200 && code < 300;
}

// returns "" on failure
String rtdbGet(const String& path) {
  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient http;
  String url = String(FIREBASE_DATABASE_URL) + path + ".json?auth=" + idToken;
  http.begin(client, url);
  int code = http.GET();
  String result = "";
  if (code == 200) {
    result = http.getString();
  }
  http.end();
  return result;
}

// ---------------- Main sensors ----------------

float readVoltage() {
  int raw = analogRead(VOLTAGE_PIN);
  float vAtPin = (raw / (float)ADC_RESOLUTION) * ADC_REF_VOLTAGE;
  return vAtPin * VOLTAGE_DIVIDER_RATIO;
}

float readCurrent() {
  int raw = analogRead(CURRENT_PIN);
  float vAtPin = (raw / (float)ADC_RESOLUTION) * ADC_REF_VOLTAGE;
  return (vAtPin - ACS712_ZERO_OFFSET_V) / (ACS712_MV_PER_AMP / 1000.0);
}

float readTemperature() {
  int raw = analogRead(TEMP_PIN);
  float vAtPin = (raw / (float)ADC_RESOLUTION) * ADC_REF_VOLTAGE;
  return (vAtPin - 0.5) * 100.0; // TMP36 formula - adjust for your sensor
}

float estimateBatteryPercent(float voltage) {
  float pct = (voltage - BATTERY_EMPTY_V) / (BATTERY_FULL_V - BATTERY_EMPTY_V) * 100.0;
  if (pct < 0) pct = 0;
  if (pct > 100) pct = 100;
  return pct;
}

// ---------------- Per-circuit sensors (ADS1115) ----------------
// See docs/per-circuit-sensors.md for the full wiring + RMS-calculation theory.

#if HAS_ADS1115_LIB
float readCircuitRmsCurrent(uint8_t channel) {
  const int SAMPLES = 200;
  double sumSquares = 0;

  for (int i = 0; i < SAMPLES; i++) {
    int16_t raw = ads.readADC_SingleEnded(channel);
    float volts = ads.computeVolts(raw) - 1.65; // remove the bias midpoint
    sumSquares += (double)volts * (double)volts;
    delayMicroseconds(150); // spread samples across ~1-2 AC cycles
  }

  float vRms = sqrt(sumSquares / SAMPLES);
  return vRms * CT_RATIO; // CT sensor's V-to-A ratio
}
#endif

// ---------------- Setup / loop ----------------

void setup() {
  Serial.begin(115200);
  analogReadResolution(12);

  connectWiFi();
  ensureFreshToken();

#if HAS_ADS1115_LIB
  if (PER_CIRCUIT_SENSORS_ENABLED) {
    Wire.begin();
    if (!ads.begin()) {
      Serial.println("Failed to find ADS1115 - check wiring");
    }
  }
#endif
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }
  ensureFreshToken();

  if (millis() - lastSend >= SEND_INTERVAL_MS) {
    lastSend = millis();
    sendMainReading();

    if (PER_CIRCUIT_SENSORS_ENABLED) {
      sendCircuitReading();
    }

    // Heartbeat so the frontend can tell the device is online. Uses device
    // uptime, not wall-clock time - see esp32-firmware/README.md for NTP
    // if you want the timestamps to reflect real time instead.
    rtdbPut("/system/lastSeen", String((unsigned long long)millis()));
  }

  if (millis() - lastSettingsPoll >= SETTINGS_POLL_MS) {
    lastSettingsPoll = millis();
    pollSettings();
  }
}

void sendMainReading() {
  float voltage = readVoltage();
  float current = readCurrent();
  float temperature = readTemperature();
  float batteryPercent = estimateBatteryPercent(voltage);
  float power = voltage * current;

  Serial.printf("V=%.2f I=%.2f T=%.2f Batt=%.0f%%\n", voltage, current, temperature, batteryPercent);

  StaticJsonDocument<256> doc;
  doc["voltage"] = voltage;
  doc["current"] = current;
  doc["temperature"] = temperature;
  doc["batteryPercent"] = batteryPercent;
  doc["power"] = power;
  doc["timestamp"] = (unsigned long long)millis();
  String payload;
  serializeJson(doc, payload);

  rtdbPut("/readings/latest", payload);
  rtdbPost("/readings/history", payload);
}

#if HAS_ADS1115_LIB
void sendCircuitReading() {
  StaticJsonDocument<384> doc;
  doc["timestamp"] = (unsigned long long)millis();

  for (int i = 0; i < 4; i++) {
    float amps = readCircuitRmsCurrent(i);
    float watts = amps * MAINS_VOLTAGE;
    JsonObject circuit = doc.createNestedObject(CIRCUIT_NAMES[i]);
    circuit["current"] = amps;
    circuit["power"] = watts;
  }

  String payload;
  serializeJson(doc, payload);
  rtdbPut("/circuits/latest", payload);
  rtdbPost("/circuits/history", payload);
}
#else
void sendCircuitReading() {
  // Adafruit_ADS1X15 library not installed - install it and set
  // PER_CIRCUIT_SENSORS_ENABLED = true once your sensors are wired up.
}
#endif

void pollSettings() {
  String value = rtdbGet("/settings/readingIntervalSec");
  if (value.length() == 0) return;
  float seconds = value.toFloat();
  if (seconds >= 1.0) {
    SEND_INTERVAL_MS = (unsigned long)(seconds * 1000);
  }
}
