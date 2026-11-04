import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import { config } from './config.js';
import { errorHandler, requireAuth } from './middleware.js';
import auth from './routes/auth.js';
import content from './routes/content.js';
import admin from './routes/admin.js';
import publicRoutes, { internal } from './routes/public.js';

export function createApp() {
  const app = express();
  app.disable('x-powered-by');
  app.use(helmet());
  // maxAge lets browsers cache the preflight instead of sending OPTIONS before every call.
  app.use(cors({ origin: config.corsOrigins, maxAge: 86400 }));
  app.use(express.json({ limit: '5mb' }));

  app.get('/health', (_req, res) => res.json({ ok: true }));

  const v1 = express.Router();
  v1.use(['/auth/login', '/auth/google'], rateLimit({ windowMs: 15 * 60_000, limit: 20, standardHeaders: true, legacyHeaders: false }));
  v1.use('/auth', auth);
  v1.use('/public', publicRoutes);
  v1.use('/internal', internal);
  v1.use('/content', requireAuth, content);
  v1.use('/', requireAuth, admin);
  app.use('/api/v1', v1);

  app.use((_req, res) => res.status(404).json({ error: 'Not found' }));
  app.use(errorHandler);
  return app;
}
