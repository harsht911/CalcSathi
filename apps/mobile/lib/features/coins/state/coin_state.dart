import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../auth/state/auth_state.dart';
import '../data/coin_repository.dart';

/// Thin [ChangeNotifier] wrapper around [CoinRepository.watchBalance], so
/// widgets can `context.watch<CoinState>()` for the current coin balance
/// instead of each building their own `StreamBuilder` — mirrors
/// [AuthState]'s role for auth.
///
/// Unlike [AuthState] (which wraps a single always-available auth stream),
/// this has to react to the *signed-in user changing* — there's no
/// balance to watch before sign-in, and a different uid to watch after a
/// sign-out/sign-in as a different account. It does that by listening to
/// [AuthState] itself and re-subscribing to Firestore whenever the uid
/// changes, rather than being handed a fixed uid at construction time.
class CoinState extends ChangeNotifier {
  CoinState({required AuthState authState, required CoinRepository repository})
      : _authState = authState,
        _repository = repository {
    _authState.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  final AuthState _authState;
  final CoinRepository _repository;
  StreamSubscription<int>? _subscription;
  String? _subscribedUid;

  int _balance = 0;
  int get balance => _balance;

  void _onAuthChanged() {
    final uid = _authState.user?.uid;
    if (uid == _subscribedUid) return;
    _subscribedUid = uid;

    _subscription?.cancel();
    if (uid == null) {
      _subscription = null;
      _balance = 0;
      notifyListeners();
      return;
    }

    _subscription = _repository.watchBalance(uid).listen((balance) {
      _balance = balance;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authState.removeListener(_onAuthChanged);
    _subscription?.cancel();
    super.dispose();
  }
}
