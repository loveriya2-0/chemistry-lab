import { useState, type FormEvent } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Trash2 } from 'lucide-react';
import { api } from '../api';
import { useAuth } from '../auth';
import { Badge, Empty, PageHeader, Spinner, useToast, when } from '../ui';

export default function Announcements() {
  const qc = useQueryClient();
  const toast = useToast();
  const { can } = useAuth();
  const [form, setForm] = useState({ title: '', body: '', kind: 'info' });
  const list = useQuery({ queryKey: ['announcements'], queryFn: () => api<any[]>('/announcements') });
  const refresh = () => qc.invalidateQueries({ queryKey: ['announcements'] });
  const create = useMutation({
    mutationFn: () => api('/announcements', { method: 'POST', body: form }),
    onSuccess: () => { toast('ok', 'Published to the app'); setForm({ title: '', body: '', kind: 'info' }); refresh(); },
    onError: (e: Error) => toast('err', e.message),
  });
  const toggle = useMutation({ mutationFn: (a: any) => api(`/announcements/${a._id}`, { method: 'PUT', body: { active: !a.active } }), onSuccess: refresh });
  const remove = useMutation({ mutationFn: (id: string) => api(`/announcements/${id}`, { method: 'DELETE' }), onSuccess: refresh });
  const submit = (e: FormEvent) => { e.preventDefault(); create.mutate(); };

  return (
    <>
      <PageHeader title="Announcements" subtitle="Short notices shown inside the app (updates, offers, maintenance)" />
      <div className="grid gap-4 lg:grid-cols-[360px_1fr]">
        {can('editor') && (
          <form onSubmit={submit} className="card h-fit space-y-3 p-5">
            <h2 className="font-medium">New announcement</h2>
            <input className="input" placeholder="Title" required maxLength={120} value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
            <textarea className="input min-h-24" placeholder="Message" required maxLength={1000} value={form.body} onChange={(e) => setForm({ ...form, body: e.target.value })} />
            <select className="input" value={form.kind} onChange={(e) => setForm({ ...form, kind: e.target.value })}>
              {['info', 'update', 'promo', 'maintenance'].map((k) => <option key={k}>{k}</option>)}
            </select>
            <button className="btn-primary w-full" disabled={create.isPending}>Publish</button>
          </form>
        )}
        <div className="card">
          {list.isLoading ? <Spinner /> : !list.data?.length ? <Empty>No announcements yet.</Empty> : (
            <ul className="divide-y divide-slate-100 dark:divide-slate-800">
              {list.data.map((a) => (
                <li key={a._id} className="flex items-start gap-3 p-4">
                  <div className="min-w-0 flex-1">
                    <p className="font-medium">{a.title} <Badge className="ml-1 bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-300">{a.kind}</Badge></p>
                    <p className="mt-1 whitespace-pre-wrap text-sm text-slate-600 dark:text-slate-300">{a.body}</p>
                    <p className="mt-1 text-xs text-slate-500">{when(a.createdAt)}</p>
                  </div>
                  {can('editor') && <>
                    <label className="flex items-center gap-1.5 text-sm"><input type="checkbox" checked={a.active} onChange={() => toggle.mutate(a)} />Live</label>
                    <button aria-label="Delete" className="text-slate-400 hover:text-rose-600" onClick={() => confirm('Delete this announcement?') && remove.mutate(a._id)}><Trash2 size={16} /></button>
                  </>}
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </>
  );
}
