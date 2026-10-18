import { useState } from 'react';
import { NavLink, Outlet } from 'react-router-dom';
import {
  BarChart3, ClipboardCheck, FlaskConical, History, LayoutDashboard, LogOut, Megaphone, Menu, MessageSquare,
  Moon, Settings as SettingsIcon, Sun, Users, Wallet, BookOpen,
} from 'lucide-react';
import { useAuth } from './auth';
import type { Role } from './api';

const NAV: { to: string; label: string; icon: typeof BookOpen; roles?: Role[]; end?: boolean }[] = [
  { to: '/', label: 'Dashboard', icon: LayoutDashboard, end: true },
  { to: '/content', label: 'Content', icon: BookOpen },
  { to: '/review', label: 'Review queue', icon: ClipboardCheck },
  { to: '/revenue', label: 'Premium & revenue', icon: Wallet, roles: ['editor'] },
  { to: '/analytics', label: 'Users & analytics', icon: BarChart3 },
  { to: '/announcements', label: 'Announcements', icon: Megaphone },
  { to: '/feedback', label: 'Feedback', icon: MessageSquare },
  { to: '/settings', label: 'App config', icon: SettingsIcon },
  { to: '/team', label: 'Team', icon: Users, roles: [] },
  { to: '/audit', label: 'Audit log', icon: History, roles: ['editor', 'reviewer'] },
];

export default function Layout() {
  const { user, logout, can } = useAuth();
  const [open, setOpen] = useState(false);
  const [dark, setDark] = useState(document.documentElement.classList.contains('dark'));

  const toggle = () => {
    const next = !dark;
    setDark(next);
    document.documentElement.classList.toggle('dark', next);
    try { localStorage.setItem('theme', next ? 'dark' : 'light'); } catch { /* ignore */ }
  };

  return (
    <div className="min-h-screen lg:flex">
      <aside className={`fixed inset-y-0 left-0 z-30 flex w-64 flex-col border-r border-slate-200 bg-white transition-transform dark:border-slate-800 dark:bg-slate-900 lg:static lg:translate-x-0 ${open ? 'translate-x-0' : '-translate-x-full'}`}>
        <div className="flex items-center gap-2.5 px-5 py-5">
          <div className="rounded-lg bg-brand-600 p-2 text-white"><FlaskConical size={18} /></div>
          <div>
            <p className="text-sm font-semibold leading-tight">Lab Console</p>
            <p className="text-xs text-slate-500">Virtual Chemistry Lab</p>
          </div>
        </div>
        <nav className="flex-1 space-y-0.5 overflow-y-auto px-3 pb-4">
          {NAV.filter((n) => !n.roles || can(...n.roles)).map(({ to, label, icon: Icon, end }) => (
            <NavLink key={to} to={to} end={end} onClick={() => setOpen(false)}
              className={({ isActive }) => `flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition ${isActive ? 'bg-brand-50 text-brand-700 dark:bg-brand-600/20 dark:text-brand-100' : 'text-slate-600 hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-slate-800'}`}>
              <Icon size={17} /> {label}
            </NavLink>
          ))}
        </nav>
        <div className="border-t border-slate-200 p-3 dark:border-slate-800">
          <div className="flex items-center gap-3 rounded-lg px-2 py-1.5">
            <div className="flex h-8 w-8 items-center justify-center rounded-full bg-brand-600 text-sm font-semibold text-white">
              {user!.name.slice(0, 1).toUpperCase()}
            </div>
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-medium">{user!.name}</p>
              <p className="text-xs capitalize text-slate-500">{user!.role}</p>
            </div>
            <button onClick={toggle} className="rounded-md p-1.5 text-slate-500 hover:bg-slate-100 dark:hover:bg-slate-800" aria-label="Toggle theme">
              {dark ? <Sun size={16} /> : <Moon size={16} />}
            </button>
            <button onClick={logout} className="rounded-md p-1.5 text-slate-500 hover:bg-slate-100 dark:hover:bg-slate-800" aria-label="Sign out">
              <LogOut size={16} />
            </button>
          </div>
        </div>
      </aside>
      {open && <div className="fixed inset-0 z-20 bg-slate-900/40 lg:hidden" onClick={() => setOpen(false)} />}

      <div className="min-w-0 flex-1">
        <header className="sticky top-0 z-10 flex items-center gap-3 border-b border-slate-200 bg-white/80 px-4 py-3 backdrop-blur dark:border-slate-800 dark:bg-slate-950/80 lg:hidden">
          <button onClick={() => setOpen(true)} aria-label="Open menu"><Menu size={20} /></button>
          <span className="font-semibold">Lab Console</span>
        </header>
        <main className="mx-auto max-w-7xl p-4 sm:p-6 lg:p-8"><Outlet /></main>
      </div>
    </div>
  );
}
