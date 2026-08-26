# Email-link (passwordless) sign-in — console + native setup

The app-side code for email-link sign-in (`EmailLinkSignInScreen`,
`EmailLinkHandler`, `AuthRepository.sendSignInLinkToEmail` /
`signInWithEmailLink`) is already written and merges with the rest of
`feature/auth-screens`. It will **compile and run**, but the emailed link
won't actually reopen the app until the steps below are done in the
Firebase Console and in the native Android/iOS projects. This is
console/Xcode/Android-Studio work only Harsh can do — Claude has no access
to any of it.

## Why this needs extra setup (and didn't used to)

Email-link sign-in used to rely on **Firebase Dynamic Links** to turn the
emailed URL into something that reopens the app on a phone. Dynamic Links
shut down in August 2025, so Firebase Auth now expects the link to point at
a domain you control instead — normally your project's own Firebase
Hosting domain (`calc-sathi.firebaseapp.com` or `calc-sathi.web.app`) —
with the app registered to intercept HTTPS links to that domain via
Android App Links / iOS Universal Links.

Reference: [Firebase's email-link migration guide (Android)](https://firebase.google.com/docs/auth/android/email-link-migration),
[same for iOS](https://firebase.google.com/docs/auth/ios/email-link-migration).

## Steps

1. **Deploy something to Firebase Hosting**, even a placeholder page, so
   `calc-sathi.firebaseapp.com` (or your custom domain, if you set one up)
   resolves. Firebase Hosting is free on Spark. `firebase init hosting`
   then `firebase deploy --only hosting` from the repo root is enough for
   now — the actual content of the page doesn't matter for this.

2. **In the Firebase Console → Authentication → Settings → Authorized
   domains**, confirm `calc-sathi.firebaseapp.com` is listed (it should be
   by default once Hosting is set up).

3. **Confirm/update the action URL.** `lib/features/auth/data/email_link_config.dart`
   currently hardcodes:

   ```dart
   url: 'https://calc-sathi.firebaseapp.com/emailLinkSignIn',
   ```

   If you set up a custom Hosting domain instead of the default one,
   update this to match — Claude can make that one-line edit once you
   confirm the domain.

4. **Android** — add an App Links intent filter to
   `apps/mobile/android/app/src/main/AndroidManifest.xml`, inside the
   `<activity>` block for `MainActivity`:

   ```xml
   <intent-filter android:autoVerify="true">
     <action android:name="android.intent.action.VIEW" />
     <category android:name="android.intent.category.DEFAULT" />
     <category android:name="android.intent.category.BROWSABLE" />
     <data android:scheme="https" android:host="calc-sathi.firebaseapp.com" />
   </intent-filter>
   ```

   `android:autoVerify="true"` is what makes Android treat this as a
   verified App Link (opens directly in the app) rather than just offering
   the app as a browser choice.

5. **iOS** — in Xcode, add an Associated Domain under Runner target →
   Signing & Capabilities → Associated Domains:

   ```
   applinks:calc-sathi.firebaseapp.com
   ```

   Firebase Hosting automatically serves the required
   `apple-app-site-association` file for this once your app is registered
   in the Firebase Console with its bundle ID (`com.calcsathi.app`) and
   Apple Team ID — no manual file hosting needed.

6. **Test end-to-end**: request a link from the app, open the emailed link
   on the same device, confirm it reopens CalcSathi and completes sign-in
   rather than opening a browser tab.

## What's already handled in code

- `AuthRepository.sendSignInLinkToEmail` / `signInWithEmailLink` — wraps
  the `firebase_auth` calls.
- `EmailLinkSignInScreen` — collects the email, sends the link, caches the
  email locally (`shared_preferences`) so completing sign-in on the same
  device doesn't ask again.
- `EmailLinkHandler` — listens for the incoming link via `app_links`
  (`uriLinkStream`, which covers both a cold app-start from the link and a
  link received while the app is already running), and prompts for the
  email if the link was opened on a different device than it was
  requested from.

Until the steps above are done, the "Sign in with an email link instead"
flow will still send the email and the link will still work in a browser
(completing sign-in on Firebase's side), but tapping it on a phone won't
reopen the app automatically — worth deferring if it's not on the critical
path for early testing, since Email/Password and Google Sign-In don't
depend on any of this.
