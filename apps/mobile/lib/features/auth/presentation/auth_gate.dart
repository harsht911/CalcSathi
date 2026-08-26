import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../onboarding/presentation/onboarding_gate.dart';
import '../state/auth_state.dart';
import 'sign_in_screen.dart';

/// Root router: shows a spinner until the first auth-state event arrives,
/// then either the sign-in flow or [OnboardingGate] for a signed-in user.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();

    switch (authState.status) {
      case AuthStatus.unknown:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.signedOut:
        return const SignInScreen();
      case AuthStatus.signedIn:
        return OnboardingGate(uid: authState.user!.uid);
    }
  }
}
