import { Router } from 'express';
import admin from 'firebase-admin';

import { getFirebaseAdmin } from '../firebaseAdmin.js';

export const coinsRouter = Router();

// Fixed reward per /coins/earn call, and the minimum gap enforced between
// two rewards for the same user — see the route's own doc comment for why
// this whole endpoint is a placeholder, not the real reward mechanism.
const PLACEHOLDER_REWARD_AMOUNT = 10;
const PLACEHOLDER_REWARD_COOLDOWN_MS = 60 * 1000;

/**
 * Verifies the caller's Firebase ID token from the Authorization header
 * (`Bearer <idToken>`) and attaches the decoded token as req.user.
 * This is the check a Cloud Functions callable would normally do for you;
 * doing it explicitly here is the price of not having Cloud Functions.
 */
async function requireAuth(req, res, next) {
  const header = req.get('Authorization') || '';
  const match = header.match(/^Bearer (.+)$/);
  if (!match) {
    return res.status(401).json({ error: 'missing_bearer_token' });
  }

  try {
    const firebaseApp = getFirebaseAdmin();
    req.user = await firebaseApp.auth().verifyIdToken(match[1]);
    next();
  } catch {
    res.status(401).json({ error: 'invalid_token' });
  }
}

/**
 * Spends coins for an unlock action, atomically, server-side — so a
 * modified client can't just write a higher balance to Firestore directly.
 * Client calls this instead of decrementing users/{uid}.coinBalance itself;
 * Firestore security rules (see firebase/firestore.rules) should deny
 * direct client writes to coinBalance to make this the only path.
 */
coinsRouter.post('/spend', requireAuth, async (req, res) => {
  const { amount, reason } = req.body ?? {};

  if (!Number.isInteger(amount) || amount <= 0) {
    return res.status(400).json({ error: 'invalid_amount' });
  }
  if (typeof reason !== 'string' || reason.length === 0) {
    return res.status(400).json({ error: 'missing_reason' });
  }

  // Same shadowing pitfall as requireAuth() above and the RevenueCat
  // webhook route: getFirebaseAdmin() returns the App instance, not the
  // `admin` module, so it's named firebaseApp here to keep the real
  // `admin` import (needed below for admin.firestore.FieldValue) usable.
  const firebaseApp = getFirebaseAdmin();
  const db = firebaseApp.firestore();
  const userRef = db.collection('users').doc(req.user.uid);

  try {
    const newBalance = await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      const balance = snap.exists ? snap.data().coinBalance ?? 0 : 0;

      if (balance < amount) {
        throw new InsufficientCoinsError(balance);
      }

      const updated = balance - amount;
      tx.set(
        userRef,
        { coinBalance: updated },
        { merge: true }
      );
      tx.create(userRef.collection('coinLedger').doc(), {
        delta: -amount,
        reason,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return updated;
    });

    res.json({ coinBalance: newBalance });
  } catch (err) {
    if (err instanceof InsufficientCoinsError) {
      return res.status(409).json({ error: 'insufficient_coins', coinBalance: err.balance });
    }
    console.error('coin spend failed', err);
    res.status(500).json({ error: 'internal_error' });
  }
});

/**
 * Grants a fixed coin reward, atomically, server-side, gated by a simple
 * per-user cooldown stored in `users/{uid}.lastEarnAt` (protected by
 * Firestore rules the same way coinBalance is, so a client can't just
 * rewrite its own cooldown timestamp to farm rewards).
 *
 * This is a PLACEHOLDER for the real "coin-earn-via-ad" flow the milestone
 * roadmap calls for — no ad SDK is wired into the app yet, so there's no
 * real ad-completion event to verify against. It exists to unblock
 * building and testing the spend/gating flow end-to-end; swap it out (or
 * gate it behind real ad-completion verification, e.g. AdMob's server-side
 * reward callback) before depending on it for real economy balance. Don't
 * treat PLACEHOLDER_REWARD_AMOUNT/_COOLDOWN_MS as tuned values — they're
 * just large enough to make manual testing sane.
 */
coinsRouter.post('/earn', requireAuth, async (req, res) => {
  const firebaseApp = getFirebaseAdmin();
  const db = firebaseApp.firestore();
  const userRef = db.collection('users').doc(req.user.uid);

  try {
    const newBalance = await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      const data = snap.exists ? snap.data() : {};
      const balance = data?.coinBalance ?? 0;
      const lastEarnAt = data?.lastEarnAt;

      if (lastEarnAt) {
        const elapsedMs = Date.now() - lastEarnAt.toMillis();
        if (elapsedMs < PLACEHOLDER_REWARD_COOLDOWN_MS) {
          throw new EarnCooldownError(Math.ceil((PLACEHOLDER_REWARD_COOLDOWN_MS - elapsedMs) / 1000));
        }
      }

      const updated = balance + PLACEHOLDER_REWARD_AMOUNT;
      tx.set(
        userRef,
        {
          coinBalance: updated,
          lastEarnAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      tx.create(userRef.collection('coinLedger').doc(), {
        delta: PLACEHOLDER_REWARD_AMOUNT,
        reason: 'placeholder_reward',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return updated;
    });

    res.json({ coinBalance: newBalance });
  } catch (err) {
    if (err instanceof EarnCooldownError) {
      return res.status(429).json({ error: 'cooldown', retryAfterSeconds: err.retryAfterSeconds });
    }
    console.error('coin earn failed', err);
    res.status(500).json({ error: 'internal_error' });
  }
});

class InsufficientCoinsError extends Error {
  constructor(balance) {
    super('insufficient_coins');
    this.balance = balance;
  }
}

class EarnCooldownError extends Error {
  constructor(retryAfterSeconds) {
    super('cooldown');
    this.retryAfterSeconds = retryAfterSeconds;
  }
}
