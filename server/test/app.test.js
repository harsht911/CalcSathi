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
