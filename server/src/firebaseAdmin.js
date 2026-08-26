import admin from 'firebase-admin';

// Reads the Firebase service-account key from an env var (set on
// Render/Railway as a secret) rather than a committed JSON file — see
// .gitignore, which blocks any *serviceAccountKey*.json from ever being
// added to the repo. Generate the key in the Firebase console under
// Project settings -> Service accounts -> Generate new private key, then
// paste the whole JSON, minified to one line, into FIREBASE_SERVICE_ACCOUNT.
let app;

export function getFirebaseAdmin() {
  if (app) return app;

  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!raw) {
    throw new Error(
      'FIREBASE_SERVICE_ACCOUNT is not set. Copy server/.env.example to server/.env ' +
        'and fill it in for local dev, or set it as a secret on your host for production.'
    );
  }

  const serviceAccount = JSON.parse(raw);
  app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  return app;
}
