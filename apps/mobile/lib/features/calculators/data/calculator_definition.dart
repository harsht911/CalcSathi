import 'package:calc_core/calc_core.dart';

/// One input field a [CalculatorDefinition]'s formula needs. `key` must
/// match a variable name used in [CalculatorDefinition.formulaTokens].
class CalculatorInputField {
  const CalculatorInputField({
    required this.key,
    required this.label,
    this.suffix,
    this.isInteger = false,
    this.min,
    this.max,
  });

  final String key;
  final String label;
  final String? suffix;

  /// True for fields like a loan tenure in months, where a fractional
  /// value wouldn't make sense and — since this ultimately feeds `^` in
  /// the formula — would trip [FormulaEvaluator]'s integer-exponent guard.
  final bool isInteger;
  final double? min;
  final double? max;

  factory CalculatorInputField.fromMap(Map<String, dynamic> map) {
    return CalculatorInputField(
      key: map['key'] as String,
      label: map['label'] as String,
      suffix: map['suffix'] as String?,
      isInteger: map['isInteger'] as bool? ?? false,
      min: (map['min'] as num?)?.toDouble(),
      max: (map['max'] as num?)?.toDouble(),
    );
  }
}

/// A single calculator in the catalog: metadata plus a `calc_core` formula.
///
/// Stored in Firestore's `calculators` collection (readable by any signed-in
/// user, writable only by admins — see `firestore.rules`) and seeded today
/// via `server/scripts/seed-calculators.js` since the admin panel that lets
/// Harsh manage these through a UI doesn't exist until M5.
class CalculatorDefinition {
  const CalculatorDefinition({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.inputs,
    required this.formulaTokens,
    required this.resultLabel,
    this.resultSuffix,
    this.resultDecimalPlaces = 2,
    this.coinCost = 0,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final List<CalculatorInputField> inputs;

  /// Coins required to open this calculator, checked/spent by
  /// `openCalculator()` (see `calculator_navigation.dart`) before
  /// navigating to it. Defaults to 0 (free) so every calculator seeded
  /// before M3's coin economy landed keeps working exactly as before —
  /// this is a per-calculator dial Harsh turns on deliberately in
  /// `calculators.seed.json`, not something this change flips on for him.
  final int coinCost;

  /// Space-tokenized infix formula (e.g. `["principal", "*", "(", ...]`),
  /// parsed into `calc_core` [FormulaToken]s at evaluation time — see
  /// [FormulaTokens.parse].
  final List<String> formulaTokens;

  final String resultLabel;
  final String? resultSuffix;
  final int resultDecimalPlaces;

  factory CalculatorDefinition.fromFirestore(String id, Map<String, dynamic> data) {
    final rawInputs = (data['inputs'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return CalculatorDefinition(
      id: id,
      name: data['name'] as String? ?? 'Untitled calculator',
      category: data['category'] as String? ?? 'Other',
      description: data['description'] as String? ?? '',
      inputs: rawInputs.map(CalculatorInputField.fromMap).toList(),
      formulaTokens: (data['formulaTokens'] as List<dynamic>? ?? const [])
          .cast<String>(),
      resultLabel: data['resultLabel'] as String? ?? 'Result',
      resultSuffix: data['resultSuffix'] as String?,
      resultDecimalPlaces: (data['resultDecimalPlaces'] as num?)?.toInt() ?? 2,
      coinCost: (data['coinCost'] as num?)?.toInt() ?? 0,
    );
  }

  /// Runs [values] through this calculator's formula. Throws a
  /// [FormulaException] (already user-facing-message-safe) on bad input,
  /// e.g. a zero denominator from a user-entered 0.
  double evaluate(Map<String, double> values) {
    return FormulaEvaluator.evaluate(FormulaTokens.parse(formulaTokens), values);
  }
}

/// Converts a calculator definition's flat, space-tokenized formula strings
/// into `calc_core` [FormulaToken]s. Kept separate from the custom formula
/// builder's own (future) token representation — this one's built for
/// hand/seed-script-authored built-in calculators, where a readable
/// space-separated string is easiest to write and review.
class FormulaTokens {
  static const _operators = {'+', '-', '*', '/', '^'};

  static List<FormulaToken> parse(List<String> raw) {
    return raw.map((token) {
      if (token == '(') return FormulaToken.leftParen;
      if (token == ')') return FormulaToken.rightParen;
      if (token == '%') return FormulaToken.percent;
      if (_operators.contains(token)) return FormulaToken.op(token);
      if (double.tryParse(token) != null) return FormulaToken.number(token);
      return FormulaToken.variable(token);
    }).toList();
  }
}
