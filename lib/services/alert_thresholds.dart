import "../models/sensor_models.dart";

/// Anything that can store an alert: SolarDataService in the app, a fake in tests.
abstract class AlertRaiser {
  Future<void> raiseAlert(String level, String title, String message);
}

/// An alert that a reading would trigger (before any cooldown is applied).
class AlertCandidate {
  final String level;
  final String title;
  final String message;
  const AlertCandidate(this.level, this.title, this.message);
}

/// Pure rule evaluation, kept free of Firebase so it can be unit tested.
/// Keep in sync with functions/alerts.js (the server-side copy of these rules).
///
/// NOTE: with the power-management firmware, `voltage` is the BATTERY voltage.
List<AlertCandidate> evaluateThresholds(Reading reading, AppSettings settings) {
  final out = <AlertCandidate>[];

  if (reading.batteryPercent < settings.batteryLowPct) {
    out.add(AlertCandidate(
      "warning",
      "Low Battery",
      "Battery at ${reading.batteryPercent.toStringAsFixed(0)}% "
          "(alert below ${settings.batteryLowPct.toStringAsFixed(0)}%)",
    ));
  }
  if (reading.voltage < settings.lowVoltageV) {
    out.add(AlertCandidate(
      "error",
      "Low Battery Voltage",
      "Battery voltage dropped to ${reading.voltage.toStringAsFixed(2)}V "
          "(limit ${settings.lowVoltageV.toStringAsFixed(1)}V)",
    ));
  }
  return out;
}

void checkThresholds(Reading reading, AppSettings settings, AlertRaiser raiser) {
  for (final a in evaluateThresholds(reading, settings)) {
    raiser.raiseAlert(a.level, a.title, a.message);
  }
}
