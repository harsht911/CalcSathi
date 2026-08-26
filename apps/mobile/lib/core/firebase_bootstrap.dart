import 'dart:ui';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../firebase_options.dart';

/// Boots Firebase and wires up Crashlytics + App Check before [runApp] is
/// called from `main.dart`.
///
/// Analytics needs no explicit init beyond `Firebase.initializeApp` —
/// `FirebaseAnalytics.instance` is ready to use as soon as this returns.
Future<void> bootstrapFirebase() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check — protects Firestore/Auth from abuse without needing a paid
  // plan. Play Integrity on Android, App Attest on iOS; debug builds use
  // the debug providers instead so a local dev build isn't throttled by
  // production attestation (Harsh needs to register the printed debug
  // token in the Firebase Console the first time a debug build runs).
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
  );

  // Route uncaught Flutter framework errors and async errors to
  // Crashlytics as fatal, per Firebase's official Flutter setup guide.
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}
