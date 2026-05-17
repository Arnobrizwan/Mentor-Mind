import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/data/models/dashboard_user.dart';
import 'package:mentor_minds/data/models/leaderboard_entry.dart';
import 'package:mentor_minds/data/models/profile_user.dart';
import 'package:mentor_minds/data/services/firebase_providers.dart';

// ---------------------------------------------------------------------------
// UsersRepository — /users/{uid} + /users/{uid}/usage/{date} (D-01, D-02)
// Returns decoded domain models; never raw Firestore snapshots.
// ---------------------------------------------------------------------------

class UsersRepository {
  UsersRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // -------------------------------------------------------------------------
  // watchDashboardUser — streams /users/{uid} decoded as DashboardUser.
  // authDisplayName is sourced by the caller (e.g. _authRepo.currentUser?.displayName)
  // so this repo does NOT read FirebaseAuth directly (single-responsibility).
  // -------------------------------------------------------------------------

  Stream<DashboardUser> watchDashboardUser(String uid, String? authDisplayName) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
      final data = doc.data() ?? const <String, dynamic>{};
      return DashboardUser.fromDoc(uid, data, authDisplayName);
    });
  }

  // -------------------------------------------------------------------------
  // watchProfileUser — streams /users/{uid} decoded as ProfileUser.
  // -------------------------------------------------------------------------

  Stream<ProfileUser> watchProfileUser(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
      final data = doc.data() ?? const <String, dynamic>{};
      return ProfileUser.fromDoc(uid, data, _auth.currentUser);
    });
  }

  // -------------------------------------------------------------------------
  // getDashboardUser — one-shot /users/{uid} read decoded as DashboardUser.
  // -------------------------------------------------------------------------

  Future<DashboardUser?> getDashboardUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return null;
    return DashboardUser.fromDoc(uid, data, _auth.currentUser?.displayName);
  }

  // -------------------------------------------------------------------------
  // getUsageDoc — reads /users/{uid}/usage/{dateKey}.
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getUsageDoc(String uid, String dateKey) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('usage')
        .doc(dateKey)
        .get();
    return doc.data();
  }

  // -------------------------------------------------------------------------
  // setUsageDoc — merge-writes /users/{uid}/usage/{dateKey}.
  // -------------------------------------------------------------------------

  Future<void> setUsageDoc(
    String uid,
    String dateKey,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('usage')
        .doc(dateKey)
        .set(data, SetOptions(merge: true));
  }

  // -------------------------------------------------------------------------
  // getUsageHistory — reads all /users/{uid}/usage docs, ordered by id desc.
  // Returns raw map list because usage docs are not a named domain entity.
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getUsageHistory(
    String uid, {
    int limit = 45,
  }) async {
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('usage')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(growable: false);
  }

  // -------------------------------------------------------------------------
  // updateUserFields — partial update on /users/{uid}.
  // -------------------------------------------------------------------------

  Future<void> updateUserFields(String uid, Map<String, dynamic> fields) async {
    await _firestore.collection('users').doc(uid).update(fields);
  }

  // -------------------------------------------------------------------------
  // setUserFields — merge-set on /users/{uid} (used for registration + profile).
  // -------------------------------------------------------------------------

  Future<void> setUserFields(
    String uid,
    Map<String, dynamic> fields,
  ) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .set(fields, SetOptions(merge: true));
  }

  // -------------------------------------------------------------------------
  // getUserDocRaw — one-shot /users/{uid} read returning the raw map.
  // Prefer getDashboardUser for typed access; this is for role-lookup paths.
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getUserDocRaw(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  // -------------------------------------------------------------------------
  // incrementUsageMessageCount — increments messageCount + updates lastMessageAt
  // on /users/{uid}/usage/{dateKey}. Called by ChatViewModel after each message.
  // -------------------------------------------------------------------------

  Future<void> incrementUsageMessageCount(String uid, String dateKey) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('usage')
        .doc(dateKey)
        .set({
      'date': dateKey,
      'messageCount': FieldValue.increment(1),
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // -------------------------------------------------------------------------
  // awardSessionPoints — batch: increments points on /users/{uid} and appends
  // a history entry to /rewards/{uid}. Called by ChatViewModel after sessions.
  // -------------------------------------------------------------------------

  Future<void> awardSessionPoints(
    String uid,
    String action,
    int amount,
  ) async {
    final batch = _firestore.batch();
    batch.update(_firestore.collection('users').doc(uid), {
      'points': FieldValue.increment(amount),
    });
    batch.set(
      _firestore.collection('rewards').doc(uid),
      {
        'userId': uid,
        'points': FieldValue.increment(amount),
        'history': FieldValue.arrayUnion([
          {
            'type': action,
            'points': amount,
            'at': Timestamp.now(),
          }
        ]),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  // -------------------------------------------------------------------------
  // awardDailyLogin — atomic batch: marks login rewarded in usage doc and
  // increments points in both /users/{uid} and /rewards/{uid}.
  // Called by DashboardViewModel to award the daily login bonus.
  // -------------------------------------------------------------------------

  Future<void> awardDailyLogin(
    String uid,
    String dateKey, {
    int amount = 5,
  }) async {
    // Mark the usage doc as rewarded.
    await setUsageDoc(uid, dateKey, {
      'date': dateKey,
      'loginRewarded': true,
      'loginRewardedAt': FieldValue.serverTimestamp(),
    });

    // Atomically increment points and append history via batch.
    final batch = _firestore.batch();
    batch.update(_firestore.collection('users').doc(uid), {
      'points': FieldValue.increment(amount),
    });
    batch.set(
      _firestore.collection('rewards').doc(uid),
      {
        'userId': uid,
        'points': FieldValue.increment(amount),
        'history': FieldValue.arrayUnion([
          {
            'type': 'daily_login',
            'points': amount,
            'date': dateKey,
          }
        ]),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  // -------------------------------------------------------------------------
  // startBatch — returns a WriteBatch for atomic multi-doc writes.
  // This leaks a Firestore-specific type to callers — intentional per D-02:
  // "batch handles are the only documented exception." Callers use batch
  // helpers below to obtain DocumentReferences without importing Firestore.
  // -------------------------------------------------------------------------

  WriteBatch startBatch() => _firestore.batch();

  /// Batch helper — returns the raw DocumentReference for /users/{uid}.
  /// For use in WriteBatch ops only. (D-02 batch exception)
  DocumentReference<Map<String, dynamic>> userDocRef(String uid) =>
      _firestore.collection('users').doc(uid);

  /// Batch helper — returns the raw DocumentReference for /rewards/{uid}.
  /// For use in WriteBatch ops only. (D-02 batch exception)
  DocumentReference<Map<String, dynamic>> rewardsDocRef(String uid) =>
      _firestore.collection('rewards').doc(uid);

  /// Batch helper — returns the raw DocumentReference for /sessions/{sid}.
  /// For use in WriteBatch ops only. (D-02 batch exception)
  DocumentReference<Map<String, dynamic>> sessionDocRef(String sessionId) =>
      _firestore.collection('sessions').doc(sessionId);

  // -------------------------------------------------------------------------
  // watchUserDocRaw — streams /users/{uid} as a raw Map.
  // Used by RewardsViewModel as a fallback source for points and subject tags
  // when the /rewards/{uid} doc hasn't been created yet.
  // -------------------------------------------------------------------------

  Stream<Map<String, dynamic>> watchUserDocRaw(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.data() ?? const <String, dynamic>{});
  }

  // -------------------------------------------------------------------------
  // getLeaderboard — top-N users by points plus the current user's rank.
  // Returns a record: top contains the ranked list; currentUserRow is non-null
  // only when the current user is NOT already in the top list.
  // -------------------------------------------------------------------------

  Future<({List<LeaderboardEntry> top, LeaderboardEntry? currentUserRow})>
      getLeaderboard(String currentUid, {int limit = 10}) async {
    final snap = await _firestore
        .collection('users')
        .orderBy('points', descending: true)
        .limit(limit)
        .get();

    final entries = <LeaderboardEntry>[];
    var rank = 0;
    var currentUserInTop = false;
    for (final doc in snap.docs) {
      rank += 1;
      final data = doc.data();
      String name = (data['name'] as String?)?.trim() ??
          (data['displayName'] as String?)?.trim() ??
          'Learner';
      if (name.isEmpty) name = 'Learner';
      String? avatar = (data['avatarUrl'] as String?)?.trim();
      if (avatar == null || avatar.isEmpty) {
        avatar = (data['photoUrl'] as String?)?.trim();
      }
      final isCurrentUser = doc.id == currentUid;
      if (isCurrentUser) currentUserInTop = true;
      entries.add(LeaderboardEntry(
        uid: doc.id,
        name: name,
        avatarUrl: (avatar?.isEmpty ?? true) ? null : avatar,
        points: (data['points'] as num?)?.toInt() ?? 0,
        subject: (data['subjects'] as List?)?.isNotEmpty == true
            ? (data['subjects'] as List).first.toString()
            : null,
        rank: rank,
        isCurrentUser: isCurrentUser,
      ));
    }

    LeaderboardEntry? currentUserRow;
    if (!currentUserInTop) {
      // Best-effort fetch for the current user's own doc so we can show their
      // approximate rank even when they're outside the top-N list.
      try {
        final userDoc = await _firestore.collection('users').doc(currentUid).get();
        final data = userDoc.data();
        if (data != null) {
          final userPoints = (data['points'] as num?)?.toInt() ?? 0;
          // Approximate rank via count query — not exact but good enough for UI.
          final countSnap = await _firestore
              .collection('users')
              .where('points', isGreaterThan: userPoints)
              .count()
              .get();
          final approxRank = (countSnap.count ?? 0) + 1;
          String name = (data['name'] as String?)?.trim() ??
              (data['displayName'] as String?)?.trim() ??
              'Learner';
          if (name.isEmpty) name = 'Learner';
          String? avatar = (data['avatarUrl'] as String?)?.trim();
          if (avatar == null || avatar.isEmpty) {
            avatar = (data['photoUrl'] as String?)?.trim();
          }
          currentUserRow = LeaderboardEntry(
            uid: currentUid,
            name: name,
            avatarUrl: (avatar?.isEmpty ?? true) ? null : avatar,
            points: userPoints,
            subject: (data['subjects'] as List?)?.isNotEmpty == true
                ? (data['subjects'] as List).first.toString()
                : null,
            rank: approxRank,
            isCurrentUser: true,
          );
        }
      } catch (_) {
        // Non-fatal — the current user row is optional UI sugar.
      }
    }

    return (top: entries, currentUserRow: currentUserRow);
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(
    firestore: ref.read(firestoreProvider),
    auth: ref.read(firebaseAuthProvider),
  );
});
