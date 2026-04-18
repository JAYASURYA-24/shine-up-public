import React, { useState, useEffect } from 'react';
import { api } from '../api/client';

export default function Hubs() {
  const [hubs, setHubs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [cityFilter, setCityFilter] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ name: '', city: 'Chennai', latitude: '', longitude: '', radius_km: '10' });
  const [saving, setSaving] = useState(false);

  const cities = ['Chennai', 'Bangalore', 'Trichy'];

  useEffect(() => {
    fetchHubs();
  }, [cityFilter]);

  const fetchHubs = async () => {
    setLoading(true);
    try {
      const token = localStorage.getItem('admin_token');
      const url = cityFilter
        ? `${api.baseUrl}/admin/hubs?city=${cityFilter}`
        : `${api.baseUrl}/admin/hubs`;
      const res = await fetch(url, {
        headers: { 'Authorization': `Bearer ${token}` },
      });
      if (res.ok) {
        const data = await res.json();
        setHubs(data || []);
      }
    } catch (e) {
      console.error('Failed to fetch hubs:', e);
    }
    setLoading(false);
  };

  const handleCreate = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      const token = localStorage.getItem('admin_token');
      const res = await fetch(`${api.baseUrl}/admin/hubs`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify({
          name: form.name,
          city: form.city,
          latitude: parseFloat(form.latitude),
          longitude: parseFloat(form.longitude),
          radius_km: parseFloat(form.radius_km),
        }),
      });
      if (res.ok) {
        setShowForm(false);
        setForm({ name: '', city: 'Chennai', latitude: '', longitude: '', radius_km: '10' });
        fetchHubs();
      }
    } catch (e) {
      console.error('Failed to create hub:', e);
    }
    setSaving(false);
  };

  const toggleHub = async (hub) => {
    try {
      const token = localStorage.getItem('admin_token');
      await fetch(`${api.baseUrl}/admin/hubs/${hub.id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify({ is_active: !hub.is_active }),
      });
      fetchHubs();
    } catch (e) {
      console.error('Failed to toggle hub:', e);
    }
  };

  return (
    <div className="page-container">
      <div className="page-header">
        <div>
          <h1>Hub Management</h1>
          <p className="subtitle">Manage serviceability zones across cities</p>
        </div>
        <button className="btn-primary" onClick={() => setShowForm(!showForm)}>
          {showForm ? '✕ Cancel' : '+ Add Hub'}
        </button>
      </div>

      {/* City Filter */}
      <div className="filter-bar">
        <button
          className={`filter-chip ${cityFilter === '' ? 'active' : ''}`}
          onClick={() => setCityFilter('')}
        >All Cities</button>
        {cities.map(city => (
          <button
            key={city}
            className={`filter-chip ${cityFilter === city ? 'active' : ''}`}
            onClick={() => setCityFilter(city)}
          >{city}</button>
        ))}
      </div>

      {/* Create Form */}
      {showForm && (
        <form className="card form-card" onSubmit={handleCreate}>
          <h3>Create New Hub</h3>
          <div className="form-grid">
            <div className="form-group">
              <label>Hub Name</label>
              <input
                type="text"
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                placeholder="e.g. Chennai Central"
                required
              />
            </div>
            <div className="form-group">
              <label>City</label>
              <select value={form.city} onChange={(e) => setForm({ ...form, city: e.target.value })}>
                {cities.map(c => <option key={c} value={c}>{c}</option>)}
              </select>
            </div>
            <div className="form-group">
              <label>Latitude</label>
              <input
                type="number"
                step="any"
                value={form.latitude}
                onChange={(e) => setForm({ ...form, latitude: e.target.value })}
                placeholder="13.0827"
                required
              />
            </div>
            <div className="form-group">
              <label>Longitude</label>
              <input
                type="number"
                step="any"
                value={form.longitude}
                onChange={(e) => setForm({ ...form, longitude: e.target.value })}
                placeholder="80.2707"
                required
              />
            </div>
            <div className="form-group">
              <label>Radius (km)</label>
              <input
                type="number"
                value={form.radius_km}
                onChange={(e) => setForm({ ...form, radius_km: e.target.value })}
                placeholder="10"
              />
            </div>
          </div>
          <button type="submit" className="btn-primary" disabled={saving}>
            {saving ? 'Saving...' : 'Create Hub'}
          </button>
        </form>
      )}

      {/* Hubs Table */}
      {loading ? (
        <div className="loading">Loading hubs...</div>
      ) : (
        <div className="card">
          <table className="data-table">
            <thead>
              <tr>
                <th>Hub Name</th>
                <th>City</th>
                <th>Coordinates</th>
                <th>Radius</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {hubs.length === 0 ? (
                <tr><td colSpan="6" className="empty">No hubs found</td></tr>
              ) : hubs.map(hub => (
                <tr key={hub.id}>
                  <td><strong>{hub.name}</strong></td>
                  <td>{hub.city}</td>
                  <td className="coords">{hub.latitude?.toFixed(4)}, {hub.longitude?.toFixed(4)}</td>
                  <td>{hub.radius_km} km</td>
                  <td>
                    <span className={`status-badge ${hub.is_active ? 'active' : 'inactive'}`}>
                      {hub.is_active ? '● Active' : '○ Inactive'}
                    </span>
                  </td>
                  <td>
                    <button
                      className={`btn-small ${hub.is_active ? 'btn-danger' : 'btn-success'}`}
                      onClick={() => toggleHub(hub)}
                    >
                      {hub.is_active ? 'Deactivate' : 'Activate'}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <style>{`
        .page-container { padding: 0; }
        .page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
        .page-header h1 { margin: 0; font-size: 24px; }
        .subtitle { color: #888; margin: 4px 0 0; font-size: 14px; }
        .btn-primary { background: #4A90E2; color: white; border: none; padding: 10px 20px; border-radius: 8px; cursor: pointer; font-weight: 600; }
        .btn-primary:hover { background: #357ABD; }
        .btn-primary:disabled { opacity: 0.6; cursor: not-allowed; }
        .filter-bar { display: flex; gap: 8px; margin-bottom: 20px; }
        .filter-chip { padding: 8px 16px; border: 1px solid #ddd; border-radius: 20px; background: white; cursor: pointer; font-size: 13px; }
        .filter-chip.active { background: #4A90E2; color: white; border-color: #4A90E2; }
        .card { background: white; border-radius: 12px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); margin-bottom: 20px; }
        .form-card h3 { margin: 0 0 16px; }
        .form-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 12px; margin-bottom: 16px; }
        .form-group label { display: block; font-size: 12px; font-weight: 600; color: #666; margin-bottom: 4px; }
        .form-group input, .form-group select { width: 100%; padding: 8px 12px; border: 1px solid #ddd; border-radius: 8px; font-size: 14px; box-sizing: border-box; }
        .data-table { width: 100%; border-collapse: collapse; }
        .data-table th { text-align: left; padding: 12px 16px; border-bottom: 2px solid #eee; font-size: 12px; text-transform: uppercase; color: #888; }
        .data-table td { padding: 12px 16px; border-bottom: 1px solid #f0f0f0; font-size: 14px; }
        .data-table tr:hover { background: #f8f9fa; }
        .coords { font-family: monospace; font-size: 12px; color: #666; }
        .status-badge { padding: 4px 10px; border-radius: 12px; font-size: 12px; font-weight: 600; }
        .status-badge.active { color: #27AE60; background: #27AE6020; }
        .status-badge.inactive { color: #E74C3C; background: #E74C3C20; }
        .btn-small { padding: 6px 12px; border: none; border-radius: 6px; cursor: pointer; font-size: 12px; font-weight: 600; }
        .btn-danger { background: #E74C3C20; color: #E74C3C; }
        .btn-success { background: #27AE6020; color: #27AE60; }
        .btn-danger:hover { background: #E74C3C; color: white; }
        .btn-success:hover { background: #27AE60; color: white; }
        .loading { text-align: center; padding: 40px; color: #888; }
        .empty { text-align: center; color: #888; padding: 40px !important; }
      `}</style>
    </div>
  );
}
