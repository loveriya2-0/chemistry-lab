import { Link } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Check, X } from 'lucide-react';
import { api, CONTENT_TYPES, type ContentRow } from '../api';
import { useAuth } from '../auth';
import { Empty, PageHeader, Spinner, useToast, when } from '../ui';

export default function ReviewQueue() {
  const qc = useQueryClient();
  const toast = useToast();
  const { can } = useAuth();
  const q = useQuery({
    queryKey: ['review-queue'],
    queryFn: async () => {
      const lists = await Promise.all(CONTENT_TYPES.map((t) => api<{ items: ContentRow[] }>(`/content/${t.id}?review=needsReview&limit=50`).then((r) => r.items)));
      return lists.flat().sort((a, b) => +new Date(b.updatedAt) - +new Date(a.updatedAt));
    },
  });
  const act = useMutation({
    mutationFn: ({ r, status }: { r: ContentRow; status: string }) => api(`/content/${r.type}/${encodeURIComponent(r.itemId)}/review`, { method: 'PATCH', body: { status } }),
    onSuccess: () => { toast('ok', 'Updated'); qc.invalidateQueries({ queryKey: ['review-queue'] }); qc.invalidateQueries({ queryKey: ['overview'] }); },
    onError: (e: Error) => toast('err', e.message),
  });

  return (
    <>
      <PageHeader title="Review queue" subtitle="Content submitted for checking. Approve once the source and Hindi are confirmed." />
      <div className="card">
        {q.isLoading ? <Spinner /> : !q.data?.length ? <Empty>Nothing is waiting for review.</Empty> : (
          <ul className="divide-y divide-slate-100 dark:divide-slate-800">
            {q.data.map((r) => (
              <li key={r._id} className="flex flex-wrap items-center gap-3 px-4 py-3">
                <div className="min-w-0 flex-1">
                  <Link to={`/content/${r.type}/${encodeURIComponent(r.itemId)}`} className="block truncate font-medium hover:text-brand-600">{r.title}</Link>
                  <p className="text-xs text-slate-500"><span className="uppercase">{r.type}</span> · {r.itemId} · {when(r.updatedAt)}</p>
                </div>
                {can('reviewer') && <>
                  <button className="btn-ghost !py-1" onClick={() => act.mutate({ r, status: 'draft' })}><X size={14} />Send back</button>
                  <button className="btn-ghost !py-1" onClick={() => act.mutate({ r, status: 'sourceChecked' })}><Check size={14} />Source checked</button>
                  <button className="btn-primary !py-1" onClick={() => act.mutate({ r, status: 'verified' })}><Check size={14} />Verify</button>
                </>}
              </li>
            ))}
          </ul>
        )}
      </div>
    </>
  );
}
