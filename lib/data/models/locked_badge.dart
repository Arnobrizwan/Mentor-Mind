import 'package:mentor_minds/data/models/badge_info.dart';

// ---------------------------------------------------------------------------
// LockedBadge — a badge the user has not yet unlocked. Pairs the static
// BadgeInfo catalog entry with the user's current numeric progress toward it.
// ---------------------------------------------------------------------------

class LockedBadge {
  final BadgeInfo info;
  final int? currentProgress;
  const LockedBadge({required this.info, required this.currentProgress});
}
