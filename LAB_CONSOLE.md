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

## Flutter app connection
Build the app with `--dart-define=CONTENT_API_URL=https://your-api` (empty = fully offline, as before).
- On launch the app sends an anonymous install ping and downloads reviewed content (`lib/sync/remote_content.dart`), cached in SharedPreferences.
- `ContentRepository` merges the cache over the bundled JSON: console items replace bundled ones with the same id, and new items are added. The merge happens at the next launch, so a screen never changes while being read. Offline or a bad cache → bundled content.
- Limitation: un-publishing an item in the console does not hide a bundled copy until the next app release.
- Purchases: set `CONSOLE_API_URL` and `CONSOLE_INTERNAL_SECRET` (same value as the API's `INTERNAL_SECRET`) on the `verifyPurchase` function and it reports orders and refunds to the console. Test purchases are skipped.

## Not done yet
- The app does not send quiz/session events yet, so weak-topic and DAU charts stay empty (the `/public/events` endpoint is ready).
- AI tutor proxy endpoint (usage stats and limits are in place, the proxy itself is not).
