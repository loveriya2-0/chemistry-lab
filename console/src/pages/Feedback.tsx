import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '../api';
import { useAuth } from '../auth';
import { Badge, Empty, PageHeader, Spinner, useToast, when } from '../ui';

const STATUS = ['new', 'inProgress', 'resolved'] as const;

export default function Feedback() {
  const qc = useQueryClient();
  const toast = useToast();
  const { can } = useAuth();
  const [filter, setFilter] = useState<string>('new');
  const list = useQuery({ queryKey: ['feedback'], queryFn: () => api<any[]>('/feedback') });
  const update = useMutation({
    mutationFn: ({ id, ...body }: { id: string; status?: string; reply?: string }) => api(`/feedback/${id}`, { method: 'PUT', body }),
    onSuccess: () => { toast('ok', 'Saved'); qc.invalidateQueries({ queryKey: ['feedback'] }); qc.invalidateQueries({ queryKey: ['overview'] }); },
    onError: (e: Error) => toast('err', e.message),
  });
  const rows = (list.data || []).filter((f) => !filter || f.status === filter);

  return (
    <>
      <PageHeader title="Feedback inbox" subtitle="Bug reports, content corrections and ideas sent from the app" />
      <div className="mb-4 flex gap-2">
        {['', ...STATUS].map((s) => (
          <button key={s} onClick={() => setFilter(s)} className={`rounded-full px-3 py-1 text-sm ${filter === s ? 'bg-brand-600 text-white' : 'bg-white text-slate-600 ring-1 ring-slate-200 dark:bg-slate-900 dark:text-slate-300 dark:ring-slate-700'}`}>{s || 'All'}</button>
        ))}
      </div>
      <div className="space-y-3">
        {list.isLoading ? <Spinner /> : rows.length === 0 ? <div className="card"><Empty>No feedback here.</Empty></div> : rows.map((f) => (
          <div key={f._id} className="card p-4">
            <div className="flex flex-wrap items-center gap-2 text-xs text-slate-500">
              <Badge className="bg-brand-50 text-brand-700 dark:bg-brand-600/20 dark:text-brand-100">{f.kind}</Badge>
              {f.contentRef && <code>{f.contentRef}</code>}<span>v{f.appVersion || '?'} · {when(f.createdAt)}</span>
            </div>
            <p className="mt-2 whitespace-pre-wrap text-sm">{f.message}</p>
            {can('editor') && (
              <div className="mt-3 flex flex-wrap items-center gap-2">
                <select className="input w-auto" value={f.status} onChange={(e) => update.mutate({ id: f._id, status: e.target.value })} aria-label="Status">{STATUS.map((s) => <option key={s}>{s}</option>)}</select>
                <input className="input min-w-48 flex-1" placeholder="Internal note / reply" defaultValue={f.reply} onBlur={(e) => e.target.value !== (f.reply || '') && update.mutate({ id: f._id, reply: e.target.value })} />
              </div>
            )}
          </div>
        ))}
      </div>
    </>
  );
}
