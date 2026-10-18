import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  CartesianGrid,
  Legend,
} from "recharts";
import type { CircuitsReading } from "../firebase/data";
import { EmptyState } from "./StatusStates";

// Fallback used only when no /circuits data has ever been written - i.e. you
// haven't wired up per-circuit CT sensors yet. See docs/per-circuit-sensors.md.
const SIMULATED_DATA = [
  { time: "10:00", lights: 20, fan: 50, tv: 90, fridge: 120 },
  { time: "10:05", lights: 25, fan: 55, tv: 85, fridge: 130 },
  { time: "10:10", lights: 22, fan: 60, tv: 95, fridge: 125 },
  { time: "10:15", lights: 28, fan: 52, tv: 100, fridge: 135 },
  { time: "10:20", lights: 24, fan: 57, tv: 92, fridge: 128 },
];

function formatTime(timestamp: number) {
  return new Date(timestamp).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

function DeviceUsageChart({ history }: { history: CircuitsReading[] | null }) {
  const isSimulated = history === null;

  const chartData = isSimulated
    ? SIMULATED_DATA
    : history!.map((r) => ({
        time: formatTime(r.timestamp),
        lights: r.lights?.power ?? 0,
        fan: r.fan?.power ?? 0,
        tv: r.tv?.power ?? 0,
        fridge: r.fridge?.power ?? 0,
      }));

  return (
    <div className="panel">
      <h3>
        Live Device Power Usage{" "}
        {isSimulated && (
          <span style={{ fontSize: 12, color: "#f59e0b", fontWeight: "normal" }}>
            (simulated - no per-circuit sensors wired up yet)
          </span>
        )}
      </h3>

      <p className="chart-subtitle">Power consumption trends over time</p>

      {chartData.length === 0 ? (
        <EmptyState message="Waiting for circuit readings..." />
      ) : (
        <ResponsiveContainer width="100%" height={350}>
          <LineChart data={chartData}>
            <CartesianGrid stroke="#334155" strokeDasharray="3 3" />
            <XAxis dataKey="time" stroke="#cbd5e1" />
            <YAxis stroke="#cbd5e1" />
            <Tooltip
              contentStyle={{
                backgroundColor: "#111827",
                border: "1px solid #334155",
                borderRadius: "12px",
                color: "white",
              }}
            />
            <Legend />
            <Line type="monotone" dataKey="lights" stroke="#facc15" strokeWidth={3} dot={false} />
            <Line type="monotone" dataKey="fan" stroke="#22c55e" strokeWidth={3} dot={false} />
            <Line type="monotone" dataKey="tv" stroke="#3b82f6" strokeWidth={3} dot={false} />
            <Line type="monotone" dataKey="fridge" stroke="#ef4444" strokeWidth={3} dot={false} />
          </LineChart>
        </ResponsiveContainer>
      )}
    </div>
  );
}

export default DeviceUsageChart;
