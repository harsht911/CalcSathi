import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// Thin [ChangeNotifier] wrapper around [AuthRepository.authStateChanges]
/// so widgets can `context.watch<AuthState>()` instead of each building
/// their own `StreamBuilder`.
class AuthState extends ChangeNotifier {
  AuthState(this.repository) {
    _subscription = repository.authStateChanges.listen(_onUserChanged);
  }

  final AuthRepository repository;
  late final StreamSubscription<User?> _subscription;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;

  AuthStatus get status => _status;
  User? get user => _user;

  void _onUserChanged(User? user) {
    _user = user;
    _status = user == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
