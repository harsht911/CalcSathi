import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thrown for auth failures we want to show a friendly message for, instead
/// of leaking a raw [FirebaseAuthException] message to the UI.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Wraps FirebaseAuth + the individual sign-in providers, and makes sure a
/// `users/{uid}` Firestore document exists after every successful sign-in.
///
/// Deliberately does NOT touch `coinBalance` here — the Firestore rules
/// (see `firestore.rules`) reject any client write that includes it, and
/// the only path allowed to set it is `server/`'s `/coins/spend` route via
/// the Admin SDK (landing in M3).
class AuthRepository {
  AuthRepository({
    required FirebaseAuth firebaseAuth,
    required FirebaseFirestore firestore,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth,
        _firestore = firestore,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _ensureUserDocument(credential.user);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  Future<void> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _ensureUserDocument(credential.user);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User dismissed the account picker — not an error.
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      await _ensureUserDocument(userCredential.user);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  /// Step 1 of passwordless sign-in: emails a sign-in link.
  ///
  /// `actionCodeSettings` is passed in from the caller rather than built
  /// here, since the correct URL depends on the Firebase Hosting domain
  /// Harsh configures for this project — see
  /// `apps/mobile/docs/email-link-setup.md`.
  Future<void> sendSignInLinkToEmail({
    required String email,
    required ActionCodeSettings actionCodeSettings,
  }) async {
    try {
      await _firebaseAuth.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  bool isSignInWithEmailLink(String link) {
    return _firebaseAuth.isSignInWithEmailLink(link);
  }

  /// Step 2: completes the sign-in once the user has tapped the emailed
  /// link and the app has received it (see [EmailLinkHandler]).
  Future<void> signInWithEmailLink({
    required String email,
    required String emailLink,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailLink(
        email: email,
        emailLink: emailLink,
      );
      await _ensureUserDocument(credential.user);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Streams whether [uid]'s onboarding is complete (see
  /// `OnboardingGate`/`OnboardingScreen`). Goes through the same injected
  /// [FirebaseFirestore] as everything else in this repository, rather than
  /// `FirebaseFirestore.instance`, so it can be exercised in widget tests
  /// with `fake_cloud_firestore` too.
  Stream<bool> onboardingCompleteStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map(
          (snapshot) => (snapshot.data()?['onboardingComplete'] as bool?) ?? false,
        );
  }

  Future<void> markOnboardingComplete(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'onboardingComplete': true,
    });
  }

  Future<void> _ensureUserDocument(User? user) async {
    if (user == null) return;
    final docRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await docRef.get();
    if (snapshot.exists) return;

    // Only ever reached when the doc doesn't exist yet, so this evaluates
    // against the Firestore rule's `allow create` path (not `update`).
    await docRef.set({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'createdAt': FieldValue.serverTimestamp(),
      'onboardingComplete': false,
      // No `coinBalance` field here — Firestore rules reject a `create`
      // that includes it. A starting balance gets assigned separately by
      // `server/` via the Admin SDK once that exists (M3).
    });
  }

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return "That email address doesn't look right.";
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Choose a stronger password (at least 6 characters).';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error — check your connection and try again.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}
