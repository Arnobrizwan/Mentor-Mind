import 'package:mentor_minds/data/models/points_history.dart';

// ---------------------------------------------------------------------------
// RewardsDoc — full rewards document decoded from /rewards/{uid}.
// Contains the earned badge IDs and full points history.
// Lightweight dashboard projection: RewardsSnapshot (lib/data/models/rewards_snapshot.dart)
// ---------------------------------------------------------------------------

class RewardsDoc {
  final String userId;
  final int points;
  final List<String> badges;
  final List<PointsHistory> history;
  const RewardsDoc({
    required this.userId,
    required this.points,
    required this.badges,
    required this.history,
  });

  static const empty =
      RewardsDoc(userId: '', points: 0, badges: [], history: []);
}
