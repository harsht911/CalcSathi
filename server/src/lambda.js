import 'dotenv/config';
import serverless from 'serverless-http';

import { createApp } from './app.js';

/**
 * AWS Lambda entry point — deployed behind a Lambda Function URL rather
 * than API Gateway (see server/README.md for why: Function URLs are billed
 * as plain Lambda invocations, which stay inside Lambda's Always-Free tier
 * forever; API Gateway's free tier is capped at 12 months and then charges
 * per request, which would eventually break the "must run on a free tier"
 * constraint this whole service exists under).
 *
 * Function URLs deliver requests using the same "payload format 2.0" event
 * shape as an API Gateway HTTP API, which is exactly what serverless-http
 * expects — so this file is the only AWS-specific code in the service.
 * index.js (the `npm start`/local-dev entry point) and every route/test
 * still work unmodified, because both entry points share the same
 * createApp() Express instance.
 *
 * serverless-http auto-decodes a base64 request body when the incoming
 * event has isBase64Encoded: true (which Function URLs set for content
 * types outside their default text/JSON allowlist), so the RevenueCat
 * webhook route's express.raw() body handling in app.js needs no changes
 * to work correctly here.
 */
const app = createApp();

export const handler = serverless(app);
