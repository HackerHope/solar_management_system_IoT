const test = require("node:test");
const assert = require("node:assert/strict");
const { evaluateReading, alertKey, shouldRaise, watchdogDecision, COOLDOWN_MS } = require("../alerts");

const ok = { voltage: 12.4, batteryPercent: 80 };

test("healthy reading raises nothing", () => {
  assert.deepEqual(evaluateReading(ok), []);
});

test("null reading raises nothing", () => {
  assert.deepEqual(evaluateReading(null), []);
});

test("exactly at the battery limit does not alert", () => {
  assert.deepEqual(evaluateReading({ ...ok, batteryPercent: 20 }), []);
});

test("a stray temperature field in an old record is ignored", () => {
  assert.deepEqual(evaluateReading({ ...ok, temperature: 99 }), []);
});

test("low battery % -> warning, low voltage -> error", () => {
  const out = evaluateReading({ ...ok, batteryPercent: 10, voltage: 9 });
  assert.deepEqual(out.map((a) => a.title), ["Low Battery", "Low Battery Voltage"]);
  assert.equal(out[1].level, "error");
});

test("user settings override defaults", () => {
  const out = evaluateReading({ ...ok, batteryPercent: 40 }, { batteryLowPct: 50 });
  assert.deepEqual(out.map((a) => a.title), ["Low Battery"]);
});

test("non-numeric values are ignored safely", () => {
  assert.deepEqual(evaluateReading({ voltage: "x", batteryPercent: null }), []);
});

test("alertKey is a valid database key", () => {
  const key = alertKey({ level: "warning", title: "Low Battery" });
  assert.equal(key, "warning_Low_Battery");
  assert.ok(!/[.#$\[\]/]/.test(key));
});

test("cooldown: first alert allowed, repeat within 5 min blocked, after 5 min allowed", () => {
  const t0 = 1_700_000_000_000;
  assert.equal(shouldRaise(undefined, t0), true);
  assert.equal(shouldRaise(t0, t0 + COOLDOWN_MS - 1), false);
  assert.equal(shouldRaise(t0, t0 + COOLDOWN_MS), true);
});

test("watchdog: stale heartbeat raises offline once", () => {
  const now = 1_760_000_000_000;
  assert.equal(watchdogDecision(now - 4 * 60000, null, now), "raise-offline");
  assert.equal(watchdogDecision(now - 4 * 60000, now - 5 * 60000, now), "none");
});

test("watchdog: fresh heartbeat after an offline alert raises online", () => {
  const now = 1_760_000_000_000;
  assert.equal(watchdogDecision(now - 10000, now - 600000, now), "raise-online");
  assert.equal(watchdogDecision(now - 10000, null, now), "none");
});

test("watchdog ignores uptime-style heartbeats and missing data", () => {
  const now = 1_760_000_000_000;
  assert.equal(watchdogDecision(123456, null, now), "none");
  assert.equal(watchdogDecision(undefined, null, now), "none");
});
