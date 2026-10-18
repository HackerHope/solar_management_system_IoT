// Pure energy accumulation, kept free of Firebase for unit testing.
// Mirrors lib/services/energy.dart (trapezoid rule, 10 minute gap limit).

const MAX_GAP_MS = 10 * 60 * 1000;
const HOUR_MS = 3600000;

const isNum = (v) => typeof v === "number" && Number.isFinite(v);
const pad = (n) => String(n).padStart(2, "0");

/** yyyy-MM-dd and yyyy-MM-dd-HH keys in a fixed UTC offset (Zambia, CAT = +2). */
function timeKeys(tsMs, tzOffsetHours = 2) {
  const d = new Date(tsMs + tzOffsetHours * HOUR_MS);
  const day = `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
  return { day, hour: `${day}-${pad(d.getUTCHours())}` };
}

/**
 * Given the previous sample (or null) and the new reading, returns the energy to
 * add (Wh) and the new "previous sample" to store.
 * Readings whose timestamp is not epoch milliseconds (old uptime-based firmware)
 * are ignored and leave the state unchanged.
 */
function accumulate(prev, reading, tzOffsetHours = 2) {
  if (!reading || !isNum(reading.timestamp) || reading.timestamp < 1e12) {
    return { next: prev || null, usedWh: 0, solarWh: 0, keys: null };
  }
  const ts = reading.timestamp;
  const usedW = isNum(reading.power) && reading.power > 0 ? reading.power : 0;
  const solarW = isNum(reading.solarPower) && reading.solarPower > 0 ? reading.solarPower : 0;
  const next = { ts, usedW, solarW };
  const keys = timeKeys(ts, tzOffsetHours);

  if (!prev || !isNum(prev.ts)) return { next, usedWh: 0, solarWh: 0, keys };
  const dt = ts - prev.ts;
  if (dt <= 0 || dt > MAX_GAP_MS) return { next: dt <= 0 ? prev : next, usedWh: 0, solarWh: 0, keys };

  const hours = dt / HOUR_MS;
  return {
    next,
    usedWh: ((prev.usedW || 0) + usedW) / 2 * hours,
    solarWh: ((prev.solarW || 0) + solarW) / 2 * hours,
    keys,
  };
}

module.exports = { accumulate, timeKeys, MAX_GAP_MS };
