import 'package:flutter/material.dart';

import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/data/models/badge_info.dart';
import 'package:mentor_minds/data/models/badge_item.dart';

// MIRROR: functions/src/lib/rewards.ts BADGE_IDS — keep IDs in sync.

const kBadgeCatalog = <BadgeInfo>[
  BadgeInfo(
    id: 'first_step',
    emoji: '🌱',
    name: 'First Step',
    description: 'Complete your first tutoring session.',
    unlockHint: 'Complete 1 session',
    target: 1,
  ),
  BadgeInfo(
    id: 'curious_learner',
    emoji: '💬',
    name: 'Curious Learner',
    description: 'Ask MentorBot 50 questions across any subject.',
    unlockHint: 'Ask 50 questions',
    target: 50,
  ),
  BadgeInfo(
    id: 'dedicated_learner',
    emoji: '📚',
    name: 'Dedicated Learner',
    description: 'Complete 5 tutoring sessions.',
    unlockHint: 'Complete 5 sessions',
    target: 5,
  ),
  BadgeInfo(
    id: 'week_warrior',
    emoji: '🏆',
    name: 'Week Warrior',
    description: 'Maintain a 7-day study streak.',
    unlockHint: 'Study 7 days in a row',
    target: 7,
  ),
  BadgeInfo(
    id: 'month_master',
    emoji: '🗓️',
    name: 'Month Master',
    description: 'Maintain a 30-day study streak.',
    unlockHint: 'Study 30 days in a row',
    target: 30,
  ),
  BadgeInfo(
    id: 'diagram_detective',
    emoji: '🔍',
    name: 'Diagram Detective',
    description: 'Upload 10 diagrams for MentorBot to analyze.',
    unlockHint: 'Upload 10 diagrams',
    target: 10,
  ),
  BadgeInfo(
    id: 'subject_expert',
    emoji: '🎯',
    name: 'Subject Expert',
    description: 'Ask 100 questions in a single subject.',
    unlockHint: 'Ask 100 questions in one subject',
    target: 100,
  ),
];

final Map<String, BadgeInfo> kBadgeCatalogById = {
  for (final b in kBadgeCatalog) b.id: b,
};

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

BadgeItem badgeItemForId(String id) {
  final info = kBadgeCatalogById[id];
  return BadgeItem(
    id: id,
    name: info?.name ?? id,
    icon: _badgeIcons[id] ?? Icons.workspace_premium_rounded,
    color: _badgeColors[id] ?? AppColors.kGold,
  );
}

/// Progress toward [subject_expert] (0..1) from per-subject question counts.
double subjectQuestionProgress(Map<String, int> perSubject, String subject) {
  final count = perSubject[subject] ?? 0;
  if (count <= 0) return 0;
  const target = 100;
  return (count / target).clamp(0.05, 1.0);
}

/// Locked-badge progress hint from /users/{uid} fields (server-maintained).
int? badgeProgressCurrent(String badgeId, Map<String, dynamic> userData) {
  switch (badgeId) {
    case 'first_step':
      return (userData['sessionsCompleted'] as num?)?.toInt();
    case 'curious_learner':
      return (userData['totalQuestions'] as num?)?.toInt();
    case 'dedicated_learner':
      return (userData['sessionsCompleted'] as num?)?.toInt();
    case 'week_warrior':
    case 'month_master':
      return (userData['streakDays'] as num?)?.toInt();
    case 'diagram_detective':
      return (userData['diagramUploads'] as num?)?.toInt();
    case 'subject_expert':
      final per = userData['questionsPerSubject'];
      if (per is! Map) return null;
      var max = 0;
      for (final v in per.values) {
        final n = v is num ? v.toInt() : int.tryParse('$v') ?? 0;
        if (n > max) max = n;
      }
      return max;
  }
  return null;
}
