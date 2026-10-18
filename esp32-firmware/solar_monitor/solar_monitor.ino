/*
  SolarIoT - ESP32 firmware
  Reads voltage, current, temperature and estimates battery %,
  then POSTs a JSON reading to the backend every SEND_INTERVAL_MS.

  Required libraries (Arduino IDE > Tools > Manage Libraries):
    - ArduinoJson (by Benoit Blanchon)
  WiFi.h and HTTPClient.h ship with the ESP32 board package.

  Board: Tools > Board > ESP32 Dev Module (or your specific board)
*/

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// ================= CONFIG - EDIT THESE =================
const char* WIFI_SSID = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

// Use your computer's LAN IP and the backend port (see backend/README.md)
const char* SERVER_URL = "http://192.168.1.100:4000/api/readings";

// ADC pins - adjust to how you've wired your sensors
const int VOLTAGE_PIN = 34;  // voltage divider output
const int CURRENT_PIN = 35;  // ACS712 (or similar) output
const int TEMP_PIN = 32;     // analog temp sensor output (e.g. TMP36)

// Voltage divider: Vin = Vpin * (R1 + R2) / R2
// e.g. R1 = 30k, R2 = 7.5k  ->  ratio = 5.0, reads up to ~16.5V safely
const float VOLTAGE_DIVIDER_RATIO = 5.0;

// ACS712 current sensor calibration - check your module's datasheet
//   5A module  ~185 mV/A
//   20A module ~100 mV/A
//   30A module ~66 mV/A
const float ACS712_MV_PER_AMP = 100.0;
const float ACS712_ZERO_OFFSET_V = 2.5; // output at 0A is usually Vcc/2

// Battery voltage range used to estimate %  - set to YOUR battery chemistry
// Example below is for a 12V lead-acid battery
const float BATTERY_EMPTY_V = 11.8;
const float BATTERY_FULL_V = 12.7;

const unsigned long SEND_INTERVAL_MS = 5000;
// =========================================================

const float ADC_REF_VOLTAGE = 3.3;
const int ADC_RESOLUTION = 4095;

unsigned long lastSend = 0;

void connectWiFi() {
  Serial.print("Connecting to WiFi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 20000) {
    delay(400);
    Serial.print(".");
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nConnected. IP: " + WiFi.localIP().toString());
  } else {
    Serial.println("\nWiFi connect failed, will retry in loop()");
  }
}

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
  // TMP36 formula: 10mV/°C, 500mV offset at 0°C. Replace with your sensor's formula
  // (e.g. if using a DS18B20 over OneWire instead, skip the ADC read entirely).
  return (vAtPin - 0.5) * 100.0;
}

float estimateBatteryPercent(float voltage) {
  float pct = (voltage - BATTERY_EMPTY_V) / (BATTERY_FULL_V - BATTERY_EMPTY_V) * 100.0;
  if (pct < 0) pct = 0;
  if (pct > 100) pct = 100;
  return pct;
}

void sendReading(float voltage, float current, float temperature, float batteryPercent) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Skipping send - WiFi not connected");
    return;
  }

  HTTPClient http;
  http.begin(SERVER_URL);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(5000);

  StaticJsonDocument<200> doc;
  doc["voltage"] = voltage;
  doc["current"] = current;
  doc["temperature"] = temperature;
  doc["batteryPercent"] = batteryPercent;

  String payload;
  serializeJson(doc, payload);

  int code = http.POST(payload);
  if (code > 0) {
    Serial.printf("POST %d\n", code);
  } else {
    Serial.printf("POST failed: %s\n", http.errorToString(code).c_str());
  }
  http.end();
}

void setup() {
  Serial.begin(115200);
  analogReadResolution(12); // ESP32 ADC is 12-bit (0-4095)
  connectWiFi();
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }

  if (millis() - lastSend >= SEND_INTERVAL_MS) {
    lastSend = millis();

    float voltage = readVoltage();
    float current = readCurrent();
    float temperature = readTemperature();
    float batteryPercent = estimateBatteryPercent(voltage);

    Serial.printf("V=%.2f  I=%.2f  T=%.2f  Batt=%.0f%%\n", voltage, current, temperature, batteryPercent);
    sendReading(voltage, current, temperature, batteryPercent);
  }
}
