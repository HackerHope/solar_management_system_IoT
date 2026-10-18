import { NavLink, useNavigate } from "react-router-dom";
import {
  LayoutDashboard,
  Cpu,
  Sun,
  BarChart3,
  Bell,
  Settings,
  Info,
  LogOut,
} from "lucide-react";
import { useAuth } from "../context/AuthContext";

function Sidebar() {
  const { logout, user } = useAuth();
  const navigate = useNavigate();

  async function handleLogout() {
    await logout();
    navigate("/login", { replace: true });
  }

  return (
    <aside className="sidebar">
      <div className="brand">
        <div className="brand-icon">☀️</div>
        <div>
          <h2>SolarIoT</h2>
          <p>Smart Energy Monitor</p>
        </div>
      </div>

      <nav className="menu">
        <NavLink to="/"><LayoutDashboard size={20} /> Dashboard</NavLink>
        <NavLink to="/devices"><Cpu size={20} /> Devices</NavLink>
        <NavLink to="/solar-system"><Sun size={20} /> Solar System</NavLink>
        <NavLink to="/analytics"><BarChart3 size={20} /> Analytics</NavLink>
        <NavLink to="/alerts"><Bell size={20} /> Alerts</NavLink>
        <NavLink to="/settings"><Settings size={20} /> Settings</NavLink>
        <NavLink to="/about-us"><Info size={20} /> About Us</NavLink>
      </nav>

      <div className="sidebar-card">
        <span className="green-dot"></span>
        <div>
          <h4>System Status</h4>
          <p>All systems operational</p>
        </div>
      </div>

      <button
        onClick={handleLogout}
        className="menu-a-like"
        style={{
          marginTop: 14,
          display: "flex",
          alignItems: "center",
          gap: 12,
          color: "#d1d5db",
          background: "none",
          border: "none",
          padding: 14,
          cursor: "pointer",
          fontSize: 14,
        }}
        title={user?.email ?? "Sign out"}
      >
        <LogOut size={20} /> Sign out
      </button>
    </aside>
  );
}

export default Sidebar;
