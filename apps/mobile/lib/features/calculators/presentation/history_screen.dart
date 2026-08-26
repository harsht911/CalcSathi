import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/state/auth_state.dart';
import '../data/calculator_repository.dart';
import '../data/history_entry.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthState>().user?.uid;
    final repository = context.read<CalculatorRepository>();

    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<List<HistoryEntry>>(
      stream: repository.watchHistory(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text("Couldn't load your history. Pull to retry.", textAlign: TextAlign.center),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries = snapshot.data!;
        if (entries.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Run a calculator and it\'ll show up here.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final suffix = entry.resultSuffix;
            final resultText = entry.result.toStringAsFixed(2) + (suffix == null || suffix.isEmpty ? '' : ' $suffix');
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.history)),
              title: Text(entry.calculatorName),
              subtitle: Text(
                entry.computedAt == null
                    ? '${entry.resultLabel}: $resultText'
                    : '${entry.resultLabel}: $resultText  ·  ${_formatDate(entry.computedAt!)}',
              ),
            );
          },
        );
      },
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  // Hand-rolled rather than pulling in `intl` for one date format — keeps
  // the dependency surface smaller.
  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '${_months[local.month - 1]} ${local.day}, ${local.year} · $hour12:$minute $period';
  }
}
