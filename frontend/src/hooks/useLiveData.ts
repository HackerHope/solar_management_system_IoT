import { useEffect, useRef, useState } from "react";
import {
  subscribeLatestReading,
  subscribeHistory,
  subscribeDevices,
  subscribeAlerts,
  subscribeSettings,
  raiseAlert,
} from "../firebase/data";
import type { Reading, DeviceStatus, Alert, Settings } from "../types/sensors";

const CLIENT_SIDE_ALERTS = import.meta.env.VITE_CLIENT_SIDE_ALERTS !== "false";

type LiveDataState = {
  latest: Reading | null;
  history: Reading[];
  devices: DeviceStatus[];
  alerts: Alert[];
  settings: Settings | null;
  connected: boolean;
  loading: boolean;
  error: string | null;
};

/**
 * Subscribes to Firebase Realtime Database for live sensor data, device
 * status, alerts, and settings. Also runs client-side threshold checks
 * against incoming readings and raises alerts when they're crossed - see
 * firebase/data.ts raiseAlert() for the de-dupe/cooldown logic.
 */
export function useLiveData(): LiveDataState {
  const [latest, setLatest] = useState<Reading | null>(null);
  const [history, setHistory] = useState<Reading[]>([]);
  const [devices, setDevices] = useState<DeviceStatus[]>([]);
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [settings, setSettings] = useState<Settings | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const settingsRef = useRef<Settings | null>(null);
  settingsRef.current = settings;

  useEffect(() => {
    const handleError = (err: Error) => {
      setLoading(false);
      setError(
        err.message?.includes("permission")
          ? "You don't have permission to read this data - check the database rules."
          : "Lost connection to Firebase. Retrying..."
      );
    };

    const unsubs = [
      subscribeLatestReading((reading) => {
        setLatest(reading);
        setLoading(false);
        setError(null);
        // Skipped when the Cloud Functions raise alerts (set VITE_CLIENT_SIDE_ALERTS=false)
        if (reading && CLIENT_SIDE_ALERTS) checkThresholds(reading, settingsRef.current);
      }, handleError),
      subscribeHistory(setHistory, handleError),
      subscribeDevices(setDevices, handleError),
      subscribeAlerts(setAlerts, handleError),
      subscribeSettings(setSettings),
    ];

    return () => unsubs.forEach((unsub) => unsub());
  }, []);

  // "connected" here means we're getting fresh data, not just that the
  // websocket-equivalent is open - Firebase's SDK manages its own socket
  // and reconnects transparently, so device freshness is the meaningful signal.
  const connected =
    devices.length > 0 && devices.every((d) => d.status === "Online");

  return { latest, history, devices, alerts, settings, connected, loading, error };
}

function checkThresholds(reading: Reading, settings: Settings | null) {
  const batteryLow = settings?.batteryLowPct ?? 20;

  if (reading.batteryPercent < batteryLow) {
    raiseAlert(
      "warning",
      "Low Battery",
      `Battery at ${reading.batteryPercent.toFixed(0)}% (alert below ${batteryLow}%)`
    );
  }
  // `voltage` is the BATTERY voltage with the power-management firmware
  const lowVoltage = settings?.lowVoltageV ?? 10.5;
  if (reading.voltage < lowVoltage) {
    raiseAlert("error", "Low Battery Voltage", `Battery voltage dropped to ${reading.voltage.toFixed(2)}V (limit ${lowVoltage}V)`);
  }
}
