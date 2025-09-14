import { useEffect, useState } from "react";

export default function LiveFeed() {
  const [events, setEvents] = useState([]);

  useEffect(() => {
    const WS_URL = process.env.NEXT_PUBLIC_WS_URL || "ws://localhost:3001";
    const ws = new WebSocket(WS_URL);
    ws.onmessage = (msg) => {
      const evt = JSON.parse(msg.data);
      // Add to the top of the list, and keep the list from getting too long
      setEvents((prev) => [evt, ...prev.slice(0, 49)]);
    };
    return () => ws.close();
  }, []);

  return (
    <div className="p-4 border border-gray-700 rounded-lg">
      <h1 className="text-green-400 text-xl mb-4">Live Event Feed</h1>
      <ul>
        {events.map((e) => (
          // Using a composite key to ensure uniqueness as multiple events share the same root ID
          <li key={`${e.id}-${e.type}-${e.timestamp}`} className="mb-2 animate-pulse once">
            {e.type === "SalaryClaimed" && <span className="text-yellow-400">[CLAIM]</span>}
            {e.type === "StripePayout" && e.status === "success" && <span className="text-green-400">[PAYOUT]</span>}
            {e.type === "StripePayout" && e.status === "fail" && <span className="text-red-500 font-bold">[PAYOUT FAILED]</span>}
            {e.type === "Burn" && <span className="text-red-400">[BURN]</span>}
            {` ${e.type}: ${e.amountUsd} USD → ${e.employee.slice(0, 6)}...${e.employee.slice(-4)}`}
          </li>
        ))}
      </ul>
    </div>
  );
}