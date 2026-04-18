import React, { useState, useEffect } from 'react';
import { Loader } from 'lucide-react';
import { api } from '../api/client';

export default function Customers() {
  const [customers, setCustomers] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.getCustomers().then(data => {
      setCustomers(data || []);
      setLoading(false);
    });
  }, []);

  return (
    <div>
      <h1 className="page-title">Customers</h1>
      
      <div className="glass-panel">
        {loading ? (
          <div style={{ display: 'flex', justifyContent: 'center', padding: '3rem' }}>
            <Loader size={28} className="spin" style={{ color: 'var(--accent-primary)' }} />
          </div>
        ) : customers.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '3rem', color: 'var(--text-muted)' }}>
            No customers registered yet. They will appear here after signing up via the Customer App.
          </div>
        ) : (
          <table className="premium-table">
            <thead>
              <tr>
                <th>Customer Name</th>
                <th>Phone</th>
                <th>Wallet Balance</th>
                <th>Referral Code</th>
              </tr>
            </thead>
            <tbody>
              {customers.map(customer => (
                <tr key={customer.id}>
                  <td style={{ fontWeight: 500 }}>{customer.name || 'Unnamed'}</td>
                  <td>{customer.phone}</td>
                  <td>₹{customer.wallet_balance.toFixed(2)}</td>
                  <td>
                    <code style={{ background: 'rgba(59, 130, 246, 0.15)', padding: '0.25rem 0.5rem', borderRadius: '4px', fontSize: '0.8rem', color: 'var(--accent-primary)' }}>
                      {customer.referral_code || '—'}
                    </code>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
