import 'package:calcsathi_mobile/features/calculators/logic/age_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculateAge', () {
    test('computes years/months/days for a birthday already passed this year', () {
      final result = calculateAge(DateTime(2000, 3, 15), DateTime(2026, 8, 27));
      expect(result.years, 26);
      expect(result.months, 5);
      expect(result.days, 12);
    });

    test('borrows a month when the day-of-month hasn\'t occurred yet', () {
      // Born the 20th, "as of" the 10th of a later month — day component
      // would be negative without borrowing from the previous month.
      final result = calculateAge(DateTime(1999, 6, 20), DateTime(2026, 1, 10));
      expect(result.years, 26);
      expect(result.months, 6);
      expect(result.days, 21);
    });

    test('handles a birthday that falls exactly on "as of"', () {
      final result = calculateAge(DateTime(2010, 1, 1), DateTime(2026, 1, 1));
      expect(result.years, 16);
      expect(result.months, 0);
      expect(result.days, 0);
    });

    test('is leap-year-correct when borrowing from February', () {
      // "As of" March 1 in a leap year — borrowing should land on Feb 29,
      // not Feb 28, since DateTime(year, month, 0) already knows this.
      final result = calculateAge(DateTime(2020, 2, 15), DateTime(2024, 3, 1));
      expect(result.years, 4);
      expect(result.months, 0);
      expect(result.days, 15);
    });

    test('throws for a future date of birth', () {
      expect(
        () => calculateAge(DateTime(2030, 1, 1), DateTime(2026, 1, 1)),
        throwsA(isA<AgeCalculationException>()),
      );
    });
  });
}
