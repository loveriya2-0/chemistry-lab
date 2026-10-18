import fs from 'node:fs/promises';
import path from 'node:path';
import { ContentItem } from '../models/index.js';
import { metaOf } from '../validator.js';

async function* walk(dir) {
  for (const e of await fs.readdir(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) yield* walk(p);
    else if (e.name.endsWith('.json')) yield p;
  }
}

// Decide what a file in assets/content holds from its path.
function classify(rel) {
  const parts = rel.split('/');
  const file = parts.at(-1);
  if (rel === 'boards.json') return { type: 'board', kind: 'boards' };
  if (parts[0] === 'boards') {
    const [, boardId, year, sub] = parts;
    const base = { boardId, year };
    if (file === 'manifest.json') return { ...base, type: 'manifest', kind: 'doc', id: `${boardId}-${year}-manifest` };
    if (/^class-\d+\.json$/.test(file) && parts.length === 4) {
      return { ...base, type: 'syllabus', kind: 'doc', id: `${boardId}-${year}-${file.replace('.json', '')}`, classLevel: Number(file.match(/\d+/)[0]) };
    }
    const type = { notes: 'note', questions: 'question', pyq: 'pyq' }[sub];
    if (type) return { ...base, type, kind: 'items' };
  }
  if (parts[0] === 'library') {
    if (parts[1] === 'concepts') return { type: 'concept', kind: 'items' };
    const type = {
      'chemicals.json': 'chemical', 'chemicals-advanced.json': 'chemical', 'lab-reactions.json': 'reaction',
      'lab-reagents.json': 'reagent', 'practical-guides.json': 'guide',
    }[file];
    if (type) return { type, kind: 'items' };
  }
  return null;
}

export async function seedContent(dir, { log = console.log } = {}) {
  const root = path.resolve(dir);
  const counts = {};
  const ops = [];
  for await (const abs of walk(root)) {
    const rel = path.relative(root, abs).split(path.sep).join('/');
    const c = classify(rel);
    if (!c) { log(`skip ${rel}`); continue; }
    const json = JSON.parse((await fs.readFile(abs, 'utf8')).replace(/^﻿/, ''));
    const hiSrc = typeof json.hiSrc === 'string' ? json.hiSrc : undefined;
    let items;
    if (c.kind === 'boards') items = json.boards;
    else if (c.kind === 'doc') items = [{ ...json, id: c.id }];
    else items = json.items;
    for (const item of items) {
      const meta = metaOf(c.type, item, { boardId: c.boardId, classLevel: c.classLevel });
      if (!item.review?.status && ['board', 'manifest', 'syllabus', 'reagent'].includes(c.type)) meta.review = 'verified';
      ops.push({
        updateOne: {
          filter: { type: c.type, itemId: item.id },
          update: { $set: { ...meta, boardId: meta.boardId || c.boardId, hiSrc, data: item } },
          upsert: true,
        },
      });
      counts[c.type] = (counts[c.type] || 0) + 1;
    }
  }
  for (let i = 0; i < ops.length; i += 500) await ContentItem.bulkWrite(ops.slice(i, i + 500), { ordered: false });
  return counts;
}
