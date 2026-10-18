// ESP32 - Full solar power management system, wired to match the Flutter app's schema
// Solar monitoring | Battery monitoring + % | Auto grid/inverter switching
// Safety cutoff | Remote-controlled load relay | Firebase sync

#include <WiFi.h>
#include <time.h>
#include <PubSubClient.h>
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"

// Requires "PubSubClient" by Nick O'Leary (Library Manager) for MQTT.

// ================= Secrets (NOT stored in this file) =================
// Wi-Fi, Firebase and MQTT credentials live in secrets.h next to this sketch.
// Copy secrets.h.example to secrets.h and fill it in. secrets.h is listed in
// .gitignore so it is never committed or shared by accident.
#include "secrets.h"


// ================= Multi-system identity =================
// Must match the "System ID" shown in the app's Settings > Device Setup
// panel. Everything below is namespaced under systems/<SYSTEM_ID>/ in
// Firebase so multiple boards can share one project without colliding.
#define SYSTEM_ID "default"


// ================= MQTT (optional, alongside Firebase) =================
// Host/port/credentials come from secrets.h. Leave MQTT_BROKER_HOST empty to skip MQTT.
// Local-network control path - lower latency than Firebase when the phone
// and broker are on the same WiFi.

#ifdef MQTT_USE_TLS
#include <WiFiClientSecure.h>
WiFiClientSecure mqttNetClient;   // define MQTT_USE_TLS and MQTT_CA_CERT in secrets.h
#else
WiFiClient mqttNetClient;
#endif
PubSubClient mqttClient(mqttNetClient);
String mqttReadingsTopic;
String mqttStatusTopic;
String mqttChannel1Topic;
String mqttChannel2Topic;
String mqttResetSafetyTopic;

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
bool firebaseReady = false;
unsigned long lastUpload = 0;
unsigned long uploadInterval = 5000; // matches AppSettings.readingIntervalSec default

// ================= Solar sensors (between panel and charge controller) =================
const int solarVoltPin = 36;
const int solarCurrentPin = 35;

// ================= Battery sensors (between battery and inverter) =================
const int battVoltPin = 34;
const int battCurrentPin = 33;

// ================= Temperature sensor (optional) =================
// Set TEMP_SENSOR_PRESENT to true after fitting a TMP36 (or similar) on tempPin.
// While false, the temperature field is left out of the upload so the app shows
// "No sensor" instead of a fake 0 C, and the temperature alert stays inactive.
const bool TEMP_SENSOR_PRESENT = false;
const int tempPin = 39;   // ADC1 input-only pin, unused elsewhere in this sketch
float readTemperatureC() {
  int adc = analogRead(tempPin);
  float v = (adc * 3.3) / 4095.0;   // volts at the pin
  return (v - 0.5) * 100.0;         // TMP36: 10 mV per degree C, 500 mV offset
}

float R1 = 30000.0, R2 = 7500.0;    // voltage sensors' own divider
float R3 = 10000.0, R4 = 10000.0;   // your added divider on voltage sensors
float R5 = 10000.0, R6 = 10000.0;   // your added divider on current sensors
float sensitivity = 0.100;          // V/A -- match your ACS712 model
float acsZero_solar = 2.5, acsZero_batt = 2.5;  // calibrate each individually

float refVoltage = 3.3;
int adcResolution = 4095;

// ================= Battery % (lookup table + coulomb counting) =================
const int numPoints = 11;
float voltageTable[numPoints] = {10.50, 11.31, 11.58, 11.75, 11.90, 12.06, 12.20, 12.32, 12.42, 12.50, 12.70};
float percentTable[numPoints] = {0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100};

float batteryCapacityAh = 100.0;    // SET to your battery's rated Ah
float chargeRemainingAh = 0.0;
unsigned long lastCoulombMillis = 0;
float restCurrentThreshold = 0.15;
unsigned long restStartTime = 0;
bool inRestPeriod = false;
unsigned long restDurationNeeded = 5UL * 60UL * 1000UL;

// ================= Mains presence sensing =================
const int mainsSensePin = 32;
float presenceThreshold = 2.5;

// ================= Transfer switch relay (grid/inverter) =================
const int transferRelayPin = 25;    // wired to BOTH IN1 and IN2
const bool transferActiveLow = false;
bool usingInverter = false;
unsigned long debounceDelay = 3000;
unsigned long lastChangeTime = 0;
bool lastRawMainsState = true;
bool stableMainsState = true;

// ================= Safety cutoff relay =================
const int safetyRelayPin = 26;
const bool safetyActiveLow = false;
bool faultLatched = false;
unsigned long faultConditionStart = 0;
unsigned long faultConfirmDelay = 1000;
bool faultConditionActive = false;
float maxLoadCurrent = 26.0;        // SET to your inverter/wiring rating
float maxBatteryVoltage = 24.5;
float minBatteryVoltage = 10.5;

// ================= Load control relay (independent, remote controlled) =================
const int loadCh1Pin = 27;          // bulb
const int loadCh2Pin = 14;          // appliance
const bool loadActiveLow = false;
bool ch1State = false;
bool ch2State = false;

// ============================================================
// Sensor reading
// ============================================================
float readVoltage(int pin) {
  int adc = analogRead(pin);
  float vAtPin = (adc * refVoltage) / adcResolution;
  float vAtSensorOut = vAtPin / (R4 / (R3 + R4));
  float v = vAtSensorOut / (R2 / (R1 + R2));
  return (v < 0.09) ? 0.0 : v;
}

float readCurrent(int pin, float acsZero) {
  int adc = analogRead(pin);
  float iAtPin = (adc * refVoltage) / adcResolution;
  float acsOut = iAtPin / (R6 / (R5 + R6));
  float i = (acsOut - acsZero) / sensitivity;
  return (abs(i) < 0.05) ? 0.0 : i;
}

float readMainsSensorVoltage() {
  int adc = analogRead(mainsSensePin);
  float vAtPin = (adc * refVoltage) / adcResolution;
  return vAtPin / (R2 / (R1 + R2));
}

bool readMainsPresent() {
  return readMainsSensorVoltage() > presenceThreshold;
}

// ============================================================
// Transfer switch (grid/inverter)
// ============================================================
void setPowerSource(bool useInverter_) {
  if (useInverter_ == usingInverter) return;
  bool pinState = transferActiveLow ? !useInverter_ : useInverter_;
  digitalWrite(transferRelayPin, pinState);
  usingInverter = useInverter_;
  Serial.print(">> Source: ");
  Serial.println(usingInverter ? "INVERTER" : "GRID");
}

void updateTransferSwitch() {
  bool rawMains = readMainsPresent();
  unsigned long now = millis();
  if (rawMains != lastRawMainsState) {
    lastChangeTime = now;
    lastRawMainsState = rawMains;
  }
  if (rawMains != stableMainsState && (now - lastChangeTime) >= debounceDelay) {
    stableMainsState = rawMains;
    setPowerSource(!stableMainsState);
  }
}

// ============================================================
// Safety cutoff
// ============================================================
void raiseAlert(const char* level, const char* title, const char* message);

void tripSafety() {
  digitalWrite(safetyRelayPin, safetyActiveLow ? LOW : HIGH);
  faultLatched = true;
}

void resetSafety() {
  digitalWrite(safetyRelayPin, safetyActiveLow ? HIGH : LOW);
  faultLatched = false;
  faultConditionActive = false;
  Serial.println(">> Safety relay reset");
}

void checkFaults(float loadCurrent, float batteryVoltage) {
  if (faultLatched) return;
  bool faultNow = (abs(loadCurrent) > maxLoadCurrent) ||
                  (batteryVoltage > maxBatteryVoltage) ||
                  (batteryVoltage < minBatteryVoltage && batteryVoltage > 0.5);
  unsigned long now = millis();
  if (faultNow) {
    if (!faultConditionActive) {
      faultConditionActive = true;
      faultConditionStart = now;
    } else if (now - faultConditionStart >= faultConfirmDelay) {
      Serial.println("!! FAULT - safety relay tripped !!");
      tripSafety();
      raiseAlert("error", "Safety cutoff tripped", "Load current, or battery voltage, went out of range.");
    }
  } else {
    faultConditionActive = false;
  }
}

// ============================================================
// Load control relay - independent channels, remote controllable
// ============================================================
void setChannel(int channel, bool on) {
  int pin = (channel == 1) ? loadCh1Pin : loadCh2Pin;
  digitalWrite(pin, loadActiveLow ? !on : on);
  if (channel == 1) ch1State = on; else ch2State = on;
  Serial.print(">> Channel "); Serial.print(channel);
  Serial.println(on ? ": ON" : ": OFF");
}

// ============================================================
// Automatic load control (battery protection and solar surplus)
// ============================================================
// Runs ON THE DEVICE, so it keeps working when Wi-Fi or the cloud is down.
// Enabled from the app (Settings > Automatic Load Control).
// Only channel 2 (the non-essential appliance) is ever switched automatically;
// channel 1 (essential lighting) is never touched.
//
//  R1 Protect battery: running on the inverter (mains absent) and battery % below
//     shedBelowPct  ->  switch channel 2 OFF. Switch it back ON when battery % reaches
//     restoreAbovePct or mains power returns. Only a shed made by this rule is undone.
//  R2 Use surplus: battery nearly full (>= 95 %) and strong solar (>= surplusSolarW)
//     ->  switch channel 2 ON; switch it OFF again when the surplus ends.
//     Not used if the user switched channel 2 off by hand.
//
// A manual command always wins: switching channel 2 by hand cancels the automation's
// hold on it, and if the user turns it back ON during a shed, no further shedding
// happens until the battery has recovered above restoreAbovePct.
bool autoLoadControl = false;    // /settings/autoLoadControl
float shedBelowPct = 20.0;       // /settings/shedBelowPct
float restoreAbovePct = 35.0;    // /settings/restoreAbovePct
float surplusSolarW = 25.0;      // solar watts that count as "surplus" (tune to your panel)
bool autoShed = false;           // channel 2 is off because of R1
bool autoSurplusOn = false;      // channel 2 is on because of R2
bool shedOverride = false;       // user re-enabled channel 2 during a shed
bool ch2ManualOff = false;       // user deliberately switched channel 2 off

// Keep the stored "desired state" in Firebase equal to the real state, otherwise
// the periodic control poll would switch the relay straight back.
void mirrorChannelToFirebase(int channel, bool on) {
  if (!firebaseReady || !Firebase.ready()) return;
  Firebase.RTDB.setBool(&fbdo, (String("/systems/") + SYSTEM_ID + "/control/channel" + String(channel)).c_str(), on);
}

// A command from the user (app, MQTT or serial).
void setChannelManual(int channel, bool on) {
  if (channel == 2) {
    if (on && autoShed) shedOverride = true;   // user overrides the shed
    autoShed = false;
    autoSurplusOn = false;
    ch2ManualOff = !on;
  }
  setChannel(channel, on);
}

// A change made by the automation itself.
void setChannelAuto(int channel, bool on) {
  setChannel(channel, on);
  mirrorChannelToFirebase(channel, on);
}

void applyAutomation(float battPercent, float solarWatts) {
  if (!autoLoadControl) {
    // Turning the feature off hands control back to the user
    autoShed = false;
    autoSurplusOn = false;
    shedOverride = false;
    return;
  }
  float restore = restoreAbovePct;
  if (restore < shedBelowPct + 5.0f) restore = shedBelowPct + 5.0f;   // keep a gap (hysteresis)
  bool recovered = (battPercent >= restore) || !usingInverter;

  // R1 - protect the battery
  if (!shedOverride && !autoShed && usingInverter && battPercent < shedBelowPct && ch2State) {
    setChannelAuto(2, false);
    autoShed = true;
    autoSurplusOn = false;
    raiseAlert("warning", "Load shed automatically", "Battery is low - appliance (channel 2) switched off to protect it.");
  } else if (autoShed && recovered) {
    setChannelAuto(2, true);
    autoShed = false;
    raiseAlert("info", "Load restored", "Battery recovered or mains is back - appliance (channel 2) switched back on.");
  }
  if (shedOverride && recovered) shedOverride = false;

  // R2 - use surplus solar
  bool surplus = (battPercent >= 95.0f && solarWatts >= surplusSolarW);
  if (surplus && !ch2State && !autoShed && !autoSurplusOn && !ch2ManualOff && !faultLatched) {
    setChannelAuto(2, true);
    autoSurplusOn = true;
  } else if (autoSurplusOn && (battPercent < 90.0f || solarWatts < surplusSolarW * 0.5f)) {
    setChannelAuto(2, false);
    autoSurplusOn = false;
  }
}

// ============================================================
// Battery percentage
// ============================================================
float batteryPercentage(float v) {
  if (v <= voltageTable[0]) return 0.0;
  if (v >= voltageTable[numPoints - 1]) return 100.0;
  for (int i = 0; i < numPoints - 1; i++) {
    if (v >= voltageTable[i] && v <= voltageTable[i + 1]) {
      float slope = (percentTable[i + 1] - percentTable[i]) / (voltageTable[i + 1] - voltageTable[i]);
      return percentTable[i] + slope * (v - voltageTable[i]);
    }
  }
  return 0.0;
}

float updateBatteryPercent(float netCurrent, float batteryVoltage) {
  unsigned long now = millis();
  float dtHours = (now - lastCoulombMillis) / 3600000.0;
  lastCoulombMillis = now;

  chargeRemainingAh += netCurrent * dtHours;
  chargeRemainingAh = constrain(chargeRemainingAh, 0.0, batteryCapacityAh);
  float battPercent = (chargeRemainingAh / batteryCapacityAh) * 100.0;

  if (abs(netCurrent) < restCurrentThreshold) {
    if (!inRestPeriod) {
      inRestPeriod = true;
      restStartTime = now;
    } else if (now - restStartTime >= restDurationNeeded) {
      float voltagePercent = batteryPercentage(batteryVoltage);
      chargeRemainingAh = batteryCapacityAh * (voltagePercent / 100.0);
      battPercent = voltagePercent;
      inRestPeriod = false;
    }
  } else {
    inRestPeriod = false;
  }
  return battPercent;
}

// ============================================================
// Firebase - schema matched to lib/models/sensor_models.dart /
// lib/services/solar_data_service.dart
// ============================================================

void raiseAlert(const char* level, const char* title, const char* message) {
  if (!firebaseReady || !Firebase.ready()) return;
  FirebaseJson json;
  json.set("level", level);
  json.set("title", title);
  json.set("message", message);
  json.set("timestamp", (double)nowEpochMs());
  Firebase.RTDB.pushJSON(&fbdo, (String("/systems/") + SYSTEM_ID + "/alerts").c_str(), &json);
}

// Real-world epoch ms (set via NTP in setup). Used for every timestamp/
// lastSeen field instead of millis(), which is device-uptime, not
// wall-clock time, and made the app think devices were always offline.
unsigned long long nowEpochMs() {
  time_t now;
  time(&now);
  return (unsigned long long)now * 1000ULL;
}

void firebaseUpload(float battV, float battI, float battP, float battPercent,
                     float solarV, float solarI) {
  if (!firebaseReady || !Firebase.ready()) return;

  // Matches Reading.fromMap: voltage, current, temperature, batteryPercent, power, timestamp
  FirebaseJson reading;
  reading.set("voltage", battV);
  reading.set("current", battI);
  if (TEMP_SENSOR_PRESENT) reading.set("temperature", readTemperatureC());
  reading.set("solarPower", solarV * solarI);   // watts, used for solar energy totals
  reading.set("batteryPercent", battPercent);
  reading.set("power", battP);
  reading.set("timestamp", (double)nowEpochMs());

  Firebase.RTDB.setJSON(&fbdo, (String("/systems/") + SYSTEM_ID + "/readings/latest").c_str(), &reading);
  Firebase.RTDB.pushJSON(&fbdo, (String("/systems/") + SYSTEM_ID + "/readings/history").c_str(), &reading);

  // Heartbeat so the app can show the device as online/offline
  Firebase.RTDB.setDouble(&fbdo, (String("/systems/") + SYSTEM_ID + "/system/lastSeen").c_str(), (double)nowEpochMs());

  // Solar-side numbers + power-management status. Doesn't conflict with
  // anything the app currently reads - the app's PowerStatus stream reads
  // this same path.
  FirebaseJson status;
  status.set("solarVoltage", solarV);
  status.set("solarCurrent", solarI);
  status.set("source", usingInverter ? "inverter" : "grid");
  status.set("mainsPresent", stableMainsState);
  status.set("faultTripped", faultLatched);
  status.set("channel1", ch1State);
  status.set("channel2", ch2State);
  status.set("autoMode", autoLoadControl);
  status.set("autoShed", autoShed);
  Firebase.RTDB.setJSON(&fbdo, (String("/systems/") + SYSTEM_ID + "/system/powerStatus").c_str(), &status);

  // Mirror both onto MQTT too, if a broker is configured - alongside
  // Firebase, not instead of it.
  if (mqttClient.connected()) {
    String readingJson;
    reading.toString(readingJson);
    mqttClient.publish(mqttReadingsTopic.c_str(), readingJson.c_str());

    String statusJson;
    status.toString(statusJson);
    mqttClient.publish(mqttStatusTopic.c_str(), statusJson.c_str());
  }
}

// ============================================================
// MQTT - local-network control alongside Firebase. Topics mirror the
// Firebase path layout: systems/<SYSTEM_ID>/readings, .../status,
// .../control/channel1, .../control/channel2, .../control/resetSafety.
// ============================================================

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String message;
  for (unsigned int i = 0; i < length; i++) message += (char)payload[i];
  message.trim();

  String t = String(topic);
  bool on = (message == "1" || message == "true" || message == "ON");

  if (t == mqttChannel1Topic) {
    setChannelManual(1, on);
    mirrorChannelToFirebase(1, on);
  } else if (t == mqttChannel2Topic) {
    setChannelManual(2, on);
    mirrorChannelToFirebase(2, on);
  } else if (t == mqttResetSafetyTopic) {
    if (on && faultLatched) resetSafety();
  }
}

void connectMqtt() {
  if (strlen(MQTT_BROKER_HOST) == 0) return;  // MQTT not configured - Firebase-only
  if (mqttClient.connected()) return;

  String clientId = String("esp32-") + SYSTEM_ID;
  Serial.print("Connecting to MQTT broker... ");
  bool mqttOk = (strlen(MQTT_USER) > 0)
                    ? mqttClient.connect(clientId.c_str(), MQTT_USER, MQTT_PASS)
                    : mqttClient.connect(clientId.c_str());
  if (mqttOk) {
    Serial.println("connected.");
    mqttClient.subscribe(mqttChannel1Topic.c_str());
    mqttClient.subscribe(mqttChannel2Topic.c_str());
    mqttClient.subscribe(mqttResetSafetyTopic.c_str());
  } else {
    Serial.print("failed, rc=");
    Serial.println(mqttClient.state());
  }
}

void firebasePollControl() {
  if (!firebaseReady || !Firebase.ready()) return;

  if (Firebase.RTDB.getBool(&fbdo, (String("/systems/") + SYSTEM_ID + "/control/channel1").c_str())) {
    bool desired = fbdo.boolData();
    if (desired != ch1State) setChannelManual(1, desired);
  }
  if (Firebase.RTDB.getBool(&fbdo, (String("/systems/") + SYSTEM_ID + "/control/channel2").c_str())) {
    bool desired = fbdo.boolData();
    if (desired != ch2State) setChannelManual(2, desired);
  }
  if (Firebase.RTDB.getBool(&fbdo, (String("/systems/") + SYSTEM_ID + "/control/resetSafety").c_str())) {
    if (fbdo.boolData() && faultLatched) {
      resetSafety();
      Firebase.RTDB.setBool(&fbdo, (String("/systems/") + SYSTEM_ID + "/control/resetSafety").c_str(), false);
    }
  }
}

// Poll /settings/readingIntervalSec so the app's Settings screen can
// change upload frequency, same as firebase_solar_monitor.ino does.
unsigned long lastSettingsPoll = 0;
const unsigned long settingsPollMs = 30000;

void pollSettings() {
  if (Firebase.RTDB.getFloat(&fbdo, (String("/systems/") + SYSTEM_ID + "/settings/readingIntervalSec").c_str())) {
    float seconds = fbdo.floatData();
    if (seconds >= 1.0) {
      uploadInterval = (unsigned long)(seconds * 1000);
    }
  }
  String base = String("/systems/") + SYSTEM_ID + "/settings/";
  if (Firebase.RTDB.getBool(&fbdo, (base + "autoLoadControl").c_str())) autoLoadControl = fbdo.boolData();
  if (Firebase.RTDB.getFloat(&fbdo, (base + "shedBelowPct").c_str())) shedBelowPct = fbdo.floatData();
  if (Firebase.RTDB.getFloat(&fbdo, (base + "restoreAbovePct").c_str())) restoreAbovePct = fbdo.floatData();
}

// ============================================================
// Serial command interface (bench-testing convenience alongside
// Firebase/MQTT). Grid/inverter switching is NOT controllable here -
// always automatic.
// ============================================================
void printHelp() {
  Serial.println("== Commands ==");
  Serial.println("1 = toggle channel 1 (bulb)");
  Serial.println("2 = toggle channel 2 (appliance)");
  Serial.println("r = reset safety trip");
  Serial.println("h = show this help");
  Serial.println("(Grid/inverter switching is automatic only - no manual command)");
}

void handleSerialCommands() {
  if (Serial.available() == 0) return;
  char cmd = Serial.read();

  switch (cmd) {
    case '1': setChannelManual(1, !ch1State); mirrorChannelToFirebase(1, ch1State); break;
    case '2': setChannelManual(2, !ch2State); mirrorChannelToFirebase(2, ch2State); break;
    case 'r': case 'R':
      if (faultLatched) resetSafety();
      else Serial.println(">> No fault to reset");
      break;
    case 'h': case 'H':
      printHelp();
      break;
    default: break;  // ignore newline/carriage return etc.
  }
}

// ============================================================
// Setup
// ============================================================
void setup() {
  Serial.begin(115200);
  analogReadResolution(12);

  pinMode(transferRelayPin, OUTPUT);
  pinMode(safetyRelayPin, OUTPUT);
  pinMode(loadCh1Pin, OUTPUT);
  pinMode(loadCh2Pin, OUTPUT);

  resetSafety();
  setChannel(1, false);
  setChannel(2, false);

  bool mainsPresent = readMainsPresent();
  lastRawMainsState = mainsPresent;
  stableMainsState = mainsPresent;
  setPowerSource(!mainsPresent);

  float startVoltage = readVoltage(battVoltPin);
  chargeRemainingAh = batteryCapacityAh * (batteryPercentage(startVoltage) / 100.0);
  lastCoulombMillis = millis();

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(300);
  }
  Serial.println("\nConnected: " + WiFi.localIP().toString());

  // NTP sync - readings/lastSeen need real wall-clock time, not millis().
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  Serial.print("Syncing time");
  time_t now = time(nullptr);
  while (now < 100000) {  // still 1970 => not synced yet
    Serial.print(".");
    delay(300);
    now = time(nullptr);
  }
  Serial.println(" done.");

  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  config.token_status_callback = tokenStatusCallback;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  firebaseReady = true;

  // Register this system so it shows up in the app's Systems screen
  // automatically, without overwriting a display name someone already set.
  String indexPath = String("/systemsIndex/") + SYSTEM_ID + "/name";
  if (!Firebase.RTDB.getString(&fbdo, indexPath.c_str())) {
    Firebase.RTDB.setString(&fbdo, indexPath.c_str(), SYSTEM_ID);
  }

  mqttReadingsTopic = String("systems/") + SYSTEM_ID + "/readings";
  mqttStatusTopic = String("systems/") + SYSTEM_ID + "/status";
  mqttChannel1Topic = String("systems/") + SYSTEM_ID + "/control/channel1";
  mqttChannel2Topic = String("systems/") + SYSTEM_ID + "/control/channel2";
  mqttResetSafetyTopic = String("systems/") + SYSTEM_ID + "/control/resetSafety";
  if (strlen(MQTT_BROKER_HOST) > 0) {
#ifdef MQTT_USE_TLS
    mqttNetClient.setCACert(MQTT_CA_CERT);   // verifies the broker's certificate
#endif
    mqttClient.setServer(MQTT_BROKER_HOST, MQTT_BROKER_PORT);
    mqttClient.setCallback(mqttCallback);
    connectMqtt();
  }

  Serial.println("== System ready ==");
  printHelp();
}

// ============================================================
// Main loop
// ============================================================
void loop() {
  handleSerialCommands();

  float solarVoltage = readVoltage(solarVoltPin);
  float solarCurrent = readCurrent(solarCurrentPin, acsZero_solar);

  float batteryVoltage = readVoltage(battVoltPin);
  float batteryCurrent = readCurrent(battCurrentPin, acsZero_batt);  // draw toward inverter
  float batteryPower = batteryVoltage * batteryCurrent;

  float netCurrent = solarCurrent - batteryCurrent;   // charging in minus draw out
  float battPercent = updateBatteryPercent(netCurrent, batteryVoltage);

  updateTransferSwitch();
  checkFaults(batteryCurrent, batteryVoltage);
  applyAutomation(battPercent, solarVoltage * solarCurrent);

  if (strlen(MQTT_BROKER_HOST) > 0) {
    if (!mqttClient.connected()) connectMqtt();
    mqttClient.loop();
  }

  static unsigned long lastPoll = 0;
  if (millis() - lastPoll > 1000) {
    firebasePollControl();
    lastPoll = millis();
  }

  if (millis() - lastSettingsPoll >= settingsPollMs) {
    lastSettingsPoll = millis();
    pollSettings();
  }

  if (millis() - lastUpload > uploadInterval) {
    firebaseUpload(batteryVoltage, batteryCurrent, batteryPower, battPercent,
                    solarVoltage, solarCurrent);
    lastUpload = millis();
  }

  Serial.print("Solar: "); Serial.print(solarVoltage * solarCurrent, 2); Serial.print("W  ");
  Serial.print("Batt: "); Serial.print(batteryVoltage, 2); Serial.print("V ");
  Serial.print(batteryCurrent, 2); Serial.print("A  ");
  Serial.print("Batt%: "); Serial.print(battPercent, 1); Serial.print("  ");
  Serial.print("Source: "); Serial.print(usingInverter ? "INV" : "GRID"); Serial.print("  ");
  Serial.print("Fault: "); Serial.println(faultLatched ? "YES" : "no");

  delay(500);
}
