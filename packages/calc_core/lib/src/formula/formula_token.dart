/// The kind of a single token in a formula expression.
enum TokenType { number, variable, operatorToken, leftParen, rightParen, percent }

/// One token in a tokenized formula, e.g. `3.5`, `monthlyAmount`, `+`, `(`.
///
/// Formulas are stored and edited as a flat list of these (matching the
/// tap-to-build UI in the design canvas' CustomFormulaBuilder screen) rather
/// than as a raw string, so the UI never has to parse free text and the
/// evaluator never has to guess token boundaries.
class FormulaToken {
  final TokenType type;
  final String raw;

  const FormulaToken(this.type, this.raw);

  static FormulaToken number(String value) => FormulaToken(TokenType.number, value);
  static FormulaToken variable(String name) => FormulaToken(TokenType.variable, name);
  static FormulaToken op(String symbol) => FormulaToken(TokenType.operatorToken, symbol);
  static const FormulaToken leftParen = FormulaToken(TokenType.leftParen, '(');
  static const FormulaToken rightParen = FormulaToken(TokenType.rightParen, ')');
  static const FormulaToken percent = FormulaToken(TokenType.percent, '%');

  @override
  String toString() => raw;

  @override
  bool operator ==(Object other) =>
      other is FormulaToken && other.type == type && other.raw == raw;

  @override
  int get hashCode => Object.hash(type, raw);
}

/// Recognized binary operators, most-tightly-binding last is NOT the
/// convention here — see [FormulaEvaluator] for actual precedence order.
const binaryOperators = {'+', '-', '*', '/', '^'};
