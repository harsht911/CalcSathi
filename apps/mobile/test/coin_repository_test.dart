import 'dart:convert';

import 'package:calcsathi_mobile/features/coins/data/coin_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Exercises CoinRepository's HTTP handling against a MockClient standing in
// for server/'s real /coins/spend and /coins/earn routes — no real server
// or network access needed, and no Flutter widget tree either (this is
// plain Dart logic). watchBalance() is covered separately with
// fake_cloud_firestore, matching CalculatorRepository's own test style.
void main() {
  group('watchBalance', () {
    test('defaults to 0 for a user doc with no coinBalance field yet', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set({'email': 'a@b.com'});

      final repository = CoinRepository(firestore: firestore, serverBaseUrl: 'https://example.invalid');
      final balance = await repository.watchBalance('u1').first;

      expect(balance, 0);
    });

    test('reads the real coinBalance once the field exists', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set({'coinBalance': 42});

      final repository = CoinRepository(firestore: firestore, serverBaseUrl: 'https://example.invalid');
      final balance = await repository.watchBalance('u1').first;

      expect(balance, 42);
    });
  });

  group('spend', () {
    test('returns the new balance on a 200', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://example.invalid/coins/spend');
        expect(request.headers['Authorization'], 'Bearer test-token');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['amount'], 5);
        expect(body['reason'], 'calculator:emi');
        return http.Response(jsonEncode({'coinBalance': 15}), 200);
      });
      final repository = CoinRepository(
        firestore: FakeFirebaseFirestore(),
        serverBaseUrl: 'https://example.invalid',
        httpClient: client,
      );

      final balance = await repository.spend(idToken: 'test-token', amount: 5, reason: 'calculator:emi');

      expect(balance, 15);
    });

    test('throws InsufficientCoinsException on a 409, carrying the real balance', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'insufficient_coins', 'coinBalance': 3}), 409);
      });
      final repository = CoinRepository(
        firestore: FakeFirebaseFirestore(),
        serverBaseUrl: 'https://example.invalid',
        httpClient: client,
      );

      await expectLater(
        repository.spend(idToken: 't', amount: 5, reason: 'calculator:emi'),
        throwsA(isA<InsufficientCoinsException>().having((e) => e.currentBalance, 'currentBalance', 3)),
      );
    });

    test('throws CoinServiceException on any other non-2xx', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'internal_error'}), 500);
      });
      final repository = CoinRepository(
        firestore: FakeFirebaseFirestore(),
        serverBaseUrl: 'https://example.invalid',
        httpClient: client,
      );

      expect(
        repository.spend(idToken: 't', amount: 5, reason: 'calculator:emi'),
        throwsA(isA<CoinServiceException>()),
      );
    });
  });

  group('earnPlaceholderReward', () {
    test('returns the new balance on a 200', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://example.invalid/coins/earn');
        return http.Response(jsonEncode({'coinBalance': 10}), 200);
      });
      final repository = CoinRepository(
        firestore: FakeFirebaseFirestore(),
        serverBaseUrl: 'https://example.invalid',
        httpClient: client,
      );

      final balance = await repository.earnPlaceholderReward(idToken: 't');

      expect(balance, 10);
    });

    test('throws EarnCooldownException on a 429, carrying retryAfterSeconds', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'cooldown', 'retryAfterSeconds': 42}), 429);
      });
      final repository = CoinRepository(
        firestore: FakeFirebaseFirestore(),
        serverBaseUrl: 'https://example.invalid',
        httpClient: client,
      );

      await expectLater(
        repository.earnPlaceholderReward(idToken: 't'),
        throwsA(isA<EarnCooldownException>().having((e) => e.retryAfterSeconds, 'retryAfterSeconds', 42)),
      );
    });
  });
}
