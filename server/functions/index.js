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
    res.status(200).json({ state: result.state });
  } catch (e) {
    logger.error('Google Play API error', { message: e && e.message });
    res.status(502).json({ error: 'play_unavailable' });
  }
});
