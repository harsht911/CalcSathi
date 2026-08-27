import 'package:calcsathi_mobile/features/calculators/logic/cgpa_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculateCgpa', () {
    test('computes the credit-weighted average across subjects', () {
      final result = calculateCgpa([
        SubjectGrade(credits: 4, gradePoint: 8),
        SubjectGrade(credits: 3, gradePoint: 9),
        SubjectGrade(credits: 2, gradePoint: 7),
      ]);
      // (4*8 + 3*9 + 2*7) / (4+3+2) = 73/9 = 8.111...
      expect(result, closeTo(8.1111, 0.001));
    });

    test('a single subject returns its own grade point', () {
      final result = calculateCgpa([SubjectGrade(credits: 4, gradePoint: 9)]);
      expect(result, 9.0);
    });

    test('throws for an empty subject list', () {
      expect(() => calculateCgpa([]), throwsA(isA<CgpaCalculationException>()));
    });

    test('throws for zero or negative credits', () {
      expect(
        () => calculateCgpa([SubjectGrade(credits: 0, gradePoint: 8)]),
        throwsA(isA<CgpaCalculationException>()),
      );
    });

    test('throws for a grade point outside 0-10', () {
      expect(
        () => calculateCgpa([SubjectGrade(credits: 4, gradePoint: 11)]),
        throwsA(isA<CgpaCalculationException>()),
      );
      expect(
        () => calculateCgpa([SubjectGrade(credits: 4, gradePoint: -1)]),
        throwsA(isA<CgpaCalculationException>()),
      );
    });
  });
}
