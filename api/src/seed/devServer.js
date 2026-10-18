// Dev convenience: runs the API against a throwaway in-memory MongoDB, seeded with
// the app content and one admin (admin@lab.local / Admin12345). Data is lost on exit.
import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import { MongoMemoryServer } from 'mongodb-memory-server';
import { config } from '../config.js';
import { createApp } from '../app.js';
import { User } from '../models/index.js';
import { seedContent } from './seedContent.js';

const mongod = await MongoMemoryServer.create();
await mongoose.connect(mongod.getUri());
await User.create({ name: 'Admin', email: 'admin@lab.local', role: 'admin', passwordHash: await bcrypt.hash('Admin12345', 10) });
console.log('Seeded:', await seedContent(config.contentDir, { log: () => {} }));
createApp().listen(config.port, () => console.log(`Dev API (in-memory DB) on http://localhost:${config.port}  login admin@lab.local / Admin12345`));
