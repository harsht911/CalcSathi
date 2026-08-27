import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/state/auth_state.dart';
import '../data/calculator_repository.dart';
import 'calculator_navigation.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthState>().user?.uid;
    final repository = context.read<CalculatorRepository>();

    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: repository.watchFavorites(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text("Couldn't load your favorites. Pull to retry.", textAlign: TextAlign.center),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final favorites = snapshot.data!;
        if (favorites.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Tap the star on a calculator to save it here.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.builder(
          itemCount: favorites.length,
          itemBuilder: (context, index) {
            final favorite = favorites[index];
            final calculatorId = favorite['id'] as String;
            return ListTile(
              leading: const Icon(Icons.star),
              title: Text(favorite['calculatorName'] as String? ?? 'Calculator'),
              subtitle: Text(favorite['category'] as String? ?? ''),
              onTap: () => _open(context, repository, calculatorId),
            );
          },
        );
      },
    );
  }

  Future<void> _open(
    BuildContext context,
    CalculatorRepository repository,
    String calculatorId,
  ) async {
    final definition = await repository.getCalculator(calculatorId);
    if (!context.mounted) return;
    if (definition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This calculator isn't available anymore.")),
      );
      return;
    }
    openCalculator(context, definition);
  }
}
