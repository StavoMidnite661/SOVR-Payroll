import { useEffect, useState } from "react";

export default function Reconciliation() {
  const [incomplete, setIncomplete] = useState([]);

  useEffect(() => {
    const fetchData = () => {
      fetch("http://localhost:3001/reconciliation")
        .then(res => res.json())
        .then(setIncomplete)
        .catch(err => console.error("Failed to fetch reconciliation data:", err));
    };
    fetchData();
    const interval = setInterval(fetchData, 5000); // Poll every 5 seconds

    return () => clearInterval(interval);
  }, []);

  return (
    <div className="p-4 border border-gray-700 rounded-lg">
      <h1 className="text-red-400 text-xl mb-4">Reconciliation Alerts</h1>
      {incomplete.length === 0 ? (
        <p className="text-green-400">All systems nominal. No pending reconciliations.</p>
      ) : (
        <ul>{incomplete.map((e, i) => (<li key={i} className="text-yellow-400 animate-pulse">{`[${e.status.toUpperCase()}] ${e.address.slice(0, 6)}...${e.address.slice(-4)} needs reconciliation.`}</li>))}</ul>
      )}
    </div>
  );
}