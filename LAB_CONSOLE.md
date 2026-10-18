# Lab Console

Admin dashboard for Virtual Chemistry Lab. Backend and frontend are separate projects.

| Folder | What | Stack |
|---|---|---|
| `api/` | REST API (`/api/v1`) | Node 20+, Express, Mongoose, Zod, JWT |
| `console/` | Admin web app | React, Vite, TypeScript, Tailwind, TanStack Query, Recharts |

## Quick look (no MongoDB needed)
```
cd api && npm install && npm run dev:mem     # in-memory DB, seeded, http://localhost:4000
cd console && npm install && npm run dev     # http://localhost:5173
```
Login: `admin@lab.local` / `Admin12345` (data is lost when the API stops).

## Real setup (MongoDB)
1. `cd api && cp .env.example .env` — set `MONGODB_URI`, `JWT_SECRET`, `INTERNAL_SECRET`, `ADMIN_EMAIL`, `ADMIN_PASSWORD`.
2. `npm run seed` — imports `assets/content/**` into MongoDB (safe to re-run; upserts).
3. `npm run create-admin`, then `npm run dev`.
4. Console: `cd console && npm run dev`. For production set `VITE_API_URL` and `CORS_ORIGINS`.

## What is in the console
- **Dashboard** — installs, active users, Premium, revenue, review-status chart, question coverage per topic, recent activity.
- **Content** — questions, PYQs, notes, concepts, chemicals, lab reactions, reagents, practical guides, syllabus, boards. English/Hindi side-by-side editor, raw JSON tab, validator (Devanagari Hindi, placeholders, MCQ options, unknown ids), bulk status change, JSON import/export in the app's exact format.
- **Review queue** — needs review → source checked → verified. Only source checked / verified items are served to the app.
- **Premium & revenue** — orders, daily revenue, refunds, CSV export.
- **Users & analytics** — DAU, board/class/app-version split, weakest topics, AI tutor usage.
- **Announcements, Feedback inbox, App config & feature flags, Team (roles), Audit log.**

Roles: `admin` (all), `editor` (content, announcements, feedback, revenue view), `reviewer` (review/verify).

## App-facing endpoints (for the Flutter app, not yet wired)
- `GET  /api/v1/public/content/:type?since=` — reviewed content only
- `GET  /api/v1/public/config` — min version, maintenance, flags, announcements
- `POST /api/v1/public/install`, `/events`, `/feedback`
- `POST /api/v1/internal/purchases` (header `x-internal-secret`) — call from `server/functions` after Google Play verification

## Not done yet
- Flutter app still reads bundled JSON; remote content sync, event reporting and the `verifyPurchase` → `/internal/purchases` call are the next phase.
- AI tutor proxy endpoint (usage stats and limits are in place, the proxy itself is not).
