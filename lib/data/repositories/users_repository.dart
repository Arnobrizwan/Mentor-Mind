import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/data/models/dashboard_user.dart';
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
