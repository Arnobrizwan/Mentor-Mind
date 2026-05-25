import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/data/models/points_history.dart';
import 'package:mentor_minds/data/models/rewards_doc.dart';
import 'package:mentor_minds/data/services/firebase_providers.dart';

// ---------------------------------------------------------------------------
// RewardsRepository — /rewards/{uid} read-only (Phase 4 server-authoritative)
// ---------------------------------------------------------------------------

class RewardsRepository {
  RewardsRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _rewardsRef(String uid) =>
      _firestore.collection('rewards').doc(uid);

  // -------------------------------------------------------------------------
  // watchRewards — streams /rewards/{uid} decoded as RewardsDoc.
  // -------------------------------------------------------------------------

  Stream<RewardsDoc> watchRewards(String uid) {
    return _rewardsRef(uid).snapshots().map((doc) {
      if (!doc.exists) return RewardsDoc.empty;
      final data = doc.data() ?? {};
      final badges = ((data['badges'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false);
      return RewardsDoc(
        userId: (data['userId'] as String?) ?? uid,
        points: (data['points'] as num?)?.toInt() ?? 0,
        badges: badges,
        history: const [],
      );
    });
  }

  // -------------------------------------------------------------------------
  // watchLedger — paginated append-only history (REWD-03).
  // -------------------------------------------------------------------------

  Stream<List<PointsHistory>> watchLedger(String uid, {int limit = 50}) {
    return _rewardsRef(uid)
        .collection('ledger')
        .orderBy('awardedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => PointsHistory.fromMap(d.data()))
          .toList(growable: false);
    });
  }

  // -------------------------------------------------------------------------
  // bootstrapRewards — idempotent creation (registration may also use
  // onUserCreate trigger; this remains a client-side safety net).
  // -------------------------------------------------------------------------

  Future<void> bootstrapRewards(String uid) async {
    final ref = _rewardsRef(uid);
    final snap = await ref.get();
    if (snap.exists) return;
    // Rules block client writes — trigger creates the doc. No-op if locked.
  }

  /// One-shot user doc read for badge eligibility display.
  Future<Map<String, dynamic>?> getUserDocRaw(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  Stream<Map<String, dynamic>> watchRewardsRaw(String uid) {
    return _rewardsRef(uid).snapshots().map((doc) {
      final raw = doc.data() ?? const <String, dynamic>{};
      final earnedAt = raw['earnedAt'];
      if (earnedAt is Map) {
        final decoded = <String, dynamic>{};
        earnedAt.forEach((key, value) {
          if (value is Timestamp) {
            decoded[key.toString()] = value.toDate();
          } else {
            decoded[key.toString()] = value;
          }
        });
        return <String, dynamic>{...raw, 'earnedAt': decoded};
      }
      return raw;
    });
  }
}

final rewardsRepositoryProvider = Provider<RewardsRepository>((ref) {
  return RewardsRepository(firestore: ref.read(firestoreProvider));
});
