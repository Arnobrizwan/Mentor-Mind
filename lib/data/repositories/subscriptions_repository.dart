import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/data/models/subscription_doc.dart';
import 'package:mentor_minds/data/services/firebase_providers.dart';

// ---------------------------------------------------------------------------
// SubscriptionsRepository — /subscriptions/{uid} (PAY-01 / PAY-05)
// ---------------------------------------------------------------------------

class SubscriptionsRepository {
  SubscriptionsRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _ref(String uid) =>
      _firestore.collection('subscriptions').doc(uid);

  Stream<SubscriptionDoc> watchSubscription(String uid) {
    return _ref(uid).snapshots().map((snap) {
      if (!snap.exists) {
        return SubscriptionDoc(
          userId: uid,
          tier: 'free',
          status: 'inactive',
        );
      }
      return SubscriptionDoc.fromMap(uid, snap.data() ?? {});
    });
  }

  Future<String?> getSubscriptionType(String uid) async {
    final snap = await _ref(uid).get();
    if (!snap.exists) return 'free';
    final doc = SubscriptionDoc.fromMap(uid, snap.data() ?? {});
    return doc.isPremiumActive ? 'premium' : 'free';
  }

  Future<bool> isSubscriptionActive(String uid) async {
    final snap = await _ref(uid).get();
    if (!snap.exists) return false;
    return SubscriptionDoc.fromMap(uid, snap.data() ?? {}).isPremiumActive;
  }
}

final subscriptionsRepositoryProvider = Provider<SubscriptionsRepository>((ref) {
  return SubscriptionsRepository(firestore: ref.read(firestoreProvider));
});
