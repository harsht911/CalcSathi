import { Router } from 'express';

import { getFirebaseAdmin } from '../firebaseAdmin.js';

export const revenueCatWebhookRouter = Router();

/**
 * Receives RevenueCat's subscription lifecycle events (INITIAL_PURCHASE,
 * RENEWAL, CANCELLATION, EXPIRATION, etc.) and mirrors entitlement state
 * into Firestore, so the mobile app can read "is this user Premium?"
 * straight from Firestore instead of calling RevenueCat directly.
 *
 * RevenueCat lets you set a fixed "Authorization header" value per webhook
 * in its dashboard (Project settings -> Integrations -> Webhooks); it sends
 * that value back verbatim on every request, which is what's checked below.
 * Confirm the exact header name/format against RevenueCat's current docs
 * when wiring this up for real — webhook auth mechanisms do get revised.
 */
revenueCatWebhookRouter.post('/', async (req, res) => {
  const expected = process.env.REVENUECAT_WEBHOOK_AUTH_TOKEN;
  const received = req.get('Authorization');

  if (!expected) {
    // Fail closed: an unconfigured server should never silently accept
    // unauthenticated webhook traffic.
    console.error('REVENUECAT_WEBHOOK_AUTH_TOKEN is not set; rejecting webhook.');
    return res.status(500).json({ error: 'server_misconfigured' });
  }
  if (received !== expected) {
    return res.status(401).json({ error: 'unauthorized' });
  }

  let payload;
  try {
    payload = JSON.parse(req.body.toString('utf8'));
  } catch {
    return res.status(400).json({ error: 'invalid_json' });
  }

  const event = payload?.event;
  if (!event?.app_user_id || !event?.type) {
    return res.status(400).json({ error: 'missing_event_fields' });
  }

  // Everything below talks to Firebase (service-account init + a Firestore
  // write), both of which can fail for reasons outside our control (bad/
  // expired credentials, a transient network error, a permissions issue).
  // This MUST be try/caught explicitly: Express 4 does not catch a
  // rejected promise thrown inside an async route handler on its own, so
  // an unguarded failure here becomes an unhandled rejection. Locally that
  // just logs a scary stack trace and hangs the request; on Lambda it
  // crashes the entire invocation, which is what produced the opaque
  // "Internal Server Error" (no JSON body, no detail) seen when this
  // webhook was first wired up — the real cause was invisible without this
  // catch block and a look at CloudWatch Logs.
  try {
    const admin = getFirebaseAdmin();
    const db = admin.firestore();

    // TODO: once the Firestore schema for users/{uid} is finalized, replace
    // this with the real entitlement fields (isPremium, expiresAt, plan, ...).
    await db
      .collection('users')
      .doc(event.app_user_id)
      .set(
        {
          lastRevenueCatEvent: {
            type: event.type,
            receivedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        { merge: true }
      );

    res.status(200).json({ received: true });
  } catch (err) {
    console.error('RevenueCat webhook: failed to write entitlement state to Firestore', err);
    res.status(500).json({ error: 'internal_error' });
  }
});
