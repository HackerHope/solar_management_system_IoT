import "package:flutter_test/flutter_test.dart";
import "package:solar_iot_project/models/sensor_models.dart";
import "package:solar_iot_project/services/energy.dart";

Reading _r(int ts, double power, {double? solar}) => Reading(
      timestamp: ts,
      voltage: 12,
      current: 1,
      batteryPercent: 50,
      power: power,
      solarPower: solar,
    );

const hour = 3600000;

void main() {
  test("fewer than two readings give zero", () {
    expect(integrateEnergy([]).usedWh, 0);
    expect(integrateEnergy([_r(0, 100)]).usedWh, 0);
  });

  test("constant 100 W for one hour is 100 Wh", () {
    final t = integrateEnergy([_r(0, 100, solar: 50), _r(hour, 100, solar: 50)]);
    expect(t.usedWh, closeTo(100, 1e-9));
    expect(t.solarWh, closeTo(50, 1e-9));
    expect(t.usedKwh, closeTo(0.1, 1e-12));
  });

  test("trapezoid: ramp from 0 to 200 W over one hour is 100 Wh", () {
    final t = integrateEnergy([_r(0, 0), _r(hour, 200)]);
    expect(t.usedWh, closeTo(100, 1e-9));
  });

  test("negative (charging) power does not count as used", () {
    final t = integrateEnergy([_r(0, -20), _r(hour, 40)]);
    expect(t.usedWh, closeTo(20, 1e-9)); // (0 + 40) / 2 * 1 h
  });

  test("readings in any order give the same result", () {
    final a = integrateEnergy([_r(0, 100), _r(hour, 100)]);
    final b = integrateEnergy([_r(hour, 100), _r(0, 100)]);
    expect(b.usedWh, a.usedWh);
  });

  test("a gap longer than 10 minutes is ignored", () {
    final t = integrateEnergy([_r(0, 100), _r(maxGapMs + 1, 100)]);
    expect(t.usedWh, 0);
  });

  test("duplicate timestamps add nothing", () {
    final t = integrateEnergy([_r(1000, 100), _r(1000, 100)]);
    expect(t.usedWh, 0);
  });

  test("missing solarPower counts as zero", () {
    final t = integrateEnergy([_r(0, 10), _r(hour, 10)]);
    expect(t.solarWh, 0);
  });

  group("costZmw", () {
    test("2 kWh at 3.5 per kWh is 7", () {
      expect(costZmw(2000, 3.5), closeTo(7.0, 1e-9));
    });
    test("tariff of zero or less means not set", () {
      expect(costZmw(2000, 0), 0);
      expect(costZmw(2000, -1), 0);
    });
  });
}
