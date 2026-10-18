import mongoose from 'mongoose';
import { CONTENT_TYPES, REVIEW_STATUSES, ROLES } from '../config.js';

const { Schema } = mongoose;
const opts = { timestamps: true };

export const User = mongoose.model('User', new Schema({
  name: { type: String, required: true, trim: true },
  email: { type: String, required: true, unique: true, lowercase: true, trim: true },
  passwordHash: { type: String, required: true, select: false },
  role: { type: String, enum: ROLES, default: 'editor' },
  active: { type: Boolean, default: true },
  lastLoginAt: Date,
}, opts));

// One generic collection for every content type. `data` holds the exact JSON
// item the Flutter app reads, so export is a lossless round-trip.
const contentSchema = new Schema({
  type: { type: String, enum: CONTENT_TYPES, required: true },
  itemId: { type: String, required: true },
  boardId: String,
  classLevel: Number,
  chapterId: String,
  topicId: String,
  title: String,
  review: { type: String, enum: REVIEW_STATUSES, default: 'draft' },
  reviewNote: String,
  hiSrc: String,
  data: { type: Schema.Types.Mixed, required: true },
  updatedBy: { type: Schema.Types.ObjectId, ref: 'User' },
}, opts);
contentSchema.index({ type: 1, itemId: 1 }, { unique: true });
contentSchema.index({ type: 1, boardId: 1, classLevel: 1, chapterId: 1 });
contentSchema.index({ title: 'text', itemId: 'text' });
export const ContentItem = mongoose.model('ContentItem', contentSchema);

export const AuditLog = mongoose.model('AuditLog', new Schema({
  actor: { type: Schema.Types.ObjectId, ref: 'User' },
  actorEmail: String,
  action: { type: String, required: true },
  entity: String,
  entityId: String,
  summary: String,
  meta: Schema.Types.Mixed,
}, opts));

export const Announcement = mongoose.model('Announcement', new Schema({
  title: { type: String, required: true },
  body: { type: String, required: true },
  kind: { type: String, enum: ['info', 'update', 'promo', 'maintenance'], default: 'info' },
  active: { type: Boolean, default: true },
  startsAt: Date,
  endsAt: Date,
}, opts));

export const Feedback = mongoose.model('Feedback', new Schema({
  installId: String,
  kind: { type: String, enum: ['bug', 'content', 'idea', 'other'], default: 'other' },
  message: { type: String, required: true, maxlength: 4000 },
  contentRef: String,
  appVersion: String,
  status: { type: String, enum: ['new', 'inProgress', 'resolved'], default: 'new' },
  reply: String,
}, opts));

export const AppConfig = mongoose.model('AppConfig', new Schema({
  key: { type: String, default: 'main', unique: true },
  minAppVersion: { type: String, default: '1.0.0' },
  maintenanceMode: { type: Boolean, default: false },
  premiumPriceText: { type: String, default: '₹99' },
  aiTutorEnabled: { type: Boolean, default: true },
  aiTutorDailyLimit: { type: Number, default: 20 },
  flags: { type: Map, of: Boolean, default: {} },
}, opts));

export const Purchase = mongoose.model('Purchase', new Schema({
  orderId: { type: String, required: true, unique: true },
  productId: { type: String, default: 'premium_lifetime' },
  installId: String,
  state: { type: String, enum: ['valid', 'pending', 'refunded', 'invalid'], default: 'valid' },
  amountInr: { type: Number, default: 99 },
  purchasedAt: { type: Date, default: Date.now },
  voidedAt: Date,
}, opts));

export const AppUser = mongoose.model('AppUser', new Schema({
  installId: { type: String, required: true, unique: true },
  boardId: String,
  classLevel: Number,
  language: String,
  appVersion: String,
  platform: String,
  premium: { type: Boolean, default: false },
  firstSeenAt: { type: Date, default: Date.now },
  lastSeenAt: { type: Date, default: Date.now },
}, opts));

const eventSchema = new Schema({
  installId: String,
  name: { type: String, required: true }, // quiz_attempt | session | practical_done | ai_tutor ...
  topicId: String,
  chapterId: String,
  correct: Boolean,
  value: Number,
  at: { type: Date, default: Date.now },
});
eventSchema.index({ at: 1 }, { expireAfterSeconds: 60 * 60 * 24 * 365 });
eventSchema.index({ name: 1, at: -1 });
export const Event = mongoose.model('Event', eventSchema);
