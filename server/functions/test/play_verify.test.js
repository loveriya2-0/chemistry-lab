'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { verifyPurchase } = require('../play_verify');

const TOKEN = 'a-real-looking-purchase-token';

/** Fake androidpublisher client. */
function publisher({ purchase, getError, voided = [] }) {
  const calls = { get: 0, voided: 0 };
  return {
    calls,
    purchases: {
      products: {
        get: async () => {
          calls.get++;
          if (getError) throw getError;
          return { data: purchase };
        },
      },
      voidedpurchases: {
        list: async () => {
          calls.voided++;
          return { data: { voidedPurchases: voided } };
        },
      },
    },
  };
}

const run = (pub, overrides = {}) =>
  verifyPurchase({
    publisher: pub,
    packageName: 'com.vlab.virtual_chemistry_lab',
    allowedProducts: ['premium_lifetime'],
    productId: 'premium_lifetime',
    purchaseToken: TOKEN,
    ...overrides,
  });

test('paid purchase is valid', async () => {
  const r = await run(publisher({ purchase: { purchaseState: 0, orderId: 'GPA.1', purchaseType: undefined } }));
  assert.deepEqual(r, { state: 'valid', orderId: 'GPA.1', test: false });
});

test('license-tester purchase is valid and marked as a test', async () => {
  const r = await run(publisher({ purchase: { purchaseState: 0, orderId: 'GPA.2', purchaseType: 0 } }));
  assert.equal(r.state, 'valid');
  assert.equal(r.test, true);
});

test('pending payment is pending', async () => {
  const r = await run(publisher({ purchase: { purchaseState: 2 } }));
  assert.equal(r.state, 'pending');
});

test('cancelled purchase is invalid', async () => {
  const r = await run(publisher({ purchase: { purchaseState: 1 } }));
  assert.deepEqual(r, { state: 'invalid', reason: 'cancelled' });
});

test('refunded purchase is invalid', async () => {
  const r = await run(publisher({ purchase: { purchaseState: 0 }, voided: [{ purchaseToken: 'other' }, { purchaseToken: TOKEN }] }));
  assert.deepEqual(r, { state: 'invalid', reason: 'refunded' });
});

test('unknown token is invalid', async () => {
  const r = await run(publisher({ getError: Object.assign(new Error('not found'), { code: 404 }) }));
  assert.deepEqual(r, { state: 'invalid', reason: 'unknown_token' });
});

test('Google errors are thrown, never reported as invalid', async () => {
  await assert.rejects(run(publisher({ getError: Object.assign(new Error('boom'), { code: 503 }) })));
});

test('other products and bad tokens are refused without calling Google', async () => {
  const pub = publisher({ purchase: { purchaseState: 0 } });
  assert.equal((await run(pub, { productId: 'free_gems' })).state, 'invalid');
  assert.equal((await run(pub, { purchaseToken: 'short' })).state, 'invalid');
  assert.equal((await run(pub, { purchaseToken: 42 })).state, 'invalid');
  assert.equal(pub.calls.get, 0);
});
