const test = require("node:test");
const assert = require("node:assert/strict");
const { buildSummary, buildPrompt, parseInsight, fallbackInsight, generateInsight } = require("../insights");
const { buildGeminiService } = require("../gemini_service_setup");

const TZ = 2;
const NOW = Date.UTC(2026, 9, 18, 6, 0, 0); // 18 Oct 2026 06:00 UTC = 08:00 CAT
const H = 3600000;

// 24 h of 5-minute readings: battery 80 % -> 15 % in the evening -> back up with the sun
function goodReadings() {
  const out = [];
  for (let t = NOW - 24 * H; t <= NOW; t += 5 * 60000) {
    const hourLocal = new Date(t + TZ * H).getUTCHours();
    const pct = hourLocal >= 19 || hourLocal < 5 ? 80 - ((hourLocal + (hourLocal < 5 ? 24 : 0) - 19) * 8) : 40 + hourLocal * 3;
    out.push({ timestamp: t, voltage: 12.2, current: hourLocal >= 18 && hourLocal < 22 ? 6 : 1.5, power: hourLocal >= 18 && hourLocal < 22 ? 75 : 18, batteryPercent: Math.max(8, Math.min(100, pct)) });
  }
  return out;
}

const hourly = {
  "2026-10-17-10": { usedWh: 20, solarWh: 150 },
  "2026-10-17-12": { usedWh: 25, solarWh: 210 },
  "2026-10-17-19": { usedWh: 80, solarWh: 0 },
};
const daily = { "2026-10-16": { usedWh: 300, solarWh: 900 }, "2026-10-17": { usedWh: 420, solarWh: 1100 } };

test("buildSummary: normal day has battery, load, energy and no warnings", () => {
  const s = buildSummary({ readings: goodReadings(), hourly, daily, alerts: [{ level: "warning", title: "Low Battery", timestamp: NOW - H }], settings: { batteryLowPct: 20 }, now: NOW, tz: TZ });
  assert.equal(s.dataWarnings.length, 0);
  assert.ok(s.coverageHours >= 23.9);
  assert.ok(s.battery.minPct < 20);
  assert.ok(s.battery.minutesBelowLowThreshold > 0);
  assert.equal(s.load.peakW, 75);
  assert.match(s.load.peakAtLocalHour, /^(18|19|20|21):00$/);
  assert.deepEqual(s.energy.yesterday, { usedWh: 420, solarWh: 1100 });
  assert.equal(s.alertsLast24h["warning: Low Battery"], 1);
  assert.equal(s.energy.solarWhByLocalHour["12"], 210);
});

test("buildSummary: summary never contains identifiers", () => {
  const s = JSON.stringify(buildSummary({ readings: goodReadings(), hourly, daily, now: NOW, tz: TZ }));
  assert.ok(!/@|password|uid|systemId|key/i.test(s));
});

test("buildSummary: the reported fault (about 20 V and 25 A on a 12 V battery) is flagged as unreliable", () => {
  const bad = [];
  for (let t = NOW - 12 * H; t <= NOW; t += 60000) bad.push({ timestamp: t, voltage: 20.3 + Math.sin(t) * 0.2, current: 25 + Math.sin(t) * 0.1, power: 500, batteryPercent: 100 });
  const s = buildSummary({ readings: bad, now: NOW, tz: TZ });
  assert.ok(s.dataWarnings.some((w) => /voltage/i.test(w)));
  assert.ok(s.dataWarnings.some((w) => /current/i.test(w)));
});

test("buildSummary: no readings or uptime-style timestamps -> warning, zero points", () => {
  const s = buildSummary({ readings: [{ timestamp: 12345, voltage: 12, current: 1 }], now: NOW, tz: TZ });
  assert.equal(s.dataPoints, 0);
  assert.ok(s.dataWarnings[0].includes("No readings"));
});

test("buildSummary: under 6 h of data is flagged", () => {
  const r = goodReadings().filter((x) => x.timestamp > NOW - 3 * H);
  const s = buildSummary({ readings: r, now: NOW, tz: TZ });
  assert.ok(s.dataWarnings.some((w) => /hours of data/.test(w)));
});

test("buildPrompt: contains the safety rules and the summary JSON", () => {
  const p = buildPrompt({ dataPoints: 3 });
  assert.match(p.systemInstruction, /Never tell the user to bypass/);
  assert.match(p.systemInstruction, /dataWarnings/);
  assert.match(p.userText, /"dataPoints":3/);
});

test("parseInsight: accepts valid JSON, trims and limits lengths", () => {
  const out = parseInsight(JSON.stringify({ headline: "x".repeat(200), summary: "ok", tips: ["a", "b", "c", "d"], watch: ["w1", "w2", "w3"] }));
  assert.equal(out.headline.length, 80);
  assert.equal(out.tips.length, 3);
  assert.equal(out.watch.length, 2);
});

test("parseInsight: strips code fences; rejects garbage and missing fields", () => {
  assert.equal(parseInsight('```json\n{"headline":"h","summary":"s"}\n```').headline, "h");
  assert.throws(() => parseInsight("not json"));
  assert.throws(() => parseInsight('{"headline":"h"}'));
  assert.deepEqual(parseInsight('{"headline":"h","summary":"s","tips":"nope"}').tips, []);
});

function okResponse(obj) {
  return { ok: true, status: 200, json: async () => ({ candidates: [{ content: { parts: [{ text: JSON.stringify(obj) }] } }] }) };
}
const errResponse = (status, message = "x") => ({ ok: false, status, json: async () => ({ error: { message } }) });
const svc = (fetchImpl, keys = ["K1"], models = ["m1"]) => buildGeminiService({ apiKeys: keys, models, fetchImpl });

test("generateInsight: success -> source gemini, reports the model that answered", async () => {
  const s = buildSummary({ readings: goodReadings(), hourly, daily, now: NOW, tz: TZ });
  const r = await generateInsight({ summary: s, service: svc(async () => okResponse({ headline: "Battery ran low", summary: "It dropped to 8%.", tips: ["Run the iron at noon."], watch: [] })) });
  assert.equal(r.source, "gemini");
  assert.equal(r.model, "m1");
  assert.equal(r.insight.tips[0], "Run the iron at noon.");
});

test("generateInsight: first model rate-limited -> second model answers", async () => {
  const s = buildSummary({ readings: goodReadings(), now: NOW, tz: TZ });
  const seen = [];
  const fetchImpl = async (url) => {
    seen.push(url);
    return url.includes("m1:") ? errResponse(429, "quota") : okResponse({ headline: "h", summary: "s" });
  };
  const r = await generateInsight({ summary: s, service: svc(fetchImpl, ["K1"], ["m1", "m2"]) });
  assert.equal(r.source, "gemini");
  assert.equal(r.model, "m2");
  assert.equal(r.configIndex, 1);
  assert.equal(seen.length, 2);
});

test("generateInsight: every model/key fails -> falls back to rules, never throws, no key in the error", async () => {
  const s = buildSummary({ readings: goodReadings(), hourly, daily, now: NOW, tz: TZ });
  const r = await generateInsight({ summary: s, service: svc(async () => errResponse(429, "quota"), ["SECRETKEY"], ["m1", "m2"]) });
  assert.equal(r.source, "rules");
  assert.match(r.error, /rate limit/);
  assert.ok(!r.error.includes("SECRETKEY"));
  assert.ok(r.insight.headline.length > 0);
});

test("generateInsight: network failure -> rules fallback", async () => {
  const s = buildSummary({ readings: goodReadings(), hourly, daily, now: NOW, tz: TZ });
  const r = await generateInsight({ summary: s, service: svc(async () => { throw new Error("offline"); }) });
  assert.equal(r.source, "rules");
});

test("generateInsight: model returns garbage -> rules fallback", async () => {
  const s = buildSummary({ readings: goodReadings(), now: NOW, tz: TZ });
  const r = await generateInsight({ summary: s, service: svc(async () => ({ ok: true, json: async () => ({ candidates: [{ content: { parts: [{ text: "Sure! Here is a summary" }] } }] }) })) });
  assert.equal(r.source, "rules");
  assert.match(r.error, /not valid JSON/);
});

test("generateInsight: no data -> rules without calling Gemini", async () => {
  const s = buildSummary({ readings: [], now: NOW, tz: TZ });
  const r = await generateInsight({ summary: s, service: svc(async () => { throw new Error("must not be called"); }) });
  assert.equal(r.source, "rules");
  assert.equal(r.error, "no-data");
});

test("fallbackInsight: unreliable data never gives energy advice", () => {
  const bad = [];
  for (let t = NOW - 12 * H; t <= NOW; t += 60000) bad.push({ timestamp: t, voltage: 21, current: 25, power: 500, batteryPercent: 100 });
  const f = fallbackInsight(buildSummary({ readings: bad, now: NOW, tz: TZ }));
  assert.equal(f.headline, "Readings look unreliable");
  assert.match(f.tips[0], /calibrate/);
});
