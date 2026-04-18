import React, { useState, useEffect } from 'react';
import { Users, TrendingUp, CalendarCheck, DollarSign, Loader, Wifi } from 'lucide-react';
import { api } from '../api/client';
import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer, BarChart, Bar, XAxis, YAxis, CartesianGrid, FunnelChart, Funnel, LabelList } from 'recharts';
import LiveFeed from '../components/LiveFeed';

export default function Dashboard() {
  const [stats, setStats] = useState(null);
  const [bookings, setBookings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [announcement, setAnnouncement] = useState({ title: '', message: '' });
  const [announcementStatus, setAnnouncementStatus] = useState('');

  useEffect(() => {
    Promise.all([api.getStats(), api.getBookings()])
      .then(([statsData, bookingsData]) => {
        setStats(statsData);
        setBookings(bookingsData);
        setLoading(false);
      })
      .catch(err => {
        console.error('Dashboard Stats Error:', err);
        setLoading(false);
      });
  }, []);

  if (loading) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh' }}>
        <Loader size={32} className="spin" style={{ color: 'var(--accent-primary)' }} />
      </div>
    );
  }

  const cards = [
    {
      title: 'Platform Revenue (30%)',
      value: stats ? `₹${(stats.total_revenue * 0.30).toLocaleString('en-IN', {maximumFractionDigits: 0})}` : '—',
      icon: DollarSign,
      gradient: true,
    },
    {
      title: 'Total Bookings',
      value: stats ? stats.total_bookings : '—',
      icon: CalendarCheck,
    },
    {
      title: 'Active Partners',
      value: stats ? `${stats.online_partners}/${stats.total_partners}` : '—',
      icon: Users,
    },
    {
      title: 'Customers',
      value: stats ? stats.total_customers : '—',
      icon: TrendingUp,
    },
    {
      title: 'Pending KYC',
      value: stats ? stats.pending_kyc : '—',
      icon: Users,
    },
    {
      title: 'WS Connections Live',
      value: stats ? `${stats.ws_connections || 0} (${stats.ws_users_online || 0} users)` : '—',
      icon: Wifi,
    },
  ];

  // Prepare chart data
  const statusCounts = bookings.reduce((acc, curr) => {
    acc[curr.status] = (acc[curr.status] || 0) + 1;
    return acc;
  }, {});

  const statusData = Object.keys(statusCounts).map(key => ({
    name: key,
    value: statusCounts[key],
  }));

  const COLORS = {
    'COMPLETED': '#4ade80',
    'IN_PROGRESS': '#facc15',
    'ASSIGNED': '#60a5fa',
    'CREATED': '#fbbf24',
    'CANCELLED': '#f87171'
  };

  const revenueByStatus = bookings.reduce((acc, curr) => {
    acc[curr.status] = (acc[curr.status] || 0) + curr.amount;
    return acc;
  }, {});

  const barData = Object.keys(revenueByStatus).map(key => ({
    name: key.replace('_', ' '),
    Revenue: revenueByStatus[key],
  }));

  const funnelData = stats?.funnel ? [
    { name: 'Signups', value: stats.funnel.signups, fill: '#60a5fa' },
    { name: 'Placed Bookings', value: stats.funnel.placed, fill: '#facc15' },
    { name: 'Completed', value: stats.funnel.completed, fill: '#4ade80' }
  ] : [];

  const handleBroadcast = async (e) => {
    e.preventDefault();
    if (!announcement.title || !announcement.message) return;
    setAnnouncementStatus('Sending...');
    try {
      await api.broadcastAnnouncement(announcement.title, announcement.message);
      setAnnouncementStatus('Sent successfully!');
      setAnnouncement({ title: '', message: '' });
      setTimeout(() => setAnnouncementStatus(''), 3000);
    } catch (err) {
      setAnnouncementStatus('Failed to send.');
    }
  };

  return (
    <div>
      <h1 className="page-title">Analytics Overview</h1>
      
      <div className="stats-grid">
        {cards.map((card, i) => (
          <div className="glass-panel card" key={i}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
              <div>
                <div className="card-title">{card.title}</div>
                <div className={`card-value ${card.gradient ? 'text-gradient' : ''}`}>
                  {card.value}
                </div>
              </div>
              <card.icon size={24} style={{ color: 'var(--text-muted)' }} />
            </div>
          </div>
        ))}
      </div>
      
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 380px', gap: '1.5rem', marginTop: '1.5rem' }}>
        <div className="glass-panel" style={{ padding: '2rem' }}>
          <h2 style={{ fontSize: '1.2rem', marginBottom: '1.5rem' }}>Bookings by Status</h2>
          {bookings.length > 0 ? (
            <div style={{ height: 300 }}>
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={statusData}
                    cx="50%"
                    cy="50%"
                    innerRadius={60}
                    outerRadius={100}
                    paddingAngle={5}
                    dataKey="value"
                  >
                    {statusData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={COLORS[entry.name] || '#8884d8'} />
                    ))}
                  </Pie>
                  <Tooltip wrapperStyle={{ outline: 'none' }} />
                </PieChart>
              </ResponsiveContainer>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '1rem', justifyContent: 'center', marginTop: '1rem' }}>
                {statusData.map(entry => (
                  <div key={entry.name} style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', fontSize: '0.85rem' }}>
                    <div style={{ width: 12, height: 12, borderRadius: '50%', backgroundColor: COLORS[entry.name] || '#8884d8' }} />
                    <span style={{ color: 'var(--text-secondary)' }}>{entry.name.replace('_', ' ')} ({entry.value})</span>
                  </div>
                ))}
              </div>
            </div>
          ) : (
            <p style={{ color: 'var(--text-muted)', textAlign: 'center' }}>No bookings data available yet.</p>
          )}
        </div>

        <div className="glass-panel" style={{ padding: '2rem' }}>
          <h2 style={{ fontSize: '1.2rem', marginBottom: '1.5rem' }}>Revenue Contribution</h2>
          {bookings.length > 0 ? (
            <div style={{ height: 300 }}>
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={barData} margin={{ top: 20, right: 30, left: 20, bottom: 5 }}>
                  <CartesianGrid strokeDasharray="3 3" opacity={0.1} />
                  <XAxis dataKey="name" tick={{ fill: 'var(--text-muted)', fontSize: 12 }} />
                  <YAxis tick={{ fill: 'var(--text-muted)', fontSize: 12 }} />
                  <Tooltip cursor={{ fill: 'rgba(255,255,255,0.05)' }} contentStyle={{ backgroundColor: 'var(--bg-dark)', border: '1px solid var(--border-color)', borderRadius: '8px' }} />
                  <Bar dataKey="Revenue" fill="var(--accent-primary)" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          ) : (
             <p style={{ color: 'var(--text-muted)', textAlign: 'center' }}>No revenue data available yet.</p>
          )}
        </div>

        {/* Live Feed Widget */}
        <LiveFeed />
      </div>

      {/* Row 2 */}
      <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '1.5rem', marginTop: '1.5rem', marginBottom: '2rem' }}>
        
        {/* Funnel Chart */}
        <div className="glass-panel" style={{ padding: '2rem' }}>
          <h2 style={{ fontSize: '1.2rem', marginBottom: '1.5rem' }}>Customer Conversion Funnel</h2>
          {funnelData.length > 0 && funnelData[0].value > 0 ? (
            <div style={{ height: 300 }}>
              <ResponsiveContainer width="100%" height="100%">
                <FunnelChart>
                  <Tooltip wrapperStyle={{ outline: 'none' }} contentStyle={{ backgroundColor: 'var(--bg-dark)', border: '1px solid var(--border-color)', borderRadius: '8px' }} />
                  <Funnel dataKey="value" data={funnelData} isAnimationActive>
                    <LabelList position="right" fill="var(--text-primary)" stroke="none" dataKey="name" />
                  </Funnel>
                </FunnelChart>
              </ResponsiveContainer>
            </div>
          ) : (
             <p style={{ color: 'var(--text-muted)', textAlign: 'center' }}>Not enough data for funnel.</p>
          )}
        </div>

        {/* Global Announcements */}
        <div className="glass-panel" style={{ padding: '2rem' }}>
          <h2 style={{ fontSize: '1.2rem', marginBottom: '1.5rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            📣 Broadcast Announcement
          </h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginBottom: '1.5rem' }}>
            Push a real-time notification to all connected Customer and Partner apps.
          </p>
          <form onSubmit={handleBroadcast} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            <div>
              <label style={{ display: 'block', fontSize: '0.85rem', marginBottom: '0.4rem', color: 'var(--text-secondary)' }}>Title</label>
              <input 
                type="text" 
                required 
                value={announcement.title}
                onChange={e => setAnnouncement({ ...announcement, title: e.target.value })}
                style={{ width: '100%', padding: '0.6rem', borderRadius: '8px', background: 'rgba(255,255,255,0.03)', border: '1px solid var(--border-color)', color: '#fff' }}
                placeholder="e.g. Server Maintenance"
              />
            </div>
            <div>
              <label style={{ display: 'block', fontSize: '0.85rem', marginBottom: '0.4rem', color: 'var(--text-secondary)' }}>Message</label>
              <textarea 
                required 
                rows="3"
                value={announcement.message}
                onChange={e => setAnnouncement({ ...announcement, message: e.target.value })}
                style={{ width: '100%', padding: '0.6rem', borderRadius: '8px', background: 'rgba(255,255,255,0.03)', border: '1px solid var(--border-color)', color: '#fff' }}
                placeholder="Message body..."
              />
            </div>
            <button type="submit" className="btn btn-primary" style={{ marginTop: '0.5rem' }}>
              Broadcast Now
            </button>
            {announcementStatus && (
              <div style={{ textAlign: 'center', fontSize: '0.85rem', color: announcementStatus.includes('Failed') ? 'var(--danger)' : 'var(--success)', marginTop: '0.5rem' }}>
                {announcementStatus}
              </div>
            )}
          </form>
        </div>

      </div>
    </div>
  );
}
