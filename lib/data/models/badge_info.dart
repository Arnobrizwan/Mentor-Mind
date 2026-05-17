// ---------------------------------------------------------------------------
// BadgeInfo — static catalog descriptor for a single achievable badge.
// Shared by gamification_viewmodel (gamification catalog) and
// rewards_viewmodel (rewards catalog). The badge catalog constants
// (_catalog, _allBadges) stay private inside their respective viewmodels.
// ---------------------------------------------------------------------------

class BadgeInfo {
  final String id;
  final String emoji;
  final String name;
  final String description;
  final String unlockHint;
  final int? target;
  const BadgeInfo({
    required this.id,
    required this.emoji,
    required this.name,
    required this.description,
    required this.unlockHint,
    this.target,
  });
}
