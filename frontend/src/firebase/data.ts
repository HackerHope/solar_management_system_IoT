import {
  ref,
  onValue,
  query,
  limitToLast,
  push,
  set,
  get,
  serverTimestamp,
} from "firebase/database";
import { db } from "./config";
import type { Reading, DeviceStatus, Alert, Settings } from "../types/sensors";

// Each installation lives under systems/<id>/ (same layout the Flutter app and the
// ESP32 firmware use). Set VITE_SYSTEM_ID in frontend/.env to view a different system.
const SYSTEM_ID: string = import.meta.env.VITE_SYSTEM_ID || "default";
const sysPath = (p: string) => `systems/${SYSTEM_ID}/${p}`;

const HISTORY_LIMIT = 50;
const DEVICE_NAMES = [
  "ESP32 Controller",
  "Battery Voltage Sensor",
  "Battery Current Sensor",
  "Battery Monitor",
] as const;
const STALE_MS = 15000;

// ---- Readings ----

export function subscribeLatestReading(
  cb: (reading: Reading | null) => void,
  onError?: (err: Error) => void
) {
  return onValue(
    ref(db, sysPath("readings/latest")),
    (snap) => cb(snap.val()),
    (err) => onError?.(err as unknown as Error)
  );
}

export function subscribeHistory(
  cb: (readings: Reading[]) => void,
  onError?: (err: Error) => void
) {
  const q = query(ref(db, sysPath("readings/history")), limitToLast(HISTORY_LIMIT));
  return onValue(
    q,
    (snap) => {
      const val = snap.val() || {};
      const list: Reading[] = Object.values(val);
      list.sort((a, b) => a.timestamp - b.timestamp);
      cb(list);
    },
    (err) => onError?.(err as unknown as Error)
  );
}

// ---- Devices (derived from a heartbeat the ESP32 writes on every push) ----

export function subscribeDevices(
  cb: (devices: DeviceStatus[]) => void,
  onError?: (err: Error) => void
) {
  return onValue(
    ref(db, sysPath("system/lastSeen")),
    (snap) => {
      const lastSeen = snap.val();
      const online = typeof lastSeen === "number" && Date.now() - lastSeen < STALE_MS;
      const status: DeviceStatus["status"] = online ? "Online" : "Offline";
      cb(DEVICE_NAMES.map((name) => ({ name, status })));
    },
    (err) => onError?.(err as unknown as Error)
  );
}

// ---- Alerts ----

export function subscribeAlerts(
  cb: (alerts: Alert[]) => void,
  onError?: (err: Error) => void
) {
  const q = query(ref(db, sysPath("alerts")), limitToLast(50));
  return onValue(
    q,
    (snap) => {
      const val = snap.val() || {};
      const list: Alert[] = Object.entries(val).map(([id, v]: [string, any]) => ({
        id,
        ...v,
      }));
      list.sort((a, b) => b.timestamp - a.timestamp);
      cb(list);
    },
    (err) => onError?.(err as unknown as Error)
  );
}

// Simple per-browser-tab de-dupe so the same breach doesn't spam duplicate
// alerts every time a reading comes in while the threshold stays crossed.
const recentAlertKeys = new Map<string, number>();
const ALERT_COOLDOWN_MS = 5 * 60 * 1000;

export async function raiseAlert(
  level: Alert["level"],
  title: string,
  message: string
) {
  const key = `${level}:${title}`;
  const last = recentAlertKeys.get(key);
  if (last && Date.now() - last < ALERT_COOLDOWN_MS) return;
  recentAlertKeys.set(key, Date.now());

  const alertRef = push(ref(db, sysPath("alerts")));
  await set(alertRef, {
    level,
    title,
    message,
    timestamp: Date.now(),
  });
}

// ---- Settings ----

const DEFAULT_SETTINGS: Settings = {
  batteryLowPct: 20,
  readingIntervalSec: 5,
};

export function subscribeSettings(cb: (settings: Settings) => void) {
  return onValue(ref(db, sysPath("settings")), (snap) => {
    cb({ ...DEFAULT_SETTINGS, ...(snap.val() || {}) });
  });
}

export async function saveSettings(settings: Settings) {
  await set(ref(db, sysPath("settings")), settings);
}

export async function getSettingsOnce(): Promise<Settings> {
  const snap = await get(ref(db, sysPath("settings")));
  return { ...DEFAULT_SETTINGS, ...(snap.val() || {}) };
}

// ---- Per-circuit power (lights/fan/tv/fridge - only real once you've wired
// up the CT sensors described in docs/per-circuit-sensors.md).
// One document covers all circuits per timestamp, to keep ESP32 writes cheap:
//   /circuits/latest         = CircuitsReading
//   /circuits/history/{id}   = CircuitsReading

export type CircuitName = "lights" | "fan" | "tv" | "fridge";
export type CircuitsReading = { timestamp: number } & Partial<
  Record<CircuitName, { current: number; power: number }>
>;

const CIRCUITS_HISTORY_LIMIT = 50;

// cb(null) means no circuit sensors have ever reported - caller should show
// the clearly-labeled simulated fallback instead of an empty real chart.
export function subscribeCircuitsLatest(
  cb: (reading: CircuitsReading | null) => void,
  onError?: (err: Error) => void
) {
  return onValue(
    ref(db, sysPath("circuits/latest")),
    (snap) => cb(snap.exists() ? snap.val() : null),
    (err) => onError?.(err as unknown as Error)
  );
}

export function subscribeCircuitsHistory(
  cb: (readings: CircuitsReading[] | null) => void,
  onError?: (err: Error) => void
) {
  const q = query(ref(db, sysPath("circuits/history")), limitToLast(CIRCUITS_HISTORY_LIMIT));
  return onValue(
    q,
    (snap) => {
      if (!snap.exists()) {
        cb(null);
        return;
      }
      const val = snap.val();
      const list: CircuitsReading[] = Object.values(val);
      list.sort((a, b) => a.timestamp - b.timestamp);
      cb(list);
    },
    (err) => onError?.(err as unknown as Error)
  );
}

export { serverTimestamp };
