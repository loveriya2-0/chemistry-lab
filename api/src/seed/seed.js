import mongoose from 'mongoose';
import { config } from '../config.js';
import { seedContent } from './seedContent.js';

await mongoose.connect(config.mongoUri);
const counts = await seedContent(config.contentDir);
console.log('Seeded content:', counts);
await mongoose.disconnect();
