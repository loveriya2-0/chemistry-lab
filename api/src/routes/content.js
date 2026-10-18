import { Router } from 'express';
import { z } from 'zod';
import { CONTENT_TYPES, REVIEW_STATUSES } from '../config.js';
import { ContentItem } from '../models/index.js';
import { HttpError, wrap, requireRole, audit } from '../middleware.js';
import { validateItem, metaOf, asArray } from '../validator.js';

const r = Router();

const typeOf = (req) => {
  const t = req.params.type;
  if (!CONTENT_TYPES.includes(t)) throw new HttpError(404, `Unknown content type "${t}"`);
  return t;
};
const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// ---- tools (declared before /:type/:itemId so they are not shadowed) ----
r.post('/tools/validate', wrap(async (req, res) => {
  const { type, data } = z.object({ type: z.enum(CONTENT_TYPES), data: z.any() }).parse(req.body);
  const issues = validateItem(type, data);
  issues.push(...(await checkRefs(type, data)));
  res.json({ ok: !issues.some((i) => i.level === 'error'), issues });
}));

r.post('/tools/bulk-review', requireRole('reviewer', 'editor'), wrap(async (req, res) => {
  const { type, ids, status, note } = z.object({
    type: z.enum(CONTENT_TYPES), ids: z.array(z.string()).min(1).max(500),
    status: z.enum(REVIEW_STATUSES), note: z.string().max(500).optional(),
  }).parse(req.body);
  if (status === 'verified' && req.user.role === 'editor') throw new HttpError(403, 'Only reviewers can verify content');
  const result = await ContentItem.updateMany(
    { type, itemId: { $in: ids } },
    { $set: { review: status, reviewNote: note, updatedBy: req.user._id, 'data.review.status': status } },
  );
  audit(req, 'bulk-review', type, ids.slice(0, 5).join(','), `${result.modifiedCount} ${type} items -> ${status}`);
  res.json({ modified: result.modifiedCount });
}));

r.get('/tools/summary', wrap(async (_req, res) => {
  const rows = await ContentItem.aggregate([{ $group: { _id: { type: '$type', review: '$review' }, n: { $sum: 1 } } }]);
  const summary = {};
  for (const { _id, n } of rows) {
    summary[_id.type] ??= { total: 0 };
    summary[_id.type][_id.review] = n;
    summary[_id.type].total += n;
  }
  res.json(summary);
}));

r.get('/export/:type', wrap(async (req, res) => {
  const type = typeOf(req);
  const filter = { type };
  if (req.query.boardId) filter.boardId = String(req.query.boardId);
  if (req.query.classLevel) filter.classLevel = Number(req.query.classLevel);
  const docs = await ContentItem.find(filter).sort({ itemId: 1 }).lean();
  res.setHeader('Content-Disposition', `attachment; filename="${type}.json"`);
  res.json({ hiSrc: docs.find((d) => d.hiSrc)?.hiSrc, items: docs.map((d) => d.data) });
}));

r.post('/import/:type', requireRole('editor'), wrap(async (req, res) => {
  const type = typeOf(req);
  const body = z.object({
    items: z.array(z.any()).min(1).max(5000),
    hiSrc: z.string().optional(),
    overwrite: z.boolean().default(false),
  }).parse(req.body);
  let created = 0; let updated = 0; let skipped = 0; const errors = [];
  for (const item of body.items) {
    const issues = validateItem(type, item).filter((i) => i.level === 'error');
    if (issues.length) { errors.push({ id: item?.id, issues }); continue; }
    const existing = await ContentItem.findOne({ type, itemId: item.id });
    if (existing && !body.overwrite) { skipped++; continue; }
    const meta = metaOf(type, item);
    await ContentItem.updateOne({ type, itemId: item.id },
      { $set: { ...meta, hiSrc: body.hiSrc, data: item, updatedBy: req.user._id } }, { upsert: true });
    existing ? updated++ : created++;
  }
  audit(req, 'import', type, '', `Import ${type}: ${created} new, ${updated} updated, ${skipped} skipped, ${errors.length} rejected`);
  res.json({ created, updated, skipped, errors });
}));

// ---- CRUD ----
r.get('/:type', wrap(async (req, res) => {
  const type = typeOf(req);
  const q = z.object({
    q: z.string().optional(), boardId: z.string().optional(), classLevel: z.coerce.number().optional(),
    chapterId: z.string().optional(), review: z.enum(REVIEW_STATUSES).optional(),
    page: z.coerce.number().min(1).default(1), limit: z.coerce.number().min(1).max(200).default(25),
  }).parse(req.query);
  const filter = { type };
  for (const k of ['boardId', 'classLevel', 'chapterId', 'review']) if (q[k] !== undefined) filter[k] = q[k];
  if (q.q) filter.$or = [{ title: new RegExp(esc(q.q), 'i') }, { itemId: new RegExp(esc(q.q), 'i') }];
  const [items, total] = await Promise.all([
    ContentItem.find(filter).select('-data').sort({ itemId: 1 }).skip((q.page - 1) * q.limit).limit(q.limit).lean(),
    ContentItem.countDocuments(filter),
  ]);
  res.json({ items, total, page: q.page, pages: Math.ceil(total / q.limit) });
}));

r.get('/:type/:itemId', wrap(async (req, res) => {
  const doc = await ContentItem.findOne({ type: typeOf(req), itemId: req.params.itemId }).lean();
  if (!doc) throw new HttpError(404, 'Not found');
  res.json(doc);
}));

const writeSchema = z.object({
  data: z.record(z.any()),
  review: z.enum(REVIEW_STATUSES).optional(),
  boardId: z.string().optional(),
  classLevel: z.number().optional(),
});

r.post('/:type', requireRole('editor'), wrap(async (req, res) => {
  const type = typeOf(req);
  const body = writeSchema.parse(req.body);
  const issues = validateItem(type, body.data);
  const errors = issues.filter((i) => i.level === 'error');
  if (errors.length) throw new HttpError(422, 'Item failed validation', issues);
  if (await ContentItem.exists({ type, itemId: body.data.id })) throw new HttpError(409, `${type} "${body.data.id}" already exists`);
  const review = body.review || 'draft';
  body.data.review = { ...body.data.review, status: review };
  const doc = await ContentItem.create({
    type, itemId: body.data.id, ...metaOf(type, body.data, body), review, data: body.data, updatedBy: req.user._id,
  });
  audit(req, 'create', type, doc.itemId, `Created ${type} ${doc.itemId}`);
  res.status(201).json({ ...doc.toObject(), issues });
}));

r.put('/:type/:itemId', requireRole('editor'), wrap(async (req, res) => {
  const type = typeOf(req);
  const body = writeSchema.parse(req.body);
  const doc = await ContentItem.findOne({ type, itemId: req.params.itemId });
  if (!doc) throw new HttpError(404, 'Not found');
  if (body.data.id !== doc.itemId) throw new HttpError(400, 'id cannot be changed; duplicate the item instead');
  const issues = validateItem(type, body.data);
  if (issues.some((i) => i.level === 'error')) throw new HttpError(422, 'Item failed validation', issues);
  // Editing verified content sends it back for review unless the caller is a reviewer re-approving.
  let review = body.review || doc.review;
  if (!body.review && ['sourceChecked', 'verified'].includes(doc.review) && req.user.role === 'editor') review = 'needsReview';
  body.data.review = { ...body.data.review, status: review };
  Object.assign(doc, metaOf(type, body.data, body), { review, data: body.data, updatedBy: req.user._id });
  doc.markModified('data');
  await doc.save();
  audit(req, 'update', type, doc.itemId, `Edited ${type} ${doc.itemId}`);
  res.json({ ...doc.toObject(), issues });
}));

r.patch('/:type/:itemId/review', requireRole('reviewer', 'editor'), wrap(async (req, res) => {
  const type = typeOf(req);
  const { status, note } = z.object({ status: z.enum(REVIEW_STATUSES), note: z.string().max(500).optional() }).parse(req.body);
  if (status === 'verified' && req.user.role === 'editor') throw new HttpError(403, 'Only reviewers can verify content');
  const doc = await ContentItem.findOne({ type, itemId: req.params.itemId });
  if (!doc) throw new HttpError(404, 'Not found');
  const from = doc.review;
  doc.review = status;
  doc.reviewNote = note;
  doc.set('data.review.status', status);
  doc.markModified('data');
  doc.updatedBy = req.user._id;
  await doc.save();
  audit(req, 'review', type, doc.itemId, `${doc.itemId}: ${from} -> ${status}`, { note });
  res.json({ itemId: doc.itemId, review: status });
}));

r.delete('/:type/:itemId', requireRole(), wrap(async (req, res) => {
  const type = typeOf(req);
  const doc = await ContentItem.findOneAndDelete({ type, itemId: req.params.itemId });
  if (!doc) throw new HttpError(404, 'Not found');
  audit(req, 'delete', type, doc.itemId, `Deleted ${type} ${doc.itemId}`);
  res.json({ ok: true });
}));

// Cross-reference checks against what is stored.
async function checkRefs(type, data) {
  const issues = [];
  const check = async (field, refType) => {
    const ids = asArray(data?.[field]);
    if (!ids.length) return;
    const found = await ContentItem.find({ type: refType, itemId: { $in: ids } }).select('itemId').lean();
    const have = new Set(found.map((f) => f.itemId));
    for (const id of ids) if (!have.has(id)) issues.push({ level: 'error', path: field, message: `Unknown ${refType} id "${id}"` });
  };
  await check('conceptIds', 'concept');
  await check('chemicalIds', 'chemical');
  if (type === 'reaction') {
    const shelf = asArray(data.shelf);
    if (shelf.length) {
      const found = await ContentItem.find({ type: 'reagent', itemId: { $in: shelf } }).select('itemId').lean();
      const have = new Set(found.map((f) => f.itemId));
      for (const id of shelf) if (!have.has(id)) issues.push({ level: 'error', path: 'shelf', message: `Unknown reagent "${id}"` });
    }
  }
  return issues;
}

export default r;
