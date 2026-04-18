import React, { useState, useEffect } from 'react';
import { Loader, Check, X, ChevronDown, ChevronUp, Eye, Calendar, Clock } from 'lucide-react';
import { api } from '../api/client';

export default function Partners() {
  const [partners, setPartners] = useState([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(null);
  const [expandedId, setExpandedId] = useState(null);
  const [partnerDetail, setPartnerDetail] = useState(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [leaves, setLeaves] = useState([]);
  const [slots, setSlots] = useState([]);
  const [slotDate, setSlotDate] = useState(new Date().toISOString().split('T')[0]);

  const fetchPartners = async () => {
    try {
      const data = await api.getPartners();
      setPartners(data || []);
    } catch (err) {
      alert('Failed to load partners');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchPartners(); }, []);

  const handleKYCAction = async (id, action) => {
    setActionLoading(id);
    try {
      if (action === 'approve') await api.approvePartner(id);
      else await api.rejectPartner(id);
      await fetchPartners();
    } catch (err) {
      alert(`KYC Action failed: ${err.message}`);
    } finally {
      setActionLoading(null);
    }
  };

  const toggleExpand = async (partnerId) => {
    if (expandedId === partnerId) {
      setExpandedId(null);
      setPartnerDetail(null);
      return;
    }
    setExpandedId(partnerId);
    setDetailLoading(true);
    try {
      const [detail, partnerLeaves, partnerSlots] = await Promise.all([
        api.getPartnerDetail(partnerId),
        api.getPartnerLeaves(partnerId),
        api.getPartnerSlots(partnerId, slotDate),
      ]);
      setPartnerDetail(detail);
      setLeaves(partnerLeaves || []);
      setSlots(partnerSlots || []);
    } catch (err) {
      console.error('Failed to load partner detail', err);
    } finally {
      setDetailLoading(false);
    }
  };

  const loadSlots = async (partnerId, date) => {
    setSlotDate(date);
    try {
      const partnerSlots = await api.getPartnerSlots(partnerId, date);
      setSlots(partnerSlots || []);
    } catch (err) {
      console.error('Failed to load slots', err);
    }
  };

  const handleLeaveAction = async (partnerId, leaveId, action) => {
    try {
      if (action === 'approve') await api.approveLeave(partnerId, leaveId);
      else await api.rejectLeave(partnerId, leaveId);
      const updatedLeaves = await api.getPartnerLeaves(partnerId);
      setLeaves(updatedLeaves || []);
    } catch (err) {
      alert(`Leave action failed: ${err.message}`);
    }
  };

  const formatHour = (h) => {
    if (h < 12) return `${h}AM`;
    if (h === 12) return '12PM';
    return `${h - 12}PM`;
  };

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <h1 className="page-title" style={{ margin: 0 }}>Service Partners</h1>
        <span style={{ color: 'var(--text-muted)', fontSize: '0.9rem' }}>
          {partners.length} partner{partners.length !== 1 ? 's' : ''} registered
        </span>
      </div>
      
      <div className="glass-panel">
        {loading ? (
          <div style={{ display: 'flex', justifyContent: 'center', padding: '3rem' }}>
            <Loader size={28} className="spin" style={{ color: 'var(--accent-primary)' }} />
          </div>
        ) : partners.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '3rem', color: 'var(--text-muted)' }}>
            No partners found. Partners will appear here after they register via the Partner App.
          </div>
        ) : (
          <table className="premium-table">
            <thead>
              <tr>
                <th></th>
                <th>Partner Name</th>
                <th>Phone</th>
                <th>KYC Status</th>
                <th>Rating</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {partners.map(partner => (
                <React.Fragment key={partner.id}>
                  <tr style={{ cursor: 'pointer' }} onClick={() => toggleExpand(partner.id)}>
                    <td style={{ width: 30, padding: '0.5rem' }}>
                      {expandedId === partner.id ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
                    </td>
                    <td style={{ fontWeight: 500 }}>{partner.name || 'Unnamed'}</td>
                    <td>{partner.phone}</td>
                    <td>
                      <span className={`badge ${partner.kyc_status === 'APPROVED' ? 'success' : partner.kyc_status === 'REJECTED' ? 'danger' : 'warning'}`}>
                        {partner.kyc_status}
                      </span>
                    </td>
                    <td>⭐ {partner.rating.toFixed(1)}</td>
                    <td>
                      <span style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                        <div style={{ width: 8, height: 8, borderRadius: '50%', background: partner.is_online ? 'var(--success)' : 'var(--text-muted)' }} />
                        {partner.is_online ? 'Online' : 'Offline'}
                      </span>
                    </td>
                    <td onClick={e => e.stopPropagation()}>
                      <div style={{ display: 'flex', gap: '0.5rem' }}>
                        {partner.kyc_status === 'PENDING' && (
                          <>
                            <button 
                              className="btn-icon success" 
                              title="Approve KYC"
                              disabled={actionLoading === partner.id}
                              onClick={() => handleKYCAction(partner.id, 'approve')}
                            >
                              <Check size={16} />
                            </button>
                            <button 
                              className="btn-icon danger" 
                              title="Reject KYC"
                              disabled={actionLoading === partner.id}
                              onClick={() => handleKYCAction(partner.id, 'reject')}
                            >
                              <X size={16} />
                            </button>
                          </>
                        )}
                        <button 
                          className="btn-icon secondary" 
                          title="View Details"
                          onClick={() => toggleExpand(partner.id)}
                        >
                          <Eye size={16} />
                        </button>
                      </div>
                    </td>
                  </tr>

                  {/* Expanded Detail Row */}
                  {expandedId === partner.id && (
                    <tr>
                      <td colSpan={7} style={{ padding: 0, background: 'var(--bg-tertiary)' }}>
                        {detailLoading ? (
                          <div style={{ display: 'flex', justifyContent: 'center', padding: '2rem' }}>
                            <Loader size={24} className="spin" style={{ color: 'var(--accent-primary)' }} />
                          </div>
                        ) : partnerDetail ? (
                          <div style={{ padding: '1.5rem', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.5rem' }}>
                            
                            {/* KYC Documents */}
                            <div className="glass-panel" style={{ padding: '1rem' }}>
                              <h3 style={{ margin: '0 0 1rem', fontSize: '1rem' }}>📋 KYC Documents</h3>
                              <div style={{ display: 'grid', gap: '0.5rem', fontSize: '0.85rem' }}>
                                <DocRow label="Aadhaar Front" url={partnerDetail.partner?.aadhaar_front} />
                                <DocRow label="Aadhaar Back" url={partnerDetail.partner?.aadhaar_back} />
                                <DocRow label="PAN Card" url={partnerDetail.partner?.pan_url} />
                                <DocRow label="Driving License" url={partnerDetail.partner?.driving_license} />
                                <DocRow label="Home Photo" url={partnerDetail.partner?.home_photo_url} />
                              </div>
                            </div>

                            {/* Performance Stats */}
                            <div className="glass-panel" style={{ padding: '1rem' }}>
                              <h3 style={{ margin: '0 0 1rem', fontSize: '1rem' }}>📊 Performance</h3>
                              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                                <StatBox label="Completed Jobs" value={partnerDetail.completed_jobs || 0} color="var(--success)" />
                                <StatBox label="Total Jobs" value={partnerDetail.total_jobs || 0} color="var(--accent-primary)" />
                                <StatBox label="Total Earnings" value={`₹${(partnerDetail.total_earnings || 0).toFixed(0)}`} color="var(--success)" />
                                <StatBox label="Pending Leaves" value={partnerDetail.pending_leaves || 0} color="var(--warning)" />
                              </div>
                              <div style={{ marginTop: '1rem', display: 'flex', gap: '1rem' }}>
                                <div>
                                  <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Rating</span>
                                  <div style={{ fontWeight: 600 }}>⭐ {(partnerDetail.partner?.rating || 5).toFixed(1)}</div>
                                </div>
                                <div>
                                  <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Acceptance Rate</span>
                                  <div style={{ fontWeight: 600 }}>{(partnerDetail.partner?.acceptance_rate || 100).toFixed(0)}%</div>
                                </div>
                                <div>
                                  <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Bank Verified</span>
                                  <div style={{ fontWeight: 600 }}>{partnerDetail.bank_account?.is_verified ? '✅ Yes' : '❌ No'}</div>
                                </div>
                              </div>
                            </div>

                            {/* Slot Calendar */}
                            <div className="glass-panel" style={{ padding: '1rem' }}>
                              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
                                <h3 style={{ margin: 0, fontSize: '1rem' }}><Calendar size={16} style={{ marginRight: 4 }} /> Slots</h3>
                                <input
                                  type="date"
                                  value={slotDate}
                                  onChange={(e) => loadSlots(partner.id, e.target.value)}
                                  style={{ padding: '0.3rem 0.5rem', borderRadius: '8px', border: '1px solid var(--border-color)', fontSize: '0.85rem' }}
                                />
                              </div>
                              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '0.5rem' }}>
                                {slots.map(slot => (
                                  <div key={slot.id} style={{
                                    padding: '0.5rem',
                                    borderRadius: '8px',
                                    textAlign: 'center',
                                    fontSize: '0.8rem',
                                    background: slot.booking_id ? '#e3f2fd' : slot.is_available ? '#f0fff4' : '#fff3f0',
                                    border: `1px solid ${slot.booking_id ? '#90caf9' : slot.is_available ? '#a3d9a5' : '#ffcdd2'}`,
                                    color: slot.booking_id ? '#1565c0' : slot.is_available ? '#2e7d32' : '#c62828',
                                  }}>
                                    <Clock size={12} style={{ marginRight: 2 }} />
                                    <div style={{ fontWeight: 600 }}>{formatHour(slot.hour)}</div>
                                    <div style={{ fontSize: '0.7rem' }}>{slot.booking_id ? 'Booked' : slot.is_available ? 'Open' : 'Closed'}</div>
                                  </div>
                                ))}
                              </div>
                            </div>

                            {/* Leave Requests */}
                            <div className="glass-panel" style={{ padding: '1rem' }}>
                              <h3 style={{ margin: '0 0 1rem', fontSize: '1rem' }}>🏖️ Leave Requests</h3>
                              {leaves.length === 0 ? (
                                <div style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>No leave requests</div>
                              ) : (
                                <div style={{ display: 'grid', gap: '0.5rem' }}>
                                  {leaves.map(leave => (
                                    <div key={leave.id} style={{
                                      display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                                      padding: '0.5rem 0.75rem', borderRadius: '8px',
                                      background: leave.status === 'APPROVED' ? '#f0fff4' : leave.status === 'REJECTED' ? '#fff3f0' : '#fff8e1',
                                      border: `1px solid ${leave.status === 'APPROVED' ? '#a3d9a5' : leave.status === 'REJECTED' ? '#ffcdd2' : '#ffe082'}`,
                                      fontSize: '0.85rem',
                                    }}>
                                      <div>
                                        <span style={{ fontWeight: 600 }}>{leave.date}</span>
                                        {leave.reason && <span style={{ color: 'var(--text-muted)', marginLeft: '0.5rem' }}>— {leave.reason}</span>}
                                      </div>
                                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                                        <span className={`badge ${leave.status === 'APPROVED' ? 'success' : leave.status === 'REJECTED' ? 'danger' : 'warning'}`}>
                                          {leave.status}
                                        </span>
                                        {leave.status === 'PENDING' && (
                                          <>
                                            <button className="btn-icon success" title="Approve" onClick={() => handleLeaveAction(partner.id, leave.id, 'approve')} style={{ width: 24, height: 24 }}>
                                              <Check size={12} />
                                            </button>
                                            <button className="btn-icon danger" title="Reject" onClick={() => handleLeaveAction(partner.id, leave.id, 'reject')} style={{ width: 24, height: 24 }}>
                                              <X size={12} />
                                            </button>
                                          </>
                                        )}
                                      </div>
                                    </div>
                                  ))}
                                </div>
                              )}
                            </div>

                          </div>
                        ) : null}
                      </td>
                    </tr>
                  )}
                </React.Fragment>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}

// Helper Components
function DocRow({ label, url }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '0.3rem 0' }}>
      <span style={{ color: 'var(--text-muted)' }}>{label}</span>
      {url ? (
        <a href={url} target="_blank" rel="noreferrer" style={{ color: 'var(--accent-primary)', textDecoration: 'none', fontSize: '0.8rem' }}>
          View ↗
        </a>
      ) : (
        <span style={{ color: 'var(--text-muted)', fontSize: '0.8rem' }}>Not uploaded</span>
      )}
    </div>
  );
}

function StatBox({ label, value, color }) {
  return (
    <div style={{
      padding: '0.75rem',
      borderRadius: '10px',
      background: `${color}11`,
      textAlign: 'center',
    }}>
      <div style={{ fontSize: '1.2rem', fontWeight: 700, color }}>{value}</div>
      <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{label}</div>
    </div>
  );
}
