import { createContext, useCallback, useContext, useState, type ReactNode } from 'react';
import { CheckCircle2, AlertCircle, Inbox, X } from 'lucide-react';
import type { Review } from './api';

export function PageHeader({ title, subtitle, actions }: { title: string; subtitle?: string; actions?: ReactNode }) {
  return (
    <div className="mb-7 flex animate-fade-up flex-wrap items-end justify-between gap-4">
      <div>
        <h1 className="font-display text-[26px] font-bold tracking-tight text-slate-900 dark:text-white">{title}</h1>
        {subtitle && <p className="mt-1.5 max-w-2xl text-sm text-slate-500 dark:text-slate-400">{subtitle}</p>}
      </div>
      <div className="flex flex-wrap gap-2">{actions}</div>
    </div>
  );
}

export function Stat({ label, value, hint, icon, tone = 'brand' }: {
  label: string; value: ReactNode; hint?: string; icon?: ReactNode; tone?: 'brand' | 'green' | 'amber' | 'rose' | 'sky';
}) {
  const tones = {
    brand: ['from-brand-500 to-violet-500', 'bg-brand-500'], green: ['from-emerald-500 to-teal-500', 'bg-emerald-500'],
    amber: ['from-amber-400 to-orange-500', 'bg-amber-500'], rose: ['from-rose-500 to-pink-500', 'bg-rose-500'],
    sky: ['from-sky-500 to-cyan-500', 'bg-sky-500'],
  };
  const [grad, glow] = tones[tone];
  return (
    <div className="card group relative animate-fade-up overflow-hidden p-5 transition hover:-translate-y-0.5 hover:shadow-lift">
      <div className={`pointer-events-none absolute -right-8 -top-8 h-28 w-28 rounded-full opacity-[0.08] blur-2xl transition group-hover:opacity-20 ${glow}`} />
      <div className="relative flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-[13px] font-medium text-slate-500 dark:text-slate-400">{label}</p>
          <p className="mt-2 font-display text-[28px] font-bold leading-none tracking-tight tabular-nums">{value}</p>
          {hint && <p className="mt-2.5 text-xs text-slate-500 dark:text-slate-400">{hint}</p>}
        </div>
        {icon && <div className={`rounded-xl bg-gradient-to-br p-2.5 text-white shadow-md ${grad}`}>{icon}</div>}
      </div>
    </div>
  );
}

const REVIEW_STYLE: Record<Review, string> = {
  draft: 'bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-300',
  needsReview: 'bg-amber-100 text-amber-700 dark:bg-amber-500/20 dark:text-amber-300',
  sourceChecked: 'bg-sky-100 text-sky-700 dark:bg-sky-500/20 dark:text-sky-300',
  verified: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-500/20 dark:text-emerald-300',
};
export const REVIEW_LABEL: Record<Review, string> = {
  draft: 'Draft', needsReview: 'Needs review', sourceChecked: 'Source checked', verified: 'Verified',
};
export const REVIEW_COLOR: Record<Review, string> = {
  draft: '#94a3b8', needsReview: '#f59e0b', sourceChecked: '#0ea5e9', verified: '#10b981',
};

export function Badge({ children, className = '' }: { children: ReactNode; className?: string }) {
  return <span className={`inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-semibold ${className}`}>{children}</span>;
}
export const ReviewBadge = ({ status }: { status: Review }) => <Badge className={REVIEW_STYLE[status]}>{REVIEW_LABEL[status]}</Badge>;

export function Empty({ children }: { children: ReactNode }) {
  return (
    <div className="flex flex-col items-center gap-3 px-4 py-12 text-center text-sm text-slate-500 dark:text-slate-400">
      <div className="rounded-2xl bg-slate-100 p-3 text-slate-400 dark:bg-white/5"><Inbox size={20} /></div>
      {children}
    </div>
  );
}
export function Spinner() {
  return <div className="flex justify-center py-12"><div className="h-8 w-8 animate-spin rounded-full border-[3px] border-brand-500/20 border-t-brand-500" /></div>;
}

export function Pager({ page, pages, onPage }: { page: number; pages: number; onPage: (p: number) => void }) {
  if (pages <= 1) return null;
  return (
    <div className="flex items-center justify-between border-t border-slate-200 px-4 py-3 text-sm dark:border-white/10">
      <span className="text-slate-500 dark:text-slate-400">Page {page} of {pages}</span>
      <div className="flex gap-2">
        <button className="btn-ghost" disabled={page <= 1} onClick={() => onPage(page - 1)}>Previous</button>
        <button className="btn-ghost" disabled={page >= pages} onClick={() => onPage(page + 1)}>Next</button>
      </div>
    </div>
  );
}

export function Modal({ title, onClose, children }: { title: string; onClose: () => void; children: ReactNode }) {
  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center bg-slate-950/60 p-4 backdrop-blur-sm" onClick={onClose}>
      <div className="card max-h-[90vh] w-full max-w-lg animate-fade-up overflow-auto p-6 shadow-lift" onClick={(e) => e.stopPropagation()}>
        <div className="mb-5 flex items-center justify-between">
          <h2 className="text-lg font-bold tracking-tight">{title}</h2>
          <button onClick={onClose} aria-label="Close" className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700 dark:hover:bg-white/10"><X size={18} /></button>
        </div>
        {children}
      </div>
    </div>
  );
}

// ---- toasts ----
interface Toast { id: number; kind: 'ok' | 'err'; text: string }
const ToastCtx = createContext<(kind: Toast['kind'], text: string) => void>(() => {});
export const useToast = () => useContext(ToastCtx);

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const push = useCallback((kind: Toast['kind'], text: string) => {
    const id = Date.now() + Math.random();
    setToasts((t) => [...t, { id, kind, text }]);
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 4000);
  }, []);
  return (
    <ToastCtx.Provider value={push}>
      {children}
      <div className="fixed bottom-4 right-4 z-50 flex flex-col gap-2">
        {toasts.map((t) => (
          <div key={t.id} className={`card flex max-w-sm animate-fade-up items-center gap-2.5 border-l-4 px-4 py-3 text-sm font-medium shadow-lift ${t.kind === 'ok' ? 'border-l-emerald-500' : 'border-l-rose-500'}`}>
            {t.kind === 'ok' ? <CheckCircle2 size={16} className="text-emerald-500" /> : <AlertCircle size={16} className="text-rose-500" />}
            {t.text}
          </div>
        ))}
      </div>
    </ToastCtx.Provider>
  );
}

export const inr = (n: number) => `₹${n.toLocaleString('en-IN')}`;
export const when = (d: string) => new Date(d).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
