/// Base type for anything that goes wrong parsing or evaluating a formula.
/// Every message is written to be shown directly to a non-technical user
/// (the custom formula builder's "Test it" panel surfaces these as-is).
sealed class FormulaException implements Exception {
  final String message;
  const FormulaException(this.message);

  @override
  String toString() => message;
}

class FormulaEmptyException extends FormulaException {
  const FormulaEmptyException() : super('Add a formula above to see a live preview');
}

class FormulaTooLongException extends FormulaException {
  const FormulaTooLongException(int max)
      : super("That formula is too long (max $max tokens) — try breaking it into a simpler one");
}

class FormulaSyntaxException extends FormulaException {
  const FormulaSyntaxException()
      : super("That doesn't quite compute yet — check for a missing number, symbol or bracket");
}

class FormulaUnknownVariableException extends FormulaException {
  const FormulaUnknownVariableException(String name) : super('Unknown variable: $name');
}

class FormulaDivisionByZeroException extends FormulaException {
  const FormulaDivisionByZeroException() : super("Can't divide by zero — check your inputs");
}

class FormulaResultNotFiniteException extends FormulaException {
  const FormulaResultNotFiniteException()
      : super('That combination of numbers gives an invalid result — try different values');
}
