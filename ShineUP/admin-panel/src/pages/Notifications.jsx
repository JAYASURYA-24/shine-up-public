import { useState, useEffect } from 'react';
import { Bell, Check, CheckCheck, Search, Filter } from 'lucide-react';
import { api } from '../api/client';

export default function Notifications() {
  const [notifications, setNotifications] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');

  useEffect(() => {
    loadNotifications();
  }, []);

  const loadNotifications = async () => {
    setLoading(true);
    try {
      const data = await api.getAdminNotifications();
      setNotifications(data || []);
    } catch (e) {
      console.error('Failed to load notifications:', e);
    }
    setLoading(false);
  };

  const formatTime = (dateStr) => {
    if (!dateStr) return '';
    const dt = new Date(dateStr);
    const now = new Date();
    const diffMs = now - dt;
    const diffMin = Math.floor(diffMs / 60000);
    if (diffMin < 1) return 'Just now';
    if (diffMin < 60) return `${diffMin}m ago`;
    const diffHr = Math.floor(diffMin / 60);
    if (diffHr < 24) return `${diffHr}h ago`;
    const diffDay = Math.floor(diffHr / 24);
    if (diffDay < 7) return `${diffDay}d ago`;
    return dt.toLocaleDateString();
  };

  const getTypeColor = (title) => {
    if (title?.includes('Assigned')) return '#3b82f6';
    if (title?.includes('Confirmed') || title?.includes('Approved')) return '#10b981';
    if (title?.includes('Started')) return '#f59e0b';
    if (title?.includes('Completed') || title?.includes('Done')) return '#059669';
    if (title?.includes('Cancelled') || title?.includes('Rejected')) return '#ef4444';
    return '#6b7280';
  };

  const filtered = notifications.filter(n => {
    if (!search) return true;
    const q = search.toLowerCase();
    return (n.title?.toLowerCase().includes(q) || n.body?.toLowerCase().includes(q));
  });

  return (
    <div style={{ padding: '24px' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
        <div>
          <h1 style={{ fontSize: '24px', fontWeight: 700, margin: 0 }}>
            <Bell size={24} style={{ marginRight: '10px', verticalAlign: 'middle' }} />
            Platform Notifications
          </h1>
          <p style={{ color: '#6b7280', margin: '4px 0 0', fontSize: '14px' }}>
            All notifications sent across the platform
          </p>
        </div>
        <div style={{
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          background: '#f9fafb',
          borderRadius: '8px',
          padding: '8px 14px',
          border: '1px solid #e5e7eb',
        }}>
          <Search size={16} color="#9ca3af" />
          <input
            type="text"
            placeholder="Search notifications..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            style={{
              border: 'none',
              background: 'transparent',
              outline: 'none',
              fontSize: '14px',
              width: '200px',
            }}
          />
        </div>
      </div>

      {loading ? (
        <div style={{ textAlign: 'center', padding: '60px 0', color: '#9ca3af' }}>
          Loading notifications...
        </div>
      ) : filtered.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '60px 0', color: '#9ca3af' }}>
          <Bell size={48} style={{ marginBottom: '12px', opacity: 0.3 }} />
          <p style={{ fontSize: '16px' }}>No notifications found</p>
        </div>
      ) : (
        <div style={{
          background: '#fff',
          borderRadius: '12px',
          border: '1px solid #e5e7eb',
          overflow: 'hidden',
        }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '14px' }}>
            <thead>
              <tr style={{ background: '#f9fafb', borderBottom: '1px solid #e5e7eb' }}>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontWeight: 600, color: '#374151' }}>Type</th>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontWeight: 600, color: '#374151' }}>Title</th>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontWeight: 600, color: '#374151' }}>Message</th>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontWeight: 600, color: '#374151' }}>Status</th>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontWeight: 600, color: '#374151' }}>Time</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((notif, i) => (
                <tr key={notif.id || i} style={{ borderBottom: '1px solid #f3f4f6' }}>
                  <td style={{ padding: '12px 16px' }}>
                    <span style={{
                      display: 'inline-block',
                      width: 8,
                      height: 8,
                      borderRadius: '50%',
                      background: getTypeColor(notif.title),
                      marginRight: 8,
                    }} />
                  </td>
                  <td style={{ padding: '12px 16px', fontWeight: 500 }}>{notif.title}</td>
                  <td style={{ padding: '12px 16px', color: '#6b7280', maxWidth: '400px' }}>
                    <span style={{ display: 'block', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {notif.body}
                    </span>
                  </td>
                  <td style={{ padding: '12px 16px' }}>
                    {notif.is_read ? (
                      <span style={{ display: 'flex', alignItems: 'center', color: '#9ca3af', gap: '4px', fontSize: '12px' }}>
                        <CheckCheck size={14} /> Read
                      </span>
                    ) : (
                      <span style={{ display: 'flex', alignItems: 'center', color: '#3b82f6', gap: '4px', fontSize: '12px' }}>
                        <Check size={14} /> Unread
                      </span>
                    )}
                  </td>
                  <td style={{ padding: '12px 16px', color: '#9ca3af', fontSize: '13px', whiteSpace: 'nowrap' }}>
                    {formatTime(notif.created_at)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
