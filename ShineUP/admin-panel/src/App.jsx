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
  React.useEffect(() => {
    const token = localStorage.getItem('admin_token');
    if (!token) {
      console.log('No admin token found. Attempting developer login bypass...');
      api.devLogin().then(success => {
        if (success) {
          console.log('✅ Developer login successful.');
          window.location.reload();
        }
      });
    }
  }, []);

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
