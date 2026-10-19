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
}) =>
    Reading(
      timestamp: 1760000000000,
      voltage: voltage,
      current: 2,
      batteryPercent: batteryPercent,
      power: 25,
    );

void main() {
  const settings = AppSettings.defaults; // 20 %, 10.5 V

  test("a healthy reading raises nothing", () {
    expect(evaluateThresholds(_reading(), settings), isEmpty);
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
    final custom = settings.copyWith(batteryLowPct: 50, lowVoltageV: 12.6);
    final titles = evaluateThresholds(_reading(batteryPercent: 40), custom)
        .map((a) => a.title)
        .toList();
    expect(titles, containsAll(["Low Battery", "Low Battery Voltage"]));
  });

  test("several breaches raise several alerts", () {
    final out = evaluateThresholds(_reading(batteryPercent: 5, voltage: 9), settings);
    expect(out.length, 2);
  });

  test("checkThresholds forwards every candidate to the raiser", () {
    final raiser = _FakeRaiser();
    checkThresholds(_reading(batteryPercent: 5, voltage: 9), settings, raiser);
    expect(raiser.raised.map((r) => r[1]), ["Low Battery", "Low Battery Voltage"]);
  });
}
