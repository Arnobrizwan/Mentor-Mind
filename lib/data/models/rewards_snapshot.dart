// ---------------------------------------------------------------------------
// RewardsSnapshot — lightweight rewards summary projected onto DashboardState.
// Decoded in-line from /rewards/{uid}; full rewards model is RewardsDoc.
// ---------------------------------------------------------------------------

class RewardsSnapshot {
  final int points;
  final List<String> badgeIds;
  const RewardsSnapshot({this.points = 0, this.badgeIds = const []});
}
