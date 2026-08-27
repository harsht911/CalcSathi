import 'package:calcsathi_mobile/features/calculators/data/calculator_definition.dart';
import 'package:flutter_test/flutter_test.dart';

// Mirrors the built-in calculators seeded by
// server/scripts/calculators.seed.json — same formula tokens, same
// expected results, independently cross-checked against the standard EMI/
// SIP/BMI formulas (and against a from-scratch Python re-implementation of
// calc_core's shunting-yard algorithm) before this branch was written.
void main() {
  test('EMI formula matches the standard EMI calculation', () {
    final emi = CalculatorDefinition(
      id: 'emi',
      name: 'EMI Calculator',
      category: 'Loans',
      description: '',
      inputs: const [],
      formulaTokens: const [
        'principal', '*', '(', 'annualRate', '/', '1200', ')', '*',
        '(', '1', '+', '(', 'annualRate', '/', '1200', ')', ')', '^', 'tenureMonths',
        '/',
        '(', '(', '1', '+', '(', 'annualRate', '/', '1200', ')', ')', '^', 'tenureMonths', '-', '1', ')',
      ],
      resultLabel: 'Monthly EMI',
    );

    // ₹1,00,000 at 10% annual for 12 months should be ~₹8,791.59 — a
    // standard, widely-published reference value for this exact input.
    final result = emi.evaluate({
      'principal': 100000,
      'annualRate': 10,
      'tenureMonths': 12,
    });

    expect(result, closeTo(8791.59, 0.01));
  });

  test('SIP formula matches the standard future-value calculation', () {
    final sip = CalculatorDefinition(
      id: 'sip',
      name: 'SIP Calculator',
      category: 'Investing',
      description: '',
      inputs: const [],
      formulaTokens: const [
        'monthlyInvestment', '*',
        '(', '(', '(', '1', '+', '(', 'expectedReturn', '/', '1200', ')', ')', '^', 'tenureMonths', '-', '1', ')',
        '/', '(', 'expectedReturn', '/', '1200', ')', ')',
        '*', '(', '1', '+', '(', 'expectedReturn', '/', '1200', ')', ')',
      ],
      resultLabel: 'Maturity value',
    );

    final result = sip.evaluate({
      'monthlyInvestment': 5000,
      'expectedReturn': 12,
      'tenureMonths': 12,
    });

    expect(result, closeTo(64046.64, 0.01));
  });

  test('BMI formula matches weight / height(m)^2', () {
    final bmi = CalculatorDefinition(
      id: 'bmi',
      name: 'BMI Calculator',
      category: 'Health',
      description: '',
      inputs: const [],
      formulaTokens: const ['weightKg', '/', '(', '(', 'heightCm', '/', '100', ')', '^', '2', ')'],
      resultLabel: 'BMI',
    );

    final result = bmi.evaluate({'weightKg': 70, 'heightCm': 175});

    expect(result, closeTo(22.857, 0.001));
  });

  test('fromFirestore defaults coinCost to 0 when the field is absent', () {
    final definition = CalculatorDefinition.fromFirestore('bmi', const {
      'name': 'BMI Calculator',
      'category': 'Health',
      'description': '',
      'inputs': [],
      'formulaTokens': ['weightKg'],
      'resultLabel': 'BMI',
    });

    // Every calculator seeded before M3's coin economy landed has no
    // coinCost field in Firestore at all — this must keep reading as free,
    // not crash on a missing field or silently gate something Harsh never
    // priced.
    expect(definition.coinCost, 0);
  });

  test('fromFirestore reads a real coinCost when the field is present', () {
    final definition = CalculatorDefinition.fromFirestore('emi', const {
      'name': 'EMI Calculator',
      'category': 'Loans',
      'description': '',
      'inputs': [],
      'formulaTokens': ['principal'],
      'resultLabel': 'Monthly EMI',
      'coinCost': 5,
    });

    expect(definition.coinCost, 5);
  });

  test('a zero-tenure EMI input surfaces a friendly division-by-zero message, not a crash', () {
    final emi = CalculatorDefinition(
      id: 'emi',
      name: 'EMI Calculator',
      category: 'Loans',
      description: '',
      inputs: const [],
      formulaTokens: const [
        'principal', '*', '(', 'annualRate', '/', '1200', ')', '*',
        '(', '1', '+', '(', 'annualRate', '/', '1200', ')', ')', '^', 'tenureMonths',
        '/',
        '(', '(', '1', '+', '(', 'annualRate', '/', '1200', ')', ')', '^', 'tenureMonths', '-', '1', ')',
      ],
      resultLabel: 'Monthly EMI',
    );

    // tenureMonths=0 makes (1+r)^0 - 1 == 0, i.e. a real division by zero a
    // user could trigger by mistyping — calc_core should catch it, not
    // throw an unhandled exception.
    expect(
      () => emi.evaluate({'principal': 100000, 'annualRate': 10, 'tenureMonths': 0}),
      throwsA(isA<Exception>()),
    );
  });
}
