import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

/// Thrown by [CoinRepository.spend] when the server rejects a spend because
/// the caller's balance is too low (a race is always possible between the
/// client's last-known balance and the server's authoritative one — this is
/// the "someone else/another tab spent first" case, not a client bug).
class InsufficientCoinsException implements Exception {
  const InsufficientCoinsException(this.currentBalance);

  final int currentBalance;
}

/// Thrown by [CoinRepository.earnPlaceholderReward] when the per-user
/// cooldown (see `server/src/routes/coins.js`) hasn't elapsed yet.
class EarnCooldownException implements Exception {
  const EarnCooldownException(this.retryAfterSeconds);

  final int retryAfterSeconds;
}

/// Thrown for any other non-2xx response from `server/`'s coin endpoints —
/// a network failure, an expired ID token, or an unexpected server error.
class CoinServiceException implements Exception {
  const CoinServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Talks to `server/`'s `/coins/spend` and `/coins/earn` routes (the only
/// two places allowed to change `users/{uid}.coinBalance` — see
/// `firestore.rules`), and reads the balance itself straight from
/// Firestore, same as everything else in the app.
///
/// Takes an injected [FirebaseFirestore] and [http.Client] (not
/// `FirebaseFirestore.instance`/a bare `http.Client()`) so this can be
/// exercised in tests the same way [AuthRepository]/[CalculatorRepository]
/// are — `http.Client` in particular via `package:http/testing.dart`'s
/// `MockClient`, no real server required.
class CoinRepository {
  CoinRepository({
    required FirebaseFirestore firestore,
    required String serverBaseUrl,
    http.Client? httpClient,
  })  : _firestore = firestore,
        _serverBaseUrl = serverBaseUrl,
        _httpClient = httpClient ?? http.Client();

  final FirebaseFirestore _firestore;
  final String _serverBaseUrl;
  final http.Client _httpClient;

  /// Streams [uid]'s current coin balance, defaulting to 0 for a user doc
  /// that doesn't have the field yet (every user starts at 0 — see
  /// `AuthRepository._ensureUserDocument`, which deliberately never sets
  /// `coinBalance` itself, since Firestore rules reject a client `create`
  /// that includes it).
  Stream<int> watchBalance(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map(
          (snapshot) => (snapshot.data()?['coinBalance'] as num?)?.toInt() ?? 0,
        );
  }

  /// Spends [amount] coins for [reason] (a short machine-readable tag, e.g.
  /// `'calculator:emi'`, stored in the server-side coin ledger for
  /// auditing). Returns the new balance on success.
  ///
  /// Throws [InsufficientCoinsException] if the server's authoritative
  /// balance is too low, [CoinServiceException] for anything else that goes
  /// wrong.
  Future<int> spend({
    required String idToken,
    required int amount,
    required String reason,
  }) async {
    final response = await _post('/coins/spend', idToken, {
      'amount': amount,
      'reason': reason,
    });

    if (response.statusCode == 200) {
      return _balanceFrom(response);
    }
    if (response.statusCode == 409) {
      final body = _decodeBody(response);
      throw InsufficientCoinsException((body['coinBalance'] as num?)?.toInt() ?? 0);
    }
    throw CoinServiceException(_errorMessageFor(response));
  }

  /// Claims the placeholder coin reward (see the route's own doc comment
  /// in `server/src/routes/coins.js` for why this is a stand-in, not the
  /// real ad-based earn flow). Returns the new balance on success.
  ///
  /// Throws [EarnCooldownException] if called again before the server-side
  /// cooldown elapses, [CoinServiceException] for anything else.
  Future<int> earnPlaceholderReward({required String idToken}) async {
    final response = await _post('/coins/earn', idToken, const {});

    if (response.statusCode == 200) {
      return _balanceFrom(response);
    }
    if (response.statusCode == 429) {
      final body = _decodeBody(response);
      throw EarnCooldownException((body['retryAfterSeconds'] as num?)?.toInt() ?? 0);
    }
    throw CoinServiceException(_errorMessageFor(response));
  }

  Future<http.Response> _post(String path, String idToken, Map<String, dynamic> body) {
    return _httpClient.post(
      Uri.parse('$_serverBaseUrl$path'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
  }

  int _balanceFrom(http.Response response) =>
      (_decodeBody(response)['coinBalance'] as num?)?.toInt() ?? 0;

  Map<String, dynamic> _decodeBody(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }

  String _errorMessageFor(http.Response response) {
    final error = _decodeBody(response)['error'] as String?;
    return error ?? 'Something went wrong (HTTP ${response.statusCode}).';
  }
}
