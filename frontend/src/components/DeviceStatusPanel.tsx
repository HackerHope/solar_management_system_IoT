import type { DeviceStatus } from "../types/sensors";
import { EmptyState } from "./StatusStates";

function DeviceStatusPanel({ devices }: { devices: DeviceStatus[] }) {
  return (
    <div className="panel">
      <h3>Device Status</h3>

      {devices.length === 0 ? (
        <EmptyState message="No devices reporting yet." />
      ) : (
        devices.map((device) => (
          <div className="device-row" key={device.name}>
            <span>{device.name}</span>

            <strong className={device.status === "Online" ? "online" : "offline"}>
              {device.status}
            </strong>
          </div>
        ))
      )}
    </div>
  );
}

export default DeviceStatusPanel;
