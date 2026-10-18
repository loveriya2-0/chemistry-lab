import { createContext, useCallback, useContext, useState, type ReactNode } from 'react';
import { CheckCircle2, AlertCircle, X } from 'lucide-react';
import type { Review } from './api';

export function PageHeader({ title, subtitle, actions }: { title: string; subtitle?: string; actions?: ReactNode }) {
  return (
    <div className="mb-6 flex flex-wrap items-end justify-between gap-3">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">{title}</h1>
        {subtitle && <p className="mt-1 text-sm text-slate-500">{subtitle}</p>}
      </div>
      <div className="flex flex-wrap gap-2">{actions}</div>
    </div>
  );
}

export function Stat({ label, value, hint, icon, tone = 'brand' }: {
  label: string; value: ReactNode; hint?: string; icon?: ReactNode; tone?: 'brand' | 'green' | 'amber' | 'rose' | 'sky';
}) {
  const tones = {
    brand: 'bg-brand-50 text-brand-600 dark:bg-brand-600/20', green: 'bg-emerald-50 text-emerald-600 dark:bg-emerald-600/20',
    amber: 'bg-amber-50 text-amber-600 dark:bg-amber-600/20', rose: 'bg-rose-50 text-rose-600 dark:bg-rose-600/20',
    sky: 'bg-sky-50 text-sky-600 dark:bg-sky-600/20',
  };
  return (
    <div className="card flex items-start justify-between p-5">
      <div>
        <p className="text-sm text-slate-500">{label}</p>
        <p className="mt-1 text-2xl font-semibold tabular-nums">{value}</p>
        {hint && <p className="mt-1 text-xs text-slate-500">{hint}</p>}
      </div>
      {icon && <div className={`rounded-lg p-2.5 ${tones[tone]}`}>{icon}</div>}
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
  return <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ${className}`}>{children}</span>;
}
export const ReviewBadge = ({ status }: { status: Review }) => <Badge className={REVIEW_STYLE[status]}>{REVIEW_LABEL[status]}</Badge>;

export function Empty({ children }: { children: ReactNode }) {
  return <div className="px-4 py-12 text-center text-sm text-slate-500">{children}</div>;
}
export function Spinner() {
  return <div className="flex justify-center py-12"><div className="h-6 w-6 animate-spin rounded-full border-2 border-brand-500 border-t-transparent" /></div>;
}

export function Pager({ page, pages, onPage }: { page: number; pages: number; onPage: (p: number) => void }) {
  if (pages <= 1) return null;
  return (
    <div className="flex items-center justify-between border-t border-slate-200 px-4 py-3 text-sm dark:border-slate-800">
      <span className="text-slate-500">Page {page} of {pages}</span>
      <div className="flex gap-2">
        <button className="btn-ghost" disabled={page <= 1} onClick={() => onPage(page - 1)}>Previous</button>
        <button className="btn-ghost" disabled={page >= pages} onClick={() => onPage(page + 1)}>Next</button>
      </div>
    </div>
  );
}

export function Modal({ title, onClose, children }: { title: string; onClose: () => void; children: ReactNode }) {
  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center bg-slate-900/50 p-4" onClick={onClose}>
      <div className="card max-h-[90vh] w-full max-w-lg overflow-auto p-6" onClick={(e) => e.stopPropagation()}>
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-semibold">{title}</h2>
          <button onClick={onClose} aria-label="Close"><X size={18} /></button>
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
          <div key={t.id} className="card flex max-w-sm items-center gap-2 px-4 py-3 text-sm shadow-lg">
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
