const BASE = `${import.meta.env.VITE_API_URL || ''}/api/v1`;
const KEY = 'lab-console-token';

export const tokenStore = {
  get: () => { try { return localStorage.getItem(KEY); } catch { return null; } },
  set: (t: string) => { try { localStorage.setItem(KEY, t); } catch { /* ignore */ } },
  clear: () => { try { localStorage.removeItem(KEY); } catch { /* ignore */ } },
};

export class ApiError extends Error {
  constructor(public status: number, message: string, public details?: unknown) { super(message); }
}

export async function api<T = any>(path: string, opts: { method?: string; body?: unknown } = {}): Promise<T> {
  const token = tokenStore.get();
  const res = await fetch(BASE + path, {
    method: opts.method || 'GET',
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
  });
  if (res.status === 401 && !path.startsWith('/auth/login')) {
    tokenStore.clear();
    window.dispatchEvent(new Event('lab-console-logout'));
  }
  const text = await res.text();
  const json = text ? JSON.parse(text) : null;
  if (!res.ok) throw new ApiError(res.status, json?.error || res.statusText, json?.details);
  return json as T;
}

export async function download(path: string, filename: string) {
  const res = await fetch(BASE + path, { headers: { Authorization: `Bearer ${tokenStore.get()}` } });
  if (!res.ok) throw new ApiError(res.status, 'Download failed');
  const url = URL.createObjectURL(await res.blob());
  const a = document.createElement('a');
  a.href = url; a.download = filename; a.click();
  URL.revokeObjectURL(url);
}

export type Role = 'admin' | 'editor' | 'reviewer';
export type Review = 'draft' | 'needsReview' | 'sourceChecked' | 'verified';
export interface Me { id: string; name: string; email: string; role: Role; picture?: string }
export interface ContentRow {
  _id: string; type: string; itemId: string; title: string; review: Review; boardId?: string;
  classLevel?: number; chapterId?: string; topicId?: string; updatedAt: string;
}
export interface Issue { level: 'error' | 'warning'; path: string; message: string }

export const CONTENT_TYPES = [
  { id: 'question', label: 'Questions' },
  { id: 'pyq', label: 'PYQs' },
  { id: 'note', label: 'Notes' },
  { id: 'concept', label: 'Concepts' },
  { id: 'chemical', label: 'Chemicals' },
  { id: 'reaction', label: 'Lab reactions' },
  { id: 'reagent', label: 'Reagents' },
  { id: 'guide', label: 'Practical guides' },
  { id: 'syllabus', label: 'Syllabus' },
  { id: 'manifest', label: 'Manifests' },
  { id: 'board', label: 'Boards' },
] as const;
