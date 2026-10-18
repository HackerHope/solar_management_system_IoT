import AlertsPanel from "../components/AlertsPanel";
import { useLiveData } from "../hooks/useLiveData";
import { ErrorState, LoadingState } from "../components/StatusStates";

function Alerts() {
  const { alerts, loading, error } = useLiveData();

  return (
    <div>
      <h1>Alerts</h1>
      <p className="page-text">System warnings and notifications.</p>

      {loading && <LoadingState label="Loading alerts..." />}
      {!loading && error && <ErrorState message={error} />}

      {!loading && !error && <AlertsPanel alerts={alerts} limit={alerts.length} />}
    </div>
  );
}

export default Alerts;
