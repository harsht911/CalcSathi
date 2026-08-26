import 'package:calc_core/calc_core.dart';
import 'package:test/test.dart';

/// Small helper: turns a token stream written as plain strings into
/// [FormulaToken]s, so test cases below read like the expression they mean.
/// A digit or '.' becomes a `number` fragment (mirroring the tap-to-build
/// UI, which pushes one digit at a time); anything in [_ops] becomes an
/// `operatorToken`; '(' / ')' / '%' get their dedicated types; anything else
/// is treated as a variable name.
const _ops = {'+', '-', '*', '/', '^'};

List<FormulaToken> _t(List<String> raw) {
  return raw.map((r) {
    if (r == '(') return FormulaToken.leftParen;
    if (r == ')') return FormulaToken.rightParen;
    if (r == '%') return FormulaToken.percent;
    if (_ops.contains(r)) return FormulaToken.op(r);
    if (RegExp(r'^[0-9.]$').hasMatch(r)) return FormulaToken.number(r);
    return FormulaToken.variable(r);
  }).toList();
}

void main() {
  group('FormulaEvaluator — basic arithmetic', () {
    test('adds two multi-digit numbers', () {
      // 12 + 5
      final tokens = _t(['1', '2', '+', '5']);
      expect(FormulaEvaluator.evaluate(tokens, {}), 17);
    });

    test('respects operator precedence', () {
      // 2 + 3 * 4 = 14, not 20
      final tokens = _t(['2', '+', '3', '*', '4']);
      expect(FormulaEvaluator.evaluate(tokens, {}), 14);
    });

    test('parentheses override precedence', () {
      // (2 + 3) * 4 = 20
      final tokens = _t(['(', '2', '+', '3', ')', '*', '4']);
      expect(FormulaEvaluator.evaluate(tokens, {}), 20);
    });

    test('handles decimals', () {
      // 1.5 * 2
      final tokens = _t(['1', '.', '5', '*', '2']);
      expect(FormulaEvaluator.evaluate(tokens, {}), 3);
    });

    test('right-associative power', () {
      // 2 ^ 3 = 8
      final tokens = _t(['2', '^', '3']);
      expect(FormulaEvaluator.evaluate(tokens, {}), 8);
    });

    test('postfix percent divides by 100', () {
      // 50 %  -> 0.5
      final tokens = _t(['5', '0', '%']);
      expect(FormulaEvaluator.evaluate(tokens, {}), 0.5);
    });

    test('percent composes with a following operator', () {
      // 200 + 50% = 200.5 (percent applies only to the 50, per RPN semantics)
      final tokens = _t(['2', '0', '0', '+', '5', '0', '%']);
      expect(FormulaEvaluator.evaluate(tokens, {}), 200.5);
    });
  });

  group('FormulaEvaluator — unary minus', () {
    test('leading unary minus', () {
      // -5 + 10 = 5
      final tokens = _t(['-', '5', '+', '1', '0']);
      expect(FormulaEvaluator.evaluate(tokens, {}), 5);
    });

    test('unary minus after an open paren', () {
      // 10 * (-2 + 5) = 30
      final tokens = _t(['1', '0', '*', '(', '-', '2', '+', '5', ')']);
      expect(FormulaEvaluator.evaluate(tokens, {}), 30);
    });
  });

  group('FormulaEvaluator — variables', () {
    test('substitutes a known variable', () {
      final tokens = _t(['principal', '*', 'rate']);
      final result = FormulaEvaluator.evaluate(tokens, {'principal': 1000, 'rate': 0.05});
      expect(result, 50);
    });

    test('throws FormulaUnknownVariableException for an unbound variable', () {
      final tokens = _t(['principal', '*', 'rate']);
      expect(
        () => FormulaEvaluator.evaluate(tokens, {'principal': 1000}),
        throwsA(isA<FormulaUnknownVariableException>()),
      );
    });
  });

  group('FormulaEvaluator — error cases', () {
    test('empty formula throws FormulaEmptyException', () {
      expect(() => FormulaEvaluator.evaluate([], {}), throwsA(isA<FormulaEmptyException>()));
    });

    test('division by zero throws FormulaDivisionByZeroException', () {
      final tokens = _t(['1', '0', '/', '0']);
      expect(
        () => FormulaEvaluator.evaluate(tokens, {}),
        throwsA(isA<FormulaDivisionByZeroException>()),
      );
    });

    test('unmatched open paren throws FormulaSyntaxException', () {
      final tokens = _t(['(', '1', '+', '2']);
      expect(() => FormulaEvaluator.evaluate(tokens, {}), throwsA(isA<FormulaSyntaxException>()));
    });

    test('unmatched close paren throws FormulaSyntaxException', () {
      final tokens = _t(['1', '+', '2', ')']);
      expect(() => FormulaEvaluator.evaluate(tokens, {}), throwsA(isA<FormulaSyntaxException>()));
    });

    test('dangling operator throws FormulaSyntaxException', () {
      final tokens = _t(['1', '+']);
      expect(() => FormulaEvaluator.evaluate(tokens, {}), throwsA(isA<FormulaSyntaxException>()));
    });

    test('a number directly followed by a variable with no operator throws FormulaSyntaxException', () {
      // Adjacent `number` tokens are merged (that's how the tap-to-build UI
      // assembles multi-digit literals), so this needs a type change between
      // the two operands to actually leave two un-combined values on the
      // RPN stack.
      final tokens = [FormulaToken.number('12'), FormulaToken.variable('x')];
      expect(
        () => FormulaEvaluator.evaluate(tokens, {'x': 5}),
        throwsA(isA<FormulaSyntaxException>()),
      );
    });

    test('formula longer than maxTokens throws FormulaTooLongException', () {
      final tokens = List.generate(FormulaEvaluator.maxTokens + 1, (_) => FormulaToken.number('1'));
      expect(
        () => FormulaEvaluator.evaluate(tokens, {}),
        throwsA(isA<FormulaTooLongException>()),
      );
    });

    test('non-integer exponent throws FormulaResultNotFiniteException', () {
      final tokens = [FormulaToken.number('2'), FormulaToken.op('^'), FormulaToken.number('0.5')];
      expect(
        () => FormulaEvaluator.evaluate(tokens, {}),
        throwsA(isA<FormulaResultNotFiniteException>()),
      );
    });
  });

  group('FormulaException', () {
    test('toString returns the user-facing message', () {
      const ex = FormulaDivisionByZeroException();
      expect(ex.toString(), "Can't divide by zero — check your inputs");
    });
  });
}
