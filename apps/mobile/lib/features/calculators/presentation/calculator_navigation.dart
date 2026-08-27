import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/state/auth_state.dart';
import '../../coins/data/coin_repository.dart';
import '../../coins/presentation/insufficient_coins_screen.dart';
import '../../coins/state/coin_state.dart';
import '../data/calculator_definition.dart';
import 'age_calculator_screen.dart';
import 'calculator_runner_screen.dart';
import 'cgpa_calculator_screen.dart';

/// Opens the right screen for [definition] — gating on
/// [CalculatorDefinition.coinCost] first if it's non-zero, then routing to
/// the right screen the same way regardless of whether a spend happened.
///
/// Most calculators run through the generic [CalculatorRunnerScreen] (a
/// formula plus numeric inputs), but a fixed few need bespoke UI
/// `calc_core`'s single-formula-over-named-variables model can't express —
/// date arithmetic for Age, a variable-length list of subjects for CGPA.
/// See `age_calculator.dart` and `cgpa_calculator.dart` for why each needs
/// real Dart logic instead of a formula.
///
/// Keyed by a fixed, hand-authored set of IDs rather than a Firestore-driven
/// "kind" field — this is a small, known built-in catalog today, not
/// something the (post-M5) admin panel creates freely yet. Revisit this if
/// M5 needs to let Harsh define new non-formula calculator types himself.
///
/// Used by both [CatalogScreen] and [FavoritesScreen] so a calculator opens
/// the same way from either entry point.
Future<void> openCalculator(BuildContext context, CalculatorDefinition definition) async {
  final cost = definition.coinCost;

  if (cost > 0) {
    final coinState = context.read<CoinState>();

    if (coinState.balance < cost) {
      final proceeded = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => InsufficientCoinsScreen(requiredCoins: cost)),
      );
      // User backed out, or the interstitial was popped without explicitly
      // confirming they now have enough (its own "Continue" button is the
      // only path that pops `true` — see InsufficientCoinsScreen).
      if (!context.mounted || proceeded != true) return;
    }

    final user = context.read<AuthState>().user;
    if (user == null) return;

    try {
      final idToken = await user.getIdToken();
      if (idToken == null) return;
      await context.read<CoinRepository>().spend(
            idToken: idToken,
            amount: cost,
            reason: 'calculator:${definition.id}',
          );
    } on InsufficientCoinsException {
      // The balance changed again between the interstitial and this spend
      // call (e.g. spent from another device in the gap) — bail out
      // quietly rather than looping the interstitial. The coin balance
      // shown in the app bar already reflects the real, current balance.
      return;
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't unlock this calculator right now. Please try again.")),
      );
      return;
    }
    if (!context.mounted) return;
  }

  final Widget screen = switch (definition.id) {
    'age' => AgeCalculatorScreen(definition: definition),
    'cgpa' => CgpaCalculatorScreen(definition: definition),
    _ => CalculatorRunnerScreen(definition: definition),
  };
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}
