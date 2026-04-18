const API_BASE = 'https://shine-up-public-production.up.railway.app/api/v1';
export const WS_BASE = 'wss://shine-up-public-production.up.railway.app/ws';


async function request(path, method = 'GET', body = null) {
  const token = localStorage.getItem('admin_token');
  const headers = {
    'Content-Type': 'application/json',
    ...(token && { 'Authorization': `Bearer ${token}` }),
  };

  try {
    const res = await fetch(`${API_BASE}${path}`, {
      method,
      headers,
      ...(body && { body: JSON.stringify(body) }),
    });

    if (res.status === 401 || res.status === 403) {
      console.warn('Unauthorized. Clearing token and retrying...');
      localStorage.removeItem('admin_token');
      window.location.reload(); // This will trigger the devLogin in App.jsx
      return;
    }

    if (!res.ok) {
      const errorData = await res.json().catch(() => ({}));
      throw new Error(errorData.error || `HTTP ${res.status}`);
    }
    return await res.json();
  } catch (err) {
    console.error(`API Error [${method} ${path}]:`, err.message);
    throw err;
  }
}

export const api = {
  // ─── Auth ───────────────────────────────────────
  login: async (token) => {
    localStorage.setItem('admin_token', token);
    return true;
  },
  logout: () => {
    localStorage.removeItem('admin_token');
  },
  devLogin: async (phone = '+10000000000') => {
    const res = await request('/auth/dev-login', 'POST', {
      phone: phone,
      role: 'ADMIN'
    });
    if (res && res.token) {
      localStorage.setItem('admin_token', res.token);
      return true;
    }
    return false;
  },

  // ─── Read Ops ──────────────────────────────────
  getStats:     () => request('/admin/stats'),
  getPartners:  () => request('/admin/partners'),
  getBookings:  () => request('/admin/bookings'),
  getCustomers: () => request('/admin/customers'),
  getServices:  () => request('/admin/services'),

  // ─── Partner Actions ───────────────────────────
  approvePartner: (id) => request(`/admin/partners/${id}/approve`, 'POST'),
  rejectPartner:  (id) => request(`/admin/partners/${id}/reject`, 'POST'),

  // ─── Booking Actions ───────────────────────────
  assignPartner: (bookingId, partnerId) => request(`/admin/bookings/${bookingId}/assign`, 'POST', { partner_id: partnerId }),
  cancelBooking: (bookingId) => request(`/admin/bookings/${bookingId}/cancel`, 'POST'),

  // ─── Catalog Actions ───────────────────────────
  createService: (data) => request('/admin/services', 'POST', data),
  deleteService: (id) => request(`/admin/services/${id}`, 'DELETE'),
  addSKU: (serviceId, data) => request(`/admin/services/${serviceId}/skus`, 'POST', data),

  // ─── Hub Management ────────────────────────
  getHubs:       () => request('/admin/hubs'),
  createHub:     (data) => request('/admin/hubs', 'POST', data),
  updateHub:     (id, data) => request(`/admin/hubs/${id}`, 'PUT', data),

  // ─── Partner Detail & Management ──────────
  getPartnerDetail: (id) => request(`/admin/partners/${id}/detail`),
  getPartnerSlots:  (id, date) => request(`/admin/partners/${id}/slots?date=${date}`),
  getPartnerLeaves: (id) => request(`/admin/partners/${id}/leaves`),
  approveLeave:     (partnerId, leaveId) => request(`/admin/partners/${partnerId}/leaves/${leaveId}/approve`, 'POST'),
  rejectLeave:      (partnerId, leaveId) => request(`/admin/partners/${partnerId}/leaves/${leaveId}/reject`, 'POST'),

  // ─── Notifications (Admin) ──────────────
  getAdminNotifications: (limit = 100) => request(`/admin/notifications?limit=${limit}`),

  // ─── Withdrawals (Admin) ──────────────
  getWithdrawals: () => request('/admin/withdrawals'),
  processWithdrawal: (id, action, bankRef) => request(`/admin/withdrawals/${id}/process`, 'POST', { action, bank_reference: bankRef }),

  // ─── Announcements & Calls ──────────────
  broadcastAnnouncement: (title, message) => request('/admin/announcements', 'POST', { title, message }),
  getCalls: () => request('/admin/calls'),
};

