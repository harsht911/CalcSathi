import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/state/auth_state.dart';
import '../data/calculator_definition.dart';
import '../data/calculator_repository.dart';
import '../logic/age_calculator.dart';

/// Age Calculator — bespoke screen rather than [CalculatorRunnerScreen];
/// see `age_calculator.dart` for why exact calendar age needs real date
/// arithmetic instead of a `calc_core` formula.
class AgeCalculatorScreen extends StatefulWidget {
  const AgeCalculatorScreen({required this.definition, super.key});

  final CalculatorDefinition definition;

  @override
  State<AgeCalculatorScreen> createState() => _AgeCalculatorScreenState();
}

class _AgeCalculatorScreenState extends State<AgeCalculatorScreen> {
  DateTime? _dob;
  AgeResult? _age;
  String? _errorText;

  // Built once in initState — see CalculatorRunnerScreen's identical
  // comment on why (avoids tearing down/reopening the Firestore listener
  // on every calculate-driven setState).
  late final Stream<Set<String>> _favoriteIdsStream;

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthState>().user?.uid;
    _favoriteIdsStream = uid == null
        ? Stream<Set<String>>.value(const {})
        : context.read<CalculatorRepository>().watchFavoriteIds(uid);
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _age = null;
        _errorText = null;
      });
    }
  }

  void _calculate() {
    final dob = _dob;
    if (dob == null) {
      setState(() {
        _age = null;
        _errorText = 'Pick a date of birth first';
      });
      return;
    }

    try {
      final age = calculateAge(dob, DateTime.now());
      setState(() {
        _errorText = null;
        _age = age;
      });
      _saveToHistory(dob, age);
    } on AgeCalculationException catch (e) {
      setState(() {
        _age = null;
        _errorText = e.message;
      });
    }
  }

  Future<void> _saveToHistory(DateTime dob, AgeResult age) async {
    final uid = context.read<AuthState>().user?.uid;
    if (uid == null) return;
    try {
      await context.read<CalculatorRepository>().recordHistory(
            uid: uid,
            definition: widget.definition,
            inputs: {
              'months': age.months.toDouble(),
              'days': age.days.toDouble(),
            },
            result: age.years.toDouble(),
          );
    } catch (_) {
      // Non-fatal — the on-screen result is already shown either way, and
      // Crashlytics (wired app-wide) will still see this if it's part of a
      // broader problem. Matches CalculatorRunnerScreen's identical choice.
    }
  }

  Future<void> _toggleFavorite(bool currentlyFavorite) async {
    final uid = context.read<AuthState>().user?.uid;
    if (uid == null) return;
    await context.read<CalculatorRepository>().setFavorite(
          uid: uid,
          definition: widget.definition,
          isFavorite: !currentlyFavorite,
        );
  }

  @override
  Widget build(BuildContext context) {
    final definition = widget.definition;

    return Scaffold(
      appBar: AppBar(
        title: Text(definition.name),
        actions: [
          StreamBuilder<Set<String>>(
            stream: _favoriteIdsStream,
            builder: (context, snapshot) {
              final isFavorite = snapshot.data?.contains(definition.id) ?? false;
              return IconButton(
                icon: Icon(isFavorite ? Icons.star : Icons.star_border),
                tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                onPressed: () => _toggleFavorite(isFavorite),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (definition.description.isNotEmpty) ...[
                Text(definition.description, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
              ],
              OutlinedButton.icon(
                onPressed: _pickDob,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(_dob == null ? 'Pick date of birth' : _formatDate(_dob!)),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _calculate,
                child: const Text('Calculate'),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_age != null) ...[
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text('Your age', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 8),
                        Text(
                          '${_age!.years} years, ${_age!.months} months, ${_age!.days} days',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  // Hand-rolled rather than pulling in `intl` for one date format — matches
  // HistoryScreen's identical choice.
  String _formatDate(DateTime date) => '${_months[date.month - 1]} ${date.day}, ${date.year}';
}
