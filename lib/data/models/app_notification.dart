import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------------
// AppNotification — a single notification item decoded from /notifications.
// Type normalisation handles legacy docs that omit the `type` field.
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
