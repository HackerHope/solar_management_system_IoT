import TopBar from "../components/Topbar";
import StatCard from "../components/StatCard";
import SensorLineChart from "../components/SensorLineChart";
import PowerChart from "../components/PowerChart";
import SystemOverview from "../components/SystemOverview";
import AlertsPanel from "../components/AlertsPanel";
import DeviceStatusPanel from "../components/DeviceStatusPanel";
import { useLiveData } from "../hooks/useLiveData";
import { ErrorState, LoadingState } from "../components/StatusStates";

function batteryStatusLabel(pct: number) {
  if (pct < 20) return "Low";
  if (pct < 50) return "Fair";
  return "Healthy";
}

function Dashboard() {
  const { latest, history, devices, alerts, connected, loading, error } = useLiveData();

  return (
    <>
      <TopBar temperature={latest?.temperature ?? null} />

      {loading && <LoadingState label="Connecting to your SolarIoT backend..." />}
      {!loading && error && <ErrorState message={error} />}
      {!loading && !error && !connected && (
        <ErrorState message="Live connection lost - reconnecting..." />
      )}

      <section className="stats-grid">
        <StatCard
          icon="🔋"
          title="Battery Level"
          value={latest ? `${latest.batteryPercent.toFixed(0)}%` : "--"}
          status={latest ? batteryStatusLabel(latest.batteryPercent) : "No data"}
        />
        <StatCard
          icon="☀️"
          title="Battery Voltage"
          value={latest ? `${latest.voltage.toFixed(1)} V` : "--"}
          status={latest ? "Stable" : "No data"}
        />
        <StatCard
          icon="⚡"
          title="Load Current"
          value={latest ? `${latest.current.toFixed(1)} A` : "--"}
          status={latest ? "Normal" : "No data"}
        />
        <StatCard
          icon="🌡️"
          title="Temperature"
          value={latest?.temperature != null ? `${latest.temperature.toFixed(0)}°C` : "N/A"}
          status={latest ? "Safe" : "No data"}
        />
      </section>

      <section className="charts-grid">
        <SensorLineChart data={history} />
        <PowerChart data={history} />
      </section>

      <section className="bottom-grid">
        <SystemOverview />
        <AlertsPanel alerts={alerts} limit={3} />
        <DeviceStatusPanel devices={devices} />
      </section>
    </>
  );
}

export default Dashboard;
