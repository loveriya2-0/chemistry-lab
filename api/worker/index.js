import { Container, getContainer } from '@cloudflare/containers';

// The Express API runs unchanged inside a container; this Worker only routes
// requests to it. Secrets are set on the Worker and handed to the container.
export class ApiContainer extends Container {
  defaultPort = 4000;
  // Stops after 15 idle minutes (no cost while asleep); the next request starts it again.
  sleepAfter = '15m';

  constructor(ctx, env) {
    super(ctx, env);
    this.envVars = {
      NODE_ENV: 'production',
      PORT: '4000',
      MONGODB_URI: env.MONGODB_URI,
      JWT_SECRET: env.JWT_SECRET,
      INTERNAL_SECRET: env.INTERNAL_SECRET,
      CORS_ORIGINS: env.CORS_ORIGINS,
      GOOGLE_CLIENT_ID: env.GOOGLE_CLIENT_ID,
    };
  }
}

export default {
  async fetch(request, env) {
    // One shared instance is enough for an admin console and light app traffic.
    return getContainer(env.API).fetch(request);
  },
};
