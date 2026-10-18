'use strict';

const { onRequest } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const { google } = require('googleapis');
const { verifyPurchase } = require('./play_verify');

// Must match android/app/build.gradle.kts and the Play Console product.
const PACKAGE_NAME = 'com.vlab.virtual_chemistry_lab';
const ALLOWED_PRODUCTS = ['premium_lifetime'];

// No key file: the function runs as its own service account, which is
// given access in Play Console (see server/README.md).
const auth = new google.auth.GoogleAuth({ scopes: ['https://www.googleapis.com/auth/androidpublisher'] });
const publisher = google.androidpublisher({ version: 'v3', auth });

/**
 * Tells the Lab Console about a purchase so revenue and refunds show on its
 * dashboard. Optional (needs CONSOLE_API_URL and CONSOLE_INTERNAL_SECRET) and
 * best effort: it never changes the answer the app gets.
 */
async function reportToConsole(productId, result) {
  const base = process.env.CONSOLE_API_URL;
  const secret = process.env.CONSOLE_INTERNAL_SECRET;
  // Test purchases take no money, and a verdict without an order id has nothing to record.
  if (!base || !secret || !result.orderId || result.test) return;
  const state = result.state === 'invalid' && result.reason === 'refunded' ? 'refunded' : result.state;
  try {
    const r = await fetch(`${base.replace(/\/+$/, '')}/api/v1/internal/purchases`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-internal-secret': secret },
      body: JSON.stringify({ orderId: result.orderId, productId, state }),
      signal: AbortSignal.timeout(3000),
    });
    if (!r.ok) logger.warn('console report rejected', { status: r.status });
  } catch (e) {
    logger.warn('console report failed', { message: e && e.message });
  }
}

/**
 * POST { productId, purchaseToken } → 200 { state: valid | pending | invalid }.
 * 5xx when Google Play could not be asked; the app retries later.
 */
exports.verifyPurchase = onRequest({ region: 'asia-south1', maxInstances: 10, timeoutSeconds: 30 }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'POST only' });
    return;
  }
  const { productId, purchaseToken } = req.body || {};
  try {
    const result = await verifyPurchase({
      publisher,
      packageName: PACKAGE_NAME,
      allowedProducts: ALLOWED_PRODUCTS,
      productId,
      purchaseToken,
    });
    // Order id only; tokens are never logged.
    logger.info('verify', { productId, state: result.state, reason: result.reason, orderId: result.orderId, test: result.test });
    await reportToConsole(productId, result);
    res.status(200).json({ state: result.state });
  } catch (e) {
    logger.error('Google Play API error', { message: e && e.message });
    res.status(502).json({ error: 'play_unavailable' });
  }
});
