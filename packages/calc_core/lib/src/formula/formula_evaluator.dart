import 'formula_exceptions.dart';
import 'formula_token.dart';

/// Evaluates a tokenized formula against a set of variable values.
///
/// This is a from-scratch shunting-yard parser + RPN evaluator — deliberately
/// NOT `eval()`/`Function()`-based. The Claude Design canvas mockup for the
/// custom formula builder used a sandboxed `Function()` call for design-preview
/// purposes only; that approach must never be carried into production (it can
/// execute arbitrary JS-equivalent code if the token list is ever untrusted —
/// e.g. synced from a compromised client or a shared/imported formula). This
/// evaluator only ever recognizes numbers, known variable names, and a fixed
/// operator set, so there is no code-execution surface at all.
///
/// Supported: `+ - * / ^` (power) as binary operators, unary minus (e.g. `-x`),
/// postfix `%` (divides the preceding value by 100), and parentheses.
class FormulaEvaluator {
  /// Hard cap on token count, independent of the UI. Guards against a
  /// pathologically long formula (accidental or malicious) causing excessive
  /// parse/eval work — this is the "evaluation step limit" the architecture
  /// notes flagged as still-needed before the formula builder ships.
  static const int maxTokens = 200;

  static const Map<String, int> _precedence = {'+': 1, '-': 1, '*': 2, '/': 2, '^': 3};
  static const Set<String> _rightAssociative = {'^'};

  /// Evaluates [tokens] against [values] (variable name -> numeric value).
  /// Throws a [FormulaException] subtype with a user-facing message on any
  /// problem — callers should catch [FormulaException], not raw exceptions.
  static double evaluate(List<FormulaToken> tokens, Map<String, double> values) {
    if (tokens.isEmpty) throw const FormulaEmptyException();
    if (tokens.length > maxTokens) throw FormulaTooLongException(maxTokens);

    final merged = _mergeDigitRuns(tokens);
    final rpn = _toRpn(merged);
    final result = _evaluateRpn(rpn, values);

    if (!result.isFinite) throw const FormulaResultNotFiniteException();
    return result;
  }

  /// The tap-to-build UI pushes each digit/decimal-point as its own token
  /// (matching CustomFormulaBuilder's palette of single-digit chips), so
  /// consecutive `number` tokens are fragments of one literal and need
  /// merging before parsing — e.g. ['1','2','.','5'] -> ['12.5'].
  static List<FormulaToken> _mergeDigitRuns(List<FormulaToken> tokens) {
    final out = <FormulaToken>[];
    final buffer = StringBuffer();

    void flush() {
      if (buffer.isNotEmpty) {
        out.add(FormulaToken.number(buffer.toString()));
        buffer.clear();
      }
    }

    for (final t in tokens) {
      if (t.type == TokenType.number) {
        buffer.write(t.raw);
      } else {
        flush();
        out.add(t);
      }
    }
    flush();
    return out;
  }

  static List<FormulaToken> _toRpn(List<FormulaToken> tokens) {
    final output = <FormulaToken>[];
    final opStack = <FormulaToken>[];

    // Insert an implicit leading 0 before a unary minus (start of expression,
    // or right after '(' or another operator) so "-x" parses as "0 - x"
    // without a separate unary-operator code path.
    final normalized = <FormulaToken>[];
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      final isUnaryMinus = t.type == TokenType.operatorToken &&
          t.raw == '-' &&
          (normalized.isEmpty ||
              normalized.last.type == TokenType.leftParen ||
              normalized.last.type == TokenType.operatorToken);
      if (isUnaryMinus) normalized.add(FormulaToken.number('0'));
      normalized.add(t);
    }

    for (final t in normalized) {
      switch (t.type) {
        case TokenType.number:
        case TokenType.variable:
          output.add(t);
          break;
        case TokenType.percent:
          // Postfix — applies immediately to whatever's already on the
          // output stack, so just append it; RPN evaluation treats it as a
          // unary op applied to the value directly beneath it.
          output.add(t);
          break;
        case TokenType.leftParen:
          opStack.add(t);
          break;
        case TokenType.rightParen:
          while (opStack.isNotEmpty && opStack.last.type != TokenType.leftParen) {
            output.add(opStack.removeLast());
          }
          if (opStack.isEmpty) throw const FormulaSyntaxException(); // unmatched ')'
          opStack.removeLast(); // discard the '('
          break;
        case TokenType.operatorToken:
          final p = _precedence[t.raw];
          if (p == null) throw const FormulaSyntaxException();
          while (opStack.isNotEmpty &&
              opStack.last.type == TokenType.operatorToken &&
              (_precedence[opStack.last.raw]! > p ||
                  (_precedence[opStack.last.raw]! == p && !_rightAssociative.contains(t.raw)))) {
            output.add(opStack.removeLast());
          }
          opStack.add(t);
          break;
      }
    }

    while (opStack.isNotEmpty) {
      final t = opStack.removeLast();
      if (t.type == TokenType.leftParen) throw const FormulaSyntaxException(); // unmatched '('
      output.add(t);
    }
    return output;
  }

  static double _evaluateRpn(List<FormulaToken> rpn, Map<String, double> values) {
    final stack = <double>[];

    for (final t in rpn) {
      switch (t.type) {
        case TokenType.number:
          final v = double.tryParse(t.raw);
          if (v == null) throw const FormulaSyntaxException();
          stack.add(v);
          break;
        case TokenType.variable:
          final v = values[t.raw];
          if (v == null) throw FormulaUnknownVariableException(t.raw);
          stack.add(v);
          break;
        case TokenType.percent:
          if (stack.isEmpty) throw const FormulaSyntaxException();
          stack.add(stack.removeLast() / 100);
          break;
        case TokenType.operatorToken:
          if (stack.length < 2) throw const FormulaSyntaxException();
          final b = stack.removeLast();
          final a = stack.removeLast();
          stack.add(_applyBinary(t.raw, a, b));
          break;
        case TokenType.leftParen:
        case TokenType.rightParen:
          // Unreachable post-shunting-yard — parens never reach RPN output.
          throw const FormulaSyntaxException();
      }
    }

    if (stack.length != 1) throw const FormulaSyntaxException();
    return stack.single;
  }

  static double _applyBinary(String op, double a, double b) {
    switch (op) {
      case '+':
        return a + b;
      case '-':
        return a - b;
      case '*':
        return a * b;
      case '/':
        if (b == 0) throw const FormulaDivisionByZeroException();
        return a / b;
      case '^':
        return _power(a, b);
      default:
        throw const FormulaSyntaxException();
    }
  }

  static double _power(double base, double exponent) {
    // dart:math's pow() returns num; keep this local so calc_core doesn't
    // need a dart:math import anywhere else, and so non-finite/huge
    // exponents fail as a FormulaException rather than an unhandled error.
    if (exponent == 0) return 1;
    var result = 1.0;
    final isNegative = exponent < 0;
    final steps = exponent.abs();
    if (steps != steps.roundToDouble() || steps > 1000) {
      // Non-integer or absurd exponents: fall back to a bounded loop guard —
      // reject rather than risk a runaway computation on adversarial input.
      throw const FormulaResultNotFiniteException();
    }
    for (var i = 0; i < steps.round(); i++) {
      result *= base;
    }
    return isNegative ? 1 / result : result;
  }
}
