import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/state/auth_state.dart';
import '../data/coin_repository.dart';
import '../state/coin_state.dart';

/// Shown when a calculator costs more coins than the user currently has.
///
/// Watches the *live* balance via [CoinState] rather than a static snapshot
/// passed in at open time — Firestore's own realtime listener is what
/// delivers a new balance after [CoinRepository.earnPlaceholderReward]
/// succeeds, and this screen just reacts to it, the same way every other
/// screen in the app reacts to its Firestore streams. Pops `true` once the
/// user has enough coins, letting `openCalculator` (see
/// `calculator_navigation.dart`) continue on to the real spend; pops
/// `false`/nothing if the user backs out.
class InsufficientCoinsScreen extends StatefulWidget {
  const InsufficientCoinsScreen({required this.requiredCoins, super.key});

  final int requiredCoins;

  @override
  State<InsufficientCoinsScreen> createState() => _InsufficientCoinsScreenState();
}

class _InsufficientCoinsScreenState extends State<InsufficientCoinsScreen> {
  bool _earning = false;
  String? _errorText;

  Future<void> _earn() async {
    final user = context.read<AuthState>().user;
    if (user == null) return;

    setState(() {
      _earning = true;
      _errorText = null;
    });

    try {
      final idToken = await user.getIdToken();
      if (idToken == null) return;
      await context.read<CoinRepository>().earnPlaceholderReward(idToken: idToken);
      // No explicit balance update here — the server's write to
      // coinBalance lands back through CoinState's own Firestore listener
      // a moment later, same as every other reactive screen in this app.
    } on EarnCooldownException catch (e) {
      if (mounted) setState(() => _errorText = 'Try again in ${e.retryAfterSeconds}s.');
    } catch (_) {
      if (mounted) {
        setState(() => _errorText = "Couldn't claim your reward right now. Please try again.");
      }
    } finally {
      if (mounted) setState(() => _earning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = context.watch<CoinState>().balance;
    final hasEnough = balance >= widget.requiredCoins;

    return Scaffold(
      appBar: AppBar(title: const Text('Not enough coins')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.toll_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'This calculator costs ${widget.requiredCoins} coins — you have $balance.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              if (hasEnough)
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Continue'),
                )
              else ...[
                FilledButton(
                  onPressed: _earning ? null : _earn,
                  child: _earning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Get 10 free coins'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Placeholder reward — ad-based earning is coming soon.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
              if (_errorText != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
