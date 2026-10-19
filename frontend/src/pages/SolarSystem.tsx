import { useLiveData } from "../hooks/useLiveData";
import { LoadingState, ErrorState } from "../components/StatusStates";

type Device = {
  name: string;
  value: string;
  status: "Online" | "Offline" | "Not wired";
  icon: string;
};

function SolarSystem() {
  const { latest, connected, loading, error } = useLiveData();

  const online: Device["status"] = connected ? "Online" : "Offline";

  const devices: Record<string, Device> = {
    solar: {
      name: "Solar Panel",
      value: latest ? `${latest.voltage.toFixed(1)} V` : "--",
      status: online,
      icon: "☀️",
    },
    controller: {
      name: "Charge Controller",
      value: latest ? `${latest.current.toFixed(1)} A` : "--",
      status: online,
      icon: "⚡",
    },
    battery: {
      name: "Battery Monitor",
      value: latest ? `${latest.batteryPercent.toFixed(0)}%` : "--",
      status: online,
      icon: "🔋",
    },
    // No physical load sensor yet - shown honestly rather than faked as Offline/Online
    load: {
      name: "Load Controller",
      value: "No sensor yet",
      status: "Not wired",
      icon: "💡",
    },
  };

  return (
    <div>
      <h1>Solar System Devices</h1>
      <p className="page-text">Visual connection map of your solar system.</p>

      {loading && <LoadingState label="Loading system map..." />}
      {!loading && error && <ErrorState message={error} />}

      {!loading && (
        <div className="solar-network panel">
          <svg className="connection-svg" viewBox="0 0 1000 600">
            <line x1="500" y1="35" x2="500" y2="250" />
            <line x1="500" y1="360" x2="250" y2="470" />
            <line x1="250" y1="470" x2="250" y2="600" />
            <line x1="750" y1="470" x2="750" y2="600" />
            <line x1="500" y1="360" x2="750" y2="470" />
            <line x1="250" y1="600" x2="500" y2="600" />
          </svg>

          <div className="network-row top-row">
            <DeviceCard device={devices.solar} />
          </div>

          <div className="network-row middle-row">
            <DeviceCard device={devices.controller} />
          </div>

          <div className="network-row bottom-row">
            <DeviceCard device={devices.battery} />
            <DeviceCard device={devices.load} />
          </div>
        </div>
      )}
    </div>
  );
}

function DeviceCard({ device }: { device: Device }) {
  const statusClass = device.status === "Online" ? "online" : device.status === "Offline" ? "offline" : "";

  return (
    <div className="solar-device-card">
      <div className="device-heading">
        <span className="device-icon">{device.icon}</span>
        <h3>{device.name}</h3>
      </div>

      <h2>{device.value}</h2>

      <p className={statusClass}>{device.status}</p>
    </div>
  );
}

export default SolarSystem;
