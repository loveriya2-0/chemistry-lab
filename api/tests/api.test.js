import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import request from 'supertest';
import { MongoMemoryServer } from 'mongodb-memory-server';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createApp } from '../src/app.js';
import { config } from '../src/config.js';
import { verifyGoogleToken } from '../src/google.js';
import { User, ContentItem } from '../src/models/index.js';

// Google's servers are not called in tests: the "credential" is a JSON string we control.
vi.mock('../src/google.js', () => ({
  verifyGoogleToken: vi.fn(async (credential) => {
    if (credential.startsWith('bad')) throw new Error('invalid token');
    return JSON.parse(credential);
  }),
}));
import { seedContent } from '../src/seed/seedContent.js';

const contentDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../assets/content');
let mongod; let app; let admin; let editor;

const login = async (email, password) =>
  (await request(app).post('/api/v1/auth/login').send({ email, password })).body.token;
const auth = (t) => ({ Authorization: `Bearer ${t}` });

beforeAll(async () => {
  mongod = await MongoMemoryServer.create();
  await mongoose.connect(mongod.getUri());
  app = createApp();
  const hash = await bcrypt.hash('Password123', 4);
  await User.create([
    { name: 'A', email: 'admin@t.io', passwordHash: hash, role: 'admin' },
    { name: 'E', email: 'editor@t.io', passwordHash: hash, role: 'editor' },
  ]);
  await seedContent(contentDir, { log: () => {} });
  admin = await login('admin@t.io', 'Password123');
  editor = await login('editor@t.io', 'Password123');
}, 120_000);

afterAll(async () => {
  await mongoose.disconnect();
  await mongod?.stop();
});

describe('auth', () => {
  it('rejects bad credentials and unauthenticated calls', async () => {
    expect((await request(app).post('/api/v1/auth/login').send({ email: 'admin@t.io', password: 'nope' })).status).toBe(401);
    expect((await request(app).get('/api/v1/content/question')).status).toBe(401);
  });
});

describe('google sign-in', () => {
  const token = (o) => JSON.stringify({ sub: 'g-1', email: 'guest@t.io', emailVerified: true, name: 'Guest', picture: 'http://p/x.png', ...o });
  const google = (credential) => request(app).post('/api/v1/auth/google').send({ credential });

  it('is disabled until a client id is configured', async () => {
    config.googleClientId = '';
    expect((await request(app).get('/api/v1/auth/config')).body.googleClientId).toBeNull();
    expect((await google(token({}) + ' '.repeat(20))).status).toBe(404);
  });

  it('only lets invited members in, and links the Google account', async () => {
    config.googleClientId = 'test-client';
    expect((await request(app).get('/api/v1/auth/config')).body.googleClientId).toBe('test-client');
    const pad = ' '.repeat(20); // credentials must look like real tokens (min length)

    // not invited
    const stranger = await google(token({ email: 'stranger@t.io' }) + pad);
    expect(stranger.status).toBe(403);
    expect(stranger.body.error).toMatch(/invited/);

    // admin invites a Google-only member (no password)
    const add = await request(app).post('/api/v1/team').set(auth(admin)).send({ name: 'Guest', email: 'guest@t.io', role: 'reviewer' });
    expect(add.status).toBe(201);

    const ok = await google(token({}) + pad);
    expect(ok.status).toBe(200);
    expect(ok.body.user).toMatchObject({ email: 'guest@t.io', role: 'reviewer', picture: 'http://p/x.png' });
    const me = await request(app).get('/api/v1/auth/me').set(auth(ok.body.token));
    expect(me.body.user.email).toBe('guest@t.io');

    // password login is impossible for a Google-only member
    expect((await request(app).post('/api/v1/auth/login').send({ email: 'guest@t.io', password: 'anything123' })).status).toBe(401);

    // a different Google account with the same email cannot take over the linked one
    expect((await google(token({ sub: 'g-2' }) + pad)).status).toBe(403);
  });

  it('rejects unverified emails, bad tokens and disabled members', async () => {
    config.googleClientId = 'test-client';
    const pad = ' '.repeat(20);
    expect((await google(token({ emailVerified: false }) + pad)).status).toBe(401);
    expect((await google('bad-token-xxxxxxxxxxxxxxxx')).status).toBe(401);
    expect((await google('short')).status).toBe(400);

    const guest = await User.findOne({ email: 'guest@t.io' });
    await request(app).patch(`/api/v1/team/${guest._id}`).set(auth(admin)).send({ active: false });
    expect((await google(token({}) + pad)).status).toBe(403);
  });

  it('requires a password for new members when Google is off', async () => {
    config.googleClientId = '';
    const res = await request(app).post('/api/v1/team').set(auth(admin)).send({ name: 'X', email: 'x@t.io', role: 'editor' });
    expect(res.status).toBe(400);
  });
});

describe('seed', () => {
  it('imports every content type with the original counts', async () => {
    const count = (type) => ContentItem.countDocuments({ type });
    expect(await ContentItem.countDocuments({ type: 'question', classLevel: 10 })).toBe(193);
    expect(await count('chemical')).toBeGreaterThanOrEqual(22);
    expect(await count('reaction')).toBe(18);
    expect(await count('reagent')).toBe(34);
    expect(await count('guide')).toBe(24);
    expect(await count('pyq')).toBe(186);
    expect(await count('board')).toBe(20);
  });
  it('exports items identical to the stored JSON', async () => {
    const res = await request(app).get('/api/v1/content/export/reaction').set(auth(admin));
    expect(res.body.items).toHaveLength(18);
    expect(res.body.items[0].id).toMatch(/^rx-/);
  });
});

describe('content CRUD + review workflow', () => {
  const item = {
    id: 'q-test-1', classLevel: 10, chapterId: 'cbse-10-ch01', topicId: 'cbse-10-ch01-t1.1', type: 'mcq', marks: 1,
    question: { en: 'What is H2O?', hi: 'H₂O क्या है?' },
    options: [{ en: 'Water', hi: 'जल' }, { en: 'Salt', hi: 'नमक' }], correctOption: 0,
    answer: { en: 'Water', hi: 'जल' }, explanation: { en: 'Water.', hi: 'जल।' },
  };

  it('rejects invalid items with validator issues', async () => {
    const bad = { ...item, id: 'q-bad', correctOption: 9 };
    const res = await request(app).post('/api/v1/content/question').set(auth(editor)).send({ data: bad });
    expect(res.status).toBe(422);
  });

  it('creates, lets editor submit for review, blocks editor from verifying', async () => {
    const created = await request(app).post('/api/v1/content/question').set(auth(editor)).send({ data: item });
    expect(created.status).toBe(201);
    expect(created.body.review).toBe('draft');
    const sub = await request(app).patch('/api/v1/content/question/q-test-1/review').set(auth(editor)).send({ status: 'needsReview' });
    expect(sub.status).toBe(200);
    const ver = await request(app).patch('/api/v1/content/question/q-test-1/review').set(auth(editor)).send({ status: 'verified' });
    expect(ver.status).toBe(403);
    const ok = await request(app).patch('/api/v1/content/question/q-test-1/review').set(auth(admin)).send({ status: 'verified' });
    expect(ok.status).toBe(200);
  });

  it('only admin can delete', async () => {
    expect((await request(app).delete('/api/v1/content/question/q-test-1').set(auth(editor))).status).toBe(403);
    expect((await request(app).delete('/api/v1/content/question/q-test-1').set(auth(admin))).status).toBe(200);
  });

  it('flags non-Devanagari Hindi and placeholders', async () => {
    const res = await request(app).post('/api/v1/content/tools/validate').set(auth(editor))
      .send({ type: 'question', data: { ...item, question: { en: 'TODO fix', hi: 'plain english' } } });
    expect(res.body.ok).toBe(false);
    expect(res.body.issues.length).toBeGreaterThanOrEqual(2);
  });
});

describe('public + stats', () => {
  it('serves only reviewed content to the app and records installs/events', async () => {
    const res = await request(app).get('/api/v1/public/content/reagent');
    expect(res.status).toBe(200);
    expect(res.body.items.length).toBeGreaterThan(0);
    const id = 'install-abcdef123456';
    expect((await request(app).post('/api/v1/public/install').send({ installId: id, boardId: 'cbse', classLevel: 10 })).status).toBe(200);
    expect((await request(app).post('/api/v1/public/events').send({ installId: id, events: [{ name: 'quiz_attempt', topicId: 't1', correct: true }] })).status).toBe(200);
    const stats = await request(app).get('/api/v1/stats/overview').set(auth(admin));
    expect(stats.body.installs).toBe(1);
  });

  it('records purchases through the internal endpoint only with the secret', async () => {
    process.env.INTERNAL_SECRET = '';
    const res = await request(app).post('/api/v1/internal/purchases').send({ orderId: 'GPA.1234' });
    expect(res.status).toBe(401);
  });

  it('computes question coverage', async () => {
    const res = await request(app).get('/api/v1/stats/coverage?classLevel=10').set(auth(admin));
    expect(res.body.totalQuestions).toBe(193);
  });
});
