import jwt from 'jsonwebtoken';
import { ZodError } from 'zod';
import { config } from './config.js';
import { AuditLog, User } from './models/index.js';

export class HttpError extends Error {
  constructor(status, message, details) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

export const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

export const signToken = (user) =>
  jwt.sign({ sub: String(user._id), role: user.role }, config.jwtSecret, { expiresIn: config.jwtExpiresIn });

export const requireAuth = wrap(async (req, _res, next) => {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) throw new HttpError(401, 'Not authenticated');
  let payload;
  try {
    payload = jwt.verify(token, config.jwtSecret);
  } catch {
    throw new HttpError(401, 'Session expired');
  }
  const user = await User.findById(payload.sub);
  if (!user || !user.active) throw new HttpError(401, 'Account disabled');
  req.user = user;
  next();
});

// admin can do everything; list the extra roles allowed for the route.
export const requireRole = (...roles) => (req, _res, next) => {
  if (req.user.role === 'admin' || roles.includes(req.user.role)) return next();
  next(new HttpError(403, 'You do not have permission for this action'));
};

export const audit = (req, action, entity, entityId, summary, meta) =>
  AuditLog.create({
    actor: req.user?._id, actorEmail: req.user?.email, action, entity, entityId, summary, meta,
  }).catch(() => {});

export const requireInternalSecret = (req, _res, next) => {
  if (!config.internalSecret || req.headers['x-internal-secret'] !== config.internalSecret) {
    return next(new HttpError(401, 'Invalid internal secret'));
  }
  next();
};

// eslint-disable-next-line no-unused-vars
export function errorHandler(err, _req, res, _next) {
  if (err instanceof ZodError) {
    return res.status(400).json({ error: 'Validation failed', details: err.flatten() });
  }
  if (err.name === 'CastError') return res.status(400).json({ error: 'Invalid id' });
  if (err.code === 11000) return res.status(409).json({ error: 'Already exists' });
  const status = err.status || 500;
  if (status >= 500) console.error(err);
  res.status(status).json({ error: status >= 500 ? 'Internal server error' : err.message, details: err.details });
}
