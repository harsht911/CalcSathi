# CalcSathi server

A small Node/Express service that exists because Firebase's free Spark plan
cannot deploy Cloud Functions at all (that requires the paid Blaze plan,
regardless of usage). This service runs anywhere that hosts a plain Node
process for free — [Render](https://render.com) or
[Railway](https://railway.app) both have a free tier suitable for this —
and talks to Firebase using the `firebase-admin` SDK, the same way a Cloud
Function would.

## What it does

- `GET /healthz` — liveness check for the host's uptime monitor.
- `POST /webhooks/revenuecat` — receives RevenueCat subscription events and
  mirrors entitlement state into Firestore (`users/{uid}`).
- `POST /coins/spend` — spends coins for an unlock action inside a Firestore
  transaction, server-side, so a modified client can't just overwrite its
  own coin balance. Requires a Firebase ID token in `Authorization: Bearer
  <token>`.

## Local setup

```
cd server
cp .env.example .env   # then fill in FIREBASE_SERVICE_ACCOUNT and REVENUECAT_WEBHOOK_AUTH_TOKEN
npm install
npm run dev
```

## Deploying (Render or Railway free tier)

1. Push this repo to GitHub (already done once the initial scaffold lands).
2. On Render/Railway, create a new Web Service pointing at this repo with
   root directory `server/`, build command `npm install`, start command
   `npm start`.
3. Set the environment variables from `.env.example` as secrets on the host
   — do not commit a real `.env` or service-account JSON (see the repo's
   `.gitignore`).
4. Point RevenueCat's webhook URL at `https://<your-host>/webhooks/revenuecat`
   and set the same Authorization header value there.

## Seeding the calculator catalog

`apps/mobile`'s catalog screen reads from Firestore's `calculators`
collection. Firestore rules only let admins write there, and there's no
admin-panel UI for it yet (that's M5), so for now it's seeded with this
script using the Admin SDK (same `.env` setup as above):

```
node scripts/seed-calculators.js
```

Edit `scripts/calculators.seed.json` to add/change calculators, then re-run
— it's safe to re-run any time, each calculator has a fixed document ID so
this overwrites rather than duplicating.

## Testing

```
npm test
```

Uses Node's built-in test runner (`node:test`) rather than an extra
dependency — see `test/app.test.js`.
