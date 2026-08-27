import 'package:flutter/material.dart';

import '../data/calculator_definition.dart';
import 'age_calculator_screen.dart';
import 'calculator_runner_screen.dart';
import 'cgpa_calculator_screen.dart';

/// Opens the right screen for [definition]. Most calculators run through
/// the generic [CalculatorRunnerScreen] (a formula plus numeric inputs),
/// but a fixed few need bespoke UI `calc_core`'s single-formula-over-named-
/// variables model can't express — date arithmetic for Age, a
/// variable-length list of subjects for CGPA. See `age_calculator.dart`
/// and `cgpa_calculator.dart` for why each needs real Dart logic instead of
/// a formula.
///
/// Keyed by a fixed, hand-authored set of IDs rather than a Firestore-driven
/// "kind" field — this is a small, known built-in catalog today, not
/// something the (post-M5) admin panel creates freely yet. Revisit this if
/// M5 needs to let Harsh define new non-formula calculator types himself.
///
/// Used by both [CatalogScreen] and [FavoritesScreen] so a calculator opens
/// the same way from either entry point.
void openCalculator(BuildContext context, CalculatorDefinition definition) {
  final Widget screen = switch (definition.id) {
    'age' => AgeCalculatorScreen(definition: definition),
    'cgpa' => CgpaCalculatorScreen(definition: definition),
    _ => CalculatorRunnerScreen(definition: definition),
  };
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}
