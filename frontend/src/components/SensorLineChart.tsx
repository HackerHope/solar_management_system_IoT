import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  CartesianGrid,
} from "recharts";
import type { Reading } from "../types/sensors";
import { EmptyState } from "./StatusStates";

function formatTime(timestamp: number) {
  return new Date(timestamp).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

function SensorLineChart({ data }: { data: Reading[] }) {
  const chartData = data.map((r) => ({
    time: formatTime(r.timestamp),
    voltage: r.voltage,
    current: r.current,
  }));

  return (
    <div className="panel large-panel">
      <h3>Voltage & Current</h3>

      {chartData.length === 0 ? (
        <EmptyState message="Waiting for readings from the ESP32..." />
      ) : (
        <ResponsiveContainer width="100%" height={260}>
          <LineChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="time" />
            <YAxis />
            <Tooltip />

            <Line type="monotone" dataKey="voltage" stroke="#4f7cff" strokeWidth={3} dot={false} />
            <Line type="monotone" dataKey="current" stroke="#4ade80" strokeWidth={3} dot={false} />
          </LineChart>
        </ResponsiveContainer>
      )}
    </div>
  );
}

export default SensorLineChart;
