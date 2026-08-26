import 'package:flutter/material.dart';

// NOTE: Firebase bootstrapping (Firebase.initializeApp) is intentionally
// left out of this scaffold. It depends on `firebase_options.dart`, which
// is generated locally by `flutterfire configure` and is gitignored (it
// contains project-specific API keys). Once Harsh runs that command against
// the real Firebase project, wire it in here:
//
//   import 'firebase_options.dart';
//   ...
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

void main() {
  runApp(const CalcSathiApp());
}

class CalcSathiApp extends StatelessWidget {
  const CalcSathiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CalcSathi',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2E7D5B),
      ),
      home: const _HomeScaffoldPlaceholder(),
    );
  }
}

/// Placeholder home screen. Replace with the real calculator catalog screen
/// (see the design canvas's Home.dc.html for the target layout).
class _HomeScaffoldPlaceholder extends StatelessWidget {
  const _HomeScaffoldPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CalcSathi')),
      body: const Center(
        child: Text('CalcSathi is under construction.'),
      ),
    );
  }
}
