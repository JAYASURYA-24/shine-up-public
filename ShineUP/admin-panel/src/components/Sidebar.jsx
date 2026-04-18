import React from 'react';
import { NavLink } from 'react-router-dom';
import { LayoutDashboard, Users, UserCog, CalendarCheck, Settings, Briefcase, LogOut, MapPin, Bell, Banknote } from 'lucide-react';
import { api } from '../api/client';

export default function Sidebar() {
  const logout = () => {
    api.logout();
    window.location.reload(); // Simple way to force re-render/redirect
  };

  return (
    <aside className="sidebar">
      <div className="sidebar-logo">
        <span className="text-gradient">✨ Shine-Up</span>
      </div>
      <nav className="nav-links">
        <NavLink to="/" className={({isActive}) => isActive ? "nav-item active" : "nav-item"} end>
          <LayoutDashboard size={20} />
          <span>Dashboard</span>
        </NavLink>
        <NavLink to="/services" className={({isActive}) => isActive ? "nav-item active" : "nav-item"}>
          <Briefcase size={20} />
          <span>Services</span>
        </NavLink>
        <NavLink to="/pricing" className={({isActive}) => isActive ? "nav-item active" : "nav-item"}>
          <Banknote size={20} />
          <span>Pricing</span>
        </NavLink>
        <NavLink to="/bookings" className={({isActive}) => isActive ? "nav-item active" : "nav-item"}>
          <CalendarCheck size={20} />
          <span>Bookings</span>
        </NavLink>
        <NavLink to="/partners" className={({isActive}) => isActive ? "nav-item active" : "nav-item"}>
          <UserCog size={20} />
          <span>Partners</span>
        </NavLink>
        <NavLink to="/withdrawals" className={({isActive}) => isActive ? "nav-item active" : "nav-item"}>
          <Banknote size={20} />
          <span>Withdrawals</span>
        </NavLink>
        <NavLink to="/customers" className={({isActive}) => isActive ? "nav-item active" : "nav-item"}>
          <Users size={20} />
          <span>Customers</span>
        </NavLink>
        <NavLink to="/hubs" className={({isActive}) => isActive ? "nav-item active" : "nav-item"}>
          <MapPin size={20} />
          <span>Hubs</span>
        </NavLink>
        <NavLink to="/notifications" className={({isActive}) => isActive ? "nav-item active" : "nav-item"}>
          <Bell size={20} />
          <span>Notifications</span>
        </NavLink>
      </nav>
      
      <div style={{ marginTop: 'auto' }}>
        <button 
          className="nav-item" 
          style={{ background: 'transparent', border: 'none', cursor: 'pointer', width: '100%', textAlign: 'left' }}
          onClick={logout}
        >
          <LogOut size={20} />
          <span>Logout</span>
        </button>
      </div>
    </aside>
  );
}
