# CalcSathi

Universal calculator platform — India-first, built to expand globally. A mobile app (Flutter, Android + iOS) with dozens of calculators, a coin-based free tier, Premium subscriptions, and a custom formula builder, backed by a Flutter Web admin panel.

## Repo layout

This is a monorepo. Each Flutter app is independent (its own `pubspec.yaml`, its own dependency versions) and pulls shared code from `packages/calc_core` as a local path dependency.

```
apps/
  mobile/        Flutter mobile app (Android + iOS) — the CalcSathi consumer app
  admin/         Flutter Web admin panel — internal tool for managing the calculator catalog, users, coins, subscriptions
packages/
  calc_core/     Shared Dart package: data models, the formula/calculation engine, design tokens — used by both apps
server/          Small Node/Express service for backend logic that Firebase's free Spark plan can't run as Cloud Functions
  (RevenueCat webhook receiver, server-side coin-economy validation, scheduled jobs). Deployed separately
  from Firebase — see server/README.md.
firebase/        firebase.json, Firestore security rules, and Firestore indexes — the config that IS deployable
  on the free Spark plan (no Cloud Functions live here).
.github/workflows/  CI — runs `flutter analyze` + `flutter test` for both apps and lint/test for the server,
  on GitHub's own runners (this repo's dev sandbox can't run the Flutter SDK directly — see note below).
```

## Why the server/ folder exists

Firebase Cloud Functions require the paid Blaze plan to deploy at all — there is no free-tier deploy path, regardless
of usage. Since this project is staying on the free Spark plan, anything that needs privileged server-side logic
(validating coin spends server-side so a client can't cheat, receiving RevenueCat's subscription webhooks, running
scheduled jobs like daily coin resets) runs instead as a small Node/Express app using the official `firebase-admin`
SDK, deployed to a free-tier host outside of Firebase (Render or Railway — see `server/README.md`). Everything else
(Auth, Firestore, Hosting, Cloud Messaging, Analytics, Crashlytics, App Check) runs on Firebase's free Spark plan
directly, no workaround needed.

## Auth

Primary sign-in: Google Sign-In and Sign in with Apple (one-tap, free on Spark, no per-use cost). Email/password is
the fallback for users without a Google/Apple account. Phone/OTP login is **not** used — real SMS delivery requires
Firebase's paid Blaze plan, which this project isn't on.

## Getting started (once Firebase project credentials exist)

This dev sandbox cannot download the Flutter SDK (network-restricted environment), so builds and tests run via
GitHub Actions CI on every push — see `.github/workflows/ci.yml`. To run locally on your own machine:

```
cd apps/mobile && flutter pub get && flutter run
cd apps/admin  && flutter pub get && flutter run -d chrome
cd server      && npm install && npm run dev
```

Each app needs its own `firebase_options.dart` (generated via `flutterfire configure`, not committed — see
`.gitignore`) once the Firebase project exists.
