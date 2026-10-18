import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { User } from '../models/index.js';
import { HttpError, wrap, signToken, requireAuth, audit } from '../middleware.js';

const r = Router();

const loginSchema = z.object({ email: z.string().email(), password: z.string().min(1) });

const publicUser = (u) => ({ id: u._id, name: u.name, email: u.email, role: u.role });

r.post('/login', wrap(async (req, res) => {
  const { email, password } = loginSchema.parse(req.body);
  const user = await User.findOne({ email: email.toLowerCase() }).select('+passwordHash');
  const ok = user && user.active && (await bcrypt.compare(password, user.passwordHash));
  if (!ok) throw new HttpError(401, 'Invalid email or password');
  user.lastLoginAt = new Date();
  await user.save();
  req.user = user;
  audit(req, 'login', 'user', String(user._id), `${user.email} signed in`);
  res.json({ token: signToken(user), user: publicUser(user) });
}));

r.get('/me', requireAuth, (req, res) => res.json({ user: publicUser(req.user) }));

r.post('/change-password', requireAuth, wrap(async (req, res) => {
  const { current, next } = z.object({ current: z.string(), next: z.string().min(8) }).parse(req.body);
  const user = await User.findById(req.user._id).select('+passwordHash');
  if (!(await bcrypt.compare(current, user.passwordHash))) throw new HttpError(400, 'Current password is wrong');
  user.passwordHash = await bcrypt.hash(next, 12);
  await user.save();
  audit(req, 'change-password', 'user', String(user._id), 'Password changed');
  res.json({ ok: true });
}));

export default r;
