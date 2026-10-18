import { useState, type FormEvent } from 'react';
import { useQuery } from '@tanstack/react-query';
import { FlaskConical } from 'lucide-react';
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
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-brand-50 via-slate-50 to-sky-50 p-4 dark:from-slate-950 dark:via-slate-950 dark:to-brand-700/20">
      <form onSubmit={submit} className="card w-full max-w-sm space-y-4 p-8">
        <div className="flex flex-col items-center gap-2 pb-2">
          <div className="rounded-xl bg-brand-600 p-3 text-white"><FlaskConical size={24} /></div>
          <h1 className="text-xl font-semibold">Lab Console</h1>
          <p className="text-sm text-slate-500">Sign in to manage Virtual Chemistry Lab</p>
        </div>

        {googleId && (
          <>
            <div className={busy ? 'pointer-events-none opacity-60' : ''}>
              <GoogleButton clientId={googleId} onCredential={(c) => run(() => loginWithGoogle(c))} />
            </div>
            <div className="flex items-center gap-3 text-xs text-slate-400">
              <span className="h-px flex-1 bg-slate-200 dark:bg-slate-800" />or<span className="h-px flex-1 bg-slate-200 dark:bg-slate-800" />
            </div>
          </>
        )}

        <label className="block text-sm font-medium">Email
          <input className="input mt-1" type="email" autoComplete="username" required value={email} onChange={(e) => setEmail(e.target.value)} />
        </label>
        <label className="block text-sm font-medium">Password
          <input className="input mt-1" type="password" autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} />
        </label>
        {error && <p role="alert" className="rounded-lg bg-rose-50 px-3 py-2 text-sm text-rose-700 dark:bg-rose-500/10 dark:text-rose-300">{error}</p>}
        <button className="btn-primary w-full" disabled={busy}>{busy ? 'Signing in…' : 'Sign in'}</button>
      </form>
    </div>
  );
}
