import { Plus, Trash2 } from 'lucide-react';

type Json = any;
const isBilingual = (v: Json) =>
  v && typeof v === 'object' && !Array.isArray(v) && typeof v.en === 'string' && Object.keys(v).every((k) => ['en', 'hi', 'hiSrc'].includes(k));
const isPlainObj = (v: Json) => v && typeof v === 'object' && !Array.isArray(v);

// Which fields are shown read-only because changing them would break references.
const LOCKED = new Set(['id']);

interface Props { value: Json; onChange: (v: Json) => void; path?: string; issues?: { path: string; level: string; message: string }[] }

// Generic editor for the app's content JSON: bilingual {en, hi} pairs are shown
// side by side, everything else is rendered by its shape.
export default function JsonForm({ value, onChange, path = '', issues = [] }: Props) {
  const issueFor = (p: string) => issues.filter((i) => i.path === p || i.path === `${p}.hi` || i.path === `${p}.en`);

  if (isBilingual(value)) return <Bilingual value={value} onChange={onChange} issues={issueFor(path)} />;

  if (Array.isArray(value)) {
    const sample = value.find((x) => x !== undefined);
    const blank = () => (typeof sample === 'string' ? '' : typeof sample === 'number' ? 0 : isBilingual(sample) ? { en: '', hi: '' } : isPlainObj(sample) ? blankLike(sample) : '');
    return (
      <div className="space-y-2">
        {value.map((item, i) => (
          <div key={i} className="flex items-start gap-2">
            <span className="mt-2 w-5 shrink-0 text-xs text-slate-400">{i + 1}</span>
            <div className="min-w-0 flex-1 rounded-lg border border-slate-200 p-2 dark:border-slate-800">
              <JsonForm value={item} path={`${path}[${i}]`} issues={issues} onChange={(v) => onChange(value.map((x, j) => (j === i ? v : x)))} />
            </div>
            <button type="button" className="mt-2 text-slate-400 hover:text-rose-600" aria-label="Remove" onClick={() => onChange(value.filter((_, j) => j !== i))}><Trash2 size={15} /></button>
          </div>
        ))}
        <button type="button" className="btn-ghost !py-1 text-xs" onClick={() => onChange([...value, blank()])}><Plus size={13} />Add</button>
      </div>
    );
  }

  if (isPlainObj(value)) {
    return (
      <div className="space-y-4">
        {Object.entries(value).map(([k, v]) => {
          const p = path ? `${path}.${k}` : k;
          return (
            <div key={k}>
              <label className="mb-1 block text-xs font-semibold uppercase tracking-wide text-slate-500">{k}</label>
              <JsonForm value={v} path={p} issues={issues} onChange={(nv) => onChange({ ...value, [k]: nv })} />
              {!isBilingual(v) && issueFor(p).map((i, n) => <Msg key={n} i={i} />)}
              {LOCKED.has(k) && <p className="mt-1 text-xs text-slate-400">Id cannot be changed after creation.</p>}
            </div>
          );
        })}
      </div>
    );
  }

  const locked = LOCKED.has(path);
  if (typeof value === 'boolean') {
    return <input type="checkbox" checked={value} onChange={(e) => onChange(e.target.checked)} />;
  }
  if (typeof value === 'number') {
    return <input className="input max-w-40" type="number" value={value} onChange={(e) => onChange(e.target.value === '' ? 0 : Number(e.target.value))} />;
  }
  const s = value == null ? '' : String(value);
  return s.length > 80 || s.includes('\n')
    ? <textarea className="input min-h-20" value={s} onChange={(e) => onChange(e.target.value)} />
    : <input className="input" value={s} readOnly={locked && s !== ''} disabled={locked && s !== ''} onChange={(e) => onChange(e.target.value)} />;
}

function Bilingual({ value, onChange, issues }: { value: Json; onChange: (v: Json) => void; issues: Props['issues'] }) {
  const long = (value.en?.length || 0) > 70 || (value.hi?.length || 0) > 70;
  const Field = long ? 'textarea' : 'input';
  return (
    <div>
      <div className="grid gap-2 sm:grid-cols-2">
        <div><span className="mb-0.5 block text-[11px] font-medium text-slate-400">English</span>
          <Field className={`input ${long ? 'min-h-24' : ''}`} value={value.en ?? ''} onChange={(e) => onChange({ ...value, en: e.target.value })} /></div>
        <div><span className="mb-0.5 block text-[11px] font-medium text-slate-400">हिन्दी</span>
          <Field lang="hi" className={`input ${long ? 'min-h-24' : ''}`} value={value.hi ?? ''} onChange={(e) => onChange({ ...value, hi: e.target.value })} /></div>
      </div>
      {issues?.map((i, n) => <Msg key={n} i={i} />)}
    </div>
  );
}

const Msg = ({ i }: { i: { level: string; message: string } }) => (
  <p className={`mt-1 text-xs ${i.level === 'error' ? 'text-rose-600' : 'text-amber-600'}`}>{i.message}</p>
);

function blankLike(o: Json): Json {
  if (Array.isArray(o)) return [];
  if (isBilingual(o)) return { en: '', hi: '' };
  if (isPlainObj(o)) return Object.fromEntries(Object.entries(o).map(([k, v]) => [k, blankLike(v)]));
  if (typeof o === 'number') return 0;
  if (typeof o === 'boolean') return false;
  return '';
}
