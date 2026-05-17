// ---------------------------------------------------------------------------
// LeaderboardEntry — a single row in the leaderboard rendered by both
// rewards_screen and gamification_viewmodel. The 7-field superset from
// rewards_viewmodel is the canonical form; gamification_viewmodel uses the
// same class with subject left as null (it has no subject context).
// ---------------------------------------------------------------------------

class LeaderboardEntry {
  final String uid;
  final String name;
  final String? avatarUrl;
  final int points;
  final String? subject; // top subject tag; null when context lacks it
  final int rank;
  final bool isCurrentUser;
  const LeaderboardEntry({
    required this.uid,
    required this.name,
    required this.avatarUrl,
    required this.points,
    required this.subject,
    required this.rank,
    required this.isCurrentUser,
  });
}
