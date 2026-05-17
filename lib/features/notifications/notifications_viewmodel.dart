import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Filter strings — match the `type` field on notification docs. 'all' is a
// sentinel that disables filtering. 'announcements' is a UI bucket that
// includes both 'announcement' and 'new_material' docs.
// ---------------------------------------------------------------------------

abstract final class NotificationFilter {
  static const all = 'all';
  static const announcements = 'announcements';
  static const achievements = 'achievements';
  static const reminders = 'reminders';

  static const values = <String>[
    all,
    announcements,
    achievements,
    reminders,
  ];
}

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'announcement' | 'achievement' | 'reminder' | 'new_material'
  final String recipientRole; // 'all' | 'student' | 'teacher' | 'admin'
  final String? deeplink;
  final DateTime? timestamp;
  final bool read;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.recipientRole,
    required this.deeplink,
    required this.timestamp,
    required this.read,
  });

  String get icon => switch (type) {
        'achievement' => '🏆',
        'reminder' => '⏰',
        'new_material' => '📚',
        _ => '📢',
      };

  /// Reads tolerant of historical field names: prefers `timestamp` (spec),
  /// falls back to `createdAt` (legacy seed). Same for body/message.
  factory AppNotification.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final ts = data['timestamp'] ?? data['createdAt'];
    return AppNotification(
      id: doc.id,
      title: (data['title'] as String?)?.trim() ?? 'Notification',
      body: ((data['body'] as String?) ?? (data['message'] as String?) ?? '')
          .trim(),
      type: _normalizeType(data),
      recipientRole:
          (data['recipientRole'] as String?)?.trim() ?? 'all',
      deeplink: (data['deeplink'] as String?)?.trim().isEmpty == true
          ? null
          : (data['deeplink'] as String?),
      timestamp: ts is Timestamp ? ts.toDate() : null,
      read: (data['read'] as bool?) ?? false,
    );
  }
}

String _normalizeType(Map<String, dynamic> data) {
  final explicit = (data['type'] as String?)?.trim().toLowerCase();
  if (explicit != null && explicit.isNotEmpty) {
    if (explicit == 'newmaterial' || explicit == 'material') {
      return 'new_material';
    }
    return explicit;
  }

  // Heuristic fallback for legacy docs without a `type` field.
  final deeplink = (data['deeplink'] as String?)?.toLowerCase() ?? '';
  final haystack =
      '${data['title'] ?? ''} ${data['body'] ?? ''} ${data['message'] ?? ''}'
          .toLowerCase();

  if (deeplink.contains('/materials')) return 'new_material';
  if (haystack.contains('badge') ||
      haystack.contains('earned') ||
      haystack.contains('achievement')) {
    return 'achievement';
  }
  if (haystack.contains('streak') && haystack.contains('keep')) {
    return 'reminder';
  }
  if (haystack.contains('reminder') ||
      haystack.contains('pending') ||
      haystack.contains('approval')) {
    return 'reminder';
  }
  return 'announcement';
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class NotificationsState {
  final List<AppNotification> notifications; // full loaded set
  final List<AppNotification> filteredNotifications; // derived
  final int unreadCount; // across full set, not filtered
  final bool isLoading;
  final String activeFilter;

  const NotificationsState({
    this.notifications = const [],
    this.filteredNotifications = const [],
    this.unreadCount = 0,
    this.isLoading = true,
    this.activeFilter = NotificationFilter.all,
  });

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    List<AppNotification>? filteredNotifications,
    int? unreadCount,
    bool? isLoading,
    String? activeFilter,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      filteredNotifications:
          filteredNotifications ?? this.filteredNotifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }
}

// ---------------------------------------------------------------------------
// ViewModel
// ---------------------------------------------------------------------------

class NotificationsViewModel extends StateNotifier<NotificationsState> {
  NotificationsViewModel() : super(const NotificationsState()) {
    // Auto-bind if auth and role are available. Role comes from the user doc;
    // if we don't know it yet, start with 'student' and the caller may
    // invoke streamNotifications(uid, role) explicitly once known.
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      _resolveRoleAndStream(uid);
    }
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  Future<void> _resolveRoleAndStream(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final role =
          (userDoc.data()?['role'] as String?)?.trim() ?? 'student';
      streamNotifications(uid, role);
    } catch (_) {
      // Best-effort: stream against 'all' only so the user still sees
      // broadcasts if we can't load their role.
      streamNotifications(uid, 'student');
    }
  }

  // -------------------------------------------------------------------------
  // streamNotifications(uid, role) — orderBy('timestamp') per spec. Docs
  // without a `timestamp` field will not appear; see seed.js migration.
  // -------------------------------------------------------------------------

  void streamNotifications(String uid, String role) {
    _sub?.cancel();
    state = state.copyWith(isLoading: true);

    _sub = _firestore
        .collection('notifications')
        .where('recipientRole', whereIn: ['all', role])
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
      (snap) {
        final items =
            snap.docs.map(AppNotification.fromDoc).toList(growable: false);
        final unread = items.where((n) => !n.read).length;
        state = state.copyWith(
          notifications: items,
          filteredNotifications: _applyFilter(items, state.activeFilter),
          unreadCount: unread,
          isLoading: false,
        );
      },
      onError: (e) {
        debugPrint('streamNotifications error: $e');
        state = state.copyWith(isLoading: false);
      },
    );
  }

  // -------------------------------------------------------------------------
  // markAsRead(notificationId) — global write. Requires rules that permit
  // authed users to update `read` on /notifications/{id}.
  // -------------------------------------------------------------------------

  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } on FirebaseException catch (e) {
      debugPrint('markAsRead error: ${e.code} — ${e.message}');
    }
  }

  // -------------------------------------------------------------------------
  // markAllAsRead(uid, role) — batch write every unread doc matching the
  // user's role bucket. Single batch, atomic.
  // -------------------------------------------------------------------------

  Future<void> markAllAsRead(String uid, String role) async {
    try {
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
    } on FirebaseException catch (e) {
      debugPrint('markAllAsRead error: ${e.code} — ${e.message}');
    }
  }

  // -------------------------------------------------------------------------
  // deleteNotification(id) — removes the doc globally. Stream redelivers.
  // -------------------------------------------------------------------------

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } on FirebaseException catch (e) {
      debugPrint('deleteNotification error: ${e.code} — ${e.message}');
    }
  }

  // -------------------------------------------------------------------------
  // filterNotifications(type) — client-side filter on the already-loaded
  // list. 'all' clears the filter. Unknown values are treated as 'all'.
  // -------------------------------------------------------------------------

  void filterNotifications(String type) {
    final normalized =
        NotificationFilter.values.contains(type) ? type : NotificationFilter.all;
    if (normalized == state.activeFilter) return;
    state = state.copyWith(
      activeFilter: normalized,
      filteredNotifications: _applyFilter(state.notifications, normalized),
    );
  }

  List<AppNotification> _applyFilter(
    List<AppNotification> items,
    String filter,
  ) {
    switch (filter) {
      case NotificationFilter.announcements:
        return items
            .where((n) => n.type == 'announcement' || n.type == 'new_material')
            .toList(growable: false);
      case NotificationFilter.achievements:
        return items.where((n) => n.type == 'achievement').toList(growable: false);
      case NotificationFilter.reminders:
        return items.where((n) => n.type == 'reminder').toList(growable: false);
      case NotificationFilter.all:
      default:
        return items;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Provider — NOT autoDispose.
// ---------------------------------------------------------------------------

final notificationsViewModelProvider =
    StateNotifierProvider<NotificationsViewModel, NotificationsState>(
  (ref) => NotificationsViewModel(),
);
