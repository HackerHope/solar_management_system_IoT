#!/usr/bin/env node
// Pretends to be the ESP32 so you can test the app and Cloud Functions without
// the hardware (test plan T4-T9, T12 and measurements M1/M5).
// Needs Node 18+. No packages to install.
//
//   FIREBASE_API_KEY=...  FIREBASE_DB_URL=https://<project>-default-rtdb.<region>.firebasedatabase.app \
//   DEVICE_EMAIL=...  DEVICE_PASSWORD=...  [SYSTEM_ID=default]  node tools/simulate_device.js <scenario>
//
// The device account must be a "device" member of the system (docs/security.md).
//
// Scenarios:
//   normal       healthy values, updates every 5 s
//   low-battery  battery drains from 40 % to below 15 %  (Low Battery / Low Battery Voltage alerts, auto load shed)
//   overtemp     temperature climbs above 45 C            (High Temperature alert)
//   fault        sets faultTripped = true once            (safety card shows TRIPPED)
//   stop         sends 3 readings then stops              (Offline after the watchdog window)
//
// Every write prints the epoch-ms timestamp so you can compare it with the time the
// value appears in the app (latency measurement M1). Press Ctrl+C to stop.

const { FIREBASE_API_KEY, FIREBASE_DB_URL, DEVICE_EMAIL, DEVICE_PASSWORD } = process.env;
const SYSTEM_ID = process.env.SYSTEM_ID || "default";
const scenario = process.argv[2] || "normal";
const INTERVAL_MS = Number(process.env.INTERVAL_MS || 5000);

for (const [k, v] of Object.entries({ FIREBASE_API_KEY, FIREBASE_DB_URL, DEVICE_EMAIL, DEVICE_PASSWORD })) {
  if (!v) { console.error(`Missing environment variable ${k}`); process.exit(1); }
}
const dbUrl = FIREBASE_DB_URL.replace(/\/$/, "");
let idToken = "";
let tokenExpiry = 0;

async function signIn() {
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}`,
    { method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: DEVICE_EMAIL, password: DEVICE_PASSWORD, returnSecureToken: true }) });
  const data = await res.json();
  if (!res.ok) throw new Error("Sign-in failed: " + (data.error?.message || res.status));
  idToken = data.idToken;
  tokenExpiry = Date.now() + (Number(data.expiresIn) - 120) * 1000;
}

async function rtdb(method, path, body) {
  if (Date.now() > tokenExpiry) await signIn();
  const res = await fetch(`${dbUrl}/systems/${SYSTEM_ID}/${path}.json?auth=${idToken}`, {
    method, headers: { "Content-Type": "application/json" }, body: body === undefined ? undefined : JSON.stringify(body) });
  if (!res.ok) throw new Error(`${method} ${path} -> ${res.status} ${await res.text()}`);
}

function values(step) {
  const v = { voltage: 12.6, current: 2.0, batteryPercent: 80, solarW: 30, temperature: undefined };
  if (scenario === "low-battery") {
    v.batteryPercent = Math.max(8, 40 - step * 2);
    v.voltage = 11.6 - Math.min(2.5, step * 0.1);
    v.solarW = 0;
  } else if (scenario === "overtemp") {
    v.temperature = Math.min(60, 35 + step);
  }
  return v;
}

async function tick(step) {
  const v = values(step);
  const now = Date.now();
  const reading = {
    voltage: v.voltage, current: v.current, batteryPercent: v.batteryPercent,
    power: +(v.voltage * v.current).toFixed(2), solarPower: v.solarW, timestamp: now,
  };
  if (v.temperature !== undefined) reading.temperature = v.temperature;
  await rtdb("PUT", "readings/latest", reading);
  await rtdb("POST", "readings/history", reading);
  await rtdb("PUT", "system/lastSeen", now);
  await rtdb("PUT", "system/powerStatus", {
    solarVoltage: v.solarW > 0 ? 18.2 : 0, solarCurrent: +(v.solarW / 18.2).toFixed(2),
    source: scenario === "low-battery" ? "inverter" : "grid", mainsPresent: scenario !== "low-battery",
    faultTripped: scenario === "fault", channel1: false, channel2: false, autoMode: false, autoShed: false,
  });
  console.log(`[${new Date(now).toISOString()}] wrote reading ts=${now} battery=${v.batteryPercent}% V=${v.voltage.toFixed(2)}`);
}

(async () => {
  await signIn();
  console.log(`Signed in. Simulating "${scenario}" for system "${SYSTEM_ID}" every ${INTERVAL_MS / 1000}s`);
  let step = 0;
  const limit = scenario === "stop" ? 3 : scenario === "fault" ? 1 : Infinity;
  while (step < limit) {
    try { await tick(step); } catch (e) { console.error(e.message); }
    step++;
    if (step < limit) await new Promise((r) => setTimeout(r, INTERVAL_MS));
  }
  console.log("Done.");
})();
