'use strict';

/**
 * Checks a Google Play one-time purchase with the Google Play Developer API.
 *
 * Kept free of Firebase and googleapis imports so it can be tested with a
 * fake `publisher` (the androidpublisher v3 client).
 *
 * Returns { state: 'valid' | 'pending' | 'invalid', reason?, orderId?, test? }.
 * Throws when Google could not be asked; the app then keeps what it had
 * verified before and never treats that as a refund.
 */
async function verifyPurchase({ publisher, packageName, allowedProducts, productId, purchaseToken }) {
  if (!allowedProducts.includes(productId)) return { state: 'invalid', reason: 'unknown_product' };
  if (typeof purchaseToken !== 'string' || purchaseToken.length < 10 || purchaseToken.length > 4096) {
    return { state: 'invalid', reason: 'bad_token' };
  }

  let purchase;
  try {
    const res = await publisher.purchases.products.get({ packageName, productId, token: purchaseToken });
    purchase = res.data;
  } catch (e) {
    // Google does not know this token for this app/product.
    if ([400, 404, 410].includes(statusOf(e))) return { state: 'invalid', reason: 'unknown_token' };
    throw e;
  }

  // purchaseState: 0 purchased, 1 cancelled, 2 pending.
  if (purchase.purchaseState === 2) return { state: 'pending' };
  if (purchase.purchaseState !== 0) return { state: 'invalid', reason: 'cancelled' };
  if (await isVoided({ publisher, packageName, purchaseToken })) return { state: 'invalid', reason: 'refunded' };

  return {
    state: 'valid',
    orderId: purchase.orderId,
    // purchaseType 0 = a license tester's test purchase (no money taken).
    test: purchase.purchaseType === 0,
  };
}

/** Refunded or charged back in the last 30 days (Voided Purchases API). */
async function isVoided({ publisher, packageName, purchaseToken }) {
  let pageToken;
  for (let page = 0; page < 20; page++) {
    const res = await publisher.purchases.voidedpurchases.list({
      packageName,
      type: 0, // one-time products
      maxResults: 1000,
      token: pageToken,
    });
    const voided = res.data.voidedPurchases || [];
    if (voided.some((v) => v.purchaseToken === purchaseToken)) return true;
    pageToken = res.data.tokenPagination && res.data.tokenPagination.nextPageToken;
    if (!pageToken) return false;
  }
  return false;
}

function statusOf(e) {
  return (e && (e.code || e.status || (e.response && e.response.status))) || 0;
}

module.exports = { verifyPurchase, isVoided };
