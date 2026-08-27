# CalcSathi server

A small Node/Express service that exists because Firebase's free Spark plan
cannot deploy Cloud Functions at all (that requires the paid Blaze plan,
regardless of usage). It talks to Firebase using the `firebase-admin` SDK,
the same way a Cloud Function would.

**Deploys to AWS Lambda, behind a Lambda Function URL — not API Gateway.**
`src/index.js` (a plain `app.listen()`) still works for local dev exactly as
before; `src/lambda.js` wraps the same Express app with
[`serverless-http`](https://www.npmjs.com/package/serverless-http) for
production. Function URLs were chosen deliberately over API Gateway: a
Function URL is billed as a plain Lambda invocation, which stays inside
Lambda's **Always Free** tier (1M requests + 400,000 GB-seconds/month,
permanent, no time limit) forever. API Gateway's free tier, in contrast, is
capped at 12 months and then charges per request — that would eventually
break the "must run on a free tier" constraint this whole service exists
under. (Render/Railway were the original candidates and remain valid
fallbacks if Lambda ever stops being the right fit — nothing here is
locked in.)

## What it does

- `GET /healthz` — liveness check for the host's uptime monitor.
- `POST /webhooks/revenuecat` — receives RevenueCat subscription events and
  mirrors entitlement state into Firestore (`users/{uid}`).
- `POST /coins/spend` — spends coins for an unlock action inside a Firestore
  transaction, server-side, so a modified client can't just overwrite its
  own coin balance. Requires a Firebase ID token in `Authorization: Bearer
  <token>`.
- `POST /coins/earn` — grants a fixed, cooldown-limited coin reward.
  **Placeholder** for the real ad-based earn flow (no ad SDK is wired into
  the app yet) — see the route's doc comment in `src/routes/coins.js`.
  Same auth requirement as `/coins/spend`.

## Local setup

```
cd server
cp .env.example .env   # then fill in FIREBASE_SERVICE_ACCOUNT and REVENUECAT_WEBHOOK_AUTH_TOKEN
npm install
npm run dev
```

## Deploying to AWS Lambda

1. **Build the deployable zip:** `npm run package:lambda` (from `server/`).
   This runs `npm ci --omit=dev` in a throwaway temp directory — never the
   local `node_modules` — and produces `server/lambda-deploy.zip` (gitignored;
   never commit it). Re-run this any time the code or dependencies change.
2. **Create the function** (AWS Console -> Lambda -> Create function):
   - Runtime: **Node.js 20.x** (matches `engines.node` in `package.json`).
   - Architecture: `x86_64` is fine for this workload.
   - Upload `lambda-deploy.zip` directly (Code source -> Upload from -> .zip
     file) — at ~14 MB it's well under the 50 MB console-upload limit, no S3
     step needed.
   - Handler: `src/lambda.handler`.
3. **Set environment variables** (Configuration -> Environment variables) —
   the same two from `.env.example`: `FIREBASE_SERVICE_ACCOUNT` (the
   minified service-account JSON) and `REVENUECAT_WEBHOOK_AUTH_TOKEN`.
   Lambda encrypts these at rest by default; never commit a real `.env` or
   service-account JSON (see the repo's `.gitignore`).
4. **Bump memory/timeout** slightly past the 128 MB/3s defaults —
   256 MB memory and a 10s timeout is comfortable headroom for this
   workload's Firestore round-trips, and still leaves the Always-Free
   400,000 GB-seconds/month budget covering well over a million requests a
   month at that size.
5. **Enable a Function URL** (Configuration -> Function URL -> Create
   function URL). Auth type **NONE** is correct here — the RevenueCat
   webhook route already checks `REVENUECAT_WEBHOOK_AUTH_TOKEN` itself, and
   `/coins/spend` already requires a Firebase ID token; Lambda-level auth
   would be redundant, not additional security.
6. Point RevenueCat's webhook URL (Project settings -> Integrations ->
   Webhooks, in the RevenueCat dashboard) at
   `<function-url>/webhooks/revenuecat`, with the same Authorization header
   value as `REVENUECAT_WEBHOOK_AUTH_TOKEN`.
7. **Set an AWS Budget + billing alarm** (Billing console -> Budgets), e.g.
   trip at $1 — a free no-cost safety net regardless of how everything
   above is configured.

To redeploy after a code change: re-run `npm run package:lambda`, then in
the Lambda console, Code -> Upload from -> .zip file again with the new
`lambda-deploy.zip`.

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
