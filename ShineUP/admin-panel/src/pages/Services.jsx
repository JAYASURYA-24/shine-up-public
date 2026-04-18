import React, { useState, useEffect } from 'react';
import { Loader, Plus, Tag, Clock, DollarSign, Image as ImageIcon, ChevronRight, ChevronDown, Trash2 } from 'lucide-react';
import { api } from '../api/client';

export default function Services() {
  const [services, setServices] = useState([]);
  const [loading, setLoading] = useState(true);
  const [expandedService, setExpandedService] = useState(null);
  const [showServiceModal, setShowServiceModal] = useState(false);
  const [showSKUModal, setShowSKUModal] = useState(null);
  const [formData, setFormData] = useState({ name: '', description: '', category: '', image_url: '' });
  const [skuData, setSkuData] = useState({ title: '', price: '', duration_mins: '' });
  const [submitting, setSubmitting] = useState(false);

  const fetchServices = async () => {
    try {
      const data = await api.getServices();
      setServices(data || []);
    } catch (err) {
      console.error('Failed to load services', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchServices();
  }, []);

  const handleCreateService = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      await api.createService(formData);
      setShowServiceModal(false);
      setFormData({ name: '', description: '', category: '', image_url: '' });
      await fetchServices();
    } catch (err) {
      alert(`Failed to create service: ${err.message}`);
    } finally {
      setSubmitting(false);
    }
  };

  const handleAddSKU = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      await api.addSKU(showSKUModal, {
        ...skuData,
        price: parseFloat(skuData.price),
        duration_mins: parseInt(skuData.duration_mins)
      });
      setShowSKUModal(null);
      setSkuData({ title: '', price: '', duration_mins: '' });
      await fetchServices();
    } catch (err) {
      alert(`Failed to add SKU: ${err.message}`);
    } finally {
      setSubmitting(false);
    }
  };

  const handleDeleteService = async (id) => {
    if (!window.confirm('Are you sure you want to delete this service? All variants will be removed.')) return;
    try {
      await api.deleteService(id);
      await fetchServices();
    } catch (err) {
      alert(`Failed to delete service: ${err.message}`);
    }
  };

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <h1 className="page-title" style={{ margin: 0 }}>Service Catalog</h1>
        <button className="btn-primary" onClick={() => setShowServiceModal(true)}>
          <Plus size={18} /> Add New Service
        </button>
      </div>
      
      <div className="glass-panel">
        {loading ? (
          <div style={{ display: 'flex', justifyContent: 'center', padding: '3rem' }}>
            <Loader size={28} className="spin" style={{ color: 'var(--accent-primary)' }} />
          </div>
        ) : services.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '3rem', color: 'var(--text-muted)' }}>
            No services configured. Start by adding your first service category.
          </div>
        ) : (
          <div className="services-list">
            {services.map((service) => (
              <div key={service.id} className="service-card" style={{ borderBottom: '1px solid var(--border-color)', padding: '1rem 0' }}>
                <div 
                  style={{ display: 'flex', alignItems: 'center', cursor: 'pointer', padding: '0.5rem' }}
                  onClick={() => setExpandedService(expandedService === service.id ? null : service.id)}
                >
                  {expandedService === service.id ? <ChevronDown size={20} /> : <ChevronRight size={20} />}
                  <div style={{ width: 40, height: 40, background: 'var(--bg-card)', borderRadius: '8px', display: 'flex', justifyContent: 'center', alignItems: 'center', margin: '0 1rem' }}>
                    <ImageIcon size={20} className="accent-text" />
                  </div>
                  <div style={{ flex: 1 }}>
                    <h3 style={{ margin: 0 }}>{service.name}</h3>
                    <span className="badge info" style={{ fontSize: '0.7rem' }}>{service.category}</span>
                  </div>
                  <div style={{ textAlign: 'right', marginRight: '1rem' }}>
                    <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>{(service.skus || []).length} Variants</div>
                  </div>
                  <button 
                    className="btn-icon secondary" 
                    title="Add SKU"
                    onClick={(e) => { e.stopPropagation(); setShowSKUModal(service.id); }}
                  >
                    <Plus size={16} />
                  </button>
                  <button 
                    className="btn-icon danger" 
                    title="Delete Service"
                    style={{ marginLeft: '0.5rem', color: '#ff4d4f' }}
                    onClick={(e) => { e.stopPropagation(); handleDeleteService(service.id); }}
                  >
                    <Trash2 size={16} />
                  </button>
                </div>

                {expandedService === service.id && (
                  <div style={{ padding: '1rem 3rem' }}>
                    <p style={{ color: 'var(--text-secondary)', marginBottom: '1rem' }}>{service.description}</p>
                    <div className="sku-grid" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: '1rem' }}>
                      {(service.skus || []).map((sku) => (
                        <div key={sku.id} className="glass-panel" style={{ padding: '1rem', background: 'rgba(255,255,255,0.03)' }}>
                          <h4 style={{ margin: '0 0 0.5rem 0' }}>{sku.title}</h4>
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                            <span className="accent-text" style={{ fontWeight: 700 }}>₹{sku.price}</span>
                            <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}><Clock size={12} /> {sku.duration_mins}m</span>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* New Service Modal */}
      {showServiceModal && (
        <div className="modal-overlay">
          <div className="modal-content glass-panel" style={{ maxWidth: '500px' }}>
            <h2>Create New Service Category</h2>
            <form onSubmit={handleCreateService}>
              <div className="form-group">
                <label>Name</label>
                <input required value={formData.name} onChange={e => setFormData({...formData, name: e.target.value})} placeholder="e.g. Premium Car Wash" />
              </div>
              <div className="form-group">
                <label>Category</label>
                <input required value={formData.category} onChange={e => setFormData({...formData, category: e.target.value})} placeholder="e.g. CAR_CARE" />
              </div>
              <div className="form-group">
                <label>Description</label>
                <textarea value={formData.description} onChange={e => setFormData({...formData, description: e.target.value})} placeholder="Detailed description..." />
              </div>
              <div style={{ display: 'flex', gap: '1rem', marginTop: '1.5rem' }}>
                <button type="button" className="btn-secondary" onClick={() => setShowServiceModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary" disabled={submitting}>Create Service</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Add SKU Modal */}
      {showSKUModal && (
        <div className="modal-overlay">
          <div className="modal-content glass-panel" style={{ maxWidth: '400px' }}>
            <h2>Add Pricing Variant (SKU)</h2>
            <form onSubmit={handleAddSKU}>
              <div className="form-group">
                <label>SKU Title</label>
                <input required value={skuData.title} onChange={e => setSkuData({...skuData, title: e.target.value})} placeholder="e.g. Hatchback / SUV" />
              </div>
              <div className="form-group">
                <label>Price (₹)</label>
                <input type="number" required value={skuData.price} onChange={e => setSkuData({...skuData, price: e.target.value})} placeholder="0.00" />
              </div>
              <div className="form-group">
                <label>Duration (Mins)</label>
                <input type="number" required value={skuData.duration_mins} onChange={e => setSkuData({...skuData, duration_mins: e.target.value})} placeholder="60" />
              </div>
              <div style={{ display: 'flex', gap: '1rem', marginTop: '1.5rem' }}>
                <button type="button" className="btn-secondary" onClick={() => setShowSKUModal(null)}>Cancel</button>
                <button type="submit" className="btn-primary" disabled={submitting}>Add SKU</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
