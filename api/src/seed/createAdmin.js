import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import { config } from '../config.js';
import { User } from '../models/index.js';

const email = (process.env.ADMIN_EMAIL || '').toLowerCase();
const password = process.env.ADMIN_PASSWORD || '';
// With Google sign-in enabled the first admin may have no password at all.
const googleOnly = !password && !!config.googleClientId;
if (!email || (!googleOnly && password.length < 8)) {
  console.error('Set ADMIN_EMAIL and ADMIN_PASSWORD (min 8 chars) in api/.env, or ADMIN_EMAIL alone when GOOGLE_CLIENT_ID is set');
  process.exit(1);
}

await mongoose.connect(config.mongoUri);
const $set = { role: 'admin', active: true };
if (!googleOnly) $set.passwordHash = await bcrypt.hash(password, 12);
await User.updateOne({ email }, { $set, $setOnInsert: { name: 'Admin', email } }, { upsert: true });
console.log(`Admin ready: ${email}${googleOnly ? ' (Google sign-in only)' : ''}`);
await mongoose.disconnect();
