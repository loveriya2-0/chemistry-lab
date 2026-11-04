import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { config } from '../config.js';
import { User } from '../models/index.js';
import { verifyGoogleToken } from '../google.js';
import { HttpError, wrap, signToken, requireAuth, audit } from '../middleware.js';

const r = Router();

const loginSchema = z.object({ email: z.string().email(), password: z.string().min(1) });

const publicUser = (u) => ({ id: u._id, name: u.name, email: u.email, role: u.role, picture: u.picture });

// Tells the login page whether to show "Continue with Google".
r.get('/config', (_req, res) => res.json({ googleClientId: config.googleClientId || null }));

r.post('/login', wrap(async (req, res) => {
  const { email, password } = loginSchema.parse(req.body);
  const user = await User.findOne({ email: email.toLowerCase() }).select('+passwordHash');
  const ok = user && user.active && user.passwordHash && (await bcrypt.compare(password, user.passwordHash));
  if (!ok) throw new HttpError(401, 'Invalid email or password');
  user.lastLoginAt = new Date();
  await user.save();
  req.user = user;
  audit(req, 'login', 'user', String(user._id), `${user.email} signed in`);
  res.json({ token: signToken(user), user: publicUser(user) });
}));

// Only people an admin already added in Team can sign in; Google just proves who they are.
r.post('/google', wrap(async (req, res) => {
  if (!config.googleClientId) throw new HttpError(404, 'Google sign-in is not enabled');
  const { credential } = z.object({ credential: z.string().min(20) }).parse(req.body);
  let g;
  try {
    g = await verifyGoogleToken(credential);
  } catch {
    throw new HttpError(401, 'Google sign-in failed. Please try again.');
  }
  if (!g.email || !g.emailVerified) throw new HttpError(401, 'Your Google email is not verified');

  const user = (await User.findOne({ googleId: g.sub })) || (await User.findOne({ email: g.email }));
  if (!user || !user.active) {
    throw new HttpError(403, `${g.email} has not been invited. Ask an admin to add this email in Team.`);
  }
  // An account already linked to one Google identity cannot be taken over by another.
  if (user.googleId && user.googleId !== g.sub) throw new HttpError(403, 'This account is linked to a different Google account');

  user.googleId = g.sub;
  user.picture = g.picture || user.picture;
  user.lastLoginAt = new Date();
  await user.save();
  req.user = user;
  audit(req, 'login', 'user', String(user._id), `${user.email} signed in with Google`);
  res.json({ token: signToken(user), user: publicUser(user) });
}));

r.get('/me', requireAuth, (req, res) => res.json({ user: publicUser(req.user) }));

r.post('/change-password', requireAuth, wrap(async (req, res) => {
  const { current, next } = z.object({ current: z.string(), next: z.string().min(8) }).parse(req.body);
  const user = await User.findById(req.user._id).select('+passwordHash');
  if (!user.passwordHash || !(await bcrypt.compare(current, user.passwordHash))) throw new HttpError(400, 'Current password is wrong');
  user.passwordHash = await bcrypt.hash(next, 12);
  await user.save();
  audit(req, 'change-password', 'user', String(user._id), 'Password changed');
  res.json({ ok: true });
}));

export default r;
