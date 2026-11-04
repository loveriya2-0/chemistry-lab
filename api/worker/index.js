import { httpServerHandler } from 'cloudflare:node';
import mongoose from 'mongoose';
import { config } from '../src/config.js';

// The Express app runs unchanged inside the Worker. A Worker can't reuse a
// socket opened by another request, so each request opens its own MongoDB
// connection and closes it when done. Mongoose has one global connection,
// so requests in the same isolate take turns (Cloudflare spreads load
// across isolates).
const PORT = 4000;
const handler = httpServerHandler({ port: PORT });
let started;
let queue = Promise.resolve();

// Loaded on the first request: the rate limiters start timers, which Workers
// don't allow at global scope.
async function startServer() {
  const { createApp } = await import('../src/app.js');
  const app = createApp();
  // Client IP arrives as X-Forwarded-For (set below from CF-Connecting-IP).
  app.set('trust proxy', 1);
  app.listen(PORT);
}

async function serve(request, env, ctx) {
  await (started ??= startServer());
  const headers = new Headers(request.headers);
  headers.set('x-forwarded-for', request.headers.get('cf-connecting-ip') || '127.0.0.1');
  const req = new Request(request, { headers });
  if (!needsDb(request)) return handler.fetch(req, env, ctx);
  await mongoose.connect(config.mongoUri, { serverSelectionTimeoutMS: 8000, maxPoolSize: 1 });
  try {
    const res = await handler.fetch(req, env, ctx);
    // Read the whole body before the connection closes.
    return new Response(await res.arrayBuffer(), res);
  } finally {
    await mongoose.disconnect();
  }
}

// CORS preflights and DB-free routes skip the MongoDB round trip.
const NO_DB = new Set(['/health', '/api/v1/auth/config']);
function needsDb(request) {
  return request.method !== 'OPTIONS' && !NO_DB.has(new URL(request.url).pathname);
}

export default {
  fetch(request, env, ctx) {
    // Not queued: these never touch the shared mongoose connection.
    if (!needsDb(request)) return serve(request, env, ctx);
    const run = queue.then(() => serve(request, env, ctx));
    queue = run.catch(() => {});
    return run;
  },
};

