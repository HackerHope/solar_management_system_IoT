import "package:flutter_test/flutter_test.dart";
import "package:solar_iot_project/models/sensor_models.dart";

void main() {
  group("Reading.fromMap", () {
    test("parses a full record", () {
      final r = Reading.fromMap({
        "timestamp": 1760000000000,
        "voltage": 12.4,
        "current": 3,
        "temperature": 31,
        "batteryPercent": 78,
        "power": 37.2,
        "solarPower": 20,
      });
      expect(r.timestamp, 1760000000000);
      expect(r.voltage, 12.4);
      expect(r.current, 3.0);
      expect(r.hasTemperature, isTrue);
      expect(r.temperature, 31.0);
      expect(r.batteryPercent, 78.0);
      expect(r.solarPower, 20.0);
    });

    test("uses safe defaults for a partial record instead of crashing", () {
      final r = Reading.fromMap({"voltage": 12});
      expect(r.timestamp, 0);
      expect(r.current, 0);
      expect(r.batteryPercent, 0);
      expect(r.solarPower, isNull);
    });

    test("a record without temperature means no sensor", () {
      final r = Reading.fromMap({"voltage": 12, "current": 1, "batteryPercent": 50});
      expect(r.hasTemperature, isFalse);
    });
  });

  group("AppSettings", () {
    test("null map gives defaults", () {
      expect(AppSettings.fromMap(null).tempLimitC, AppSettings.defaults.tempLimitC);
    });

    test("missing fields fall back to defaults", () {
      final s = AppSettings.fromMap({"tempLimitC": 50});
      expect(s.tempLimitC, 50);
      expect(s.batteryLowPct, 20);
      expect(s.lowVoltageV, 10.5);
      expect(s.autoLoadControl, isFalse);
      expect(s.tariffZmwPerKwh, 0);
    });

    test("toMap and fromMap round-trip", () {
      final original = AppSettings.defaults.copyWith(
        deviceName: "Home",
        autoLoadControl: true,
        shedBelowPct: 25,
        restoreAbovePct: 40,
        tariffZmwPerKwh: 1.5,
        mqttUseTls: true,
      );
      final copy = AppSettings.fromMap(original.toMap());
      expect(copy.deviceName, "Home");
      expect(copy.autoLoadControl, isTrue);
      expect(copy.shedBelowPct, 25);
      expect(copy.restoreAbovePct, 40);
      expect(copy.tariffZmwPerKwh, 1.5);
      expect(copy.mqttUseTls, isTrue);
    });
  });

  group("PowerStatus", () {
    test("parses fields and computes solar power", () {
      final p = PowerStatus.fromMap({
        "solarVoltage": 18,
        "solarCurrent": 2,
        "source": "inverter",
        "mainsPresent": false,
        "faultTripped": true,
        "channel1": true,
        "channel2": false,
        "autoMode": true,
        "autoShed": true,
      });
      expect(p.solarPower, 36);
      expect(p.source, "inverter");
      expect(p.mainsPresent, isFalse);
      expect(p.faultTripped, isTrue);
      expect(p.autoMode, isTrue);
      expect(p.autoShed, isTrue);
    });

    test("old firmware without auto fields defaults to off", () {
      final p = PowerStatus.fromMap({"solarVoltage": 1, "solarCurrent": 1});
      expect(p.autoMode, isFalse);
      expect(p.autoShed, isFalse);
      expect(p.source, "grid");
    });
  });

  test("alertLevelFromString maps known levels and defaults to info", () {
    expect(alertLevelFromString("warning"), AlertLevel.warning);
    expect(alertLevelFromString("error"), AlertLevel.error);
    expect(alertLevelFromString("something"), AlertLevel.info);
    expect(alertLevelFromString(null), AlertLevel.info);
  });

  test("DailyEnergy.fromMap", () {
    final d = DailyEnergy.fromMap("2026-10-13", {"usedWh": 1500, "solarWh": 2200.5});
    expect(d.date, "2026-10-13");
    expect(d.usedWh, 1500);
    expect(d.solarWh, 2200.5);
  });
}
