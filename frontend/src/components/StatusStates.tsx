export function LoadingState({ label = "Loading..." }: { label?: string }) {
  return <p className="chart-subtitle">{label}</p>;
}

export function ErrorState({ message }: { message: string }) {
  return <p className="chart-subtitle offline">{message}</p>;
}

export function EmptyState({ message = "No data yet." }: { message?: string }) {
  return <p className="chart-subtitle">{message}</p>;
}
