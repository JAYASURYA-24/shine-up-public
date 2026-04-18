import { useState, useEffect } from 'react';
import { api } from '../api/client';

export default function Withdrawals() {
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [processingId, setProcessingId] = useState(null);

  const fetchWithdrawals = async () => {
    try {
      const data = await api.getWithdrawals();
      setRequests(data || []);
    } catch (err) {
      alert(err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchWithdrawals();
  }, []);

  const handleProcess = async (id, action) => {
    let bankRef = '';
    if (action === 'APPROVE') {
      bankRef = prompt('Enter Bank Reference / Transaction ID for approval:');
      if (!bankRef) return;
    } else {
      if (!confirm('Are you sure you want to reject this request? The amount will be refunded to the partner wallet.')) return;
    }

    setProcessingId(id);
    try {
      await api.processWithdrawal(id, action, bankRef);
      alert(`Withdrawal ${action.toLowerCase()}ed successfully`);
      fetchWithdrawals();
    } catch (err) {
      alert(err.message);
    } finally {
      setProcessingId(null);
    }
  };

  if (loading) return <div className="p-8">Loading requests...</div>;

  return (
    <div className="max-w-6xl mx-auto space-y-6">
      <h1 className="text-2xl font-bold">Withdrawal Requests</h1>

      <div className="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
        <table className="w-full text-left text-sm text-slate-600">
          <thead className="bg-slate-50 border-b border-slate-200">
            <tr>
              <th className="px-4 py-3 font-semibold text-slate-700">Date</th>
              <th className="px-4 py-3 font-semibold text-slate-700">Partner</th>
              <th className="px-4 py-3 font-semibold text-slate-700">Amount (₹)</th>
              <th className="px-4 py-3 font-semibold text-slate-700">Status</th>
              <th className="px-4 py-3 font-semibold text-slate-700">Bank Ref</th>
              <th className="px-4 py-3 font-semibold text-slate-700 text-right">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {requests.map((r) => (
              <tr key={r.id} className="hover:bg-slate-50">
                <td className="px-4 py-3">{r.created_at}</td>
                <td className="px-4 py-3">
                  <div className="font-medium text-slate-800">{r.partner_name}</div>
                  <div className="text-xs text-slate-500">{r.partner_phone}</div>
                </td>
                <td className="px-4 py-3 font-bold text-slate-800">₹{r.amount}</td>
                <td className="px-4 py-3">
                  <span className={`px-2 py-1 rounded-full text-xs font-semibold ${
                    r.status === 'PENDING' ? 'bg-orange-100 text-orange-700' :
                    r.status === 'APPROVED' ? 'bg-green-100 text-green-700' :
                    'bg-red-100 text-red-700'
                  }`}>
                    {r.status}
                  </span>
                </td>
                <td className="px-4 py-3 text-xs text-slate-500">{r.bank_reference || '-'}</td>
                <td className="px-4 py-3 text-right">
                  {r.status === 'PENDING' && (
                    <div className="flex justify-end gap-2">
                      <button
                        onClick={() => handleProcess(r.id, 'APPROVE')}
                        disabled={processingId === r.id}
                        className="px-3 py-1 bg-green-600 text-white rounded text-xs font-medium hover:bg-green-700 disabled:opacity-50"
                      >
                        Approve
                      </button>
                      <button
                        onClick={() => handleProcess(r.id, 'REJECT')}
                        disabled={processingId === r.id}
                        className="px-3 py-1 bg-red-100 text-red-700 rounded text-xs font-medium hover:bg-red-200 disabled:opacity-50"
                      >
                        Reject
                      </button>
                    </div>
                  )}
                </td>
              </tr>
            ))}
            {requests.length === 0 && (
               <tr>
                 <td colSpan="6" className="px-4 py-8 text-center text-slate-500">
                   No withdrawal requests found.
                 </td>
               </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
