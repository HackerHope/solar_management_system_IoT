import { useEffect, useState, type FormEvent } from "react";
import { subscribeSettings, saveSettings } from "../firebase/data";
import type { Settings as SettingsType } from "../types/sensors";
import { LoadingState } from "../components/StatusStates";

function Settings() {
  const [settings, setSettings] = useState<SettingsType | null>(null);
  const [saving, setSaving] = useState(false);
  const [savedAt, setSavedAt] = useState<number | null>(null);

  useEffect(() => subscribeSettings(setSettings), []);

  if (!settings) return <LoadingState label="Loading settings..." />;

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (!settings) return;
    setSaving(true);
    try {
      await saveSettings(settings);
      setSavedAt(Date.now());
    } finally {
      setSaving(false);
    }
  }

  return (
    <div>
      <h1>Settings</h1>
      <p className="page-text">
        Configure system preferences. These are read by the dashboard for
        alerts, and can be read by the ESP32 to adjust its reading interval.
      </p>

      <form onSubmit={handleSubmit}>
        <div className="page-grid">
          <div className="panel">
            <h3>Temperature Limit (°C)</h3>
            <input
              className="input"
              type="number"
              value={settings.tempLimitC}
              onChange={(e) =>
                setSettings({ ...settings, tempLimitC: Number(e.target.value) })
              }
            />
          </div>

          <div className="panel">
            <h3>Battery Low Alert (%)</h3>
            <input
              className="input"
              type="number"
              value={settings.batteryLowPct}
              onChange={(e) =>
                setSettings({ ...settings, batteryLowPct: Number(e.target.value) })
              }
            />
          </div>

          <div className="panel">
            <h3>Reading Interval (seconds)</h3>
            <input
              className="input"
              type="number"
              value={settings.readingIntervalSec}
              onChange={(e) =>
                setSettings({ ...settings, readingIntervalSec: Number(e.target.value) })
              }
            />
          </div>
        </div>

        <button className="primary-btn" type="submit" disabled={saving} style={{ maxWidth: 200 }}>
          {saving ? "Saving..." : "Save Settings"}
        </button>

        {savedAt && (
          <p className="chart-subtitle" style={{ marginTop: 10 }}>
            Saved at {new Date(savedAt).toLocaleTimeString()}
          </p>
        )}
      </form>
    </div>
  );
}

export default Settings;
