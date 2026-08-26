import 'package:calcsathi_mobile/app.dart';
import 'package:calcsathi_mobile/features/auth/data/auth_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('signed-out user sees the sign-in screen', (tester) async {
    final authRepository = AuthRepository(
      firebaseAuth: MockFirebaseAuth(signedIn: false),
      firestore: FakeFirebaseFirestore(),
    );

    await tester.pumpWidget(CalcSathiApp(authRepository: authRepository));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('signed-in user with onboarding already complete lands on the home shell', (tester) async {
    final mockUser = MockUser(
      uid: 'test-uid',
      email: 'harsh@example.com',
      displayName: 'Harsh',
    );
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('test-uid').set({
      'uid': 'test-uid',
      'email': 'harsh@example.com',
      'onboardingComplete': true,
    });

    final authRepository = AuthRepository(
      firebaseAuth: MockFirebaseAuth(signedIn: true, mockUser: mockUser),
      firestore: firestore,
    );

    await tester.pumpWidget(CalcSathiApp(authRepository: authRepository));
    await tester.pumpAndSettle();

    expect(find.text('CalcSathi'), findsOneWidget);
    expect(find.textContaining('harsh@example.com'), findsOneWidget);
  });

  testWidgets('signed-in user with onboarding incomplete sees onboarding', (tester) async {
    final mockUser = MockUser(uid: 'test-uid-2', email: 'new@example.com');
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('test-uid-2').set({
      'uid': 'test-uid-2',
      'email': 'new@example.com',
      'onboardingComplete': false,
    });

    final authRepository = AuthRepository(
      firebaseAuth: MockFirebaseAuth(signedIn: true, mockUser: mockUser),
      firestore: firestore,
    );

    await tester.pumpWidget(CalcSathiApp(authRepository: authRepository));
    await tester.pumpAndSettle();

    expect(find.text('Dozens of calculators, one app'), findsOneWidget);
  });
}
