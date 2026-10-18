import { useState, type FormEvent } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

function Login() {
  const { login, error } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const redirectTo = (location.state as { from?: string })?.from || "/";

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setSubmitting(true);
    try {
      await login(email, password);
      navigate(redirectTo, { replace: true });
    } catch {
      // error is surfaced via useAuth().error
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div
      style={{
        minHeight: "100vh",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      <form onSubmit={handleSubmit} className="panel" style={{ width: 340 }}>
        <div className="brand" style={{ marginBottom: 24 }}>
          <div className="brand-icon">☀️</div>
          <div>
            <h2>SolarIoT</h2>
            <p>Sign in to view your dashboard</p>
          </div>
        </div>

        <input
          className="input"
          type="email"
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          autoComplete="username"
          required
        />
        <input
          className="input"
          type="password"
          placeholder="Password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          autoComplete="current-password"
          required
        />

        {error && (
          <p className="chart-subtitle offline" style={{ marginTop: 12 }}>
            {error}
          </p>
        )}

        <button className="primary-btn" type="submit" disabled={submitting}>
          {submitting ? "Signing in..." : "Sign In"}
        </button>
      </form>
    </div>
  );
}

export default Login;
