import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import { CONTENT_TYPES } from '../config.js';
import { AppConfig, AppUser, Announcement, ContentItem, Event, Feedback, Purchase } from '../models/index.js';
import { HttpError, wrap, requireInternalSecret } from '../middleware.js';

// Endpoints used by the Flutter app (no console login). Content is read-only
// and limited to reviewed items, matching what the app already shows.
const r = Router();
r.use(rateLimit({ windowMs: 60_000, limit: 120, standardHeaders: true, legacyHeaders: false }));

const SHOWN = ['sourceChecked', 'verified'];

r.get('/content/:type', wrap(async (req, res) => {
  const { type } = req.params;
  if (!CONTENT_TYPES.includes(type)) throw new HttpError(404, 'Unknown type');
  const filter = { type, review: { $in: SHOWN } };
  if (req.query.since) filter.updatedAt = { $gt: new Date(String(req.query.since)) };
  if (req.query.boardId) filter.boardId = String(req.query.boardId);
  if (req.query.classLevel) filter.classLevel = Number(req.query.classLevel);
  const docs = await ContentItem.find(filter).select('data hiSrc').lean();
  // File-level Hindi provenance the app applies to texts that do not set their own.
  const hiSrc = Object.fromEntries(docs.filter((d) => d.hiSrc).map((d) => [d.data.id, d.hiSrc]));
  res.json({ serverTime: new Date().toISOString(), items: docs.map((d) => d.data), hiSrc });
}));

r.get('/config', wrap(async (_req, res) => {
  const [cfg, announcements] = await Promise.all([
    AppConfig.findOneAndUpdate({ key: 'main' }, { $setOnInsert: { key: 'main' } }, { upsert: true, new: true }).lean(),
    Announcement.find({
      active: true,
      $and: [
        { $or: [{ startsAt: null }, { startsAt: { $lte: new Date() } }] },
        { $or: [{ endsAt: null }, { endsAt: { $gte: new Date() } }] },
      ],
    }).sort({ createdAt: -1 }).limit(5).select('title body kind').lean(),
  ]);
  res.json({ ...cfg, announcements });
}));

const installSchema = z.object({
  installId: z.string().min(8).max(64),
  boardId: z.string().max(40).optional(), classLevel: z.number().int().min(1).max(12).optional(),
  language: z.string().max(8).optional(), appVersion: z.string().max(20).optional(),
  platform: z.string().max(20).optional(), premium: z.boolean().optional(),
});
r.post('/install', wrap(async (req, res) => {
  const { installId, ...rest } = installSchema.parse(req.body);
  await AppUser.updateOne({ installId }, { $set: { ...rest, lastSeenAt: new Date() }, $setOnInsert: { firstSeenAt: new Date() } }, { upsert: true });
  res.json({ ok: true });
}));

const eventSchema = z.object({
  installId: z.string().min(8).max(64),
  events: z.array(z.object({
    name: z.enum(['quiz_attempt', 'session', 'practical_done', 'ai_tutor']),
    topicId: z.string().max(80).optional(), chapterId: z.string().max(80).optional(),
    correct: z.boolean().optional(), value: z.number().optional(), at: z.coerce.date().optional(),
  })).min(1).max(100),
});
r.post('/events', wrap(async (req, res) => {
  const { installId, events } = eventSchema.parse(req.body);
  await Event.insertMany(events.map((e) => ({ ...e, installId })));
  await AppUser.updateOne({ installId }, { $set: { lastSeenAt: new Date() } }, { upsert: true });
  res.json({ ok: true });
}));

r.post('/feedback', rateLimit({ windowMs: 3600_000, limit: 10 }), wrap(async (req, res) => {
  const b = z.object({
    installId: z.string().max(64).optional(), kind: z.enum(['bug', 'content', 'idea', 'other']).default('other'),
    message: z.string().min(3).max(4000), contentRef: z.string().max(120).optional(), appVersion: z.string().max(20).optional(),
  }).parse(req.body);
  await Feedback.create(b);
  res.status(201).json({ ok: true });
}));

// Called server-to-server by verifyPurchase after Google Play confirms a purchase.
export const internal = Router();
internal.post('/purchases', requireInternalSecret, wrap(async (req, res) => {
  const b = z.object({
    orderId: z.string().min(3), installId: z.string().optional(), productId: z.string().default('premium_lifetime'),
    state: z.enum(['valid', 'pending', 'refunded', 'invalid']).default('valid'), amountInr: z.number().default(99),
  }).parse(req.body);
  const p = await Purchase.findOneAndUpdate({ orderId: b.orderId }, { $set: { ...b, ...(b.state === 'refunded' ? { voidedAt: new Date() } : {}) } }, { upsert: true, new: true });
  if (b.installId) await AppUser.updateOne({ installId: b.installId }, { premium: b.state === 'valid' });
  res.json({ ok: true, state: p.state });
}));

export default r;
