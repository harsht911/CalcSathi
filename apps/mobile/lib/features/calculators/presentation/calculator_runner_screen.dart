import 'package:calc_core/calc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../auth/state/auth_state.dart';
import '../data/calculator_definition.dart';
import '../data/calculator_repository.dart';

/// Generic calculator screen: renders one input field per
/// [CalculatorDefinition.inputs], runs the formula through `calc_core` on
/// submit, and shows the result — the same UI drives every built-in
/// calculator, since the formula and field list are all data, not code.
class CalculatorRunnerScreen extends StatefulWidget {
  const CalculatorRunnerScreen({required this.definition, super.key});

  final CalculatorDefinition definition;

  @override
  State<CalculatorRunnerScreen> createState() => _CalculatorRunnerScreenState();
}

class _CalculatorRunnerScreenState extends State<CalculatorRunnerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers = {
    for (final input in widget.definition.inputs) input.key: TextEditingController(),
  };

  double? _result;
  String? _errorText;

  // Built once in initState rather than inline in `build()` — a fresh
  // `Stream` instance on every rebuild (e.g. every keystroke-driven
  // setState from `_calculate`) would make `StreamBuilder` tear down and
  // reopen the underlying Firestore listener each time.
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
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _calculate() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final values = <String, double>{
      for (final entry in _controllers.entries) entry.key: double.parse(entry.value.text),
    };

    setState(() => _errorText = null);
    try {
      final result = widget.definition.evaluate(values);
      setState(() => _result = result);
      _saveToHistory(values, result);
    } on FormulaException catch (e) {
      setState(() {
        _result = null;
        _errorText = e.message;
      });
    }
  }

  Future<void> _saveToHistory(Map<String, double> values, double result) async {
    final uid = context.read<AuthState>().user?.uid;
    if (uid == null) return;
    try {
      await context.read<CalculatorRepository>().recordHistory(
            uid: uid,
            definition: widget.definition,
            inputs: values,
            result: result,
          );
    } catch (_) {
      // Non-fatal — the on-screen result is already shown either way, and
      // Crashlytics (wired app-wide via PlatformDispatcher.onError) will
      // still see this if it's part of a broader problem.
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
                for (final input in definition.inputs) ...[
                  TextFormField(
                    controller: _controllers[input.key],
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: !input.isInteger,
                      signed: false,
                    ),
                    inputFormatters: [
                      if (input.isInteger)
                        FilteringTextInputFormatter.digitsOnly
                      else
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: InputDecoration(
                      labelText: input.label,
                      suffixText: input.suffix,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) => _validateInput(input, value),
                  ),
                  const SizedBox(height: 16),
                ],
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
                            _formatResult(_result!, definition),
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

  String? _validateInput(CalculatorInputField input, String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final parsed = double.tryParse(value);
    if (parsed == null) return 'Enter a number';
    if (input.min != null && parsed < input.min!) return 'Must be at least ${input.min}';
    if (input.max != null && parsed > input.max!) return 'Must be at most ${input.max}';
    return null;
  }

  String _formatResult(double value, CalculatorDefinition definition) {
    final formatted = value.toStringAsFixed(definition.resultDecimalPlaces);
    final suffix = definition.resultSuffix;
    return suffix == null || suffix.isEmpty ? formatted : '$formatted $suffix';
  }
}
