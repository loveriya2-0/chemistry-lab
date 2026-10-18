import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { Download, IndianRupee, ShoppingCart, Undo2 } from 'lucide-react';
import { api, download } from '../api';
import { useAuth } from '../auth';
import { Badge, Empty, PageHeader, Pager, Spinner, Stat, inr, useToast, when } from '../ui';
import { axis } from './Dashboard';

const STATE_STYLE: Record<string, string> = {
  valid: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-500/20 dark:text-emerald-300',
  pending: 'bg-amber-100 text-amber-700 dark:bg-amber-500/20 dark:text-amber-300',
  refunded: 'bg-rose-100 text-rose-700 dark:bg-rose-500/20 dark:text-rose-300',
  invalid: 'bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-300',
};

export default function Revenue() {
  const [page, setPage] = useState(1);
  const [state, setState] = useState('');
  const [days, setDays] = useState(30);
  const { can } = useAuth();
  const qc = useQueryClient();
  const toast = useToast();
  const overview = useQuery({ queryKey: ['overview'], queryFn: () => api('/stats/overview') });
  const series = useQuery({ queryKey: ['revenue', days], queryFn: () => api<any[]>(`/stats/revenue?days=${days}`) });
  const orders = useQuery({
    queryKey: ['purchases', page, state],
    queryFn: () => api<any>(`/purchases?page=${page}${state ? `&state=${state}` : ''}`), placeholderData: (p) => p,
  });
  const change = useMutation({
    mutationFn: ({ id, s }: { id: string; s: string }) => api(`/purchases/${encodeURIComponent(id)}`, { method: 'PATCH', body: { state: s } }),
    onSuccess: () => { toast('ok', 'Order updated'); qc.invalidateQueries({ queryKey: ['purchases'] }); qc.invalidateQueries({ queryKey: ['overview'] }); qc.invalidateQueries({ queryKey: ['revenue'] }); },
    onError: (e: Error) => toast('err', e.message),
  });
  const o = overview.data;

  return (
    <>
      <PageHeader title="Premium & revenue" subtitle="₹99 lifetime Premium purchases recorded from Google Play verification"
        actions={<button className="btn-ghost" onClick={() => download('/purchases/export.csv', 'purchases.csv').catch((e) => toast('err', e.message))}><Download size={16} />Export CSV</button>} />

      {o && (
        <div className="grid gap-4 sm:grid-cols-3">
          <Stat label="Total revenue" value={inr(o.revenueInr)} icon={<IndianRupee size={20} />} tone="green" />
          <Stat label="Orders" value={o.orders} hint={`${o.conversionPct}% of installs`} icon={<ShoppingCart size={20} />} />
          <Stat label="Refunds" value={o.refunds} icon={<Undo2 size={20} />} tone="rose" />
        </div>
      )}

      <div className="card mt-4 p-5">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="font-medium">Daily revenue</h2>
          <select className="input w-auto" value={days} onChange={(e) => setDays(Number(e.target.value))} aria-label="Range">
            {[7, 30, 90, 180].map((d) => <option key={d} value={d}>Last {d} days</option>)}
          </select>
        </div>
        <div className="h-64">
          <ResponsiveContainer>
            <BarChart data={series.data || []}>
              <CartesianGrid strokeDasharray="3 3" stroke="#94a3b8" strokeOpacity={0.2} />
              <XAxis dataKey="date" tickFormatter={(d) => d.slice(5)} {...axis} />
              <YAxis allowDecimals={false} {...axis} />
              <Tooltip formatter={(v: number) => inr(v)} />
              <Bar dataKey="revenue" name="Revenue" fill="#6366f1" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div className="card mt-4">
        <div className="flex items-center justify-between border-b border-slate-200 p-3 dark:border-slate-800">
          <h2 className="px-1 font-medium">Orders</h2>
          <select className="input w-auto" value={state} onChange={(e) => { setState(e.target.value); setPage(1); }} aria-label="State">
            <option value="">All</option>{['valid', 'pending', 'refunded', 'invalid'].map((s) => <option key={s}>{s}</option>)}
          </select>
        </div>
        {orders.isLoading ? <Spinner /> : !orders.data?.items.length ? <Empty>No orders yet. They appear once verifyPurchase reports to this API.</Empty> : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="border-b border-slate-200 dark:border-slate-800"><tr><th className="th">Order</th><th className="th">Date</th><th className="th">Amount</th><th className="th">State</th><th className="th" /></tr></thead>
              <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                {orders.data.items.map((p: any) => (
                  <tr key={p._id}>
                    <td className="td font-mono text-xs">{p.orderId}</td>
                    <td className="td">{when(p.purchasedAt)}</td>
                    <td className="td">{inr(p.amountInr)}</td>
                    <td className="td"><Badge className={STATE_STYLE[p.state]}>{p.state}</Badge></td>
                    <td className="td text-right">
                      {can() && p.state === 'valid' && <button className="btn-ghost !py-1 text-xs" onClick={() => confirm(`Mark ${p.orderId} refunded?`) && change.mutate({ id: p.orderId, s: 'refunded' })}>Mark refunded</button>}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        <Pager page={page} pages={orders.data?.pages || 1} onPage={setPage} />
      </div>
    </>
  );
}
