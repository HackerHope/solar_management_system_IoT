// Pure alert and watchdog rules. No Firebase imports, so they can be unit tested.
// Keep the threshold rules in sync with lib/services/alert_thresholds.dart.

const COOLDOWN_MS = 5 * 60 * 1000; // same 5-minute cooldown as the app
const OFFLINE_AFTER_MS = 3 * 60 * 1000; // no heartbeat for 3 minutes => offline

const DEFAULT_SETTINGS = {
  batteryLowPct: 20,
  lowVoltageV: 10.5,
};

const isNum = (v) => typeof v === "number" && Number.isFinite(v);

/**
 * Alerts a reading would trigger, before the cooldown is applied.
 * NOTE: `voltage` is the BATTERY voltage with the power-management firmware.
 */
function evaluateReading(reading, settings = {}) {
  const s = { ...DEFAULT_SETTINGS, ...settings };
  const out = [];
  if (!reading) return out;

  if (isNum(reading.batteryPercent) && reading.batteryPercent < s.batteryLowPct) {
    out.push({
      level: "warning",
      title: "Low Battery",
      message: `Battery at ${reading.batteryPercent.toFixed(0)}% (alert below ${s.batteryLowPct.toFixed(0)}%)`,
    });
  }
  if (isNum(reading.voltage) && reading.voltage < s.lowVoltageV) {
    out.push({
      level: "error",
      title: "Low Battery Voltage",
      message: `Battery voltage dropped to ${reading.voltage.toFixed(2)}V (limit ${s.lowVoltageV.toFixed(1)}V)`,
    });
  }
  return out;
}

/** Realtime Database keys may not contain . # $ [ ] / so make a safe key. */
function alertKey(alert) {
  return `${alert.level}_${alert.title}`.replace(/[^A-Za-z0-9]+/g, "_");
}

/** True when enough time has passed since the same alert was last raised. */
function shouldRaise(lastRaisedMs, nowMs, cooldownMs = COOLDOWN_MS) {
  if (!isNum(lastRaisedMs)) return true;
  return nowMs - lastRaisedMs >= cooldownMs;
}

/**
 * Decide what the offline watchdog should do for one system.
 * lastSeenMs: device heartbeat (epoch ms), offlineMarker: lastSeen value for which
 * an "offline" alert was already raised (or null/undefined).
 * Returns "raise-offline", "raise-online" or "none".
 * Heartbeats that are not epoch milliseconds (old firmware using uptime) are ignored.
 */
function watchdogDecision(lastSeenMs, offlineMarker, nowMs, offlineAfterMs = OFFLINE_AFTER_MS) {
  if (!isNum(lastSeenMs) || lastSeenMs < 1e12) return "none";
  const stale = nowMs - lastSeenMs > offlineAfterMs;
  const alreadyAlerted = isNum(offlineMarker);
  if (stale && !alreadyAlerted) return "raise-offline";
  if (!stale && alreadyAlerted) return "raise-online";
  return "none";
}

module.exports = { evaluateReading, alertKey, shouldRaise, watchdogDecision, COOLDOWN_MS, OFFLINE_AFTER_MS, DEFAULT_SETTINGS };
