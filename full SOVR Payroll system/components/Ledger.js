import { useEffect, useState } from "react";

export default function Ledger() {
  const [employees, setEmployees] = useState([]);

  useEffect(() => {
    const fetchData = () => {
      fetch("http://localhost:4000/employees")
        .then(res => res.json())
        .then(setEmployees)
        .catch(err => console.error("Failed to fetch employee ledger:", err));
    };
    fetchData();
    const interval = setInterval(fetchData, 5000); // Poll every 5 seconds

    return () => clearInterval(interval);
  }, []);

  return (
    <div className="p-4 border border-gray-700 rounded-lg mb-4">
      <h1 className="text-purple-400 text-xl mb-4">Employee Ledger</h1>
      <table className="w-full text-left">
        <thead className="border-b border-gray-700">
          <tr>
            <th className="pb-2">Address</th>
            <th className="pb-2">Last Payout</th>
            <th className="pb-2">Status</th>
            <th className="pb-2">Mode</th>
          </tr>
        </thead>
        <tbody>
          {employees.map((e, i) => (
            <tr key={i} className="border-b border-gray-800">
              <td className="py-2">{`${e.address.slice(0, 6)}...${e.address.slice(-4)}`}</td>
              <td className="py-2">${e.lastPayout.toFixed(2)}</td>
              <td className={`py-2 font-bold capitalize ${
                  e.status === "reconciled" ? "text-green-400" :
                  e.status === "paid" ? "text-blue-400" :
                  e.status === "pending" ? "text-yellow-400" : 
                  e.status === "failed" ? "text-red-500" :
                  "text-red-400"
              }`}>{e.status}</td>
              <td className="py-2">{e.mode}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}