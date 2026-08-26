import 'package:firebase_auth/firebase_auth.dart';

/// SharedPreferences key used to remember which email address a
/// passwordless sign-in link was sent to, so [EmailLinkHandler] can
/// complete the sign-in without asking again when the link is opened on
/// the same device it was requested from.
const emailLinkCachedEmailKey = 'calcsathi.emailLinkSignIn.email';

/// ActionCodeSettings for passwordless email-link sign-in.
///
/// IMPORTANT: Firebase Dynamic Links — which email-link sign-in used to
/// rely on for the mobile deep link — shut down in August 2025. Email-link
/// sign-in now needs its own domain configured through Firebase Hosting
/// instead, plus native App Links (Android) / Universal Links (iOS)
/// configuration. The URL below is a placeholder built from this project's
/// default Hosting domain and MUST be confirmed/adjusted against
/// `apps/mobile/docs/email-link-setup.md` before this flow works
/// end-to-end — it will compile and run, but the link will only actually
/// open the app once that console + native-project setup is done.
final ActionCodeSettings emailLinkActionCodeSettings = ActionCodeSettings(
  url: 'https://calc-sathi.firebaseapp.com/emailLinkSignIn',
  handleCodeInApp: true,
  androidPackageName: 'com.calcsathi.app',
  androidInstallApp: true,
  androidMinimumVersion: '1',
  iOSBundleId: 'com.calcsathi.app',
);
