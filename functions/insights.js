// AI Energy Advisor - pure logic (no Firebase imports, so it can be unit tested).
//
//   buildSummary()   turns raw database data into a small, anonymous summary of the last 24 h
//   buildPrompt()    turns the summary into a prompt for Gemini
//   (the Gemini REST call, model/key fallback chain and error types live in gemini_service.js)
//   parseInsight()   validates / trims the model's JSON answer
//   fallbackInsight() the same output without AI, used when Gemini is unreachable
//   generateInsight() summary -> Gemini -> validated insight (or fallback)
//
// SAFETY: the model only WRITES TEXT that is shown in the app. It has no access to relays,
// settings or commands, and it never receives passwords, e-mail addresses or system names.

"use strict";

const HOUR_MS = 3600000;
const MIN_REAL_TS = 1e12; // timestamps below this are uptime counters, not epoch milliseconds
const MAX_GAP_MS = 10 * 60 * 1000; // gaps longer than this are not counted as "time spent"

const isNum = (v) => typeof v === "number" && Number.isFinite(v);
const pad = (n) => String(n).padStart(2, "0");
const round = (v, d = 1) => (isNum(v) ? Math.round(v * 10 ** d) / 10 ** d : null);

function localHour(ts, tz) {
  return new Date(ts + tz * HOUR_MS).getUTCHours();
}
function dayKey(ts, tz) {
  const d = new Date(ts + tz * HOUR_MS);
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
}

/**
 * @param {object} i
 * @param {object[]} i.readings  readings/history values (timestamp, voltage, current, power, batteryPercent)
 * @param {object}   i.hourly    energy/hourly   { "yyyy-MM-dd-HH": { usedWh, solarWh } }
 * @param {object}   i.daily     energy/daily    { "yyyy-MM-dd":    { usedWh, solarWh } }
 * @param {object[]} i.alerts    alerts values (level, title, timestamp)
 * @param {object}   i.settings  settings node
 * @param {object}   i.power     system/powerStatus
 * @param {number}   i.now       epoch ms
 * @param {number}   i.tz        hours east of UTC (Zambia = 2)
 * @param {number}   i.nominalV  battery nominal voltage (12)
 * @param {number}   i.batteryAh battery rating in Ah (20)
 */
function buildSummary({
  readings = [], hourly = {}, daily = {}, alerts = [], settings = {}, power = null,
  now = Date.now(), tz = 2, nominalV = 12, batteryAh = 20,
} = {}) {
  const since = now - 24 * HOUR_MS;
  const rs = (readings || [])
    .filter((r) => r && isNum(r.timestamp) && r.timestamp >= MIN_REAL_TS && r.timestamp >= since && r.timestamp <= now + 60000)
    .sort((a, b) => a.timestamp - b.timestamp);

  const lowPct = isNum(settings.batteryLowPct) ? settings.batteryLowPct : 20;
  const out = {
    system: { batteryNominalV: nominalV, batteryAh, lowBatteryAlertPct: lowPct },
    windowHours: 24,
    dataPoints: rs.length,
    coverageHours: rs.length > 1 ? round((rs[rs.length - 1].timestamp - rs[0].timestamp) / HOUR_MS, 1) : 0,
    dataWarnings: [],
  };

  // ---- battery -------------------------------------------------------------------------
  const pcts = rs.map((r) => r.batteryPercent).filter(isNum);
  if (pcts.length) {
    let minutesBelowLow = 0;
    let minR = rs.find((r) => isNum(r.batteryPercent));
    for (let k = 0; k < rs.length; k++) {
      const r = rs[k];
      if (isNum(r.batteryPercent) && r.batteryPercent < minR.batteryPercent) minR = r;
      if (k > 0 && isNum(r.batteryPercent) && r.batteryPercent < lowPct) {
        const gap = r.timestamp - rs[k - 1].timestamp;
        if (gap > 0 && gap <= MAX_GAP_MS) minutesBelowLow += gap / 60000;
      }
    }
    const byHour = {};
    for (const r of rs) {
      if (!isNum(r.batteryPercent)) continue;
      const h = pad(localHour(r.timestamp, tz));
      (byHour[h] ||= []).push(r.batteryPercent);
    }
    out.battery = {
      minPct: round(Math.min(...pcts), 0),
      maxPct: round(Math.max(...pcts), 0),
      avgPct: round(pcts.reduce((a, b) => a + b, 0) / pcts.length, 0),
      lowestAtLocalHour: pad(localHour(minR.timestamp, tz)) + ":00",
      minutesBelowLowThreshold: Math.round(minutesBelowLow),
      avgPctByLocalHour: Object.fromEntries(
        Object.keys(byHour).sort().map((h) => [h, round(byHour[h].reduce((a, b) => a + b, 0) / byHour[h].length, 0)])
      ),
    };
  }

  // ---- voltage / current / load -------------------------------------------------------
  const volts = rs.map((r) => r.voltage).filter(isNum);
  const amps = rs.map((r) => r.current).filter(isNum);
  if (volts.length) out.batteryVoltage = { minV: round(Math.min(...volts), 2), maxV: round(Math.max(...volts), 2) };
  if (amps.length) {
    out.loadCurrent = {
      minA: round(Math.min(...amps), 1),
      maxA: round(Math.max(...amps), 1),
      avgAbsA: round(amps.reduce((a, b) => a + Math.abs(b), 0) / amps.length, 2),
    };
  }
  const powers = rs.filter((r) => isNum(r.power) && r.power > 0);
  if (powers.length) {
    let peak = powers[0];
    for (const r of powers) if (r.power > peak.power) peak = r;
    out.load = {
      avgW: round(powers.reduce((a, r) => a + r.power, 0) / powers.length, 0),
      peakW: round(peak.power, 0),
      peakAtLocalHour: pad(localHour(peak.timestamp, tz)) + ":00",
    };
  }

  // ---- energy (Wh) -------------------------------------------------------------------
  const today = dayKey(now, tz);
  const yesterday = dayKey(now - 24 * HOUR_MS, tz);
  const dayVal = (k) => (daily && daily[k] ? { usedWh: round(daily[k].usedWh || 0, 0), solarWh: round(daily[k].solarWh || 0, 0) } : null);
  const sumHours = (prefix) => {
    let used = 0, solar = 0, n = 0;
    for (const [k, v] of Object.entries(hourly || {})) {
      if (k.startsWith(prefix) && v) { used += v.usedWh || 0; solar += v.solarWh || 0; n++; }
    }
    return n ? { usedWh: round(used, 0), solarWh: round(solar, 0) } : null;
  };
  out.energy = {
    today: dayVal(today) || sumHours(today),
    yesterday: dayVal(yesterday) || sumHours(yesterday),
    last7Days: Object.keys(daily || {}).sort().slice(-7).map((k) => ({ date: k, usedWh: round(daily[k].usedWh || 0, 0), solarWh: round(daily[k].solarWh || 0, 0) })),
  };
  // solar by hour over yesterday + today: when is the sun actually producing?
  const sunHours = {};
  for (const [k, v] of Object.entries(hourly || {})) {
    if (!v || !(k.startsWith(today) || k.startsWith(yesterday))) continue;
    const h = k.slice(-2);
    sunHours[h] = round((sunHours[h] || 0) + (v.solarWh || 0), 0);
  }
  if (Object.keys(sunHours).length) out.energy.solarWhByLocalHour = Object.fromEntries(Object.entries(sunHours).sort());

  // ---- alerts (24 h) ------------------------------------------------------------------
  const counts = {};
  for (const a of alerts || []) {
    if (!a || !isNum(a.timestamp) || a.timestamp < since) continue;
    const key = `${a.level || "info"}: ${a.title || "alert"}`;
    counts[key] = (counts[key] || 0) + 1;
  }
  out.alertsLast24h = counts;

  // ---- current status -----------------------------------------------------------------
  if (power) {
    out.status = {
      activeSource: power.source || null,
      mainsPresent: typeof power.mainsPresent === "boolean" ? power.mainsPresent : null,
      safetyTripped: typeof power.faultTripped === "boolean" ? power.faultTripped : null,
      solarW: isNum(power.solarPower) ? round(power.solarPower, 0) : null,
    };
  }

  // ---- sanity checks: bad calibration must never turn into confident advice -------------
  if (rs.length === 0) out.dataWarnings.push("No readings in the last 24 hours.");
  if (volts.length && (Math.max(...volts) > nominalV * 1.3 || Math.min(...volts) < nominalV * 0.65)) {
    out.dataWarnings.push(`Battery voltage readings (${round(Math.min(...volts), 1)}-${round(Math.max(...volts), 1)} V) are outside what a ${nominalV} V battery can show; the voltage sensor is probably not calibrated.`);
  }
  if (amps.length && Math.max(...amps.map(Math.abs)) > 25) {
    out.dataWarnings.push("Current readings above 25 A are not plausible for this system; the current sensor is probably not calibrated.");
  }
  if (amps.length > 20 && Math.min(...amps) > 20 && Math.max(...amps) - Math.min(...amps) < 1) {
    out.dataWarnings.push("Current is stuck near a constant large value; this usually means the current sensor zero point is wrong.");
  }
  if (pcts.some((p) => p < 0 || p > 100)) out.dataWarnings.push("Battery percentage outside 0-100%.");
  if (rs.length > 0 && out.coverageHours < 6) out.dataWarnings.push(`Only ${out.coverageHours} hours of data are available, so patterns are not reliable yet.`);
  return out;
}

const SYSTEM_PROMPT = [
  "You are the Energy Advisor inside a home solar monitoring app used in Zambia.",
  "You receive a JSON summary of the last 24 hours of a small 12 V solar + battery + inverter system and write a short, friendly report for the homeowner.",
  "Rules:",
  "1. Use ONLY the numbers in the JSON. Never invent values, dates, prices or equipment. If something is not in the data, say it is not known.",
  "2. Write in plain English for a non-technical reader. No jargon, no formulas. Units: %, V, A, W, Wh.",
  "3. If dataWarnings is not empty, the readings may be wrong: the headline must say the readings look unreliable, the summary must name the problem in simple words, tips must only suggest checking or calibrating the sensors, and you must give NO energy-saving advice.",
  "4. Otherwise give at most 3 practical tips about WHEN to use big loads (for example when solar is producing), reducing the evening drain, or protecting the battery. Base each tip on a specific number from the data.",
  "5. Never tell the user to bypass, disable or reset a safety device, to open electrical equipment, or to change wiring. If the safety device tripped, tell them to check the load and the app message and to ask a qualified electrician if it repeats.",
  "6. Do not give medical, legal or financial advice. Do not mention that you are an AI model.",
  "Answer with JSON only, exactly in this shape:",
  '{"headline": string (max 80 characters), "summary": string (max 350 characters, 2-3 sentences), "tips": string[] (0-3 items, each max 140 characters), "watch": string[] (0-2 items, each max 140 characters, things that need attention, empty if none)}',
].join("\n");

function buildPrompt(summary) {
  return {
    systemInstruction: SYSTEM_PROMPT,
    userText: "Here is the summary of the last 24 hours (JSON):\n" + JSON.stringify(summary),
  };
}

const clip = (s, n) => String(s).replace(/\s+/g, " ").trim().slice(0, n);

/** Validate and trim the model's answer. Throws if it is not usable. */
function parseInsight(text) {
  let t = String(text || "").trim();
  t = t.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "");
  let obj;
  try { obj = JSON.parse(t); } catch (_) { throw new Error("Model answer is not valid JSON"); }
  if (!obj || typeof obj.headline !== "string" || typeof obj.summary !== "string" || !obj.headline.trim() || !obj.summary.trim()) {
    throw new Error("Model answer is missing headline or summary");
  }
  const list = (v, max, len) => (Array.isArray(v) ? v.filter((x) => typeof x === "string" && x.trim()).slice(0, max).map((x) => clip(x, len)) : []);
  return {
    headline: clip(obj.headline, 80),
    summary: clip(obj.summary, 350),
    tips: list(obj.tips, 3, 140),
    watch: list(obj.watch, 2, 140),
  };
}

/** Same output shape without AI. Deliberately simple and conservative. */
function fallbackInsight(summary) {
  if (summary.dataWarnings && summary.dataWarnings.length) {
    return {
      headline: "Readings look unreliable",
      summary: clip(summary.dataWarnings[0], 350),
      tips: ["Check the sensor wiring and calibrate the voltage and current sensors before trusting the numbers."],
      watch: [],
    };
  }
  const b = summary.battery;
  const e = summary.energy && summary.energy.yesterday;
  const parts = [];
  if (b) parts.push(`Battery ranged from ${b.minPct}% to ${b.maxPct}% (lowest around ${b.lowestAtLocalHour}).`);
  if (e) parts.push(`Yesterday the house used about ${e.usedWh} Wh and solar produced about ${e.solarWh} Wh.`);
  const tips = [];
  const watch = [];
  if (b && b.minutesBelowLowThreshold > 0) watch.push(`Battery was below ${summary.system.lowBatteryAlertPct}% for about ${b.minutesBelowLowThreshold} minutes.`);
  if (summary.load && summary.load.peakW) tips.push(`Your highest load was about ${summary.load.peakW} W around ${summary.load.peakAtLocalHour}; try to avoid running big appliances together.`);
  const alertKeys = Object.keys(summary.alertsLast24h || {});
  if (alertKeys.length) watch.push(`Alerts in the last 24 hours: ${alertKeys.slice(0, 2).join(", ")}.`);
  return {
    headline: b && b.minPct < summary.system.lowBatteryAlertPct ? "Battery ran low in the last 24 hours" : "Daily energy summary",
    summary: clip(parts.join(" ") || "Not enough data yet for a summary.", 350),
    tips: tips.slice(0, 3),
    watch: watch.slice(0, 2),
  };
}

/**
 * summary -> Gemini (through GeminiService: model/key fallback chain) -> insight.
 * Never throws: if every model/key fails, or the answer is unusable, the rule-based insight is returned
 * and `error` says why (it never contains an API key).
 * @param {{summary: object, service: {generateText: Function}}} o
 */
async function generateInsight({ summary, service }) {
  if (summary.dataPoints === 0) {
    return { insight: fallbackInsight(summary), source: "rules", model: null, configIndex: null, error: "no-data" };
  }
  const { systemInstruction, userText } = buildPrompt(summary);
  try {
    const { text, model, configIndex } = await service.generateText({ systemInstruction, userText });
    return { insight: parseInsight(text), source: "gemini", model, configIndex, error: null };
  } catch (err) {
    return { insight: fallbackInsight(summary), source: "rules", model: null, configIndex: null, error: err && err.message ? err.message : String(err) };
  }
}

module.exports = { buildSummary, buildPrompt, parseInsight, fallbackInsight, generateInsight, SYSTEM_PROMPT };
