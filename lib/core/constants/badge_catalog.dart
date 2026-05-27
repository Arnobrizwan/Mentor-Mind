import 'package:flutter/material.dart';

import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/data/models/badge_item.dart';
import 'package:mentor_minds/data/models/gamification_config.dart';

// ---------------------------------------------------------------------------
// Badge presentation helpers — icon and color mapping by badge id.
// The CANONICAL badge data (name, description, target, progressField) lives
// in /config/gamification via GamificationConfig. Icons/colors stay in code
// because Material IconData and Color constants can't be Firestore-encoded.
//
// MIRROR: functions/src/lib/rewards.ts BADGE_IDS — keep IDs in sync.
// ---------------------------------------------------------------------------

const _badgeIcons = <String, IconData>{
  'first_step': Icons.rocket_launch_rounded,
  'curious_learner': Icons.chat_bubble_outline_rounded,
  'dedicated_learner': Icons.menu_book_rounded,
  'week_warrior': Icons.local_fire_department_rounded,
  'month_master': Icons.calendar_month_rounded,
  'diagram_detective': Icons.image_search_rounded,
  'subject_expert': Icons.emoji_events_rounded,
};

const _badgeColors = <String, Color>{
  'first_step': AppColors.kGold,
  'curious_learner': AppColors.kAccent,
  'dedicated_learner': AppColors.kPrimary,
  'week_warrior': AppColors.kError,
  'month_master': AppColors.kGold,
  'diagram_detective': AppColors.kAccent,
  'subject_expert': AppColors.kGold,
};

/// Builds a presentation [BadgeItem] for a given badge id. Pass [catalog]
/// to resolve the badge's display name from the current GamificationConfig
/// (falls back to defaults if omitted).
BadgeItem badgeItemForId(String id, {GamificationConfig? catalog}) {
  final cfg = catalog ?? GamificationConfig.defaults;
  final def = cfg.badgesById[id];
  return BadgeItem(
    id: id,
    name: def?.name ?? id,
    icon: _badgeIcons[id] ?? Icons.workspace_premium_rounded,
    color: _badgeColors[id] ?? AppColors.kGold,
  );
}

/// Progress (0..1) toward the [subject_expert] target from per-subject
/// question counts. [target] defaults to 100 but the caller should pass
/// the live target from GamificationConfig when possible.
double subjectQuestionProgress(
  Map<String, int> perSubject,
  String subject, {
  int target = 100,
}) {
  final count = perSubject[subject] ?? 0;
  if (count <= 0 || target <= 0) return 0;
  return (count / target).clamp(0.05, 1.0);
}

/// Locked-badge progress reading from /users/{uid} fields. Reads the
/// configured [BadgeDef.progressField]; supports the sentinel
/// '_questionsPerSubjectMax' for the subject_expert per-subject max.
int? badgeProgressCurrent(BadgeDef def, Map<String, dynamic> userData) {
  final field = def.progressField;
  if (field == null || field.isEmpty) return null;
  if (field == '_questionsPerSubjectMax') {
    final per = userData['questionsPerSubject'];
    if (per is! Map) return null;
    var max = 0;
    for (final v in per.values) {
      final n = v is num ? v.toInt() : int.tryParse('$v') ?? 0;
      if (n > max) max = n;
    }
    return max;
  }
  return (userData[field] as num?)?.toInt();
}
