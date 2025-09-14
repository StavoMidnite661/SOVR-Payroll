import { useEffect, useState } from "react";

export default function ProofExplorer() {
  const [files, setFiles] = useState([]);

  useEffect(() => {
    const fetchData = () => {
      fetch('/api/proofs')
        .then(res => res.json())
        .then(setFiles)
        .catch(err => console.error("Failed to fetch proofs:", err));
    };
    fetchData();
    const interval = setInterval(fetchData, 30000); // Poll every 30 seconds

    return () => clearInterval(interval);
  }, []);

  return (
    <div className="p-4 border border-gray-700 rounded-lg">
      <h1 className="text-blue-400 text-xl mb-4">Proof Explorer</h1>
      <ul>
        {files.map((f, i) => (
          <li key={i}>
            <a className="text-cyan-400 underline hover:text-cyan-300" href={f.url} download>{f.name}</a>
          </li>
        ))}
      </ul>
    </div>
  );
}