import { useState, useEffect, useRef } from 'react';
import { Activity, Bell, CheckCircle, XCircle, UserCheck, Play, Clock } from 'lucide-react';

const EVENT_COLORS = {
  BOOKING_CREATED: { bg: '#e0f2fe', text: '#0369a1', icon: Clock },
  BOOKING_ASSIGNED: { bg: '#dbeafe', text: '#1d4ed8', icon: UserCheck },
  JOB_ACCEPTED: { bg: '#d1fae5', text: '#059669', icon: CheckCircle },
  JOB_STARTED: { bg: '#fef3c7', text: '#d97706', icon: Play },
  JOB_COMPLETED: { bg: '#d1fae5', text: '#047857', icon: CheckCircle },
  BOOKING_CANCELLED: { bg: '#fee2e2', text: '#dc2626', icon: XCircle },
  BOOKING_RESCHEDULED: { bg: '#ede9fe', text: '#7c3aed', icon: Clock },
};

export default function LiveFeed() {
  const [events, setEvents] = useState([]);
  const [wsConnected, setWsConnected] = useState(false);
  const wsRef = useRef(null);
  const eventsEndRef = useRef(null);

  useEffect(() => {
    connectWebSocket();
    return () => {
      if (wsRef.current) wsRef.current.close();
    };
  }, []);

  const connectWebSocket = () => {
    const token = localStorage.getItem('admin_token');
    if (!token) return;

    const ws = new WebSocket(`ws://localhost:8080/ws?token=${token}`);
    wsRef.current = ws;

    ws.onopen = () => {
      setWsConnected(true);
      console.log('🔌 Admin WS connected');
    };

    ws.onmessage = (e) => {
      try {
        const msg = JSON.parse(e.data);
        if (msg.type === 'LIVE_FEED') {
          setEvents(prev => [{
            ...msg.payload,
            time: new Date().toLocaleTimeString(),
            id: Date.now()
          }, ...prev].slice(0, 50));
        } else if (msg.type === 'NEW_NOTIFICATION') {
          setEvents(prev => [{
            event: 'NOTIFICATION',
            ...msg.payload,
            time: new Date().toLocaleTimeString(),
            id: Date.now()
          }, ...prev].slice(0, 50));
        }
      } catch (err) {
        console.error('WS parse error:', err);
      }
    };

    ws.onclose = () => {
      setWsConnected(false);
      console.log('WS disconnected, reconnecting in 5s...');
      setTimeout(connectWebSocket, 5000);
    };

    ws.onerror = () => {
      setWsConnected(false);
    };
  };

  const getEventConfig = (eventType) => {
    return EVENT_COLORS[eventType] || { bg: '#f3f4f6', text: '#6b7280', icon: Activity };
  };

  return (
    <div style={{
      background: '#fff',
      borderRadius: '12px',
      border: '1px solid #e5e7eb',
      overflow: 'hidden',
    }}>
      <div style={{
        padding: '14px 16px',
        borderBottom: '1px solid #e5e7eb',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <Activity size={18} />
          <span style={{ fontWeight: 600, fontSize: '14px' }}>Live Feed</span>
        </div>
        <div style={{
          display: 'flex',
          alignItems: 'center',
          gap: '6px',
          fontSize: '12px',
          color: wsConnected ? '#059669' : '#6b7280',
        }}>
          <div style={{
            width: 8,
            height: 8,
            borderRadius: '50%',
            background: wsConnected ? '#10b981' : '#9ca3af',
            animation: wsConnected ? 'pulse 2s infinite' : 'none',
          }} />
          {wsConnected ? 'Live' : 'Offline'}
        </div>
      </div>

      <div style={{
        maxHeight: '400px',
        overflowY: 'auto',
        padding: '8px',
      }}>
        {events.length === 0 ? (
          <div style={{
            padding: '40px 16px',
            textAlign: 'center',
            color: '#9ca3af',
            fontSize: '13px',
          }}>
            <Bell size={32} style={{ marginBottom: '8px', opacity: 0.5 }} />
            <p>Waiting for events...</p>
            <p style={{ fontSize: '11px', marginTop: '4px' }}>
              Booking updates will appear here in real-time
            </p>
          </div>
        ) : (
          events.map((event) => {
            const config = getEventConfig(event.event);
            const Icon = config.icon;
            return (
              <div
                key={event.id}
                style={{
                  display: 'flex',
                  alignItems: 'flex-start',
                  gap: '10px',
                  padding: '10px 12px',
                  borderRadius: '8px',
                  marginBottom: '4px',
                  background: config.bg,
                  animation: 'slideIn 0.3s ease-out',
                }}
              >
                <Icon size={16} color={config.text} style={{ marginTop: '2px', flexShrink: 0 }} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{
                    fontSize: '13px',
                    fontWeight: 500,
                    color: config.text,
                  }}>
                    {event.event?.replace(/_/g, ' ')}
                  </div>
                  <div style={{
                    fontSize: '11px',
                    color: '#6b7280',
                    marginTop: '2px',
                  }}>
                    {event.booking_id && `Booking: ${event.booking_id.slice(0, 8)}...`}
                    {event.amount && ` • ₹${event.amount}`}
                  </div>
                </div>
                <span style={{
                  fontSize: '10px',
                  color: '#9ca3af',
                  whiteSpace: 'nowrap',
                }}>
                  {event.time}
                </span>
              </div>
            );
          })
        )}
        <div ref={eventsEndRef} />
      </div>

      <style>{`
        @keyframes slideIn {
          from { opacity: 0; transform: translateY(-10px); }
          to { opacity: 1; transform: translateY(0); }
        }
        @keyframes pulse {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.5; }
        }
      `}</style>
    </div>
  );
}
