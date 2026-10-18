import type { Alert } from "../types/sensors";
import { EmptyState } from "./StatusStates";

const ICONS: Record<Alert["level"], string> = {
  info: "ℹ️",
  warning: "⚠️",
  error: "🔴",
};

function AlertsPanel({ alerts, limit = 3 }: { alerts: Alert[]; limit?: number }) {
  const shown = alerts.slice(0, limit);

  return (
    <div className="panel">
      <h3>Recent Alerts</h3>

      {shown.length === 0 ? (
        <EmptyState message="No alerts. All systems normal." />
      ) : (
        shown.map((alert) => (
          <div className="alert-row" key={alert.id}>
            <span>{ICONS[alert.level]}</span>
            <div>
              <h4>{alert.title}</h4>
              <p>{alert.message}</p>
            </div>
          </div>
        ))
      )}
    </div>
  );
}

export default AlertsPanel;
