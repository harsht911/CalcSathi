/// Thrown when an age can't be computed from the given date(s).
class AgeCalculationException implements Exception {
  const AgeCalculationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// A calendar-exact age, broken into years/months/days.
class AgeResult {
  const AgeResult({required this.years, required this.months, required this.days});
  final int years;
  final int months;
  final int days;
}

/// Calendar-exact age as of [asOf] — proper years/months/days, not a
/// total-days/365.25 approximation, since that's what "how old am I"
/// actually means to a user.
///
/// Deliberately NOT expressed as a `calc_core` formula: there's no
/// month-length or leap-year awareness in a fixed `+ - * / ^` formula, so
/// this needs real `DateTime` arithmetic instead — see
/// `calculator_navigation.dart` for how this gets routed to its own screen
/// instead of the generic [CalculatorRunnerScreen].
AgeResult calculateAge(DateTime dob, DateTime asOf) {
  if (dob.isAfter(asOf)) {
    throw const AgeCalculationException('Date of birth is in the future');
  }

  var years = asOf.year - dob.year;
  var months = asOf.month - dob.month;
  var days = asOf.day - dob.day;

  if (days < 0) {
    months -= 1;
    // Day 0 of a given month is the last day of the previous month — a
    // clean way to get "how many days are in the previous month" without
    // a hand-rolled month-length table (and it's leap-year-correct for
    // February, since DateTime already knows that).
    days += DateTime(asOf.year, asOf.month, 0).day;
  }
  if (months < 0) {
    years -= 1;
    months += 12;
  }

  return AgeResult(years: years, months: months, days: days);
}
