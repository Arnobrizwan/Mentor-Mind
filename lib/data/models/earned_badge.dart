import 'package:mentor_minds/data/models/badge_info.dart';

// ---------------------------------------------------------------------------
// EarnedBadge — a badge the user has already unlocked. Pairs the static
// BadgeInfo catalog entry with the timestamp it was earned and a one-time
// "recentlyEarned" flag for the celebration overlay.
// ---------------------------------------------------------------------------

class EarnedBadge {
  final BadgeInfo info;
  final DateTime? earnedAt;
  final bool recentlyEarned;
  const EarnedBadge({
    required this.info,
    required this.earnedAt,
    required this.recentlyEarned,
  });
}
