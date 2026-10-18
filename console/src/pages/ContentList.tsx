import { useEffect, useRef, useState } from 'react';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Download, Plus, Search, Upload } from 'lucide-react';
import { api, download, CONTENT_TYPES, type ContentRow, type Review } from '../api';
import { useAuth } from '../auth';
import { Empty, PageHeader, Pager, REVIEW_LABEL, ReviewBadge, Spinner, useToast } from '../ui';

export default function ContentList() {
  const { type = 'question' } = useParams();
  const [sp, setSp] = useSearchParams();
  const nav = useNavigate();
  const qc = useQueryClient();
  const toast = useToast();
  const { can } = useAuth();
  const fileRef = useRef<HTMLInputElement>(null);
  const [search, setSearch] = useState(sp.get('q') || '');
  const [selected, setSelected] = useState<string[]>([]);

  const page = Number(sp.get('page') || 1);
  const review = sp.get('review') || '';
  const classLevel = sp.get('classLevel') || '';
  const q = sp.get('q') || '';

  const set = (k: string, v: string) => {
    const n = new URLSearchParams(sp);
    v ? n.set(k, v) : n.delete(k);
    if (k !== 'page') n.delete('page');
    setSp(n, { replace: true });
  };
  useEffect(() => { const t = setTimeout(() => set('q', search), 300); return () => clearTimeout(t); /* eslint-disable-next-line */ }, [search]);
  useEffect(() => setSelected([]), [type, page, review, classLevel, q]);

  const params = new URLSearchParams({ page: String(page), limit: '25' });
  if (review) params.set('review', review);
  if (classLevel) params.set('classLevel', classLevel);
  if (q) params.set('q', q);

  const list = useQuery({
    queryKey: ['content', type, page, review, classLevel, q],
    queryFn: () => api<{ items: ContentRow[]; total: number; pages: number }>(`/content/${type}?${params}`),
    placeholderData: (prev) => prev,
  });

  const bulk = useMutation({
    mutationFn: (status: Review) => api('/content/tools/bulk-review', { method: 'POST', body: { type, ids: selected, status } }),
    onSuccess: () => { toast('ok', 'Status updated'); setSelected([]); qc.invalidateQueries({ queryKey: ['content'] }); qc.invalidateQueries({ queryKey: ['overview'] }); },
    onError: (e: Error) => toast('err', e.message),
  });

  const onImport = async (file: File) => {
    try {
      const json = JSON.parse(await file.text());
      const items = Array.isArray(json) ? json : json.items;
      const overwrite = confirm('Overwrite existing items with the same id?\nOK = overwrite, Cancel = skip existing');
      const r = await api<any>(`/content/import/${type}`, { method: 'POST', body: { items, hiSrc: json.hiSrc, overwrite } });
      toast(r.errors.length ? 'err' : 'ok', `Imported: ${r.created} new, ${r.updated} updated, ${r.skipped} skipped, ${r.errors.length} rejected`);
      qc.invalidateQueries({ queryKey: ['content'] });
    } catch (e) { toast('err', (e as Error).message); }
  };

  const rows = list.data?.items || [];
  const allOn = rows.length > 0 && rows.every((r) => selected.includes(r.itemId));

  return (
    <>
      <PageHeader title="Content" subtitle="Everything the app teaches — notes, questions, PYQs, chemicals and lab experiments"
        actions={<>
          <button className="btn-ghost" onClick={() => download(`/content/export/${type}`, `${type}.json`).catch((e) => toast('err', e.message))}><Download size={16} />Export</button>
          {can('editor') && <>
            <input ref={fileRef} type="file" accept="application/json" hidden onChange={(e) => e.target.files?.[0] && onImport(e.target.files[0])} />
            <button className="btn-ghost" onClick={() => fileRef.current?.click()}><Upload size={16} />Import</button>
            <Link to={`/content/${type}/new`} className="btn-primary"><Plus size={16} />New</Link>
          </>}
        </>} />

      <div className="mb-4 flex gap-1 overflow-x-auto border-b border-slate-200 dark:border-slate-800">
        {CONTENT_TYPES.map((t) => (
          <Link key={t.id} to={`/content/${t.id}`}
            className={`whitespace-nowrap border-b-2 px-3 py-2 text-sm font-medium ${t.id === type ? 'border-brand-600 text-brand-700 dark:text-brand-100' : 'border-transparent text-slate-500 hover:text-slate-800 dark:hover:text-slate-200'}`}>
            {t.label}
          </Link>
        ))}
      </div>

      <div className="card">
        <div className="flex flex-wrap items-center gap-2 border-b border-slate-200 p-3 dark:border-slate-800">
          <div className="relative min-w-52 flex-1">
            <Search size={15} className="absolute left-3 top-3 text-slate-400" />
            <input className="input pl-9" placeholder="Search title or id…" value={search} onChange={(e) => setSearch(e.target.value)} />
          </div>
          <select className="input w-auto" value={classLevel} onChange={(e) => set('classLevel', e.target.value)} aria-label="Class">
            <option value="">All classes</option>
            {[9, 10, 11, 12].map((c) => <option key={c} value={c}>Class {c}</option>)}
          </select>
          <select className="input w-auto" value={review} onChange={(e) => set('review', e.target.value)} aria-label="Review status">
            <option value="">All statuses</option>
            {(Object.keys(REVIEW_LABEL) as Review[]).map((r) => <option key={r} value={r}>{REVIEW_LABEL[r]}</option>)}
          </select>
        </div>

        {selected.length > 0 && (
          <div className="flex flex-wrap items-center gap-2 bg-brand-50 px-4 py-2 text-sm dark:bg-brand-600/10">
            <b>{selected.length}</b> selected — set status:
            {(Object.keys(REVIEW_LABEL) as Review[]).filter((r) => r !== 'verified' || can('reviewer')).map((r) => (
              <button key={r} className="btn-ghost !py-1" disabled={bulk.isPending} onClick={() => bulk.mutate(r)}>{REVIEW_LABEL[r]}</button>
            ))}
          </div>
        )}

        {list.isLoading ? <Spinner /> : rows.length === 0 ? <Empty>No items match.</Empty> : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="border-b border-slate-200 dark:border-slate-800">
                <tr>
                  <th className="th w-10"><input type="checkbox" checked={allOn} onChange={() => setSelected(allOn ? [] : rows.map((r) => r.itemId))} aria-label="Select all" /></th>
                  <th className="th">Title</th><th className="th">Id</th><th className="th">Class</th><th className="th">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                {rows.map((r) => (
                  <tr key={r._id} className="cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-800/50" onClick={() => nav(`/content/${type}/${encodeURIComponent(r.itemId)}`)}>
                    <td className="td" onClick={(e) => e.stopPropagation()}>
                      <input type="checkbox" checked={selected.includes(r.itemId)} aria-label={`Select ${r.itemId}`}
                        onChange={() => setSelected((s) => (s.includes(r.itemId) ? s.filter((x) => x !== r.itemId) : [...s, r.itemId]))} />
                    </td>
                    <td className="td max-w-md truncate font-medium">{r.title}</td>
                    <td className="td font-mono text-xs text-slate-500">{r.itemId}</td>
                    <td className="td">{r.classLevel ?? '—'}</td>
                    <td className="td"><ReviewBadge status={r.review} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        <Pager page={page} pages={list.data?.pages || 1} onPage={(p) => set('page', String(p))} />
        <p className="border-t border-slate-200 px-4 py-2 text-xs text-slate-500 dark:border-slate-800">{list.data?.total ?? 0} items</p>
      </div>
    </>
  );
}
