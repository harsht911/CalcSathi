import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/auth/presentation/email_link_handler.dart';
import 'features/auth/state/auth_state.dart';
import 'features/calculators/data/calculator_repository.dart';

/// App-wide navigator key so [EmailLinkHandler] can show a dialog / snack
/// bar from outside the widget tree that triggered it (an incoming deep
/// link isn't tied to any particular screen's BuildContext).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class CalcSathiApp extends StatelessWidget {
  /// [authRepository]/[calculatorRepository] are exposed purely so widget
  /// tests can inject repositories built on `firebase_auth_mocks` /
  /// `fake_cloud_firestore` instead of the real `FirebaseAuth.instance` /
  /// `FirebaseFirestore.instance` (which require a live Firebase app that CI
  /// doesn't have). Production code never passes either — the defaults
  /// build the real thing.
  const CalcSathiApp({super.key, AuthRepository? authRepository, CalculatorRepository? calculatorRepository})
      : _authRepository = authRepository,
        _calculatorRepository = calculatorRepository;

  final AuthRepository? _authRepository;
  final CalculatorRepository? _calculatorRepository;

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
        ChangeNotifierProxyProvider<AuthRepository, AuthState>(
          create: (context) => AuthState(context.read<AuthRepository>()),
          update: (context, repository, previous) => previous ?? AuthState(repository),
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
