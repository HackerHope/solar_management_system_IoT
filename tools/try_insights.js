#!/usr/bin/env node
// Try the AI Energy Advisor on this computer. No Firebase, no deployment, no hardware.
// Needs Node 18+ and a Gemini API key from https://aistudio.google.com/apikey
//
//   GEMINI_API_KEYS="key1,key2" node tools/try_insights.js [scenario]     (a single GEMINI_API_KEY also works)
//   (optional) GEMINI_MODELS="gemini-3.6-flash,gemini-3.5-flash"          (default: chain in functions/gemini_service_setup.js)
//
// Scenarios (each builds 24 h of made-up readings and runs the REAL pipeline):
//   normal       healthy day: battery dips in the evening, recovers with the sun
//   evening-low  battery drains below 20 % after 20:00 with a heavy evening load
//   bad-sensors  the fault seen on the prototype: about 20 V and about 25 A on a 12 V battery
//   no-key       forces the rule-based fallback (Gemini is not called)
//
// The printed summary is exactly what is sent to Gemini: numbers only, no names or identifiers.
// Keep the printed outputs: they are evidence for the project report (test T-AI).

const { buildSummary, generateInsight } = require("../functions/insights");
const { buildGeminiService, parseApiKeys, parseModels } = require("../functions/gemini_service_setup");

const TZ = 2;
const H = 3600000;
const NOW = Date.now();
const scenario = process.argv[2] || "normal";

function localHour(t) { return new Date(t + TZ * H).getUTCHours(); }

function makeReadings(kind) {
  const out = [];
  let pct = 70;
  for (let t = NOW - 24 * H; t <= NOW; t += 5 * 60000) {
    const h = localHour(t);
    const sun = h >= 7 && h < 17 ? Math.sin(((h - 7) / 10) * Math.PI) : 0; // 0..1
    const evening = h >= 18 && h < 23;
    let load = evening ? (kind === "evening-low" ? 3.6 : 2.0) : 0.8;
    const charge = sun * 6;
    pct += ((charge - load) * (5 / 60)) / 20 * 100; // 20 Ah battery, 5-minute step
    pct = Math.max(kind === "evening-low" ? 6 : 25, Math.min(100, pct));
    let v = 11.6 + pct * 0.011;
    let i = load;
    let p = v * i;
    if (kind === "bad-sensors") { v = 20.3 + Math.sin(t / 1e6) * 0.2; i = 25.0; p = v * i; }
    out.push({ timestamp: t, voltage: v, current: i, power: p, batteryPercent: kind === "bad-sensors" ? 100 : pct });
  }
  return out;
}

function makeEnergy() {
  const hourly = {};
  const daily = {};
  for (let d = 2; d >= 0; d--) {
    const day = new Date(NOW + TZ * H - d * 24 * H);
    const key = `${day.getUTCFullYear()}-${String(day.getUTCMonth() + 1).padStart(2, "0")}-${String(day.getUTCDate()).padStart(2, "0")}`;
    let used = 0, solar = 0;
    for (let h = 0; h < 24; h++) {
      const s = h >= 7 && h < 17 ? Math.round(Math.sin(((h - 7) / 10) * Math.PI) * 60) : 0;
      const u = h >= 18 && h < 23 ? 60 : 14;
      hourly[`${key}-${String(h).padStart(2, "0")}`] = { usedWh: u, solarWh: s };
      used += u; solar += s;
    }
    daily[key] = { usedWh: used, solarWh: solar };
  }
  return { hourly, daily };
}

(async () => {
  const kind = scenario === "no-key" ? "normal" : scenario;
  const { hourly, daily } = makeEnergy();
  const summary = buildSummary({
    readings: makeReadings(kind),
    hourly,
    daily,
    alerts: kind === "evening-low" ? [{ level: "warning", title: "Low Battery", timestamp: NOW - 2 * H }, { level: "warning", title: "Low Battery", timestamp: NOW - 3 * H }] : [],
    settings: { batteryLowPct: 20 },
    power: { source: "grid", mainsPresent: true, faultTripped: false, solarPower: 35 },
    now: NOW,
    tz: TZ,
    nominalV: 12,
    batteryAh: 20,
  });

  console.log("=== Summary sent to Gemini ===");
  console.log(JSON.stringify(summary, null, 2));

  const keys = scenario === "no-key" ? [] : parseApiKeys(process.env.GEMINI_API_KEYS || process.env.GEMINI_API_KEY);
  if (keys.length === 0 && scenario !== "no-key") {
    console.error("\nNo GEMINI_API_KEYS set. Running the rule-based fallback instead.\n");
  }
  const skipped = [];
  const service = keys.length
    ? buildGeminiService({ apiKeys: keys, models: parseModels(process.env.GEMINI_MODELS), logger: { warn: (l) => skipped.push(l) } })
    : { generateText: async () => { throw new Error("no Gemini API key configured"); } };
  const result = await generateInsight({ summary, service });
  skipped.forEach((l) => console.log("skipped: " + l));
  console.log("\n=== Result (source: " + result.source + (result.model ? ", model: " + result.model : "") + (result.error ? ", note: " + result.error : "") + ") ===");
  console.log(JSON.stringify(result.insight, null, 2));
})();
