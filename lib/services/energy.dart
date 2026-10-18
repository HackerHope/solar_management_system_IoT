import "../models/sensor_models.dart";

/// Energy totals over a list of readings.
class EnergyTotals {
  final double usedWh;
  final double solarWh;
  const EnergyTotals(this.usedWh, this.solarWh);
  double get usedKwh => usedWh / 1000;
  double get solarKwh => solarWh / 1000;
}

/// Gaps longer than this between two readings are treated as "no data"
/// rather than assuming power stayed constant (device off / offline).
const int maxGapMs = 10 * 60 * 1000;

/// Integrates power over time using the trapezoid rule.
/// "Used" counts only positive battery power (energy drawn by the loads);
/// negative values (charging) are ignored. Readings may be in any order.
EnergyTotals integrateEnergy(List<Reading> readings) {
  if (readings.length < 2) return const EnergyTotals(0, 0);
  final sorted = [...readings]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  var used = 0.0;
  var solar = 0.0;
  for (var i = 1; i < sorted.length; i++) {
    final dtMs = sorted[i].timestamp - sorted[i - 1].timestamp;
    if (dtMs <= 0 || dtMs > maxGapMs) continue;
    final hours = dtMs / 3600000.0;
    final usedA = sorted[i - 1].power > 0 ? sorted[i - 1].power : 0.0;
    final usedB = sorted[i].power > 0 ? sorted[i].power : 0.0;
    used += (usedA + usedB) / 2 * hours;
    final solarA = sorted[i - 1].solarPower ?? 0.0;
    final solarB = sorted[i].solarPower ?? 0.0;
    solar += (solarA + solarB) / 2 * hours;
  }
  return EnergyTotals(used, solar);
}

/// Cost in kwacha. A tariff of 0 (or less) means "not set" and gives 0.
double costZmw(double wh, double tariffZmwPerKwh) {
  if (tariffZmwPerKwh <= 0) return 0;
  return wh / 1000 * tariffZmwPerKwh;
}
