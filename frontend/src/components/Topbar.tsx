import { Search, Bell } from "lucide-react";

function TopBar({ temperature }: { temperature?: number | null }) {
  const today = new Date().toLocaleDateString(undefined, {
    year: "numeric",
    month: "long",
    day: "numeric",
  });

  return (
    <header className="topbar">
      <div>
        <h1>Dashboard</h1>
        <p>Welcome back. Here’s what’s happening with your solar system today.</p>
      </div>

      <div className="top-actions">
        <Search />
        <Bell />

        <div className="date-box">
          <p>{today}</p>
          <strong>{temperature != null ? `${temperature.toFixed(0)}°C` : "--°C"}</strong>
        </div>
      </div>
    </header>
  );
}

export default TopBar;
