import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { ROLES, config } from '../config.js';
import {
  Announcement, AppConfig, AppUser, AuditLog, ContentItem, Event, Feedback, Purchase, User,
} from '../models/index.js';
import { HttpError, wrap, requireRole, audit } from '../middleware.js';

const r = Router();
const day = (d) => d.toISOString().slice(0, 10);
const daysAgo = (n) => new Date(Date.now() - n * 86400000);

// ---------- stats ----------
async function overviewStats() {
  const [installs, active7, active1, premium, content, revenueAgg, refunds, openFeedback, pendingReview] = await Promise.all([
    AppUser.countDocuments(),
    AppUser.countDocuments({ lastSeenAt: { $gte: daysAgo(7) } }),
    AppUser.countDocuments({ lastSeenAt: { $gte: daysAgo(1) } }),
    AppUser.countDocuments({ premium: true }),
    ContentItem.aggregate([{ $group: { _id: '$review', n: { $sum: 1 } } }]),
    Purchase.aggregate([{ $match: { state: 'valid' } }, { $group: { _id: null, total: { $sum: '$amountInr' }, n: { $sum: 1 } } }]),
    Purchase.countDocuments({ state: 'refunded' }),
    Feedback.countDocuments({ status: 'new' }),
    ContentItem.countDocuments({ review: 'needsReview' }),
  ]);
  const review = Object.fromEntries(content.map((c) => [c._id, c.n]));
  return {
    installs, activeUsers7d: active7, activeUsers1d: active1, premiumUsers: premium,
    conversionPct: installs ? +((premium / installs) * 100).toFixed(2) : 0,
    revenueInr: revenueAgg[0]?.total || 0, orders: revenueAgg[0]?.n || 0, refunds,
    openFeedback, pendingReview, contentByReview: review,
  };
}

async function revenueStats(days) {
  const rows = await Purchase.aggregate([
    { $match: { purchasedAt: { $gte: daysAgo(days) } } },
    { $group: {
      _id: { $dateToString: { format: '%Y-%m-%d', date: '$purchasedAt' } },
      revenue: { $sum: { $cond: [{ $eq: ['$state', 'valid'] }, '$amountInr', 0] } },
      orders: { $sum: { $cond: [{ $eq: ['$state', 'valid'] }, 1, 0] } },
      refunds: { $sum: { $cond: [{ $eq: ['$state', 'refunded'] }, 1, 0] } },
    } },
  ]);
  return fillDays(rows, days, { revenue: 0, orders: 0, refunds: 0 });
}

async function userStats(days) {
  const [growth, byBoard, byClass, byVersion, activity] = await Promise.all([
    AppUser.aggregate([
      { $match: { firstSeenAt: { $gte: daysAgo(days) } } },
      { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$firstSeenAt' } }, installs: { $sum: 1 } } },
    ]),
    AppUser.aggregate([{ $group: { _id: '$boardId', n: { $sum: 1 } } }, { $sort: { n: -1 } }]),
    AppUser.aggregate([{ $group: { _id: '$classLevel', n: { $sum: 1 } } }, { $sort: { _id: 1 } }]),
    AppUser.aggregate([{ $group: { _id: '$appVersion', n: { $sum: 1 } } }, { $sort: { n: -1 } }]),
    Event.aggregate([
      { $match: { at: { $gte: daysAgo(days) } } },
      { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$at' } }, users: { $addToSet: '$installId' } } },
      { $project: { dau: { $size: '$users' } } },
    ]),
  ]);
  return {
    growth: fillDays(growth, days, { installs: 0 }),
    dau: fillDays(activity, days, { dau: 0 }),
    byBoard: byBoard.map((x) => ({ name: x._id || 'unknown', value: x.n })),
    byClass: byClass.map((x) => ({ name: x._id ? `Class ${x._id}` : 'unknown', value: x.n })),
    byVersion: byVersion.map((x) => ({ name: x._id || 'unknown', value: x.n })),
  };
}

r.get('/stats/learning', wrap(async (_req, res) => {
  const weak = await Event.aggregate([
    { $match: { name: 'quiz_attempt', topicId: { $ne: null } } },
    { $group: { _id: '$topicId', attempts: { $sum: 1 }, correct: { $sum: { $cond: ['$correct', 1, 0] } } } },
    { $match: { attempts: { $gte: 5 } } },
    { $project: { attempts: 1, accuracy: { $round: [{ $multiply: [{ $divide: ['$correct', '$attempts'] }, 100] }, 1] } } },
    { $sort: { accuracy: 1 } }, { $limit: 10 },
  ]);
  const tutor = await Event.aggregate([
    { $match: { name: 'ai_tutor', at: { $gte: daysAgo(30) } } },
    { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$at' } }, requests: { $sum: 1 } } },
  ]);
  res.json({
    weakTopics: weak.map((w) => ({ topicId: w._id, attempts: w.attempts, accuracy: w.accuracy })),
    aiTutor: fillDays(tutor, 30, { requests: 0 }),
  });
}));

// Questions per topic vs target (replaces QUESTION_COVERAGE.md)
async function coverageStats(target, classLevel) {
  const match = { type: 'question', topicId: { $ne: null } };
  if (classLevel) match.classLevel = classLevel;
  const rows = await ContentItem.aggregate([
    { $match: match },
    { $group: { _id: '$topicId', chapterId: { $first: '$chapterId' }, classLevel: { $first: '$classLevel' }, count: { $sum: 1 } } },
    { $sort: { classLevel: 1, _id: 1 } },
  ]);
  const topics = rows.map((x) => ({ topicId: x._id, chapterId: x.chapterId, classLevel: x.classLevel, count: x.count, missing: Math.max(0, target - x.count) }));
  return {
    target, topics,
    totalQuestions: topics.reduce((a, t) => a + t.count, 0),
    belowTarget: topics.filter((t) => t.missing > 0).length,
  };
}

const daysParam = (req) => Math.min(Number(req.query.days) || 30, 365);
const can = (req, ...roles) => req.user.role === 'admin' || roles.includes(req.user.role);

r.get('/stats/overview', wrap(async (_req, res) => res.json(await overviewStats())));
r.get('/stats/revenue', wrap(async (req, res) => res.json(await revenueStats(daysParam(req)))));
r.get('/stats/users', wrap(async (req, res) => res.json(await userStats(daysParam(req)))));
r.get('/stats/coverage', wrap(async (req, res) =>
  res.json(await coverageStats(Number(req.query.target) || 10, Number(req.query.classLevel) || null))));

// Everything the dashboard shows in one request: on Workers each request pays
// for its own MongoDB connection, so five calls cost five connections.
r.get('/stats/dashboard', wrap(async (req, res) => {
  const days = daysParam(req);
  const [overview, revenue, users, coverage, audit] = await Promise.all([
    overviewStats(),
    can(req, 'editor') ? revenueStats(days) : null,
    userStats(days),
    coverageStats(10, null),
    can(req, 'editor', 'reviewer') ? AuditLog.find().sort({ createdAt: -1 }).limit(8).lean() : null,
  ]);
  res.json({ overview, revenue, users, coverage, audit });
}));

function fillDays(rows, days, zero) {
  const map = new Map(rows.map((x) => [x._id, x]));
  const out = [];
  for (let i = days - 1; i >= 0; i--) {
    const d = day(daysAgo(i));
    const row = map.get(d);
    out.push({ date: d, ...zero, ...(row ? Object.fromEntries(Object.entries(row).filter(([k]) => k !== '_id')) : {}) });
  }
  return out;
}

// ---------- purchases ----------
r.get('/purchases', requireRole('editor'), wrap(async (req, res) => {
  const page = Math.max(1, Number(req.query.page) || 1);
  const limit = Math.min(100, Number(req.query.limit) || 25);
  const filter = req.query.state ? { state: String(req.query.state) } : {};
  const [items, total] = await Promise.all([
    Purchase.find(filter).sort({ purchasedAt: -1 }).skip((page - 1) * limit).limit(limit).lean(),
    Purchase.countDocuments(filter),
  ]);
  res.json({ items, total, page, pages: Math.ceil(total / limit) });
}));

r.get('/purchases/export.csv', requireRole('editor'), wrap(async (_req, res) => {
  const rows = await Purchase.find().sort({ purchasedAt: -1 }).lean();
  const csv = ['orderId,productId,state,amountInr,purchasedAt,voidedAt']
    .concat(rows.map((p) => [p.orderId, p.productId, p.state, p.amountInr, p.purchasedAt?.toISOString(), p.voidedAt?.toISOString() || ''].join(',')))
    .join('\n');
  res.type('text/csv').send(csv);
}));

r.patch('/purchases/:orderId', requireRole(), wrap(async (req, res) => {
  const { state } = z.object({ state: z.enum(['valid', 'pending', 'refunded', 'invalid']) }).parse(req.body);
  const p = await Purchase.findOneAndUpdate(
    { orderId: req.params.orderId },
    { state, voidedAt: state === 'refunded' ? new Date() : null }, { new: true });
  if (!p) throw new HttpError(404, 'Order not found');
  if (p.installId) await AppUser.updateOne({ installId: p.installId }, { premium: state === 'valid' });
  audit(req, 'purchase-state', 'purchase', p.orderId, `${p.orderId} -> ${state}`);
  res.json(p);
}));

// ---------- announcements / feedback ----------
const simpleCrud = (path, Model, schema, entity) => {
  r.get(path, wrap(async (_req, res) => res.json(await Model.find().sort({ createdAt: -1 }).limit(500).lean())));
  r.post(path, requireRole('editor'), wrap(async (req, res) => {
    const doc = await Model.create(schema.parse(req.body));
    audit(req, 'create', entity, String(doc._id), `Created ${entity}`);
    res.status(201).json(doc);
  }));
  r.put(`${path}/:id`, requireRole('editor'), wrap(async (req, res) => {
    const doc = await Model.findByIdAndUpdate(req.params.id, schema.partial().parse(req.body), { new: true });
    if (!doc) throw new HttpError(404, 'Not found');
    audit(req, 'update', entity, String(doc._id), `Updated ${entity}`);
    res.json(doc);
  }));
  r.delete(`${path}/:id`, requireRole('editor'), wrap(async (req, res) => {
    await Model.findByIdAndDelete(req.params.id);
    audit(req, 'delete', entity, req.params.id, `Deleted ${entity}`);
    res.json({ ok: true });
  }));
};

simpleCrud('/announcements', Announcement, z.object({
  title: z.string().min(1).max(120), body: z.string().min(1).max(1000),
  kind: z.enum(['info', 'update', 'promo', 'maintenance']).default('info'),
  active: z.boolean().default(true), startsAt: z.coerce.date().optional(), endsAt: z.coerce.date().optional(),
}), 'announcement');

simpleCrud('/feedback', Feedback, z.object({
  status: z.enum(['new', 'inProgress', 'resolved']).default('new'), reply: z.string().max(2000).optional(),
  message: z.string().default('-'), kind: z.enum(['bug', 'content', 'idea', 'other']).default('other'),
}), 'feedback');

// ---------- app config ----------
const configSchema = z.object({
  minAppVersion: z.string().regex(/^\d+\.\d+\.\d+$/),
  maintenanceMode: z.boolean(), premiumPriceText: z.string().max(20),
  aiTutorEnabled: z.boolean(), aiTutorDailyLimit: z.number().int().min(0).max(1000),
  flags: z.record(z.boolean()),
}).partial();

r.get('/config', wrap(async (_req, res) => {
  res.json(await AppConfig.findOneAndUpdate({ key: 'main' }, { $setOnInsert: { key: 'main' } }, { upsert: true, new: true }));
}));
r.put('/config', requireRole(), wrap(async (req, res) => {
  const doc = await AppConfig.findOneAndUpdate({ key: 'main' }, configSchema.parse(req.body), { upsert: true, new: true });
  audit(req, 'update', 'config', 'main', 'App config changed', req.body);
  res.json(doc);
}));

// ---------- audit + team ----------
r.get('/audit', requireRole('editor', 'reviewer'), wrap(async (req, res) => {
  const filter = {};
  if (req.query.entity) filter.entity = String(req.query.entity);
  if (req.query.action) filter.action = String(req.query.action);
  const limit = Math.min(200, Number(req.query.limit) || 50);
  res.json(await AuditLog.find(filter).sort({ createdAt: -1 }).limit(limit).lean());
}));

r.get('/team', requireRole(), wrap(async (_req, res) => res.json(await User.find().sort({ createdAt: 1 }).lean())));
r.post('/team', requireRole(), wrap(async (req, res) => {
  const b = z.object({
    name: z.string().min(1), email: z.string().email(), password: z.string().min(8).optional(), role: z.enum(ROLES),
  }).parse(req.body);
  // Without a password the member can only sign in with Google.
  if (!b.password && !config.googleClientId) throw new HttpError(400, 'Set a password (Google sign-in is not enabled)');
  const user = await User.create({
    name: b.name, email: b.email, role: b.role, passwordHash: b.password ? await bcrypt.hash(b.password, 12) : undefined,
  });
  audit(req, 'create', 'user', String(user._id), `Added ${b.role} ${b.email}`);
  res.status(201).json({ id: user._id, name: user.name, email: user.email, role: user.role });
}));
r.patch('/team/:id', requireRole(), wrap(async (req, res) => {
  const b = z.object({ role: z.enum(ROLES).optional(), active: z.boolean().optional() }).parse(req.body);
  if (String(req.user._id) === req.params.id) throw new HttpError(400, 'You cannot change your own role or status');
  const user = await User.findByIdAndUpdate(req.params.id, b, { new: true });
  if (!user) throw new HttpError(404, 'User not found');
  audit(req, 'update', 'user', String(user._id), `Updated ${user.email}`, b);
  res.json(user);
}));

export default r;
