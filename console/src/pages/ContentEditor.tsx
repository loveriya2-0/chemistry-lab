import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { ArrowLeft, CheckCircle2, Save, ShieldCheck, Trash2, TriangleAlert } from 'lucide-react';
import { api, ApiError, type Issue, type Review } from '../api';
import { useAuth } from '../auth';
import JsonForm from '../JsonForm';
import { PageHeader, REVIEW_LABEL, ReviewBadge, Spinner, useToast, when } from '../ui';

const bi = () => ({ en: '', hi: '' });
const TEMPLATES: Record<string, () => any> = {
  question: () => ({ id: '', classLevel: 10, chapterId: '', topicId: '', type: 'mcq', marks: 1, difficulty: 'medium', question: bi(), options: [bi(), bi(), bi(), bi()], correctOption: 0, answer: bi(), explanation: bi(), sources: [], review: { status: 'draft' } }),
  note: () => ({ id: '', targetId: '', definition: bi(), explanation: bi(), keyPoints: [bi()], realLife: bi(), examFocus: bi(), commonMistakes: [bi()], formulas: [''], review: { status: 'draft' } }),
  concept: () => ({ id: '', type: 'concept', title: bi(), sections: { whatIsIt: bi() }, relatedConceptIds: [], review: { status: 'draft' } }),
  chemical: () => ({ id: '', kind: 'compound', name: bi(), formula: '', properties: [bi()], uses: [bi()], equations: [''], explanation: bi(), practicalNote: bi(), review: { status: 'draft' } }),
  reaction: () => ({ id: '', kind: bi(), title: bi(), aim: bi(), equation: '', reactants: [bi()], products: [bi()], shelf: [], beakerMl: 40, steps: [{ reagent: '', ml: 0, instruction: bi(), observation: bi(), effects: {} }], what: bi(), why: bi(), realLife: bi(), examPoint: bi(), review: { status: 'draft' } }),
  reagent: () => ({ id: '', name: bi(), formula: '', color: '#BFE6FF', state: 'liquid' }),
  guide: () => ({ id: '', aim: bi(), equation: '', apparatus: [{ name: bi(), quantity: '' }], chemicals: [{ name: bi(), formula: '', quantity: '', hazard: bi() }], steps: [{ instruction: bi(), observation: bi(), explanation: bi() }], result: bi(), safety: [bi()], viva: [{ question: bi(), answer: bi() }], review: { status: 'draft' } }),
  pyq: () => ({ id: '', boardId: 'cbse', classLevel: 10, examYear: 2024, attempt: 'main', questionNumber: '1', marks: 1, type: 'mcq', chapterId: '', topicId: '', summary: bi(), options: [bi(), bi(), bi(), bi()], correctOption: 0, answer: bi(), review: { status: 'draft' } }),
};

export default function ContentEditor() {
  const { type = 'question', itemId } = useParams();
  const isNew = !itemId;
  const nav = useNavigate();
  const qc = useQueryClient();
  const toast = useToast();
  const { can } = useAuth();
  const [data, setData] = useState<any>(null);
  const [raw, setRaw] = useState('');
  const [mode, setMode] = useState<'form' | 'json'>('form');
  const [issues, setIssues] = useState<Issue[]>([]);
  const [dirty, setDirty] = useState(false);

  const doc = useQuery({
    queryKey: ['content-item', type, itemId], enabled: !isNew,
    queryFn: () => api<any>(`/content/${type}/${encodeURIComponent(itemId!)}`),
  });

  useEffect(() => {
    if (isNew) setData((TEMPLATES[type] || (() => ({ id: '' })))());
    else if (doc.data) { setData(doc.data.data); setDirty(false); }
  }, [isNew, type, doc.data]);

  useEffect(() => { if (mode === 'json' && data) setRaw(JSON.stringify(data, null, 2)); }, [mode]); // eslint-disable-line

  useEffect(() => {
    const h = (e: BeforeUnloadEvent) => { if (dirty) e.preventDefault(); };
    window.addEventListener('beforeunload', h);
    return () => window.removeEventListener('beforeunload', h);
  }, [dirty]);

  const edit = (v: any) => { setData(v); setDirty(true); };
  const current = () => { if (mode === 'json') return JSON.parse(raw); return data; };

  const validate = useMutation({
    mutationFn: () => api<{ ok: boolean; issues: Issue[] }>('/content/tools/validate', { method: 'POST', body: { type, data: current() } }),
    onSuccess: (r) => { setIssues(r.issues); toast(r.ok ? 'ok' : 'err', r.ok ? `Valid (${r.issues.length} warnings)` : 'Validation errors found'); },
    onError: (e: Error) => toast('err', e.message),
  });

  const save = useMutation({
    mutationFn: () => {
      const body = { data: current() };
      return isNew ? api<any>(`/content/${type}`, { method: 'POST', body }) : api<any>(`/content/${type}/${encodeURIComponent(itemId!)}`, { method: 'PUT', body });
    },
    onSuccess: (r) => {
      toast('ok', 'Saved'); setDirty(false); setIssues(r.issues || []);
      qc.invalidateQueries({ queryKey: ['content'] }); qc.invalidateQueries({ queryKey: ['content-item'] });
      if (isNew) nav(`/content/${type}/${encodeURIComponent(r.itemId)}`, { replace: true });
    },
    onError: (e: Error) => {
      if (e instanceof ApiError && Array.isArray(e.details)) setIssues(e.details as Issue[]);
      toast('err', e instanceof SyntaxError ? 'Invalid JSON' : e.message);
    },
  });

  const setReview = useMutation({
    mutationFn: (status: Review) => api(`/content/${type}/${encodeURIComponent(itemId!)}/review`, { method: 'PATCH', body: { status } }),
    onSuccess: () => { toast('ok', 'Review status updated'); qc.invalidateQueries({ queryKey: ['content-item'] }); qc.invalidateQueries({ queryKey: ['content'] }); qc.invalidateQueries({ queryKey: ['overview'] }); },
    onError: (e: Error) => toast('err', e.message),
  });

  const del = useMutation({
    mutationFn: () => api(`/content/${type}/${encodeURIComponent(itemId!)}`, { method: 'DELETE' }),
    onSuccess: () => { toast('ok', 'Deleted'); qc.invalidateQueries({ queryKey: ['content'] }); nav(`/content/${type}`); },
    onError: (e: Error) => toast('err', e.message),
  });

  if (!isNew && doc.isLoading) return <Spinner />;
  if (!data) return doc.isError ? <p className="p-8 text-center text-slate-500">Item not found.</p> : <Spinner />;

  const errors = issues.filter((i) => i.level === 'error');
  const canEdit = can('editor');

  return (
    <>
      <Link to={`/content/${type}`} className="mb-3 inline-flex items-center gap-1 text-sm text-slate-500 hover:text-slate-800 dark:hover:text-slate-200"><ArrowLeft size={14} />Back to {type}</Link>
      <PageHeader title={isNew ? `New ${type}` : (doc.data?.title || itemId!)}
        subtitle={isNew ? 'Fill both English and Hindi. Save as draft, then submit for review.' : `${itemId} · updated ${doc.data ? when(doc.data.updatedAt) : ''}`}
        actions={<>
          <button className="btn-ghost" onClick={() => validate.mutate()} disabled={validate.isPending}><ShieldCheck size={16} />Validate</button>
          {canEdit && <button className="btn-primary" onClick={() => save.mutate()} disabled={save.isPending}><Save size={16} />{save.isPending ? 'Saving…' : 'Save'}</button>}
          {!isNew && can() && <button className="btn-danger" onClick={() => confirm(`Delete ${itemId}? This cannot be undone.`) && del.mutate()}><Trash2 size={16} /></button>}
        </>} />

      <div className="grid gap-4 lg:grid-cols-[1fr_300px]">
        <div className="card p-5">
          <div className="mb-4 inline-flex rounded-lg border border-slate-200 p-0.5 text-sm dark:border-slate-700">
            {(['form', 'json'] as const).map((m) => (
              <button key={m} onClick={() => {
                if (mode === 'json' && m === 'form') { try { setData(JSON.parse(raw)); } catch { return toast('err', 'Invalid JSON'); } }
                setMode(m);
              }} className={`rounded-md px-3 py-1 ${mode === m ? 'bg-brand-600 text-white' : 'text-slate-600 dark:text-slate-300'}`}>{m === 'form' ? 'Form' : 'JSON'}</button>
            ))}
          </div>
          {mode === 'form'
            ? <fieldset disabled={!canEdit} className="min-w-0"><JsonForm value={data} onChange={edit} issues={issues} /></fieldset>
            : <textarea className="input min-h-[28rem] font-mono text-xs" spellCheck={false} value={raw} readOnly={!canEdit} onChange={(e) => { setRaw(e.target.value); setDirty(true); }} />}
        </div>

        <aside className="space-y-4">
          {!isNew && doc.data && (
            <div className="card p-4">
              <h3 className="mb-2 text-sm font-semibold">Review</h3>
              <ReviewBadge status={doc.data.review} />
              <div className="mt-3 flex flex-col gap-2">
                {(Object.keys(REVIEW_LABEL) as Review[]).filter((r) => r !== doc.data.review && (r !== 'verified' || can('reviewer'))).map((r) => (
                  <button key={r} className="btn-ghost justify-start" disabled={setReview.isPending || dirty} onClick={() => setReview.mutate(r)}>Mark as {REVIEW_LABEL[r].toLowerCase()}</button>
                ))}
              </div>
              {dirty && <p className="mt-2 text-xs text-amber-600">Save your edits before changing status.</p>}
              <p className="mt-3 text-xs text-slate-500">Only <b>source checked</b> and <b>verified</b> items are shown in the app. Editing reviewed content sends it back to “needs review”.</p>
            </div>
          )}
          <div className="card p-4">
            <h3 className="mb-2 flex items-center gap-2 text-sm font-semibold">Validation
              {issues.length > 0 && (errors.length ? <TriangleAlert size={15} className="text-rose-500" /> : <CheckCircle2 size={15} className="text-emerald-500" />)}</h3>
            {issues.length === 0 ? <p className="text-sm text-slate-500">Press Validate to check Hindi script, placeholders, options and references.</p> : (
              <ul className="space-y-1.5 text-sm">
                {issues.map((i, n) => (
                  <li key={n} className={i.level === 'error' ? 'text-rose-600' : 'text-amber-600'}><code className="text-xs">{i.path || 'item'}</code> — {i.message}</li>
                ))}
              </ul>
            )}
          </div>
        </aside>
      </div>
    </>
  );
}
