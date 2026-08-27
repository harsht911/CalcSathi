import { Router } from 'express';
import admin from 'firebase-admin';

import { getFirebaseAdmin } from '../firebaseAdmin.js';

export const coinsRouter = Router();

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

class InsufficientCoinsError extends Error {
  constructor(balance) {
    super('insufficient_coins');
    this.balance = balance;
  }
}
