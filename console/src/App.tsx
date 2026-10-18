import { Navigate, Route, Routes } from 'react-router-dom';
import { useAuth } from './auth';
import Layout from './Layout';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import ContentList from './pages/ContentList';
import ContentEditor from './pages/ContentEditor';
import ReviewQueue from './pages/ReviewQueue';
import Revenue from './pages/Revenue';
import Analytics from './pages/Analytics';
import Announcements from './pages/Announcements';
import Feedback from './pages/Feedback';
import Settings from './pages/Settings';
import Team from './pages/Team';
import Audit from './pages/Audit';
import { Spinner } from './ui';

export default function App() {
  const { user, loading } = useAuth();
  if (loading) return <Spinner />;
  if (!user) return <Login />;
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<Dashboard />} />
        <Route path="content" element={<Navigate to="/content/question" replace />} />
        <Route path="content/:type" element={<ContentList />} />
        <Route path="content/:type/new" element={<ContentEditor />} />
        <Route path="content/:type/:itemId" element={<ContentEditor />} />
        <Route path="review" element={<ReviewQueue />} />
        <Route path="revenue" element={<Revenue />} />
        <Route path="analytics" element={<Analytics />} />
        <Route path="announcements" element={<Announcements />} />
        <Route path="feedback" element={<Feedback />} />
        <Route path="settings" element={<Settings />} />
        <Route path="team" element={<Team />} />
        <Route path="audit" element={<Audit />} />
        <Route path="*" element={<div className="p-10 text-center text-slate-500">Page not found</div>} />
      </Route>
    </Routes>
  );
}
