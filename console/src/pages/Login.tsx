import { useState, type FormEvent } from 'react';
import { useQuery } from '@tanstack/react-query';
import { CheckCircle2, FlaskConical } from 'lucide-react';
import { api } from '../api';
import { useAuth } from '../auth';
import GoogleButton from '../GoogleButton';

export default function Login() {
  const { login, loginWithGoogle } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const cfg = useQuery({ queryKey: ['auth-config'], queryFn: () => api<{ googleClientId: string | null }>('/auth/config'), retry: false });
  const googleId = cfg.data?.googleClientId;

  const run = async (fn: () => Promise<void>) => {
    setBusy(true); setError('');
    try { await fn(); } catch (err) { setError((err as Error).message); } finally { setBusy(false); }
  };
  const submit = (e: FormEvent) => { e.preventDefault(); run(() => login(email, password)); };

  return (
    <div className="grid min-h-screen lg:grid-cols-[1.1fr_1fr]">
      <aside className="relative hidden overflow-hidden bg-[#0c0e1a] p-12 text-white lg:flex lg:flex-col">
        <div className="absolute -left-24 -top-24 h-96 w-96 rounded-full bg-brand-600/40 blur-3xl" />
        <div className="absolute -bottom-32 right-0 h-96 w-96 rounded-full bg-violet-600/30 blur-3xl" />
        <div className="absolute inset-0 opacity-[0.07] [background-image:radial-gradient(white_1px,transparent_1px)] [background-size:22px_22px]" />
        <div className="relative flex items-center gap-3">
          <div className="rounded-xl bg-gradient-to-br from-brand-400 to-violet-600 p-2.5 shadow-glow"><FlaskConical size={20} /></div>
          <span className="font-display text-lg font-bold">Lab Console</span>
        </div>
        <div className="relative mt-auto max-w-md">
          <h2 className="font-display text-4xl font-extrabold leading-tight tracking-tight">
            Run your chemistry lab<br /><span className="bg-gradient-to-r from-brand-300 to-violet-300 bg-clip-text text-transparent">from one place.</span>
          </h2>
          <p className="mt-4 text-slate-400">Manage content, review questions, track Premium sales and talk to your learners — all in the Virtual Chemistry Lab console.</p>
          <ul className="mt-8 space-y-3 text-sm text-slate-300">
            {['Notes, PYQs, chemicals & experiments', 'Review workflow with source checks', 'Live installs, revenue & feedback'].map((t) => (
              <li key={t} className="flex items-center gap-3"><CheckCircle2 size={18} className="text-brand-300" />{t}</li>
            ))}
          </ul>
        </div>
        <p className="relative mt-12 text-xs text-slate-500">© {new Date().getFullYear()} Virtual Chemistry Lab</p>
      </aside>

      <div className="flex items-center justify-center p-6">
        <form onSubmit={submit} className="w-full max-w-sm animate-fade-up space-y-5">
          <div className="space-y-2 pb-2">
            <div className="mb-6 inline-flex rounded-xl bg-gradient-to-br from-brand-400 to-violet-600 p-3 text-white shadow-glow lg:hidden"><FlaskConical size={24} /></div>
            <h1 className="font-display text-3xl font-bold tracking-tight">Welcome back</h1>
            <p className="text-sm text-slate-500 dark:text-slate-400">Sign in to manage Virtual Chemistry Lab</p>
          </div>

          {googleId && (
            <>
              <div className={busy ? 'pointer-events-none opacity-60' : ''}>
                <GoogleButton clientId={googleId} onCredential={(c) => run(() => loginWithGoogle(c))} />
              </div>
              <div className="flex items-center gap-3 text-xs uppercase tracking-wider text-slate-400">
                <span className="h-px flex-1 bg-slate-200 dark:bg-white/10" />or<span className="h-px flex-1 bg-slate-200 dark:bg-white/10" />
              </div>
            </>
          )}

          <label className="block text-sm font-medium">Email
            <input className="input mt-1.5" type="email" autoComplete="username" placeholder="you@example.com" required value={email} onChange={(e) => setEmail(e.target.value)} />
          </label>
          <label className="block text-sm font-medium">Password
            <input className="input mt-1.5" type="password" autoComplete="current-password" placeholder="••••••••" required value={password} onChange={(e) => setPassword(e.target.value)} />
          </label>
          {error && <p role="alert" className="rounded-xl border border-rose-200 bg-rose-50 px-3.5 py-2.5 text-sm text-rose-700 dark:border-rose-500/20 dark:bg-rose-500/10 dark:text-rose-300">{error}</p>}
          <button className="btn-primary w-full !py-2.5" disabled={busy}>{busy ? 'Signing in…' : 'Sign in'}</button>
        </form>
      </div>
    </div>
  );
}
