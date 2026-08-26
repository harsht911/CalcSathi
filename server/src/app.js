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

  return app;
}
