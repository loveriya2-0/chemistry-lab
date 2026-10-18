import { useQuery } from '@tanstack/react-query';
import { Bar, BarChart, CartesianGrid, Cell, Line, LineChart, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { api } from '../api';
import { Empty, PageHeader, Spinner } from '../ui';
import { axis } from './Dashboard';

const PALETTE = ['#6366f1', '#0ea5e9', '#10b981', '#f59e0b', '#ec4899', '#8b5cf6', '#64748b'];

function Donut({ title, data }: { title: string; data: { name: string; value: number }[] }) {
  return (
    <div className="card p-5">
      <h2 className="mb-2 font-medium">{title}</h2>
      {!data.length ? <Empty>No data yet</Empty> : (
        <>
          <div className="h-44"><ResponsiveContainer><PieChart>
            <Pie data={data} dataKey="value" nameKey="name" innerRadius={42} outerRadius={70} paddingAngle={2}>{data.map((_, i) => <Cell key={i} fill={PALETTE[i % PALETTE.length]} />)}</Pie>
            <Tooltip />
          </PieChart></ResponsiveContainer></div>
          <ul className="mt-2 space-y-1 text-sm">{data.slice(0, 6).map((d, i) => (
            <li key={d.name} className="flex justify-between"><span className="flex items-center gap-2"><i className="h-2.5 w-2.5 rounded-full" style={{ background: PALETTE[i % PALETTE.length] }} />{d.name}</span><span className="tabular-nums text-slate-500">{d.value}</span></li>
          ))}</ul>
        </>
      )}
    </div>
  );
}

export default function Analytics() {
  const users = useQuery({ queryKey: ['users', 30], queryFn: () => api('/stats/users?days=30') });
  const learning = useQuery({ queryKey: ['learning'], queryFn: () => api('/stats/learning') });
  if (users.isLoading) return <Spinner />;
  const u = users.data;
  return (
    <>
      <PageHeader title="Users & analytics" subtitle="Anonymous usage reported by the app (install id only — no personal data)" />
      <div className="card p-5">
        <h2 className="mb-4 font-medium">Daily active users — last 30 days</h2>
        <div className="h-60"><ResponsiveContainer><LineChart data={u.dau}>
          <CartesianGrid strokeDasharray="3 3" stroke="#94a3b8" strokeOpacity={0.2} />
          <XAxis dataKey="date" tickFormatter={(d) => d.slice(5)} {...axis} /><YAxis allowDecimals={false} {...axis} /><Tooltip />
          <Line dataKey="dau" name="Active users" stroke="#10b981" strokeWidth={2} dot={false} />
        </LineChart></ResponsiveContainer></div>
      </div>
      <div className="mt-4 grid gap-4 md:grid-cols-3">
        <Donut title="By board" data={u.byBoard} /><Donut title="By class" data={u.byClass} /><Donut title="App versions" data={u.byVersion} />
      </div>
      <div className="mt-4 grid gap-4 lg:grid-cols-2">
        <div className="card p-5">
          <h2 className="mb-1 font-medium">Weakest topics</h2>
          <p className="mb-3 text-sm text-slate-500">Lowest quiz accuracy (min. 5 attempts) — good candidates for better notes.</p>
          {!learning.data?.weakTopics.length ? <Empty>Needs quiz events from the app.</Empty> : (
            <div style={{ height: learning.data.weakTopics.length * 36 + 20 }}><ResponsiveContainer>
              <BarChart data={learning.data.weakTopics} layout="vertical" margin={{ left: 40 }}>
                <XAxis type="number" domain={[0, 100]} unit="%" {...axis} /><YAxis type="category" dataKey="topicId" width={120} {...axis} /><Tooltip />
                <Bar dataKey="accuracy" name="Accuracy %" fill="#f59e0b" radius={[0, 4, 4, 0]} />
              </BarChart>
            </ResponsiveContainer></div>
          )}
        </div>
        <div className="card p-5">
          <h2 className="mb-4 font-medium">AI tutor requests — last 30 days</h2>
          <div className="h-60"><ResponsiveContainer><BarChart data={learning.data?.aiTutor || []}>
            <CartesianGrid strokeDasharray="3 3" stroke="#94a3b8" strokeOpacity={0.2} />
            <XAxis dataKey="date" tickFormatter={(d) => d.slice(5)} {...axis} /><YAxis allowDecimals={false} {...axis} /><Tooltip />
            <Bar dataKey="requests" name="Requests" fill="#8b5cf6" radius={[4, 4, 0, 0]} />
          </BarChart></ResponsiveContainer></div>
        </div>
      </div>
    </>
  );
}
