import {
  AreaChart,
  Area,
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

function PowerChart({ data }: { data: Reading[] }) {
  const chartData = data.map((r) => ({
    time: formatTime(r.timestamp),
    power: r.power,
  }));

  return (
    <div className="panel large-panel">
      <h3>Power Generation</h3>

      {chartData.length === 0 ? (
        <EmptyState message="Waiting for readings from the ESP32..." />
      ) : (
        <ResponsiveContainer width="100%" height={260}>
          <AreaChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="time" />
            <YAxis />
            <Tooltip formatter={(value) => [`${value} W`, "Power"]} />

            <Area
              type="monotone"
              dataKey="power"
              stroke="#a855f7"
              fill="#6d28d9"
              strokeWidth={3}
            />
          </AreaChart>
        </ResponsiveContainer>
      )}
    </div>
  );
}

export default PowerChart;
