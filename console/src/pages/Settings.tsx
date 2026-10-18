import { useEffect, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Plus, Trash2 } from 'lucide-react';
import { api } from '../api';
import { useAuth } from '../auth';
import { PageHeader, Spinner, useToast } from '../ui';

export default function Settings() {
  const qc = useQueryClient();
  const toast = useToast();
  const { can } = useAuth();
  const q = useQuery({ queryKey: ['config'], queryFn: () => api<any>('/config') });
  const [c, setC] = useState<any>(null);
  const [flag, setFlag] = useState('');
  useEffect(() => { if (q.data) setC({ ...q.data, flags: q.data.flags || {} }); }, [q.data]);
  const save = useMutation({
    mutationFn: () => api('/config', { method: 'PUT', body: {
      minAppVersion: c.minAppVersion, maintenanceMode: c.maintenanceMode, premiumPriceText: c.premiumPriceText,
      aiTutorEnabled: c.aiTutorEnabled, aiTutorDailyLimit: c.aiTutorDailyLimit, flags: c.flags,
    } }),
    onSuccess: () => { toast('ok', 'Config saved'); qc.invalidateQueries({ queryKey: ['config'] }); },
    onError: (e: Error) => toast('err', e.message),
  });
  if (!c) return <Spinner />;
  const ro = !can();
  const set = (k: string, v: unknown) => setC({ ...c, [k]: v });

  return (
    <>
      <PageHeader title="App config" subtitle="Remote settings and feature flags the app reads on launch"
        actions={!ro && <button className="btn-primary" onClick={() => save.mutate()} disabled={save.isPending}>Save changes</button>} />
      <fieldset disabled={ro} className="grid gap-4 lg:grid-cols-2">
        <div className="card space-y-4 p-5">
          <h2 className="font-medium">General</h2>
          <label className="block text-sm font-medium">Minimum app version
            <input className="input mt-1" pattern="\d+\.\d+\.\d+" value={c.minAppVersion} onChange={(e) => set('minAppVersion', e.target.value)} />
            <span className="text-xs font-normal text-slate-500">Older versions are asked to update.</span></label>
          <label className="block text-sm font-medium">Premium price label
            <input className="input mt-1" maxLength={20} value={c.premiumPriceText} onChange={(e) => set('premiumPriceText', e.target.value)} /></label>
          <label className="flex items-center gap-2 text-sm font-medium"><input type="checkbox" checked={c.maintenanceMode} onChange={(e) => set('maintenanceMode', e.target.checked)} />Maintenance mode</label>
        </div>
        <div className="card space-y-4 p-5">
          <h2 className="font-medium">AI tutor</h2>
          <label className="flex items-center gap-2 text-sm font-medium"><input type="checkbox" checked={c.aiTutorEnabled} onChange={(e) => set('aiTutorEnabled', e.target.checked)} />Enabled</label>
          <label className="block text-sm font-medium">Daily questions per user
            <input className="input mt-1 max-w-40" type="number" min={0} max={1000} value={c.aiTutorDailyLimit} onChange={(e) => set('aiTutorDailyLimit', Number(e.target.value))} /></label>
        </div>
        <div className="card space-y-3 p-5 lg:col-span-2">
          <h2 className="font-medium">Feature flags</h2>
          {Object.entries(c.flags as Record<string, boolean>).map(([k, v]) => (
            <div key={k} className="flex items-center gap-3">
              <label className="flex flex-1 items-center gap-2 text-sm"><input type="checkbox" checked={v} onChange={(e) => set('flags', { ...c.flags, [k]: e.target.checked })} /><code>{k}</code></label>
              <button aria-label="Remove flag" className="text-slate-400 hover:text-rose-600" onClick={() => { const f = { ...c.flags }; delete f[k]; set('flags', f); }}><Trash2 size={15} /></button>
            </div>
          ))}
          <div className="flex gap-2">
            <input className="input max-w-64" placeholder="new_flag_name" value={flag} onChange={(e) => setFlag(e.target.value.replace(/[^a-z0-9_]/gi, '_'))} />
            <button type="button" className="btn-ghost" disabled={!flag} onClick={() => { set('flags', { ...c.flags, [flag]: false }); setFlag(''); }}><Plus size={15} />Add flag</button>
          </div>
        </div>
      </fieldset>
      {ro && <p className="mt-3 text-sm text-slate-500">Only admins can change app config.</p>}
    </>
  );
}
