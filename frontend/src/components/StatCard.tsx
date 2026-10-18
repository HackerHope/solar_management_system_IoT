type StatCardProps = {
  icon: string;
  title: string;
  value: string;
  status: string;
};

function StatCard({ icon, title, value, status }: StatCardProps) {
  return (
    <div className="stat-card">
      <div className="stat-icon">{icon}</div>

      <div>
        <p>{title}</p>
        <h2>{value}</h2>
        <span>{status}</span>
      </div>
    </div>
  );
}

export default StatCard;
