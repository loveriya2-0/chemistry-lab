import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import { api, tokenStore, type Me, type Role } from './api';

interface AuthState {
  user: Me | null; loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  loginWithGoogle: (credential: string) => Promise<void>;
  logout: () => void;
  can: (...roles: Role[]) => boolean;
}
const Ctx = createContext<AuthState>(null as never);
export const useAuth = () => useContext(Ctx);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<Me | null>(null);
  const [loading, setLoading] = useState(!!tokenStore.get());

  useEffect(() => {
    if (tokenStore.get()) {
      api<{ user: Me }>('/auth/me').then((r) => setUser(r.user)).catch(() => tokenStore.clear()).finally(() => setLoading(false));
    }
    const out = () => setUser(null);
    window.addEventListener('lab-console-logout', out);
    return () => window.removeEventListener('lab-console-logout', out);
  }, []);

  const value: AuthState = {
    user, loading,
    login: async (email, password) => {
      const r = await api<{ token: string; user: Me }>('/auth/login', { method: 'POST', body: { email, password } });
      tokenStore.set(r.token);
      setUser(r.user);
    },
    loginWithGoogle: async (credential) => {
      const r = await api<{ token: string; user: Me }>('/auth/google', { method: 'POST', body: { credential } });
      tokenStore.set(r.token);
      setUser(r.user);
    },
    logout: () => { tokenStore.clear(); setUser(null); },
    // admin always passes; otherwise the user's role must be listed
    can: (...roles) => !!user && (user.role === 'admin' || roles.includes(user.role)),
  };
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}
