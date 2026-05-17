// ---------------------------------------------------------------------------
// ProfileStats — aggregate counters displayed on the profile screen.
// Computed from /sessions (count) and /users/{uid} (points, streak).
// ---------------------------------------------------------------------------

class ProfileStats {
  final int sessionCount;
  final int points;
  final int streakDays;
  const ProfileStats({
    required this.sessionCount,
    required this.points,
    required this.streakDays,
  });

  static const empty = ProfileStats(sessionCount: 0, points: 0, streakDays: 0);
}
