import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------------
// PointsHistory — a single entry in the /rewards/{uid} history array.
// Decoded from gamification_viewmodel's Firestore snapshot listener.
// ---------------------------------------------------------------------------

class PointsHistory {
  final String action;
  final int pointsAwarded;
  final DateTime? timestamp;
  const PointsHistory({
    required this.action,
    required this.pointsAwarded,
    required this.timestamp,
  });

  factory PointsHistory.fromMap(Map<String, dynamic> m) {
    final ts = m['timestamp'];
    return PointsHistory(
      action: (m['action'] as String?)?.trim() ?? 'unknown',
      pointsAwarded: (m['pointsAwarded'] as num?)?.toInt() ??
          (m['points'] as num?)?.toInt() ??
          0,
      timestamp: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
