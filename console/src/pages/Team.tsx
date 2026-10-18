import { useState, type FormEvent } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '../api';
import { useAuth } from '../auth';
import { Badge, PageHeader, Spinner, useToast, when } from '../ui';

const ROLE_HELP = { admin: 'Everything, including team, config, refunds and delete', editor: 'Create and edit content, announcements, feedback, revenue view', reviewer: 'Review and verify content, read-only elsewhere' };

export default function Team() {
  const qc = useQueryClient();
  const toast = useToast();
  const { user, can } = useAuth();
  const [f, setF] = useState({ name: '', email: '', password: '', role: 'editor' });
  const list = useQuery({ queryKey: ['team'], queryFn: () => api<any[]>('/team'), enabled: can() });
  const refresh = () => qc.invalidateQueries({ queryKey: ['team'] });
  const add = useMutation({
    mutationFn: () => api('/team', { method: 'POST', body: f }),
    onSuccess: () => { toast('ok', 'Member added'); setF({ name: '', email: '', password: '', role: 'editor' }); refresh(); },
    onError: (e: Error) => toast('err', e.message),
  });
  const patch = useMutation({
    mutationFn: ({ id, ...b }: { id: string; role?: string; active?: boolean }) => api(`/team/${id}`, { method: 'PATCH', body: b }),
    onSuccess: refresh, onError: (e: Error) => toast('err', e.message),
  });
  const submit = (e: FormEvent) => { e.preventDefault(); add.mutate(); };

  if (!can()) return <p className="p-8 text-center text-slate-500">Admins only.</p>;
  return (
    <>
      <PageHeader title="Team" subtitle="People who can sign in to the console" />
      <div className="grid gap-4 lg:grid-cols-[360px_1fr]">
        <form onSubmit={submit} className="card h-fit space-y-3 p-5">
          <h2 className="font-medium">Add member</h2>
          <input className="input" placeholder="Name" required value={f.name} onChange={(e) => setF({ ...f, name: e.target.value })} />
          <input className="input" type="email" placeholder="Email" required value={f.email} onChange={(e) => setF({ ...f, email: e.target.value })} />
          <input className="input" type="password" placeholder="Temporary password (min 8)" minLength={8} required value={f.password} onChange={(e) => setF({ ...f, password: e.target.value })} />
          <select className="input" value={f.role} onChange={(e) => setF({ ...f, role: e.target.value })}>{Object.keys(ROLE_HELP).map((r) => <option key={r}>{r}</option>)}</select>
          <p className="text-xs text-slate-500">{ROLE_HELP[f.role as keyof typeof ROLE_HELP]}</p>
          <button className="btn-primary w-full" disabled={add.isPending}>Add</button>
        </form>
        <div className="card overflow-x-auto">
          {list.isLoading ? <Spinner /> : (
            <table className="w-full">
              <thead className="border-b border-slate-200 dark:border-slate-800"><tr><th className="th">Name</th><th className="th">Role</th><th className="th">Last sign-in</th><th className="th">Status</th></tr></thead>
              <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                {list.data?.map((m) => {
                  const me = m._id === user!.id;
                  return (
                    <tr key={m._id}>
                      <td className="td"><p className="font-medium">{m.name}</p><p className="text-xs text-slate-500">{m.email}</p></td>
                      <td className="td">{me ? <Badge className="bg-brand-50 text-brand-700">{m.role} (you)</Badge> :
                        <select className="input w-auto" value={m.role} onChange={(e) => patch.mutate({ id: m._id, role: e.target.value })} aria-label="Role">{Object.keys(ROLE_HELP).map((r) => <option key={r}>{r}</option>)}</select>}</td>
                      <td className="td">{m.lastLoginAt ? when(m.lastLoginAt) : '—'}</td>
                      <td className="td">{me ? 'Active' : <button className="btn-ghost !py-1 text-xs" onClick={() => patch.mutate({ id: m._id, active: !m.active })}>{m.active ? 'Disable' : 'Enable'}</button>}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </>
  );
}
