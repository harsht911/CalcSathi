import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../auth/state/auth_state.dart';
import '../data/calculator_definition.dart';
import '../data/calculator_repository.dart';
import '../logic/cgpa_calculator.dart';

/// CGPA Calculator — bespoke screen rather than [CalculatorRunnerScreen];
/// see `cgpa_calculator.dart` for why a variable-length list of subjects
/// needs its own UI instead of a `calc_core` formula.
class CgpaCalculatorScreen extends StatefulWidget {
  const CgpaCalculatorScreen({required this.definition, super.key});

  final CalculatorDefinition definition;

  @override
  State<CgpaCalculatorScreen> createState() => _CgpaCalculatorScreenState();
}

class _SubjectRow {
  _SubjectRow()
      : credits = TextEditingController(),
        gradePoint = TextEditingController();

  final TextEditingController credits;
  final TextEditingController gradePoint;

  void dispose() {
    credits.dispose();
    gradePoint.dispose();
  }
}

class _CgpaCalculatorScreenState extends State<CgpaCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<_SubjectRow> _rows = [_SubjectRow(), _SubjectRow()];

  double? _result;
  String? _errorText;

  late final Stream<Set<String>> _favoriteIdsStream;

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthState>().user?.uid;
    _favoriteIdsStream = uid == null
        ? Stream<Set<String>>.value(const {})
        : context.read<CalculatorRepository>().watchFavoriteIds(uid);
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addRow() => setState(() => _rows.add(_SubjectRow()));

  void _removeRow(int index) {
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
    });
  }

  void _calculate() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final subjects = _rows
        .map((row) => SubjectGrade(
              credits: double.parse(row.credits.text),
              gradePoint: double.parse(row.gradePoint.text),
            ))
        .toList();

    setState(() => _errorText = null);
    try {
      final result = calculateCgpa(subjects);
      setState(() => _result = result);
      _saveToHistory(subjects, result);
    } on CgpaCalculationException catch (e) {
      setState(() {
        _result = null;
        _errorText = e.message;
      });
    }
  }

  Future<void> _saveToHistory(List<SubjectGrade> subjects, double result) async {
    final uid = context.read<AuthState>().user?.uid;
    if (uid == null) return;
    final totalCredits = subjects.fold<double>(0, (sum, s) => sum + s.credits);
    try {
      await context.read<CalculatorRepository>().recordHistory(
            uid: uid,
            definition: widget.definition,
            inputs: {
              'subjectCount': subjects.length.toDouble(),
              'totalCredits': totalCredits,
            },
            result: result,
          );
    } catch (_) {
      // Non-fatal — see CalculatorRunnerScreen's identical comment.
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (definition.description.isNotEmpty) ...[
                  Text(definition.description, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                ],
                for (var i = 0; i < _rows.length; i++) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _rows[i].credits,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Credits',
                            border: OutlineInputBorder(),
                          ),
                          validator: _validateCredits,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _rows[i].gradePoint,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Grade point',
                            border: OutlineInputBorder(),
                          ),
                          validator: _validateGradePoint,
                        ),
                      ),
                      if (_rows.length > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          tooltip: 'Remove subject',
                          onPressed: () => _removeRow(i),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Add subject'),
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
                if (_result != null) ...[
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(definition.resultLabel, style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 8),
                          Text(
                            _formatResult(_result!),
                            style: Theme.of(context).textTheme.headlineMedium,
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
      ),
    );
  }

  String? _validateCredits(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final parsed = double.tryParse(value);
    if (parsed == null) return 'Enter a number';
    if (parsed <= 0) return 'Must be > 0';
    return null;
  }

  String? _validateGradePoint(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final parsed = double.tryParse(value);
    if (parsed == null) return 'Enter a number';
    if (parsed < 0 || parsed > 10) return '0-10 only';
    return null;
  }

  String _formatResult(double value) {
    final formatted = value.toStringAsFixed(widget.definition.resultDecimalPlaces);
    final suffix = widget.definition.resultSuffix;
    return suffix == null || suffix.isEmpty ? formatted : '$formatted $suffix';
  }
}
