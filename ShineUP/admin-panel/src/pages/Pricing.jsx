import React, { useState, useEffect } from 'react';
import { Tag, Plus, Save, Loader, AlertCircle } from 'lucide-react';
import { api } from '../api/client';

export default function Pricing() {
  const [services, setServices] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchServices();
  }, []);

  const fetchServices = () => {
    api.getServices()
      .then(data => {
        setServices(data || []);
        setLoading(false);
      })
      .catch(err => {
        console.error(err);
        setLoading(false);
      });
  };

  if (loading) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh' }}>
        <Loader size={32} className="spin" style={{ color: 'var(--accent-primary)' }} />
      </div>
    );
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <h1 className="page-title" style={{ marginBottom: 0 }}>Pricing & Catalog Management</h1>
        <button className="btn btn-primary" style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <Plus size={18} /> New Category
        </button>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
        {services.map(service => (
          <div key={service.id} className="glass-panel" style={{ padding: '1.5rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--border-color)', paddingBottom: '1rem', marginBottom: '1rem' }}>
              <div>
                <h3 style={{ fontSize: '1.1rem', fontWeight: '500' }}>{service.name}</h3>
                <div style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginTop: '0.2rem' }}>Category: {service.category}</div>
              </div>
              <button className="btn btn-outline" style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', padding: '0.4rem 0.8rem', fontSize: '0.85rem' }}>
                <Plus size={14} /> Add SKU
              </button>
            </div>

            <div className="table-container">
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>Variant</th>
                    <th>Base Price (₹)</th>
                    <th>Duration (Mins)</th>
                    <th>Mock Discount (%)</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {service.skus && service.skus.length > 0 ? (
                    service.skus.map(sku => (
                      <tr key={sku.id}>
                        <td>{sku.title}</td>
                        <td>
                          <input 
                            type="number" 
                            defaultValue={sku.price} 
                            style={{ 
                              background: 'rgba(255,255,255,0.05)', border: '1px solid var(--border-color)', 
                              color: 'var(--text-primary)', padding: '0.4rem', borderRadius: '4px', width: '80px' 
                            }} 
                          />
                        </td>
                        <td>{sku.duration_mins}</td>
                        <td>
                          <input 
                            type="number" 
                            placeholder="0" 
                            style={{ 
                              background: 'rgba(255,255,255,0.05)', border: '1px solid var(--border-color)', 
                              color: 'var(--text-primary)', padding: '0.4rem', borderRadius: '4px', width: '60px' 
                            }} 
                          />
                        </td>
                        <td>
                          <button className="btn-icon" style={{ color: 'var(--accent-primary)' }} title="Save Changes">
                            <Save size={16} />
                          </button>
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan="5" style={{ textAlign: 'center', color: 'var(--text-muted)' }}>
                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.5rem', padding: '1rem 0' }}>
                          <AlertCircle size={16} /> No SKUs associated with this service
                        </div>
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        ))}

        {services.length === 0 && (
          <div className="glass-panel" style={{ padding: '3rem', textAlign: 'center', color: 'var(--text-muted)' }}>
            No service categories found. Build your catalog!
          </div>
        )}
      </div>
    </div>
  );
}
