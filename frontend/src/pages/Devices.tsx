import { useLiveData } from "../hooks/useLiveData";
import { ErrorState, LoadingState, EmptyState } from "../components/StatusStates";

const ICONS: Record<string, string> = {
  "ESP32 Controller": "📡",
  "Battery Voltage Sensor": "🔌",
  "Battery Current Sensor": "⚡",
  "Temperature Sensor": "🌡️",
  "Battery Monitor": "🔋",
};

function Devices() {
  const { devices, latest, loading, error } = useLiveData();

  return (
    <div>
      <h1>Solar System Devices</h1>
      <p className="page-text">
        Live status of every sensor reporting from your ESP32.
      </p>

      {loading && <LoadingState label="Loading device status..." />}
      {!loading && error && <ErrorState message={error} />}

      {!loading && !error && devices.length === 0 && (
        <EmptyState message="No devices reporting yet." />
      )}

      {!loading && !error && devices.length > 0 && (
        <div className="page-grid">
          {devices.map((device) => (
            <div className="panel" key={device.name}>
              <h3>
                <span className="device-icon">{ICONS[device.name] ?? "🔧"}</span>
                {device.name}
              </h3>
              <h2>{readingValueFor(device.name, latest)}</h2>
              <p className={device.status === "Online" ? "online" : "offline"}>
                {device.status}
              </p>
            </div>
          ))}
        </div>
      )}

      <div className="panel" style={{ marginTop: 22 }}>
        <h3>Per-appliance monitoring</h3>
        <p className="chart-subtitle" style={{ marginBottom: 0 }}>
          Breaking usage down by individual appliance (lights, fan, TV, fridge)
          needs a current sensor on each circuit. Right now this system measures
          total system voltage, current, temperature and battery — add per-circuit
          sensors to unlock per-device numbers.
        </p>
      </div>
    </div>
  );
}

function readingValueFor(
  deviceName: string,
  latest: ReturnType<typeof useLiveData>["latest"]
) {
  if (!latest) return "--";
  switch (deviceName) {
    case "Battery Voltage Sensor":
      return `${latest.voltage.toFixed(1)} V`;
    case "Battery Current Sensor":
      return `${latest.current.toFixed(1)} A`;
    case "Temperature Sensor":
      return latest.temperature != null ? `${latest.temperature.toFixed(0)}°C` : "No sensor";
    case "Battery Monitor":
      return `${latest.batteryPercent.toFixed(0)}%`;
    default:
      return "—";
  }
}

export default Devices;
