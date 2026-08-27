import express from 'express';

import { revenueCatWebhookRouter } from './routes/revenueCatWebhook.js';
import { coinsRouter } from './routes/coins.js';

/**
 * Builds the Express app without starting a listener — kept separate from
 * index.js so tests can import and exercise it with supertest-style
 * requests instead of binding a real port.
 */
export function createApp() {
  const app = express();

  // RevenueCat sends the raw body for webhook signature/auth-header
  // verification (see routes/revenueCatWebhook.js), everything else is JSON.
  app.use('/webhooks/revenuecat', express.raw({ type: '*/*' }));
  app.use(express.json());

  app.get('/healthz', (req, res) => {
    res.json({ status: 'ok' });
  });

  app.use('/webhooks/revenuecat', revenueCatWebhookRouter);
  app.use('/coins', coinsRouter);

  // Catch-all error handler — belt-and-suspenders defense in depth. Every
  // route above already handles its own known failure modes explicitly and
  // responds with a clean JSON error; this only fires if something new
  // slips through uncaught. Without it, an escaped error falls through to
  // Express's default handler, which replies with a bare, undetailed
  // "Internal Server Error" — exactly the kind of response that's
  // impossible to debug on Lambda, where there's no live console to watch.
  // Logging err.stack here means the real cause always lands in CloudWatch
  // Logs (or the terminal, for local dev), whatever it turns out to be.
  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    console.error('Unhandled error:', err?.stack || err);
    if (res.headersSent) {
      return;
    }
    res.status(500).json({ error: 'internal_error' });
  });

  return app;
}
