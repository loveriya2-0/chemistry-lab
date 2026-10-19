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
Build the app with `--dart-define=CONTENT_API_URL=https://lab-console-api.wearepartnerha.workers.dev` (empty = fully offline, as before).
- On launch the app sends an anonymous install ping and downloads reviewed content (`lib/sync/remote_content.dart`), cached in SharedPreferences.
- `ContentRepository` merges the cache over the bundled JSON: console items replace bundled ones with the same id, and new items are added. The merge happens at the next launch, so a screen never changes while being read. Offline or a bad cache → bundled content.
- Limitation: un-publishing an item in the console does not hide a bundled copy until the next app release.
- Purchases: set `CONSOLE_API_URL` and `CONSOLE_INTERNAL_SECRET` (same value as the API's `INTERNAL_SECRET`) on the `verifyPurchase` function and it reports orders and refunds to the console. Test purchases are skipped.

## Not done yet
- The app does not send quiz/session events yet, so weak-topic and DAU charts stay empty (the `/public/events` endpoint is ready).
- AI tutor proxy endpoint (usage stats and limits are in place, the proxy itself is not).

## Hosting on Cloudflare
- **Console** (static): project root `console`, build `npm run build`, deploy `npx wrangler deploy`, build variable `VITE_API_URL=<api url>`.
- **API** (Workers Free plan, no Docker): project root `api`, deploy `npx wrangler deploy` → `https://lab-console-api.wearepartnerha.workers.dev`. `api/worker/index.js` runs the Express app directly in the Worker (`nodejs_compat`); `CORS_ORIGINS` is a var in `api/wrangler.jsonc`.
  1. Create a free MongoDB Atlas cluster; allow access from anywhere (`0.0.0.0/0`) since Worker IPs are not fixed.
  2. Set Worker secrets with `npx wrangler secret put NAME`: `MONGODB_URI`, `JWT_SECRET`, `INTERNAL_SECRET`, optionally `GOOGLE_CLIENT_ID`.
  3. Once from your computer with `MONGODB_URI` in `api/.env`: `npm run seed` and `npm run create-admin`.
- Each request opens its own MongoDB connection (Workers can't share sockets between requests), so expect ~100–300 ms extra per request.
- Local Worker test: put `MONGODB_URI`/`JWT_SECRET` in `api/.dev.vars` and run `npx wrangler dev`.

## Continue with Google
Only people an admin has added in **Team** can sign in; Google just proves who they are (email must be verified). Nobody can sign up on their own.
1. [Google Cloud Console](https://console.cloud.google.com/apis/credentials) → Create credentials → **OAuth client ID** → type **Web application** (set up the consent screen first if asked).
2. **Authorized JavaScript origins:** `http://localhost:5173` and the console's production URL (e.g. `https://lab-console.<you>.workers.dev`). No redirect URI is needed.
3. Put the client id in the API's `GOOGLE_CLIENT_ID` (`api/.env` locally; a Worker variable/secret on Cloudflare). The console reads it from the API, so there is nothing to set in `console/`.
4. First admin without a password: set only `ADMIN_EMAIL` and run `npm run create-admin`, then sign in with that Google account. Add others in Team (leave the password empty for Google-only members).
Without `GOOGLE_CLIENT_ID` the button is hidden and email/password works as before.
