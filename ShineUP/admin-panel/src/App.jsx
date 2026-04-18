import React from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import Sidebar from './components/Sidebar';
import Dashboard from './pages/Dashboard';
import Services from './pages/Services';
import Partners from './pages/Partners';
import Bookings from './pages/Bookings';
import Customers from './pages/Customers';
import Hubs from './pages/Hubs';
import Notifications from './pages/Notifications';
import Withdrawals from './pages/Withdrawals';
import Pricing from './pages/Pricing';

import { api } from './api/client';

function App() {
  const [isAuthenticating, setIsAuthenticating] = React.useState(false);

  React.useEffect(() => {
    const token = localStorage.getItem('admin_token');
    if (!token && !isAuthenticating) {
      setIsAuthenticating(true);
      console.log('No admin token found. Attempting developer login bypass...');
      api.devLogin().then(success => {
        if (success) {
          console.log('✅ Developer login successful.');
          window.location.reload();
        } else {
          setIsAuthenticating(false);
          alert('Failed to log in as Admin. Please check if your backend is running.');
        }
      });
    }
  }, [isAuthenticating]);

  if (isAuthenticating) {
    return (
      <div style={{ height: '100vh', display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center', background: '#0f172a', color: 'white' }}>
        <div className="spin" style={{ width: 40, height: 40, border: '4px solid #3b82f6', borderTopColor: 'transparent', borderRadius: '50%', marginBottom: 20 }}></div>
        <h2>Setting up Admin Session...</h2>
        <p>Connecting to Railway Backend</p>
      </div>
    );
  }

  return (
    <BrowserRouter>
      <div className="app-container">
        <Sidebar />
        <main className="main-content">
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/services" element={<Services />} />
            <Route path="/bookings" element={<Bookings />} />
            <Route path="/partners" element={<Partners />} />
            <Route path="/customers" element={<Customers />} />
            <Route path="/hubs" element={<Hubs />} />
            <Route path="/notifications" element={<Notifications />} />
            <Route path="/withdrawals" element={<Withdrawals />} />
            <Route path="/pricing" element={<Pricing />} />
          </Routes>
        </main>
      </div>
    </BrowserRouter>
  );
}

export default App;
