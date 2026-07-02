import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/data/models/learning_material.dart';
import 'package:mentor_minds/data/models/material_item.dart';
import 'package:mentor_minds/data/services/firebase_providers.dart';

// ---------------------------------------------------------------------------
// MaterialsRepository — /materials collection (D-01, D-02)
// Returns decoded domain models; never raw Firestore snapshots.
// ---------------------------------------------------------------------------

class MaterialsRepository {
  MaterialsRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  // -------------------------------------------------------------------------
  // streamMaterials — filtered stream of LearningMaterial (browse screen).
  // D-02 cursor-pagination exception: startAfter accepts DocumentSnapshot
  // because Firestore cursor pagination requires the raw cursor type. The
  // public API returns decoded models — only the input param uses Firestore type.
  // -------------------------------------------------------------------------

  Stream<List<LearningMaterial>> streamMaterials({
    String? subject,
    String? level,
    MaterialType? type,
    /// Cursor pagination input — DocumentSnapshot is intentionally accepted
    /// here per D-02 documented exception (cursor pagination inputs).
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) {
    Query<Map<String, dynamic>> q = _firestore
        .collection('materials')
        .orderBy('createdAt', descending: true);

    if (subject != null && subject != 'all') {
      q = q.where('subject', isEqualTo: subject);
    }
    if (level != null && level != 'both') {
      // Materials published for 'both' levels must appear under either
      // specific level filter.
      q = q.where('level', whereIn: [level, 'both']);
    }
    if (type != null) {
      q = q.where('type', isEqualTo: type.name);
    }
    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    return q
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map(LearningMaterial.fromDoc).toList(growable: false));
  }

  // -------------------------------------------------------------------------
  // getMaterials — one-shot paginated query for MaterialsViewModel.
  // Returns a record of (items, lastDoc) for cursor-pagination support.
  // lastDoc is the cursor — only returned for the caller to pass back as
  // startAfter; it is never surfaced to UI (D-02 cursor exception).
  // -------------------------------------------------------------------------

  Future<({List<LearningMaterial> items, DocumentSnapshot? lastDoc})>
      getMaterials({
    String? subject,
    String? level,
    MaterialType? type,
    /// Cursor pagination input — see D-02 cursor-pagination exception above.
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> q = _firestore
        .collection('materials')
        .orderBy('createdAt', descending: true);

    if (subject != null && subject != 'all') {
      q = q.where('subject', isEqualTo: subject);
    }
    if (level != null && level != 'both') {
      // Materials published for 'both' levels must appear under either
      // specific level filter.
      q = q.where('level', whereIn: [level, 'both']);
    }
    if (type != null) {
      q = q.where('type', isEqualTo: type.name);
    }
    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    final snap = await q.limit(limit).get();
    final items = snap.docs.map(LearningMaterial.fromDoc).toList(growable: false);
    final lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
    return (items: items, lastDoc: lastDoc);
  }

  // -------------------------------------------------------------------------
  // streamDashboardMaterials — lightweight MaterialItem projection (dashboard).
  // -------------------------------------------------------------------------

  Stream<List<MaterialItem>> streamDashboardMaterials({int limit = 4}) {
    return _firestore
        .collection('materials')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map(MaterialItem.fromDoc).toList(growable: false));
  }

  // -------------------------------------------------------------------------
  // streamDashboardMaterialsBySubjects — filtered MaterialItem for dashboard.
  // -------------------------------------------------------------------------

  Stream<List<MaterialItem>> streamDashboardMaterialsBySubjects(
    List<String> subjects, {
    int limit = 6,
  }) {
    final capped = subjects.take(10).toList();
    return _firestore
        .collection('materials')
        .where('subject', whereIn: capped)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map(MaterialItem.fromDoc).toList(growable: false));
  }

  // -------------------------------------------------------------------------
  // searchMaterialDocs — title prefix + subject exact-match queries.
  // Runs both original-case and title-case variants to improve hit rate on
  // case-sensitive Firestore starts-with queries. Returns raw maps (no
  // QuerySnapshot leak — D-02 compliant). The '' suffix is the standard
  // Firestore "prefix search" upper bound.
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> searchMaterialDocs(
    String query, {
    List<String> knownSubjects = const [],
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final end = '$q';
    final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[
      _firestore
          .collection('materials')
          .where('title', isGreaterThanOrEqualTo: q)
          .where('title', isLessThan: end)
          .limit(10)
          .get(),
    ];

    // Also try title-case variant for case-insensitive improvement.
    if (q[0].toUpperCase() != q[0]) {
      final cap = q[0].toUpperCase() + q.substring(1);
      final capEnd = '$cap';
      futures.add(
        _firestore
            .collection('materials')
            .where('title', isGreaterThanOrEqualTo: cap)
            .where('title', isLessThan: capEnd)
            .limit(10)
            .get(),
      );
    }

    // Subject exact-match if query matches a known subject prefix.
    final matchingSubject = knownSubjects.firstWhere(
      (s) => s.toLowerCase().startsWith(q.toLowerCase()),
      orElse: () => '',
    );
    if (matchingSubject.isNotEmpty) {
      futures.add(
        _firestore
            .collection('materials')
            .where('subject', isEqualTo: matchingSubject)
            .orderBy('createdAt', descending: true)
            .limit(10)
            .get(),
      );
    }

    final snaps = await Future.wait(futures);
    final byId = <String, Map<String, dynamic>>{};
    for (final snap in snaps) {
      for (final doc in snap.docs) {
        byId[doc.id] = {'id': doc.id, ...doc.data()};
      }
    }
    return byId.values.toList(growable: false);
  }

  // -------------------------------------------------------------------------
  // incrementViewCount — increments the views counter on a material doc.
  // -------------------------------------------------------------------------

  Future<void> incrementViewCount(String materialId) async {
    await _firestore
        .collection('materials')
        .doc(materialId)
        .update({'views': FieldValue.increment(1)});
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final materialsRepositoryProvider = Provider<MaterialsRepository>((ref) {
  return MaterialsRepository(firestore: ref.read(firestoreProvider));
});
