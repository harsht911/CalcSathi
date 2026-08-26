import 'package:cloud_firestore/cloud_firestore.dart';

/// One completed calculator run, as stored under
/// `users/{uid}/history/{entryId}` (write-once — see `firestore.rules`).
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.calculatorId,
    required this.calculatorName,
    required this.inputs,
    required this.result,
    required this.resultLabel,
    this.resultSuffix,
    required this.computedAt,
  });

  final String id;
  final String calculatorId;
  final String calculatorName;
  final Map<String, double> inputs;
  final double result;
  final String resultLabel;
  final String? resultSuffix;
  final DateTime? computedAt;

  factory HistoryEntry.fromFirestore(String id, Map<String, dynamic> data) {
    final rawInputs = (data['inputs'] as Map<String, dynamic>? ?? const {});
    return HistoryEntry(
      id: id,
      calculatorId: data['calculatorId'] as String? ?? '',
      calculatorName: data['calculatorName'] as String? ?? 'Calculator',
      inputs: rawInputs.map((key, value) => MapEntry(key, (value as num).toDouble())),
      result: (data['result'] as num?)?.toDouble() ?? 0,
      resultLabel: data['resultLabel'] as String? ?? 'Result',
      resultSuffix: data['resultSuffix'] as String?,
      // `computedAt` is a Firestore server timestamp — null for the brief
      // window between an optimistic local write and the server's estimate
      // resolving, which callers should handle (see HistoryScreen).
      computedAt: (data['computedAt'] as Timestamp?)?.toDate(),
    );
  }
}
