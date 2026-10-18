import mongoose from 'mongoose';
import { config } from './config.js';
import { createApp } from './app.js';

if (config.jwtSecret === 'dev-only-secret' && process.env.NODE_ENV === 'production') {
  throw new Error('Set JWT_SECRET before running in production');
}

await mongoose.connect(config.mongoUri);
createApp().listen(config.port, () => console.log(`Lab Console API on http://localhost:${config.port}`));
