import "package:flutter_test/flutter_test.dart";
import "package:solar_iot_project/models/sensor_models.dart";
import "package:solar_iot_project/services/alert_thresholds.dart";

class _FakeRaiser implements AlertRaiser {
  final raised = <List<String>>[];
  @override
  Future<void> raiseAlert(String level, String title, String message) async {
    raised.add([level, title, message]);
  }
}

Reading _reading({
  double voltage = 12.4,
  double batteryPercent = 80,
  double temperature = 30,
  bool hasTemperature = true,
}) =>
    Reading(
      timestamp: 1760000000000,
      voltage: voltage,
      current: 2,
      temperature: temperature,
      batteryPercent: batteryPercent,
      power: 25,
      hasTemperature: hasTemperature,
    );

void main() {
  const settings = AppSettings.defaults; // 45 C, 20 %, 10.5 V

  test("a healthy reading raises nothing", () {
    expect(evaluateThresholds(_reading(), settings), isEmpty);
  });

  test("high temperature raises a warning", () {
    final out = evaluateThresholds(_reading(temperature: 50), settings);
    expect(out.length, 1);
    expect(out.first.level, "warning");
    expect(out.first.title, "High Temperature");
  });

  test("exactly at the temperature limit does not alert", () {
    expect(evaluateThresholds(_reading(temperature: 45), settings), isEmpty);
  });

  test("temperature is ignored when no sensor is fitted", () {
    final out = evaluateThresholds(_reading(temperature: 99, hasTemperature: false), settings);
    expect(out, isEmpty);
  });

  test("low battery percentage raises a warning", () {
    final out = evaluateThresholds(_reading(batteryPercent: 10), settings);
    expect(out.map((a) => a.title), ["Low Battery"]);
    expect(out.first.level, "warning");
  });

  test("low battery voltage raises an error", () {
    final out = evaluateThresholds(_reading(voltage: 9.5), settings);
    expect(out.map((a) => a.title), ["Low Battery Voltage"]);
    expect(out.first.level, "error");
  });

  test("user-set limits are respected", () {
    final custom = settings.copyWith(batteryLowPct: 50, tempLimitC: 30);
    final titles = evaluateThresholds(_reading(batteryPercent: 40, temperature: 35), custom)
        .map((a) => a.title)
        .toList();
    expect(titles, containsAll(["Low Battery", "High Temperature"]));
  });

  test("several breaches raise several alerts", () {
    final out = evaluateThresholds(
        _reading(temperature: 60, batteryPercent: 5, voltage: 9), settings);
    expect(out.length, 3);
  });

  test("checkThresholds forwards every candidate to the raiser", () {
    final raiser = _FakeRaiser();
    checkThresholds(_reading(batteryPercent: 5, voltage: 9), settings, raiser);
    expect(raiser.raised.map((r) => r[1]), ["Low Battery", "Low Battery Voltage"]);
  });
}
