/// Thrown when a CGPA can't be computed from the given subjects.
class CgpaCalculationException implements Exception {
  const CgpaCalculationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// One subject's credits and grade point (India's standard 0-10 scale).
class SubjectGrade {
  const SubjectGrade({required this.credits, required this.gradePoint});
  final double credits;
  final double gradePoint;
}

/// Credit-weighted average CGPA: sum(credits * gradePoint) / sum(credits).
///
/// Deliberately NOT expressed as a `calc_core` formula: the number of
/// subjects is variable, and `calc_core`'s evaluator is a fixed,
/// single-expression formula over named variables — it has no notion of a
/// list to sum over. See `calculator_navigation.dart` for how this gets
/// routed to its own screen instead of the generic [CalculatorRunnerScreen].
double calculateCgpa(List<SubjectGrade> subjects) {
  if (subjects.isEmpty) {
    throw const CgpaCalculationException('Add at least one subject');
  }

  var totalCredits = 0.0;
  var weightedSum = 0.0;
  for (final subject in subjects) {
    if (subject.credits <= 0) {
      throw const CgpaCalculationException('Credits must be greater than zero');
    }
    if (subject.gradePoint < 0 || subject.gradePoint > 10) {
      throw const CgpaCalculationException('Grade point must be between 0 and 10');
    }
    totalCredits += subject.credits;
    weightedSum += subject.credits * subject.gradePoint;
  }

  if (totalCredits == 0) {
    throw const CgpaCalculationException('Total credits must be greater than zero');
  }
  return weightedSum / totalCredits;
}
