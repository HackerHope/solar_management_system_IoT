const test = require("node:test");
const assert = require("node:assert/strict");
const { accumulate, timeKeys } = require("../energy");

const T0 = 1_760_000_000_000; // a real epoch-ms timestamp
const HOUR = 3600000;
const near = (a, b) => assert.ok(Math.abs(a - b) < 1e-9, `${a} !~ ${b}`);

test("first reading only stores state", () => {
  const r = accumulate(null, { timestamp: T0, power: 100, solarPower: 50 });
  assert.equal(r.usedWh, 0);
  assert.deepEqual(r.next, { ts: T0, usedW: 100, solarW: 50 });
});

test("constant 100 W for 5 s adds 100*5/3600 Wh", () => {
  const prev = { ts: T0, usedW: 100, solarW: 0 };
  const r = accumulate(prev, { timestamp: T0 + 5000, power: 100 });
  near(r.usedWh, (100 * 5) / 3600);
});

test("trapezoid: 0 W to 200 W over an hour = 100 Wh (gap too long, so use 10 min)", () => {
  const prev = { ts: T0, usedW: 0, solarW: 0 };
  const r = accumulate(prev, { timestamp: T0 + 600000, power: 200 });
  near(r.usedWh, (100 * 600000) / HOUR);
});

test("negative power (charging) counts as zero used", () => {
  const prev = { ts: T0, usedW: 0, solarW: 0 };
  const r = accumulate(prev, { timestamp: T0 + 10000, power: -50 });
  assert.equal(r.usedWh, 0);
});

test("solar energy is accumulated from solarPower", () => {
  const prev = { ts: T0, usedW: 0, solarW: 40 };
  const r = accumulate(prev, { timestamp: T0 + 10000, power: 0, solarPower: 40 });
  near(r.solarWh, (40 * 10) / 3600);
});

test("gap over 10 minutes adds nothing but moves the state forward", () => {
  const prev = { ts: T0, usedW: 100, solarW: 0 };
  const r = accumulate(prev, { timestamp: T0 + 11 * 60000, power: 100 });
  assert.equal(r.usedWh, 0);
  assert.equal(r.next.ts, T0 + 11 * 60000);
});

test("out-of-order or duplicate timestamp adds nothing and keeps previous state", () => {
  const prev = { ts: T0, usedW: 100, solarW: 0 };
  const r = accumulate(prev, { timestamp: T0, power: 500 });
  assert.equal(r.usedWh, 0);
  assert.equal(r.next, prev);
});

test("uptime-style timestamps are ignored", () => {
  const prev = { ts: T0, usedW: 100, solarW: 0 };
  const r = accumulate(prev, { timestamp: 123456, power: 100 });
  assert.equal(r.usedWh, 0);
  assert.equal(r.keys, null);
  assert.equal(r.next, prev);
});

test("timeKeys use the Zambia offset (UTC+2)", () => {
  // 2026-10-13 22:30 UTC is already 2026-10-14 00:30 in Zambia
  const ts = Date.UTC(2026, 9, 13, 22, 30);
  assert.deepEqual(timeKeys(ts, 2), { day: "2026-10-14", hour: "2026-10-14-00" });
  assert.deepEqual(timeKeys(ts, 0), { day: "2026-10-13", hour: "2026-10-13-22" });
});
