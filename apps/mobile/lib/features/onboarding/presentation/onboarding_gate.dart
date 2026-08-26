import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/data/auth_repository.dart';
import '../../home/presentation/home_shell.dart';
import 'onboarding_screen.dart';

/// Watches the signed-in user's `onboardingComplete` flag (set on their
/// `users/{uid}` doc by [AuthRepository] on first sign-in) and shows the
/// onboarding flow or the home shell accordingly.
///
/// Deliberately Firestore-backed rather than local device storage, so
/// onboarding follows the account across devices/reinstalls instead of
/// repeating. Reads through the injected [AuthRepository] (not
/// `FirebaseFirestore.instance` directly) so this stays testable with
/// `fake_cloud_firestore`, same as the rest of the auth flow.
class OnboardingGate extends StatelessWidget {
  const OnboardingGate({required this.uid, super.key});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<AuthRepository>();

    return StreamBuilder<bool>(
      stream: repository.onboardingCompleteStream(uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data! ? const HomeShell() : const OnboardingScreen();
      },
    );
  }
}
