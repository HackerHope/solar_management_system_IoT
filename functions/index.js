// Solar IoT Cloud Functions (Node 22, firebase-functions v2 API).
//
//  onReading       every new reading -> alerts (with cooldown) + daily/hourly energy totals
//  pushOnAlert     every new warning/error alert -> push notification to the phones
//  deviceWatchdog  every 5 min -> "Device offline" / "Device back online" alerts
//  pruneHistory    daily -> deletes readings older than RETENTION_DAYS
//  dailyInsights   daily 06:00 -> AI Energy Advisor (Gemini) writes systems/<id>/insights/latest
//                  (text only; never touches relays or settings). See docs/ai-insights.md
//
// Requires the Blaze (pay-as-you-go) plan; usage for one household stays inside
// the free monthly allowance. See docs/cloud-functions.md.

const { onValueWritten, onValueCreated } = require("firebase-functions/v2/database");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret, defineString } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { evaluateReading, alertKey, shouldRaise, watchdogDecision } = require("./alerts");
const { accumulate } = require("./energy");
const { buildSummary, generateInsight } = require("./insights");
const { buildGeminiService, parseApiKeys, parseModels } = require("./gemini_service_setup");

admin.initializeApp();

// Must match the region of your Realtime Database instance.
const REGION = "europe-west1";
const TZ_OFFSET_HOURS = 2; // Zambia (CAT)
const RETENTION_DAYS = 7;

// ---- AI Energy Advisor (Gemini) ----
// One secret holds up to 6 keys separated by commas (each key is tried against every model, in order):
//   firebase functions:secrets:set GEMINI_API_KEYS
const GEMINI_API_KEYS = defineSecret("GEMINI_API_KEYS");
// Optional: override the model chain (comma separated, most capable first). Empty = defaults in gemini_service_setup.js.
// Model names change over time; run tools/check_gemini.js to see which ones your keys can use.
const GEMINI_MODELS = defineString("GEMINI_MODELS", { default: "" });
const NOMINAL_VOLTAGE = defineString("BATTERY_NOMINAL_V", { default: "12" });
const BATTERY_AH = defineString("BATTERY_AH", { default: "20" });

const db = () => admin.database();

async function raiseAlert(systemId, level, title, message, now) {
  const ref = db().ref(`/systems/${systemId}/alerts`).push();
  await ref.set({ level, title, message, timestamp: now });
}

// ---------------------------------------------------------------- readings
exports.onReading = onValueWritten(
  { ref: "/systems/{systemId}/readings/latest", region: REGION },
  async (event) => {
    const reading = event.data.after.val();
    if (!reading) return;
    const { systemId } = event.params;
    const base = `/systems/${systemId}`;
    const now = Date.now();

    const [settingsSnap, alertStateSnap, energyStateSnap] = await Promise.all([
      db().ref(`${base}/settings`).get(),
      db().ref(`${base}/alertState`).get(),
      db().ref(`${base}/energyState`).get(),
    ]);
    const updates = {};

    // 1. Threshold alerts with a per-alert cooldown
    const alertState = alertStateSnap.val() || {};
    for (const alert of evaluateReading(reading, settingsSnap.val() || {})) {
      const key = alertKey(alert);
      if (!shouldRaise(alertState[key], now)) continue;
      const id = db().ref(`${base}/alerts`).push().key;
      updates[`${base}/alerts/${id}`] = { ...alert, timestamp: now };
      updates[`${base}/alertState/${key}`] = now;
    }

    // 2. Energy totals (used by the Analytics screen)
    const acc = accumulate(energyStateSnap.val(), reading, TZ_OFFSET_HOURS);
    if (acc.next) updates[`${base}/energyState`] = acc.next;
    if (acc.keys && (acc.usedWh > 0 || acc.solarWh > 0)) {
      const inc = admin.database.ServerValue.increment;
      updates[`${base}/energy/daily/${acc.keys.day}/usedWh`] = inc(acc.usedWh);
      updates[`${base}/energy/daily/${acc.keys.day}/solarWh`] = inc(acc.solarWh);
      updates[`${base}/energy/hourly/${acc.keys.hour}/usedWh`] = inc(acc.usedWh);
      updates[`${base}/energy/hourly/${acc.keys.hour}/solarWh`] = inc(acc.solarWh);
    }

    if (Object.keys(updates).length) await db().ref().update(updates);
  }
);

// ------------------------------------------------------------------- push
exports.pushOnAlert = onValueCreated(
  { ref: "/systems/{systemId}/alerts/{alertId}", region: REGION },
  async (event) => {
    const alert = event.data.val();
    if (!alert) return;
    if (alert.level !== "warning" && alert.level !== "error") return; // info stays in-app
    if (Date.now() - (alert.timestamp || 0) > 10 * 60 * 1000) return; // do not push old alerts
    const { systemId } = event.params;
    try {
      await admin.messaging().send({
        topic: `system_${systemId}`,
        notification: { title: alert.title || "Solar alert", body: alert.message || "" },
        data: { level: String(alert.level), systemId },
        android: { priority: "high" },
        apns: { headers: { "apns-priority": "10" } },
      });
    } catch (err) {
      logger.error("push failed", err);
    }
  }
);

// --------------------------------------------------------------- watchdog
exports.deviceWatchdog = onSchedule(
  { schedule: "every 5 minutes", region: REGION },
  async () => {
    const idsSnap = await db().ref("/systemsIndex").get();
    const ids = Object.keys(idsSnap.val() || {});
    const now = Date.now();
    for (const systemId of ids) {
      const base = `/systems/${systemId}`;
      const [seenSnap, markerSnap] = await Promise.all([
        db().ref(`${base}/system/lastSeen`).get(),
        db().ref(`${base}/alertState/offline`).get(),
      ]);
      const decision = watchdogDecision(seenSnap.val(), markerSnap.val(), now);
      if (decision === "raise-offline") {
        await raiseAlert(systemId, "error", "Device offline", "No data from the device for over 3 minutes.", now);
        await db().ref(`${base}/alertState/offline`).set(seenSnap.val());
      } else if (decision === "raise-online") {
        await raiseAlert(systemId, "info", "Device back online", "The device is sending data again.", now);
        await db().ref(`${base}/alertState/offline`).remove();
      }
    }
  }
);

// ------------------------------------------------------------------ prune
async function deleteOlderThan(path, cutoffMs) {
  // needs ".indexOn": ["timestamp"] (already in database.rules.json)
  for (let i = 0; i < 20; i++) {
    const snap = await db().ref(path).orderByChild("timestamp").endAt(cutoffMs).limitToFirst(1000).get();
    if (!snap.exists()) return;
    const updates = {};
    snap.forEach((child) => { updates[child.key] = null; });
    await db().ref(path).update(updates);
  }
}

exports.pruneHistory = onSchedule(
  { schedule: "every day 03:00", timeZone: "Africa/Lusaka", region: REGION },
  async () => {
    const idsSnap = await db().ref("/systemsIndex").get();
    const cutoff = Date.now() - RETENTION_DAYS * 24 * 3600 * 1000;
    for (const systemId of Object.keys(idsSnap.val() || {})) {
      await deleteOlderThan(`/systems/${systemId}/readings/history`, cutoff);
      await deleteOlderThan(`/systems/${systemId}/circuits/history`, cutoff);
    }
  }
);

// -------------------------------------------------------------- AI insights
const valuesOf = (snap) => (snap.exists() ? Object.values(snap.val()) : []);

async function generateForSystem(systemId, now, service) {
  const base = `/systems/${systemId}`;
  const settings = (await db().ref(`${base}/settings`).get()).val() || {};
  if (settings.aiInsights === false) return { skipped: true }; // owner switched it off

  const since = now - 24 * 3600 * 1000;
  const [historySnap, hourlySnap, dailySnap, alertsSnap, powerSnap] = await Promise.all([
    db().ref(`${base}/readings/history`).orderByChild("timestamp").startAt(since).limitToFirst(20000).get(),
    db().ref(`${base}/energy/hourly`).orderByKey().limitToLast(48).get(),
    db().ref(`${base}/energy/daily`).orderByKey().limitToLast(7).get(),
    db().ref(`${base}/alerts`).orderByKey().limitToLast(200).get(),
    db().ref(`${base}/system/powerStatus`).get(),
  ]);

  const summary = buildSummary({
    readings: valuesOf(historySnap),
    hourly: hourlySnap.val() || {},
    daily: dailySnap.val() || {},
    alerts: valuesOf(alertsSnap),
    settings,
    power: powerSnap.val(),
    now,
    tz: TZ_OFFSET_HOURS,
    nominalV: Number(NOMINAL_VOLTAGE.value()) || 12,
    batteryAh: Number(BATTERY_AH.value()) || 20,
  });

  const result = await generateInsight({ summary, service });
  await db().ref(`${base}/insights/latest`).set({
    ...result.insight,
    generatedAt: now,
    source: result.source, // "gemini" or "rules" (fallback when Gemini was unavailable)
    model: result.model,
    dataPoints: summary.dataPoints,
    dataWarnings: summary.dataWarnings,
  });
  // Evidence for the project report: the exact (anonymous) summary and answer, no key, no identifiers.
  logger.info("insight generated", { source: result.source, model: result.model, configIndex: result.configIndex, error: result.error, summary, insight: result.insight });
  return { skipped: false, source: result.source };
}

exports.dailyInsights = onSchedule(
  { schedule: "every day 06:00", timeZone: "Africa/Lusaka", region: REGION, secrets: [GEMINI_API_KEYS], timeoutSeconds: 300, memory: "512MiB" },
  async () => {
    const idsSnap = await db().ref("/systemsIndex").get();
    const now = Date.now();
    const keys = parseApiKeys(GEMINI_API_KEYS.value());
    if (keys.length === 0) {
      logger.error("GEMINI_API_KEYS is empty: insights will use the rule-based fallback");
    }
    // A service with no keys cannot be built; generateInsight then falls back to rules through this stub.
    const service = keys.length
      ? buildGeminiService({ apiKeys: keys, models: parseModels(GEMINI_MODELS.value()), logger })
      : { generateText: async () => { throw new Error("no Gemini API key configured"); } };
    for (const systemId of Object.keys(idsSnap.val() || {})) {
      try {
        await generateForSystem(systemId, now, service);
      } catch (err) {
        logger.error("insight failed for a system", { systemId, message: err && err.message });
      }
    }
  }
);
