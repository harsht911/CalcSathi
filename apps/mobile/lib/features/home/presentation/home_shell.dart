import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/state/auth_state.dart';

/// Placeholder home shell — replaced by the real calculator catalog in M2.
/// For M1 the bar is just "a signed-in, onboarded user lands here."
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CalcSathi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => authState.repository.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calculate_outlined, size: 64),
            const SizedBox(height: 16),
            Text('Signed in as ${user?.email ?? user?.displayName ?? user?.uid ?? 'unknown'}'),
            const SizedBox(height: 8),
            const Text('The calculator catalog lands in M2.'),
          ],
        ),
      ),
    );
  }
}
