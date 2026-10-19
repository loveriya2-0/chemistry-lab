import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { Area, AreaChart, CartesianGrid, Cell, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { Activity, BadgeCheck, ClipboardCheck, Crown, IndianRupee, MessageSquare, Smartphone, Undo2 } from 'lucide-react';
import { api, type Review } from '../api';
import { useAuth } from '../auth';
import { PageHeader, Stat, Spinner, REVIEW_COLOR, REVIEW_LABEL, inr, when, Empty } from '../ui';

export const axis = { stroke: '#94a3b8', fontSize: 12 };

export default function Dashboard() {
  const { can } = useAuth();
  // One request instead of five: each API call opens its own DB connection.
  const dash = useQuery({ queryKey: ['overview', 'dashboard'], queryFn: () => api('/stats/dashboard?days=30') });

  if (dash.isLoading) return <Spinner />;
  const d = dash.data;
  const o = d.overview;
  const revenue = { data: d.revenue as any[] | null };
  const users = { data: d.users };
  const coverage = { data: d.coverage };
  const audit = { data: d.audit as any[] | null };
  const review = Object.entries(o.contentByReview as Record<string, number>).map(([k, v]) => ({ name: REVIEW_LABEL[k as Review] ?? k, key: k, value: v }));
  const totalContent = review.reduce((a, r) => a + r.value, 0);

  return (
    <>
      <PageHeader title="Dashboard" subtitle="Overview of content, users and Premium sales" />

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <Stat label="Installs" value={o.installs.toLocaleString('en-IN')} hint={`${o.activeUsers1d} active today`} icon={<Smartphone size={20} />} />
        <Stat label="Active users (7d)" value={o.activeUsers7d.toLocaleString('en-IN')} icon={<Activity size={20} />} tone="sky" />
        <Stat label="Premium users" value={o.premiumUsers} hint={`${o.conversionPct}% conversion`} icon={<Crown size={20} />} tone="amber" />
        <Stat label="Revenue" value={inr(o.revenueInr)} hint={`${o.orders} orders · ${o.refunds} refunds`} icon={<IndianRupee size={20} />} tone="green" />
      </div>

      <div className="mt-4 grid gap-4 lg:grid-cols-3">
        <div className="card p-5 lg:col-span-2">
          <h2 className="card-title mb-4">Revenue — last 30 days</h2>
          {can('editor') ? (
            <div className="h-64">
              <ResponsiveContainer>
                <AreaChart data={revenue.data || []}>
                  <defs><linearGradient id="rev" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor="#6463f2" stopOpacity={0.35} /><stop offset="100%" stopColor="#6463f2" stopOpacity={0} /></linearGradient></defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="#94a3b8" strokeOpacity={0.2} />
                  <XAxis dataKey="date" tickFormatter={(d) => d.slice(5)} {...axis} />
                  <YAxis allowDecimals={false} {...axis} />
                  <Tooltip formatter={(v: number) => inr(v)} />
                  <Area dataKey="revenue" name="Revenue" stroke="#6463f2" strokeWidth={2} fill="url(#rev)" />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          ) : <Empty>Revenue is visible to editors and admins.</Empty>}
        </div>

        <div className="card p-5">
          <h2 className="card-title mb-2">Content review status</h2>
          <div className="h-48">
            <ResponsiveContainer>
              <PieChart>
                <Pie data={review} dataKey="value" nameKey="name" innerRadius={50} outerRadius={78} paddingAngle={2}>
                  {review.map((r) => <Cell key={r.key} fill={REVIEW_COLOR[r.key as Review] || '#94a3b8'} />)}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </div>
          <ul className="mt-2 space-y-1 text-sm">
            {review.map((r) => (
              <li key={r.key} className="flex items-center justify-between">
                <span className="flex items-center gap-2"><i className="h-2.5 w-2.5 rounded-full" style={{ background: REVIEW_COLOR[r.key as Review] }} />{r.name}</span>
                <span className="tabular-nums text-slate-500">{r.value} ({totalContent ? Math.round((r.value / totalContent) * 100) : 0}%)</span>
              </li>
            ))}
          </ul>
        </div>
      </div>

      <div className="mt-4 grid gap-4 lg:grid-cols-3">
        <div className="card p-5 lg:col-span-2">
          <h2 className="card-title mb-4">New installs — last 30 days</h2>
          <div className="h-56">
            <ResponsiveContainer>
              <AreaChart data={users.data?.growth || []}>
                <CartesianGrid strokeDasharray="3 3" stroke="#94a3b8" strokeOpacity={0.2} />
                <XAxis dataKey="date" tickFormatter={(d) => d.slice(5)} {...axis} />
                <YAxis allowDecimals={false} {...axis} />
                <Tooltip />
                <Area dataKey="installs" name="Installs" stroke="#0ea5e9" strokeWidth={2} fill="#0ea5e9" fillOpacity={0.15} />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="card p-5">
          <h2 className="card-title mb-3">Needs attention</h2>
          <ul className="space-y-2 text-sm">
            <Task to="/review" icon={<ClipboardCheck size={16} />} label="Items waiting for review" n={o.pendingReview} />
            <Task to="/feedback" icon={<MessageSquare size={16} />} label="New feedback" n={o.openFeedback} />
            <Task to="/content/question" icon={<BadgeCheck size={16} />} label="Topics below question target" n={coverage.data?.belowTarget ?? 0} />
            <Task to="/revenue" icon={<Undo2 size={16} />} label="Refunded orders" n={o.refunds} />
          </ul>
          <div className="mt-4 flex flex-wrap gap-2">
            <Link to="/content/question/new" className="btn-primary">New question</Link>
            <Link to="/announcements" className="btn-ghost">Announce</Link>
          </div>
        </div>
      </div>

      <div className="mt-4 grid gap-4 lg:grid-cols-2">
        <div className="card p-5">
          <h2 className="card-title mb-3">Question coverage (target {coverage.data?.target ?? 10}/topic)</h2>
          <p className="mb-3 text-sm text-slate-500">{coverage.data?.totalQuestions ?? 0} questions across {coverage.data?.topics.length ?? 0} topics</p>
          <ul className="max-h-60 space-y-2 overflow-auto pr-1">
            {(coverage.data?.topics || []).filter((t: any) => t.missing > 0).slice(0, 12).map((t: any) => (
              <li key={t.topicId} className="text-sm">
                <div className="flex justify-between"><span className="truncate">{t.topicId}</span><span className="text-slate-500">{t.count}/{coverage.data.target}</span></div>
                <div className="mt-1 h-1.5 rounded-full bg-slate-100 dark:bg-slate-800"><div className="h-full rounded-full bg-gradient-to-r from-amber-400 to-orange-500" style={{ width: `${(t.count / coverage.data.target) * 100}%` }} /></div>
              </li>
            ))}
            {coverage.data && coverage.data.belowTarget === 0 && <Empty>Every topic meets the target 🎉</Empty>}
          </ul>
        </div>

        <div className="card p-5">
          <h2 className="card-title mb-3">Recent activity</h2>
          {!can('editor', 'reviewer') ? <Empty>No access</Empty> : (
            <ul className="divide-y divide-slate-100 dark:divide-slate-800">
              {(audit.data || []).map((a) => (
                <li key={a._id} className="py-2 text-sm">
                  <p>{a.summary}</p>
                  <p className="text-xs text-slate-500">{a.actorEmail} · {when(a.createdAt)}</p>
                </li>
              ))}
              {audit.data?.length === 0 && <Empty>No activity yet</Empty>}
            </ul>
          )}
        </div>
      </div>
    </>
  );
}

function Task({ to, icon, label, n }: { to: string; icon: React.ReactNode; label: string; n: number }) {
  return (
    <li>
      <Link to={to} className="flex items-center justify-between rounded-lg px-2 py-2 transition hover:bg-slate-50 dark:hover:bg-white/5">
        <span className="flex items-center gap-2 text-slate-600 dark:text-slate-300">{icon}{label}</span>
        <span className={`rounded-full px-2 py-0.5 text-xs font-semibold ${n > 0 ? 'bg-amber-100 text-amber-700 dark:bg-amber-500/20 dark:text-amber-300' : 'bg-slate-100 text-slate-500 dark:bg-slate-800'}`}>{n}</span>
      </Link>
    </li>
  );
}
