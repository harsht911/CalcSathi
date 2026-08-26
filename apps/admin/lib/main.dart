import 'package:flutter/material.dart';

// See apps/mobile/lib/main.dart for why Firebase.initializeApp is not wired
// up yet — same reasoning (firebase_options.dart is generated later, per
// platform, by `flutterfire configure`, and is gitignored).

void main() {
  runApp(const CalcSathiAdminApp());
}

class CalcSathiAdminApp extends StatelessWidget {
  const CalcSathiAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CalcSathi Admin',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2E7D5B),
      ),
      home: const _AdminHomePlaceholder(),
    );
  }
}

/// Placeholder admin dashboard. Replace with the real admin panel screens
/// (see the design canvas's admin artboards on page-3 for the target layout).
class _AdminHomePlaceholder extends StatelessWidget {
  const _AdminHomePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CalcSathi Admin')),
      body: const Center(
        child: Text('Admin panel is under construction.'),
      ),
    );
  }
}
