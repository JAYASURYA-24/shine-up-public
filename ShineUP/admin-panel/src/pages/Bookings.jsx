import React, { useState, useEffect } from 'react';
import { Loader, UserPlus, XCircle, CheckCircle, Info, Filter, MapPin, Key } from 'lucide-react';
import { api } from '../api/client';

export default function Bookings() {
  const [bookings, setBookings] = useState([]);
  const [partners, setPartners] = useState([]);
  const [loading, setLoading] = useState(true);
  const [assigningBooking, setAssigningBooking] = useState(null);
  const [assignmentLoading, setAssignmentLoading] = useState(false);
  const [statusFilter, setStatusFilter] = useState('ALL');
  
  // Refund/Cancellation Modal State
  const [cancellingBookingId, setCancellingBookingId] = useState(null);
  const [cancelReason, setCancelReason] = useState('');
  const [refundAmount, setRefundAmount] = useState(0);

  const fetchData = async () => {
    try {
      const [bookingsData, partnersData] = await Promise.all([
        api.getBookings(),
        api.getPartners()
      ]);
      setBookings(bookingsData || []);
      setPartners(partnersData || []);
    } catch (err) {
      console.error('Failed to load data', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  const handleAssign = async (bookingId, partnerId) => {
    setAssignmentLoading(true);
    try {
      await api.assignPartner(bookingId, partnerId);
      setAssigningBooking(null);
      await fetchData();
    } catch (err) {
      alert(`Assignment failed: ${err.message}`);
    } finally {
      setAssignmentLoading(false);
    }
  };

  const executeCancel = async () => {
    if (!cancellingBookingId) return;
    try {
      // Mock passing reason to backend. The actual API schema requires reason.
      await api.cancelBooking(cancellingBookingId, cancelReason);
      setCancellingBookingId(null);
      setCancelReason('');
      fetchData();
    } catch (err) {
      alert(`Cancellation failed: ${err.message}`);
    }
  };

  const statusBadge = (status) => {
    const map = {
      'COMPLETED': 'success',
      'IN_PROGRESS': 'warning',
      'ASSIGNED': 'info',
      'CREATED': 'warning',
      'CANCELLED': 'danger',
    };
    return map[status] || 'warning';
  };

  const filteredBookings = bookings.filter(b => statusFilter === 'ALL' || b.status === statusFilter);

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <h1 className="page-title" style={{ margin: 0 }}>Service Bookings</h1>
        <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
          <Filter size={18} style={{ color: 'var(--text-muted)' }} />
          <select 
            value={statusFilter} 
            onChange={(e) => setStatusFilter(e.target.value)}
            className="form-input" 
            style={{ width: 'auto', padding: '0.4rem 1rem' }}
          >
            <option value="ALL">All Statuses</option>
            <option value="CREATED">Created</option>
            <option value="ASSIGNED">Assigned</option>
            <option value="IN_PROGRESS">In Progress</option>
            <option value="COMPLETED">Completed</option>
            <option value="CANCELLED">Cancelled</option>
          </select>
        </div>
      </div>
      
      <div className="glass-panel">
        {loading ? (
          <div style={{ display: 'flex', justifyContent: 'center', padding: '3rem' }}>
            <Loader size={28} className="spin" style={{ color: 'var(--accent-primary)' }} />
          </div>
        ) : filteredBookings.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '3rem', color: 'var(--text-muted)' }}>
            No bookings found for the selected filter.
          </div>
        ) : (
          <table className="premium-table">
            <thead>
              <tr>
                <th>Booking Details</th>
                <th>Customer</th>
                <th>Partner Workflow</th>
                <th>Amount</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredBookings.map((booking) => (
                <tr key={booking.id}>
                  <td>
                    <div style={{ fontWeight: 600, color: 'var(--accent-secondary)' }}>BK-{booking.id.slice(0, 8)}</div>
                    <div style={{ fontSize: '0.9rem', marginTop: '4px' }}>{booking.service_name || '—'}</div>
                    <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '4px', display: 'flex', alignItems: 'center', gap: '4px' }}>
                      <MapPin size={12} /> {booking.slot_start}
                    </div>
                  </td>
                  <td>
                    <div>{booking.customer}</div>
                    {/* Mock payload display for phone/address if available */}
                    <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>{booking.customer_phone || 'Phone hidden'}</div>
                  </td>
                  <td>
                    {booking.partner !== 'Unassigned' ? (
                      <div>
                        <span style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', color: 'var(--success)' }}>
                          <CheckCircle size={14} /> {booking.partner}
                        </span>
                        {(booking.status === 'ASSIGNED' || booking.status === 'CREATED' || booking.status === 'IN_PROGRESS') && (
                          <div style={{ fontSize: '0.8rem', marginTop: '6px', backgroundColor: 'var(--bg-darker)', padding: '4px 8px', borderRadius: '4px', display: 'inline-flex', alignItems: 'center', gap: '4px' }}>
                            <Key size={12} style={{ color: 'var(--accent-primary)' }} /> 
                            <span>OTP: <strong style={{ color: 'white', letterSpacing: '1px' }}>{booking.otp}</strong></span>
                          </div>
                        )}
                      </div>
                    ) : (
                      <span className="badge warning" style={{ opacity: 0.8 }}>Pending Assignment</span>
                    )}
                  </td>
                  <td style={{ fontWeight: 'bold' }}>₹{booking.amount}</td>
                  <td>
                    <span className={`badge ${statusBadge(booking.status)}`}>
                      {booking.status}
                    </span>
                  </td>
                  <td style={{ display: 'flex', gap: '0.5rem' }}>
                    {booking.can_be_assigned && (
                      <button 
                        className="btn-icon success" 
                        title="Assign Partner"
                        onClick={() => setAssigningBooking(booking)}
                      >
                        <UserPlus size={16} />
                      </button>
                    )}
                    {booking.status !== 'CANCELLED' && booking.status !== 'COMPLETED' && (
                      <button 
                        className="btn-icon danger" 
                        title="Cancel Booking & Refund"
                        onClick={() => {
                          setCancellingBookingId(booking.id);
                          setCancelReason('');
                          setRefundAmount(booking.amount);
                        }}
                      >
                        <XCircle size={16} />
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Cancellation & Refund Modal */}
      {cancellingBookingId && (
        <div className="modal-overlay">
          <div className="modal-content glass-panel" style={{ maxWidth: '400px' }}>
            <h2 style={{ marginBottom: '1.5rem', color: '#ff4d4f' }}>Cancel Booking</h2>
            <div className="form-group">
              <label>Cancellation Reason</label>
              <textarea 
                className="form-input" 
                rows={3} 
                value={cancelReason}
                onChange={(e) => setCancelReason(e.target.value)}
                placeholder="Partner requested cancellation / Customer unavailable..."
              />
            </div>
            <div className="form-group">
              <label>Refund Amount (₹)</label>
              <input 
                type="number" 
                className="form-input" 
                value={refundAmount}
                onChange={(e) => setRefundAmount(e.target.value)}
              />
              <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '4px' }}>
                Amount will be refunded to customer's wallet or original payment source.
              </p>
            </div>
            <div style={{ display: 'flex', gap: '1rem', marginTop: '2rem' }}>
              <button className="btn-secondary" style={{ flex: 1 }} onClick={() => setCancellingBookingId(null)}>
                Keep Booking
              </button>
              <button 
                className="btn-primary" 
                style={{ flex: 1, backgroundColor: '#ff4d4f' }} 
                onClick={executeCancel}
              >
                Confirm Cancellation
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Assignment Modal */}
      {assigningBooking && (
        <div className="modal-overlay">
          <div className="modal-content glass-panel" style={{ maxWidth: '600px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '1.5rem' }}>
              <h2 style={{ margin: 0 }}>Assign Partner</h2>
              <button 
                onClick={() => setAssigningBooking(null)}
                style={{ background: 'none', border: 'none', color: 'white', cursor: 'pointer' }}
              >
                <XCircle size={24} />
              </button>
            </div>

            <p style={{ color: 'var(--text-secondary)', marginBottom: '1rem' }}>
              Select a verified partner for <strong>{assigningBooking.service_name}</strong> - BK-{assigningBooking.id.slice(0, 8)}
            </p>

            <div style={{ maxHeight: '400px', overflowY: 'auto' }}>
              {partners.filter(p => p.kyc_status === 'APPROVED').length === 0 ? (
                <div style={{ textAlign: 'center', padding: '1.5rem', color: 'var(--text-muted)' }}>
                  No approved partners available. Approve a partner's KYC first.
                </div>
              ) : (
                <table className="premium-table">
                  <thead>
                    <tr>
                      <th>Partner</th>
                      <th>Rating</th>
                      <th>Status</th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {partners.filter(p => p.kyc_status === 'APPROVED').map(p => (
                      <tr key={p.id}>
                        <td>{p.name}</td>
                        <td>⭐ {p.rating.toFixed(1)}</td>
                        <td>
                          <span style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                            <div style={{ width: 8, height: 8, borderRadius: '50%', background: p.is_online ? 'var(--success)' : 'var(--text-muted)' }} />
                            {p.is_online ? 'Online' : 'Offline'}
                          </span>
                        </td>
                        <td>
                          <button 
                            className="btn-primary" 
                            style={{ padding: '0.4rem 0.8rem', fontSize: '0.8rem' }}
                            disabled={assignmentLoading}
                            onClick={() => handleAssign(assigningBooking.id, p.id)}
                          >
                            Assign
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
