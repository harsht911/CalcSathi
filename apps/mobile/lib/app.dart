import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/auth/presentation/email_link_handler.dart';
import 'features/auth/state/auth_state.dart';
import 'features/calculators/data/calculator_repository.dart';
import 'features/coins/data/coin_repository.dart';
import 'features/coins/state/coin_state.dart';

/// App-wide navigator key so [EmailLinkHandler] can show a dialog / snack
/// bar from outside the widget tree that triggered it (an incoming deep
/// link isn't tied to any particular screen's BuildContext).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Base URL of the `server/` deployment (currently an AWS Lambda Function
/// URL — see `server/README.md`), used by [CoinRepository] to call
/// `/coins/spend` and `/coins/earn`. Passed at build/run time via
/// `--dart-define=SERVER_BASE_URL=https://<function-url>` rather than
/// hardcoded, since it's per-environment config (local dev server vs. the
/// real deployment) the same way `firebase_options.dart` is generated
/// per-project rather than committed as a fixed value. Left empty by
/// default so a build without that flag still compiles and runs — it only
/// actually gets called for a calculator with a non-zero `coinCost`, which
/// defaults to 0 (free) everywhere until Harsh sets one.
const _serverBaseUrl = String.fromEnvironment('SERVER_BASE_URL');

class CalcSathiApp extends StatelessWidget {
  /// [authRepository]/[calculatorRepository]/[coinRepository] are exposed
  /// purely so widget tests can inject repositories built on
  /// `firebase_auth_mocks`/`fake_cloud_firestore` instead of the real
  /// `FirebaseAuth.instance`/`FirebaseFirestore.instance` (which require a
  /// live Firebase app that CI doesn't have). Production code never passes
  /// any of them — the defaults build the real thing.
  const CalcSathiApp({
    super.key,
    AuthRepository? authRepository,
    CalculatorRepository? calculatorRepository,
    CoinRepository? coinRepository,
  })  : _authRepository = authRepository,
        _calculatorRepository = calculatorRepository,
        _coinRepository = coinRepository;

  final AuthRepository? _authRepository;
  final CalculatorRepository? _calculatorRepository;
  final CoinRepository? _coinRepository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>(
          create: (_) =>
              _authRepository ??
              AuthRepository(
                firebaseAuth: FirebaseAuth.instance,
                firestore: FirebaseFirestore.instance,
              ),
        ),
        Provider<CalculatorRepository>(
          create: (_) =>
              _calculatorRepository ?? CalculatorRepository(firestore: FirebaseFirestore.instance),
        ),
        Provider<CoinRepository>(
          create: (_) =>
              _coinRepository ??
              CoinRepository(firestore: FirebaseFirestore.instance, serverBaseUrl: _serverBaseUrl),
        ),
        ChangeNotifierProxyProvider<AuthRepository, AuthState>(
          create: (context) => AuthState(context.read<AuthRepository>()),
          update: (context, repository, previous) => previous ?? AuthState(repository),
        ),
        ChangeNotifierProxyProvider2<AuthState, CoinRepository, CoinState>(
          create: (context) =>
              CoinState(authState: context.read<AuthState>(), repository: context.read<CoinRepository>()),
          update: (context, authState, repository, previous) =>
              previous ?? CoinState(authState: authState, repository: repository),
        ),
      ],
      child: EmailLinkHandler(
        navigatorKey: rootNavigatorKey,
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          title: 'CalcSathi',
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFF2E7D5B),
          ),
          home: const AuthGate(),
        ),
      ),
    );
  }
}
