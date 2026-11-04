import { OAuth2Client } from 'google-auth-library';
import { config } from './config.js';

let client;

// Verifies a Google ID token (signature, expiry, issuer and that it was issued
// for this app's client id) and returns the identity it vouches for.
export async function verifyGoogleToken(credential) {
  if (!config.googleClientId) throw new Error('Google sign-in is not configured');
  client ??= new OAuth2Client();
  const ticket = await client.verifyIdToken({ idToken: credential, audience: config.googleClientId });
  const p = ticket.getPayload();
  return { sub: p.sub, email: p.email?.toLowerCase(), emailVerified: p.email_verified === true, name: p.name, picture: p.picture };
}
