import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/state/auth_state.dart';
import '../data/calculator_definition.dart';
import '../data/calculator_repository.dart';
import 'calculator_runner_screen.dart';

/// The calculator catalog — the M2 home screen. Groups calculators by
/// category (client-side; see [CalculatorRepository.watchCatalog] for why)
/// and shows a filled/outlined star per tile driven by the user's
/// favorites, without a second per-tile query.
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<CalculatorRepository>();
    final uid = context.watch<AuthState>().user?.uid;

    return StreamBuilder<List<CalculatorDefinition>>(
      stream: repository.watchCatalog(),
      builder: (context, catalogSnapshot) {
        if (catalogSnapshot.hasError) {
          return const _CatalogMessage(
            icon: Icons.error_outline,
            message: "Couldn't load the calculator catalog. Pull to retry.",
          );
        }
        if (!catalogSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final calculators = catalogSnapshot.data!;
        if (calculators.isEmpty) {
          return const _CatalogMessage(
            icon: Icons.calculate_outlined,
            message: 'No calculators yet — check back soon.',
          );
        }

        final byCategory = <String, List<CalculatorDefinition>>{};
        for (final calculator in calculators) {
          byCategory.putIfAbsent(calculator.category, () => []).add(calculator);
        }
        final categories = byCategory.keys.toList()..sort();

        return StreamBuilder<Set<String>>(
          stream: uid == null
              ? Stream<Set<String>>.value(const {})
              : repository.watchFavoriteIds(uid),
          builder: (context, favoritesSnapshot) {
            final favoriteIds = favoritesSnapshot.data ?? const <String>{};

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: categories.length,
              itemBuilder: (context, categoryIndex) {
                final category = categories[categoryIndex];
                final items = byCategory[category]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(category, style: Theme.of(context).textTheme.titleSmall),
                    ),
                    ...items.map(
                      (definition) => _CalculatorTile(
                        definition: definition,
                        isFavorite: favoriteIds.contains(definition.id),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _CalculatorTile extends StatelessWidget {
  const _CalculatorTile({required this.definition, required this.isFavorite});

  final CalculatorDefinition definition;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.calculate_outlined)),
      title: Text(definition.name),
      subtitle: definition.description.isEmpty ? null : Text(definition.description),
      trailing: isFavorite
          ? Icon(Icons.star, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CalculatorRunnerScreen(definition: definition)),
      ),
    );
  }
}

class _CatalogMessage extends StatelessWidget {
  const _CatalogMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
