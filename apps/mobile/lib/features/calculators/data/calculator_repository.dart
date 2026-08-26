import 'package:cloud_firestore/cloud_firestore.dart';

import 'calculator_definition.dart';
import 'history_entry.dart';

/// Firestore access for the calculator catalog and a signed-in user's
/// history/favorites. Takes an injected [FirebaseFirestore] (not
/// `FirebaseFirestore.instance`) so it can be exercised in widget tests
/// with `fake_cloud_firestore`, matching [AuthRepository]'s pattern.
class CalculatorRepository {
  CalculatorRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// The full catalog, ordered by name.
  ///
  /// Deliberately a single-field `orderBy` (auto-indexed by Firestore, no
  /// deploy step needed) rather than `orderBy('category').orderBy('name')`
  /// — a multi-field orderBy needs a composite index Harsh would have to
  /// remember to create/deploy, and the catalog is small enough (a few
  /// dozen entries at most, per the milestone roadmap) that grouping by
  /// category client-side in [CatalogScreen] costs nothing.
  Stream<List<CalculatorDefinition>> watchCatalog() {
    return _firestore.collection('calculators').orderBy('name').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => CalculatorDefinition.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> recordHistory({
    required String uid,
    required CalculatorDefinition definition,
    required Map<String, double> inputs,
    required double result,
  }) async {
    await _firestore.collection('users').doc(uid).collection('history').add({
      'calculatorId': definition.id,
      'calculatorName': definition.name,
      'inputs': inputs,
      'result': result,
      'resultLabel': definition.resultLabel,
      'resultSuffix': definition.resultSuffix,
      'computedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<HistoryEntry>> watchHistory(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('history')
        .orderBy('computedAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HistoryEntry.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  /// Streams the set of currently-favorited calculator IDs — a `Set` rather
  /// than full definitions, so [CatalogScreen] can cheaply check
  /// `favoriteIds.contains(definition.id)` per tile without a second join.
  Stream<Set<String>> watchFavoriteIds(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }

  /// Streams the favorited calculators themselves (name/category snapshotted
  /// at favorite-time, so this survives a catalog entry changing or — in
  /// the admin panel, post-M5 — being removed).
  Stream<List<Map<String, dynamic>>> watchFavorites(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  /// Fetches one calculator by ID — used by [FavoritesScreen] to open the
  /// full [CalculatorDefinition] (formula + inputs) for a favorited entry,
  /// which only stores a name/category snapshot.
  Future<CalculatorDefinition?> getCalculator(String id) async {
    final doc = await _firestore.collection('calculators').doc(id).get();
    final data = doc.data();
    if (data == null) return null;
    return CalculatorDefinition.fromFirestore(doc.id, data);
  }

  Future<void> setFavorite({
    required String uid,
    required CalculatorDefinition definition,
    required bool isFavorite,
  }) async {
    final docRef =
        _firestore.collection('users').doc(uid).collection('favorites').doc(definition.id);
    if (isFavorite) {
      await docRef.set({
        'calculatorName': definition.name,
        'category': definition.category,
        'addedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.delete();
    }
  }
}
