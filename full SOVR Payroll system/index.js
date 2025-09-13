import Ledger from "./Ledger";
import LiveFeed from "./LiveFeed";
import ProofExplorer from "./ProofExplorer";
import Reconciliation from "./Reconciliation";

export default function Home() {
  return (
    <main className="min-h-screen p-8 grid grid-cols-1 md:grid-cols-2 gap-8">
      <div>
        <h1 className="text-2xl text-purple-400 mb-6">SOVR Payroll Command Center</h1>
        <LiveFeed />
      </div>
      <div className="flex flex-col gap-8">
        <Ledger />
        <Reconciliation />
        <ProofExplorer />
      </div>
    </main>
  );
}