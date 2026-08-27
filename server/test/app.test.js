import assert from 'node:assert/strict';
import { test } from 'node:test';

import { createApp } from '../src/app.js';

test('GET /healthz returns ok', async () => {
  const app = createApp();
  const server = app.listen(0);
  const { port } = server.address();

  try {
    const res = await fetch(`http://127.0.0.1:${port}/healthz`);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.deepEqual(body, { status: 'ok' });
  } finally {
    server.close();
  }
});

test('POST /webhooks/revenuecat without auth header is rejected', async () => {
  const app = createApp();
  const server = app.listen(0);
  const { port } = server.address();

  try {
    const res = await fetch(`http://127.0.0.1:${port}/webhooks/revenuecat`, {
      method: 'POST',
      body: JSON.stringify({ event: { type: 'TEST', app_user_id: 'abc' } }),
    });
    // No REVENUECAT_WEBHOOK_AUTH_TOKEN set in test env -> fails closed (500),
    // and a set-but-mismatched token would 401. Either way, never 200.
    assert.notEqual(res.status, 200);
  } finally {
    server.close();
  }
});

test('POST /webhooks/revenuecat with valid auth+JSON but no Firebase credentials fails clean, not crashed', async () => {
  const app = createApp();
  const server = app.listen(0);
  const { port } = server.address();

  const token = 'test-only-token';
  process.env.REVENUECAT_WEBHOOK_AUTH_TOKEN = token;

  try {
    const res = await fetch(`http://127.0.0.1:${port}/webhooks/revenuecat`, {
      method: 'POST',
      headers: { Authorization: token, 'Content-Type': 'application/json' },
      body: JSON.stringify({ event: { type: 'TEST', app_user_id: 'abc' } }),
    });
    // No FIREBASE_SERVICE_ACCOUNT set in this test's env -> getFirebaseAdmin()
    // throws once auth+JSON parsing succeed. That MUST come back as a clean
    // JSON 500 from the route's own try/catch (regression test for the bug
    // that crashed the real Lambda deploy: an uncaught rejection here became
    // an unhandled promise rejection, which Lambda surfaces as an opaque,
    // bodyless "Internal Server Error" instead of any usable response).
    assert.equal(res.status, 500);
    const body = await res.json();
    assert.equal(body.error, 'internal_error');
  } finally {
    delete process.env.REVENUECAT_WEBHOOK_AUTH_TOKEN;
    server.close();
  }
});

test('POST /coins/spend without a bearer token is rejected', async () => {
  const app = createApp();
  const server = app.listen(0);
  const { port } = server.address();

  try {
    const res = await fetch(`http://127.0.0.1:${port}/coins/spend`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ amount: 10, reason: 'test' }),
    });
    assert.equal(res.status, 401);
  } finally {
    server.close();
  }
});
