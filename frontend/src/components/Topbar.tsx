import { Search, Bell } from "lucide-react";

function TopBar() {
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
        </div>
      </div>
    </header>
  );
}

export default TopBar;
