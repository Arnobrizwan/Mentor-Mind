import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/data/models/points_history.dart';
import 'package:mentor_minds/data/models/rewards_doc.dart';
import 'package:mentor_minds/data/services/firebase_providers.dart';

// ---------------------------------------------------------------------------
// RewardsRepository — /rewards/{uid} (D-01, D-02)
// Returns decoded domain models; never raw Firestore snapshots.
// ---------------------------------------------------------------------------

class RewardsRepository {
  RewardsRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  // -------------------------------------------------------------------------
  // watchRewards — streams /rewards/{uid} decoded as RewardsDoc.
  // -------------------------------------------------------------------------

  Stream<RewardsDoc> watchRewards(String uid) {
    return _firestore
        .collection('rewards')
        .where('userId', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return RewardsDoc.empty;
      final doc = snap.docs.first;
      final data = doc.data();
      final history = ((data['history'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => PointsHistory.fromMap(m.cast<String, dynamic>()))
          .toList(growable: false);
      final badges = ((data['badges'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false);
      return RewardsDoc(
        userId: (data['userId'] as String?) ?? uid,
        points: (data['points'] as num?)?.toInt() ?? 0,
        badges: badges,
        history: history,
      );
    });
  }

  // -------------------------------------------------------------------------
  // awardPoints — merge-set on /rewards/{uid} to increment points.
  // Also updates /users/{uid}.points to keep denormalised fields in sync.
  // -------------------------------------------------------------------------

  Future<void> awardPoints(String uid, String action, int delta) async {
    await _firestore.runTransaction<void>((txn) async {
      final userRef = _firestore.collection('users').doc(uid);
      final rewardsRef = _firestore.collection('rewards').doc(uid);

      final historyEntry = <String, dynamic>{
        'action': action,
        'pointsAwarded': delta,
        'timestamp': Timestamp.now(),
      };

      txn.set(
        userRef,
        {'points': FieldValue.increment(delta)},
        SetOptions(merge: true),
      );
      txn.set(
        rewardsRef,
        {
          'userId': uid,
          'points': FieldValue.increment(delta),
          'history': FieldValue.arrayUnion([historyEntry]),
        },
        SetOptions(merge: true),
      );
    });
  }

  // -------------------------------------------------------------------------
  // awardPointsBatch — awards points using a provided batch.
  // D-02 batch exception: WriteBatch is a Firestore type.
  // -------------------------------------------------------------------------

  void awardPointsBatch(
    WriteBatch batch,
    String uid,
    int delta,
    Map<String, dynamic> historyEntry,
  ) {
    final userRef = _firestore.collection('users').doc(uid);
    final rewardsRef = _firestore.collection('rewards').doc(uid);
    batch.update(userRef, {'points': FieldValue.increment(delta)});
    batch.set(
      rewardsRef,
      {
        'userId': uid,
        'points': FieldValue.increment(delta),
        'history': FieldValue.arrayUnion([historyEntry]),
      },
      SetOptions(merge: true),
    );
  }

  // -------------------------------------------------------------------------
  // addBadge — arrayUnion on /rewards/{uid}.badges (and /users/{uid}.badges).
  // -------------------------------------------------------------------------

  Future<void> addBadge(String uid, String badgeId) async {
    final userRef = _firestore.collection('users').doc(uid);
    final rewardsRef = _firestore.collection('rewards').doc(uid);
    final batch = _firestore.batch();
    batch.set(
      userRef,
      {'badges': FieldValue.arrayUnion([badgeId])},
      SetOptions(merge: true),
    );
    batch.set(
      rewardsRef,
      {
        'userId': uid,
        'badges': FieldValue.arrayUnion([badgeId]),
        'earnedAt': {badgeId: FieldValue.serverTimestamp()},
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  // -------------------------------------------------------------------------
  // addBadgesBatch — awards multiple badges atomically, emits earnedAt map.
  // D-02 batch exception: WriteBatch is a Firestore type.
  // -------------------------------------------------------------------------

  void addBadgesBatch(
    WriteBatch batch,
    String uid,
    List<String> badgeIds,
    Map<String, dynamic> earnedAt,
  ) {
    final userRef = _firestore.collection('users').doc(uid);
    final rewardsRef = _firestore.collection('rewards').doc(uid);
    batch.set(
      userRef,
      {'badges': FieldValue.arrayUnion(badgeIds)},
      SetOptions(merge: true),
    );
    batch.set(
      rewardsRef,
      {
        'userId': uid,
        'badges': FieldValue.arrayUnion(badgeIds),
        'earnedAt': earnedAt,
      },
      SetOptions(merge: true),
    );
  }

  // -------------------------------------------------------------------------
  // bootstrapRewards — idempotent creation of /rewards/{uid} for a new user.
  // -------------------------------------------------------------------------

  Future<void> bootstrapRewards(String uid) async {
    await _firestore.collection('rewards').doc(uid).set({
      'userId': uid,
      'points': 0,
      'badges': <String>[],
      'history': <Map<String, dynamic>>[],
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // -------------------------------------------------------------------------
  // startBatch — returns a WriteBatch for multi-doc atomic writes.
  // D-02 batch exception: WriteBatch is a Firestore type.
  // -------------------------------------------------------------------------

  WriteBatch startBatch() => _firestore.batch();

  /// Batch helper — DocumentReference for /rewards/{uid}.
  /// For use in WriteBatch ops only. (D-02 batch exception)
  DocumentReference<Map<String, dynamic>> rewardsDocRef(String uid) =>
      _firestore.collection('rewards').doc(uid);

  /// Batch helper — DocumentReference for /users/{uid}.
  /// For use in WriteBatch ops only. (D-02 batch exception)
  DocumentReference<Map<String, dynamic>> userDocRef(String uid) =>
      _firestore.collection('users').doc(uid);

  // -------------------------------------------------------------------------
  // appendLedgerEntry — STUB (Phase 4).
  // Phase 4 will replace client-side writes here with the `onSessionWrite`
  // Cloud Function trigger. In Phase 1 this method exists so the repo surface
  // is stable, but the client SHOULD NOT call it (call sites are TBD in Phase 4).
  // -------------------------------------------------------------------------

  Future<void> appendLedgerEntry(String uid, Map<String, dynamic> entry) async {
    await _firestore
        .collection('rewards')
        .doc(uid)
        .collection('ledger')
        .add(entry);
  }

  // -------------------------------------------------------------------------
  // runTransaction — exposes Firestore transaction for complex atomic writes.
  // D-02 batch exception: Transaction is a Firestore type needed for
  // multi-document atomicity in gamification (badge + points in one txn).
  // -------------------------------------------------------------------------

  Future<T> runTransaction<T>(
    Future<T> Function(Transaction txn) action,
  ) {
    return _firestore.runTransaction<T>(action);
  }

  /// Batch helper — user reference for transaction ops.
  /// For use in Transaction ops only. (D-02 batch exception)
  DocumentReference<Map<String, dynamic>> usersRef(String uid) =>
      _firestore.collection('users').doc(uid);

  /// Batch helper — sessions aggregate query for badge eligibility.
  AggregateQuery sessionsCountQuery(String uid) => _firestore
      .collection('sessions')
      .where('userId', isEqualTo: uid)
      .count();

  /// One-shot user doc read for badge eligibility.
  Future<Map<String, dynamic>?> getUserDocRaw(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  // -------------------------------------------------------------------------
  // watchRewardsRaw — streams /rewards/{uid} as a raw Map with Timestamps
  // decoded to DateTime. Used by RewardsViewModel for badge-merging logic
  // that requires access to the earnedAt sub-map as typed DateTime values.
  // Raw access is intentional: the viewmodel handles the complex badge-merge
  // logic; structured decoding would discard intermediate fields needed there.
  // -------------------------------------------------------------------------

  Stream<Map<String, dynamic>> watchRewardsRaw(String uid) {
    return _firestore
        .collection('rewards')
        .doc(uid)
        .snapshots()
        .map((doc) {
      final raw = doc.data() ?? const <String, dynamic>{};
      // Decode earnedAt sub-map: Timestamp → DateTime so the viewmodel
      // never needs to import cloud_firestore.
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

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final rewardsRepositoryProvider = Provider<RewardsRepository>((ref) {
  return RewardsRepository(firestore: ref.read(firestoreProvider));
});
