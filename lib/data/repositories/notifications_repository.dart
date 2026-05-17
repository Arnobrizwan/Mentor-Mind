import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/data/models/app_notification.dart';
import 'package:mentor_minds/data/services/firebase_providers.dart';

// ---------------------------------------------------------------------------
// NotificationsRepository — /notifications collection (D-01, D-02)
// Returns decoded domain models; never raw Firestore snapshots.
// ---------------------------------------------------------------------------

class NotificationsRepository {
  NotificationsRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  // -------------------------------------------------------------------------
  // watchNotifications — streams /notifications for a given role.
  // Includes docs addressed to 'all' recipients and the specific role.
  // -------------------------------------------------------------------------

  Stream<List<AppNotification>> watchNotifications(
    String role, {
    int limit = 50,
  }) {
    return _firestore
        .collection('notifications')
        .where('recipientRole', whereIn: ['all', role])
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map(AppNotification.fromDoc).toList(growable: false));
  }

  // -------------------------------------------------------------------------
  // watchUnreadCount — streams the count of unread notifications for a role.
  // -------------------------------------------------------------------------

  Stream<int> watchUnreadCount(String role) {
    return _firestore
        .collection('notifications')
        .where('recipientRole', whereIn: ['all', role])
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.size);
  }

  // -------------------------------------------------------------------------
  // markRead — marks a single notification as read.
  // -------------------------------------------------------------------------

  Future<void> markRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  // -------------------------------------------------------------------------
  // markAllRead — batch marks all unread notifications for a role as read.
  // -------------------------------------------------------------------------

  Future<void> markAllRead(String role) async {
    final snap = await _firestore
        .collection('notifications')
        .where('recipientRole', whereIn: ['all', role])
        .where('read', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // -------------------------------------------------------------------------
  // deleteNotification — removes a notification doc globally.
  // -------------------------------------------------------------------------

  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(firestore: ref.read(firestoreProvider));
});
