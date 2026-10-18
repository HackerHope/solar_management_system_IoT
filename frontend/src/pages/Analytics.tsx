import { useEffect, useState } from "react";
import SensorLineChart from "../components/SensorLineChart";
import PowerChart from "../components/PowerChart";
import DevicePowerChart from "../components/DevicePowerChart";
import TotalPowerUsageBarChart from "../components/TotalPowerUsageChart";
import { useLiveData } from "../hooks/useLiveData";
import { subscribeCircuitsHistory, type CircuitsReading } from "../firebase/data";
import { LoadingState, ErrorState } from "../components/StatusStates";

function Analytics() {
  const { history, loading, error } = useLiveData();
  const [circuitHistory, setCircuitHistory] = useState<CircuitsReading[] | null>(null);

  useEffect(() => subscribeCircuitsHistory(setCircuitHistory), []);

  return (
    <div>
      <h1>Analytics</h1>
      <p className="page-text">Study voltage, current, and power trends.</p>

      {loading && <LoadingState label="Loading analytics..." />}
      {!loading && error && <ErrorState message={error} />}

      <h2>Solar Output Data</h2>
      <div className="charts-grid">
        <SensorLineChart data={history} />
        <PowerChart data={history} />
      </div>

      <h2 style={{ marginTop: 22 }}>Device Usage Data</h2>
      <div>
        <DevicePowerChart history={circuitHistory} />
      </div>
      <div style={{ marginTop: "22px" }}>
        <TotalPowerUsageBarChart history={circuitHistory} />
      </div>
    </div>
  );
}

export default Analytics;
