import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import { config } from '../config.js';
import { User } from '../models/index.js';

const email = (process.env.ADMIN_EMAIL || '').toLowerCase();
const password = process.env.ADMIN_PASSWORD || '';
if (!email || password.length < 8) {
  console.error('Set ADMIN_EMAIL and ADMIN_PASSWORD (min 8 chars) in api/.env');
  process.exit(1);
}

await mongoose.connect(config.mongoUri);
const passwordHash = await bcrypt.hash(password, 12);
await User.updateOne(
  { email },
  { $set: { passwordHash, role: 'admin', active: true }, $setOnInsert: { name: 'Admin', email } },
  { upsert: true },
);
console.log(`Admin ready: ${email}`);
await mongoose.disconnect();
