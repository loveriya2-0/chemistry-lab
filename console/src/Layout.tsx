import { Suspense, useState } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import {
  BarChart3, ClipboardCheck, FlaskConical, History, LayoutDashboard, LogOut, Megaphone, Menu, MessageSquare,
  Moon, Settings as SettingsIcon, Sun, Users, Wallet, BookOpen,
} from 'lucide-react';
import { useAuth } from './auth';
import type { Role } from './api';
import { Spinner } from './ui';

type NavItem = { to: string; label: string; icon: typeof BookOpen; roles?: Role[]; end?: boolean };
const NAV: { group: string; items: NavItem[] }[] = [
  { group: 'Overview', items: [
    { to: '/', label: 'Dashboard', icon: LayoutDashboard, end: true },
    { to: '/analytics', label: 'Users & analytics', icon: BarChart3 },
    { to: '/revenue', label: 'Premium & revenue', icon: Wallet, roles: ['editor'] },
  ] },
  { group: 'Content', items: [
    { to: '/content', label: 'Content', icon: BookOpen },
    { to: '/review', label: 'Review queue', icon: ClipboardCheck },
  ] },
  { group: 'Engage', items: [
    { to: '/announcements', label: 'Announcements', icon: Megaphone },
    { to: '/feedback', label: 'Feedback', icon: MessageSquare },
  ] },
  { group: 'Admin', items: [
    { to: '/settings', label: 'App config', icon: SettingsIcon },
    { to: '/team', label: 'Team', icon: Users, roles: [] },
    { to: '/audit', label: 'Audit log', icon: History, roles: ['editor', 'reviewer'] },
  ] },
];
const ALL = NAV.flatMap((g) => g.items);

export default function Layout() {
  const { user, logout, can } = useAuth();
  const { pathname } = useLocation();
  const [open, setOpen] = useState(false);
  const [dark, setDark] = useState(document.documentElement.classList.contains('dark'));

  const toggle = () => {
    const next = !dark;
    setDark(next);
    document.documentElement.classList.toggle('dark', next);
    try { localStorage.setItem('theme', next ? 'dark' : 'light'); } catch { /* ignore */ }
  };

  const current = ALL.find((n) => (n.end ? pathname === n.to : pathname.startsWith(n.to) && n.to !== '/')) ?? ALL[0];
  const hour = new Date().getHours();
  const greet = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
  const avatar = (size: string) => user!.picture
    ? <img src={user!.picture} alt="" referrerPolicy="no-referrer" className={`${size} rounded-full ring-2 ring-white/10`} />
    : <div className={`${size} flex items-center justify-center rounded-full bg-gradient-to-br from-brand-400 to-violet-500 text-sm font-bold text-white`}>
        {user!.name.slice(0, 1).toUpperCase()}
      </div>;

  return (
    <div className="min-h-screen lg:flex lg:h-screen lg:overflow-hidden">
      <aside className={`fixed inset-y-0 left-0 z-30 flex w-[17rem] flex-col bg-[#0c0e1a] text-slate-300 transition-transform duration-300 lg:static lg:h-full lg:shrink-0 lg:translate-x-0 ${open ? 'translate-x-0' : '-translate-x-full'}`}>
        <div className="pointer-events-none absolute inset-x-0 top-0 h-48 bg-gradient-to-b from-brand-600/20 to-transparent" />
        <div className="relative flex items-center gap-3 px-5 py-6">
          <div className="rounded-xl bg-gradient-to-br from-brand-400 to-violet-600 p-2.5 text-white shadow-glow"><FlaskConical size={20} /></div>
          <div>
            <p className="font-display text-[15px] font-bold leading-tight text-white">Lab Console</p>
            <p className="text-xs text-slate-400">Virtual Chemistry Lab</p>
          </div>
        </div>
        <nav className="relative flex-1 space-y-5 overflow-y-auto px-3 pb-4">
          {NAV.map(({ group, items }) => {
            const visible = items.filter((n) => !n.roles || can(...n.roles));
            if (!visible.length) return null;
            return (
              <div key={group}>
                <p className="px-3 pb-1.5 text-[10.5px] font-semibold uppercase tracking-[0.14em] text-slate-500">{group}</p>
                <div className="space-y-0.5">
                  {visible.map(({ to, label, icon: Icon, end }) => (
                    <NavLink key={to} to={to} end={end} onClick={() => setOpen(false)}
                      className={({ isActive }) => `group relative flex items-center gap-3 rounded-xl px-3 py-2 text-sm font-medium transition ${isActive ? 'bg-white/[0.08] text-white' : 'text-slate-400 hover:bg-white/[0.04] hover:text-slate-100'}`}>
                      {({ isActive }) => (<>
                        {isActive && <span className="absolute left-0 top-1/2 h-5 w-[3px] -translate-y-1/2 rounded-r-full bg-brand-400" />}
                        <Icon size={17} className={isActive ? 'text-brand-300' : 'text-slate-500 group-hover:text-slate-300'} /> {label}
                      </>)}
                    </NavLink>
                  ))}
                </div>
              </div>
            );
          })}
        </nav>
        <div className="relative border-t border-white/[0.06] p-3">
          <div className="flex items-center gap-3 rounded-xl bg-white/[0.04] px-2.5 py-2">
            {avatar('h-9 w-9')}
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-semibold text-white">{user!.name}</p>
              <p className="text-xs capitalize text-slate-400">{user!.role}</p>
            </div>
            <button onClick={logout} className="rounded-lg p-1.5 text-slate-400 transition hover:bg-rose-500/15 hover:text-rose-300" aria-label="Sign out" title="Sign out">
              <LogOut size={16} />
            </button>
          </div>
        </div>
      </aside>
      {open && <div className="fixed inset-0 z-20 bg-slate-950/60 backdrop-blur-sm lg:hidden" onClick={() => setOpen(false)} />}

      <div className="min-w-0 flex-1 lg:h-full lg:overflow-y-auto">
        <header className="sticky top-0 z-10 flex items-center gap-3 border-b border-slate-200/70 bg-white/75 px-4 py-3 backdrop-blur-xl dark:border-white/[0.06] dark:bg-[#0b0d14]/75 sm:px-6 lg:px-8">
          <button onClick={() => setOpen(true)} className="rounded-lg p-1.5 hover:bg-slate-100 dark:hover:bg-white/10 lg:hidden" aria-label="Open menu"><Menu size={20} /></button>
          <div className="min-w-0 flex-1">
            <p className="hidden text-xs text-slate-500 dark:text-slate-400 sm:block">{greet}, {user!.name.split(' ')[0]}</p>
            <p className="truncate text-sm font-semibold">{current.label}</p>
          </div>
          <button onClick={toggle} className="rounded-xl border border-slate-200 p-2 text-slate-500 transition hover:bg-slate-100 hover:text-slate-800 dark:border-white/10 dark:text-slate-400 dark:hover:bg-white/10 dark:hover:text-white" aria-label="Toggle theme" title="Toggle theme">
            {dark ? <Sun size={16} /> : <Moon size={16} />}
          </button>
          <div className="lg:hidden">{avatar('h-8 w-8')}</div>
        </header>
        <main key={pathname} className="mx-auto max-w-7xl animate-fade-up p-4 sm:p-6 lg:p-8"><Suspense fallback={<Spinner />}><Outlet /></Suspense></main>
      </div>
    </div>
  );
}
