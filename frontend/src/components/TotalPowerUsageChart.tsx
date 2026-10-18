import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  CartesianGrid,
  LabelList,
} from "recharts";
import type { CircuitsReading, CircuitName } from "../firebase/data";
import { EmptyState } from "./StatusStates";

const SIMULATED_DATA = [
  { device: "Lights", totalUsage: 300 },
  { device: "Fan", totalUsage: 650 },
  { device: "TV", totalUsage: 900 },
  { device: "Fridge", totalUsage: 1200 },
];

const CIRCUIT_LABELS: Record<CircuitName, string> = {
  lights: "Lights",
  fan: "Fan",
  tv: "TV",
  fridge: "Fridge",
};

// Sums power (W) across all history points and converts to a rough Wh
// estimate, assuming roughly even spacing between readings.
function summarizeUsage(history: CircuitsReading[]): { device: string; totalUsage: number }[] {
  if (history.length < 2) return [];

  const totals: Record<string, number> = { lights: 0, fan: 0, tv: 0, fridge: 0 };
  for (let i = 1; i < history.length; i++) {
    const hours = (history[i].timestamp - history[i - 1].timestamp) / (1000 * 60 * 60);
    (Object.keys(CIRCUIT_LABELS) as CircuitName[]).forEach((name) => {
      const watts = history[i][name]?.power ?? 0;
      totals[name] += watts * hours;
    });
  }

  return (Object.keys(CIRCUIT_LABELS) as CircuitName[]).map((name) => ({
    device: CIRCUIT_LABELS[name],
    totalUsage: Math.round(totals[name]),
  }));
}

function TotalPowerUsageBarChart({ history }: { history: CircuitsReading[] | null }) {
  const isSimulated = history === null;
  const chartData = isSimulated ? SIMULATED_DATA : summarizeUsage(history!);

  return (
    <div className="panel">
      <div className="chart-header">
        <div>
          <h3>
            Total Device Power Usage{" "}
            {isSimulated && (
              <span style={{ fontSize: 12, color: "#f59e0b", fontWeight: "normal" }}>
                (simulated - no per-circuit sensors wired up yet)
              </span>
            )}
          </h3>
          <p className="chart-subtitle">
            {isSimulated
              ? "Total energy consumed by each device"
              : "Estimated Wh consumed by each circuit over the recent history window"}
          </p>
        </div>
      </div>

      {chartData.length === 0 ? (
        <EmptyState message="Waiting for enough circuit readings to estimate usage..." />
      ) : (
        <ResponsiveContainer width="100%" height={350}>
          <BarChart data={chartData}>
            <CartesianGrid stroke="#334155" strokeDasharray="3 3" />
            <XAxis dataKey="device" stroke="#cbd5e1" />
            <YAxis stroke="#cbd5e1" />
            <Tooltip
              contentStyle={{
                backgroundColor: "#111827",
                border: "1px solid #334155",
                borderRadius: "12px",
                color: "white",
              }}
              formatter={(value) => [`${value} Wh`, "Total Usage"]}
            />
            <Bar dataKey="totalUsage" fill="#4f46e5" radius={[10, 10, 0, 0]} barSize={45}>
              <LabelList
                dataKey="totalUsage"
                position="top"
                fill="#ffffff"
                formatter={(value: number) => `${value} Wh`}
              />
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      )}
    </div>
  );
}

export default TotalPowerUsageBarChart;
