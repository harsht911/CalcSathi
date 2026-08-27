import assert from 'node:assert/strict';
import { test } from 'node:test';

import { handler } from '../src/lambda.js';

// Minimal Lambda Function URL invocation event (payload format 2.0) for a
// GET /healthz request — enough to prove serverless-http's Express wrapping
// round-trips correctly outside of a real AWS environment, without needing
// live AWS credentials or a deployed function to run this test.
function healthzEvent() {
  return {
    version: '2.0',
    routeKey: '$default',
    rawPath: '/healthz',
    rawQueryString: '',
    headers: { 'content-type': 'application/json' },
    requestContext: {
      http: { method: 'GET', path: '/healthz', sourceIp: '127.0.0.1', protocol: 'HTTP/1.1' },
      domainName: 'test.lambda-url.us-east-1.on.aws',
      requestId: 'test-request-id',
      routeKey: '$default',
      stage: '$default',
      time: '01/Jan/2026:00:00:00 +0000',
      timeEpoch: 0,
    },
    isBase64Encoded: false,
  };
}

test('lambda handler wraps GET /healthz the same as the Express app', async () => {
  const result = await handler(healthzEvent(), {});
  assert.equal(result.statusCode, 200);
  assert.deepEqual(JSON.parse(result.body), { status: 'ok' });
});

test('lambda handler rejects an unauthenticated RevenueCat webhook POST', async () => {
  const event = {
    ...healthzEvent(),
    rawPath: '/webhooks/revenuecat',
    requestContext: {
      ...healthzEvent().requestContext,
      http: { method: 'POST', path: '/webhooks/revenuecat', sourceIp: '127.0.0.1', protocol: 'HTTP/1.1' },
    },
    body: JSON.stringify({ event: { type: 'TEST', app_user_id: 'abc' } }),
    isBase64Encoded: false,
  };

  const result = await handler(event, {});
  // No REVENUECAT_WEBHOOK_AUTH_TOKEN set in test env -> fails closed (500),
  // and a set-but-mismatched token would 401. Either way, never 200 — same
  // contract as the direct-Express test in app.test.js.
  assert.notEqual(result.statusCode, 200);
});
