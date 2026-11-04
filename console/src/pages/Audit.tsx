import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { api } from '../api';
import { Badge, Empty, PageHeader, Spinner, when } from '../ui';

export default function Audit() {
  const [entity, setEntity] = useState('');
  const q = useQuery({ queryKey: ['audit', 'full', entity], queryFn: () => api<any[]>(`/audit?limit=200${entity ? `&entity=${entity}` : ''}`) });
  return (
    <>
      <PageHeader title="Audit log" subtitle="Every change made through the console"
        actions={<select className="input w-auto" value={entity} onChange={(e) => setEntity(e.target.value)} aria-label="Entity">
          <option value="">All</option>{['question', 'note', 'pyq', 'concept', 'chemical', 'reaction', 'guide', 'purchase', 'config', 'user', 'announcement'].map((x) => <option key={x}>{x}</option>)}
        </select>} />
      <div className="card">
        {q.isLoading ? <Spinner /> : !q.data?.length ? <Empty>No activity yet.</Empty> : (
          <ul className="divide-y divide-slate-100 dark:divide-slate-800">
            {q.data.map((a) => (
              <li key={a._id} className="flex flex-wrap items-center gap-3 px-4 py-3 text-sm">
                <Badge className="w-20 justify-center bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-300">{a.action}</Badge>
                <span className="min-w-0 flex-1">{a.summary}</span>
                <span className="text-xs text-slate-500">{a.actorEmail} · {when(a.createdAt)}</span>
              </li>
            ))}
          </ul>
        )}
      </div>
    </>
  );
}
