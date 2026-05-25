import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------------
// HistoryEntry — a formatted points-history item for the rewards screen.
// Decoded from the /rewards/{uid} history array; includes a display icon.
// ---------------------------------------------------------------------------

class HistoryEntry {
  final String action;
  final String icon;
  final int points;
  final DateTime? timestamp;
  const HistoryEntry({
    required this.action,
    required this.icon,
    required this.points,
    required this.timestamp,
  });

  factory HistoryEntry.fromMap(Map<String, dynamic> m) {
    final ts = m['timestamp'] ?? m['awardedAt'];
    final action = (m['action'] as String?)?.trim() ??
        (m['type'] as String?)?.trim() ??
        'Points earned';
    return HistoryEntry(
      action: action,
      icon: (m['icon'] as String?)?.trim().isNotEmpty == true
          ? (m['icon'] as String).trim()
          : iconForAction(action),
      points: (m['points'] as num?)?.toInt() ??
          (m['amount'] as num?)?.toInt() ??
          (m['pointsAwarded'] as num?)?.toInt() ??
          0,
      timestamp: ts is Timestamp ? ts.toDate() : null,
    );
  }

  static String iconForAction(String action) => switch (action) {
        'daily_login' => '🌅',
        'complete_session' => '✅',
        'upload_diagram' => '🖼️',
        'earn_badge' => '🏅',
        'streak_7' || 'week_warrior' => '🔥',
        'streak_30' || 'month_master' => '🗓️',
        _ => '✨',
      };
}
