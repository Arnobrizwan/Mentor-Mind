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
    final ts = m['timestamp'];
    return HistoryEntry(
      action: (m['action'] as String?)?.trim() ?? 'Points earned',
      icon: (m['icon'] as String?)?.trim().isNotEmpty == true
          ? (m['icon'] as String).trim()
          : '✨',
      points: (m['points'] as num?)?.toInt() ?? 0,
      timestamp: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
