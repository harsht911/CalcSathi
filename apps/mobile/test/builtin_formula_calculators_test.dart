import 'package:calcsathi_mobile/features/calculators/data/calculator_definition.dart';
import 'package:flutter_test/flutter_test.dart';

// Direct evaluation checks for the M2 formula-based calculators' token
// arrays (must stay in sync with server/scripts/calculators.seed.json —
// these are hand-copied, not read from that file, so a future edit to one
// needs the other updated too). Catches an unbalanced-paren or
// wrong-operator bug in the formula tokens themselves, independent of any
// UI.
void main() {
  test('GST calculator adds tax onto the base amount', () {
    final gst = CalculatorDefinition(
      id: 'gst',
      name: 'GST Calculator',
      category: 'Tax',
      description: '',
      inputs: const [],
      formulaTokens: const ['amount', '*', '(', '1', '+', '(', 'gstRate', '/', '100', ')', ')'],
      resultLabel: 'Total (incl. GST)',
    );
    final result = gst.evaluate({'amount': 1000, 'gstRate': 18});
    expect(result, closeTo(1180.0, 0.001));
  });

  test('KM to Miles converter applies the standard conversion factor', () {
    final converter = CalculatorDefinition(
      id: 'km-to-miles',
      name: 'KM to Miles Converter',
      category: 'Utilities',
      description: '',
      inputs: const [],
      formulaTokens: const ['km', '*', '0.621371'],
      resultLabel: 'Distance',
    );
    final result = converter.evaluate({'km': 10});
    expect(result, closeTo(6.21371, 0.00001));
  });

  test('Loan Eligibility calculator is the mathematical inverse of EMI', () {
    final loanEligibility = CalculatorDefinition(
      id: 'loan-eligibility',
      name: 'Loan Eligibility Calculator',
      category: 'Loans',
      description: '',
      inputs: const [],
      formulaTokens: const [
        'affordableEmi', '*',
        '(', '(', '1', '+', '(', 'annualRate', '/', '1200', ')', ')', '^', 'tenureMonths', '-', '1', ')',
        '/',
        '(', '(', 'annualRate', '/', '1200', ')', '*', '(', '1', '+', '(', 'annualRate', '/', '1200', ')', ')', '^', 'tenureMonths', ')',
      ],
      resultLabel: 'Max loan amount',
    );
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

    final maxLoan = loanEligibility.evaluate({
      'affordableEmi': 10000,
      'annualRate': 10,
      'tenureMonths': 240,
    });
    expect(maxLoan, closeTo(1036246.19, 0.5));

    // Round-trip: feeding the eligibility result's principal back through
    // EMI's own formula should reproduce the original affordable EMI.
    final roundTripEmi = emi.evaluate({
      'principal': maxLoan,
      'annualRate': 10,
      'tenureMonths': 240,
    });
    expect(roundTripEmi, closeTo(10000, 0.5));
  });
}
