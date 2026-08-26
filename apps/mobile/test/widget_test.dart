import 'package:calcsathi_mobile/app.dart';
import 'package:calcsathi_mobile/features/auth/data/auth_repository.dart';
import 'package:calcsathi_mobile/features/calculators/data/calculator_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _bmiCalculator = {
  'name': 'BMI Calculator',
  'category': 'Health',
  'description': 'Body Mass Index from your weight and height.',
  'inputs': [
    {'key': 'weightKg', 'label': 'Weight', 'suffix': 'kg'},
    {'key': 'heightCm', 'label': 'Height', 'suffix': 'cm'},
  ],
  'formulaTokens': ['weightKg', '/', '(', '(', 'heightCm', '/', '100', ')', '^', '2', ')'],
  'resultLabel': 'BMI',
  'resultSuffix': '',
  'resultDecimalPlaces': 1,
};

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

    await tester.pumpWidget(CalcSathiApp(
      authRepository: authRepository,
      calculatorRepository: CalculatorRepository(firestore: firestore),
    ));
    await tester.pumpAndSettle();

    expect(find.text('CalcSathi'), findsOneWidget);
    // Empty catalog (nothing seeded in this test's Firestore) — the empty
    // state, not a crash, is the correctness bar here.
    expect(find.text('No calculators yet — check back soon.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
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

    await tester.pumpWidget(CalcSathiApp(
      authRepository: authRepository,
      calculatorRepository: CalculatorRepository(firestore: firestore),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Dozens of calculators, one app'), findsOneWidget);
  });

  testWidgets('catalog -> run a calculator -> see the result, end to end', (tester) async {
    final mockUser = MockUser(uid: 'test-uid-3', email: 'runner@example.com');
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('test-uid-3').set({
      'uid': 'test-uid-3',
      'email': 'runner@example.com',
      'onboardingComplete': true,
    });
    await firestore.collection('calculators').doc('bmi').set(_bmiCalculator);

    final authRepository = AuthRepository(
      firebaseAuth: MockFirebaseAuth(signedIn: true, mockUser: mockUser),
      firestore: firestore,
    );
    final calculatorRepository = CalculatorRepository(firestore: firestore);

    await tester.pumpWidget(CalcSathiApp(
      authRepository: authRepository,
      calculatorRepository: calculatorRepository,
    ));
    await tester.pumpAndSettle();

    expect(find.text('BMI Calculator'), findsOneWidget);
    await tester.tap(find.text('BMI Calculator'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), '70');
    await tester.enterText(fields.at(1), '175');
    await tester.tap(find.text('Calculate'));
    await tester.pumpAndSettle();

    // 70 / (1.75^2) = 22.857... -> "22.9" at 1 decimal place.
    expect(find.text('22.9'), findsOneWidget);

    // The run should also have landed in Firestore history.
    final history = await firestore.collection('users').doc('test-uid-3').collection('history').get();
    expect(history.docs, hasLength(1));
    expect(history.docs.single.data()['calculatorId'], 'bmi');
  });
}
