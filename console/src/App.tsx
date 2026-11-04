import { lazy } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import { useAuth } from './auth';
import Layout from './Layout';
import Login from './pages/Login';
import { Spinner } from './ui';

const Dashboard = lazy(() => import('./pages/Dashboard'));
const ContentList = lazy(() => import('./pages/ContentList'));
const ContentEditor = lazy(() => import('./pages/ContentEditor'));
const ReviewQueue = lazy(() => import('./pages/ReviewQueue'));
const Revenue = lazy(() => import('./pages/Revenue'));
const Analytics = lazy(() => import('./pages/Analytics'));
const Announcements = lazy(() => import('./pages/Announcements'));
const Feedback = lazy(() => import('./pages/Feedback'));
const Settings = lazy(() => import('./pages/Settings'));
const Team = lazy(() => import('./pages/Team'));
const Audit = lazy(() => import('./pages/Audit'));

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
