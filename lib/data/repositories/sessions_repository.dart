import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/data/models/session_item.dart';
import 'package:mentor_minds/data/services/firebase_providers.dart';

// ---------------------------------------------------------------------------
// SessionsRepository — /sessions (D-01, D-02)
// Returns decoded domain models; never raw Firestore snapshots.
// ---------------------------------------------------------------------------

class SessionsRepository {
  SessionsRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  // -------------------------------------------------------------------------
  // watchRecentSessions — streams /sessions filtered by userId, ordered by
  // updatedAt desc, decoded as List<SessionItem>.
  // -------------------------------------------------------------------------

  Stream<List<SessionItem>> watchRecentSessions(String uid, {int limit = 5}) {
    return _firestore
        .collection('sessions')
        .where('userId', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map(SessionItem.fromDoc).toList(growable: false));
  }

  // -------------------------------------------------------------------------
  // searchSessions — one-shot pull from /sessions for the given uid.
  // -------------------------------------------------------------------------

  Future<List<SessionItem>> searchSessions(String uid, {int limit = 20}) async {
    final snap = await _firestore
        .collection('sessions')
        .where('userId', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(SessionItem.fromDoc).toList(growable: false);
  }

  // -------------------------------------------------------------------------
  // saveSession — creates or updates a session document.
  // If sessionId is null: creates a new doc via add() and returns the new id.
  // If sessionId is provided: merge-sets the doc and returns the same id.
  // -------------------------------------------------------------------------

  Future<String> saveSession(
    String uid,
    Map<String, dynamic> data, {
    String? sessionId,
  }) async {
    final sessions = _firestore.collection('sessions');
    if (sessionId == null) {
      final ref = sessions.doc();
      await ref.set(data, SetOptions(merge: true));
      return ref.id;
    } else {
      await sessions.doc(sessionId).set(data, SetOptions(merge: true));
      return sessionId;
    }
  }

  // -------------------------------------------------------------------------
  // getSession — one-shot single-session read, returns raw map for
  // deserialization by callers (e.g. chat_viewmodel.loadSession).
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getSession(String sessionId) async {
    final doc = await _firestore.collection('sessions').doc(sessionId).get();
    return doc.data();
  }

  // -------------------------------------------------------------------------
  // getSessions — one-shot full query for account-deletion cleanup.
  // Returns DocumentReference list for use in a WriteBatch.
  // -------------------------------------------------------------------------

  Future<List<DocumentReference<Map<String, dynamic>>>> getSessionRefs(
    String uid,
  ) async {
    final snap = await _firestore
        .collection('sessions')
        .where('userId', isEqualTo: uid)
        .get();
    return snap.docs.map((d) => d.reference).toList(growable: false);
  }

  // -------------------------------------------------------------------------
  // searchSessionDocs — returns raw query snapshot for search_viewmodel which
  // needs to do client-side content filtering across message arrays.
  // D-02 note: the query itself is a Firestore operation; raw maps are
  // extracted so the caller does not receive a QuerySnapshot (D-02 compliant —
  // it returns List<Map> rather than QuerySnapshot).
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> searchSessionDocs(
    String uid, {
    int limit = 100,
    DateTime? since,
  }) async {
    Query<Map<String, dynamic>> q = _firestore
        .collection('sessions')
        .where('userId', isEqualTo: uid)
        .orderBy('updatedAt', descending: true);

    if (since != null) {
      q = q.where('updatedAt', isGreaterThan: Timestamp.fromDate(since));
    }

    final snap = await q.limit(limit).get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(growable: false);
  }

  // -------------------------------------------------------------------------
  // countSessions — aggregate count for stats (profile screen).
  // -------------------------------------------------------------------------

  Future<int> countSessions(String uid) async {
    final agg = await _firestore
        .collection('sessions')
        .where('userId', isEqualTo: uid)
        .count()
        .get();
    return agg.count ?? 0;
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final sessionsRepositoryProvider = Provider<SessionsRepository>((ref) {
  return SessionsRepository(firestore: ref.read(firestoreProvider));
});
