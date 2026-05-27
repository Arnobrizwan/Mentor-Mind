import 'package:mentor_minds/data/models/badge_info.dart';

// ---------------------------------------------------------------------------
// GamificationConfig — /config/gamification doc shape.
// Falls back to defaults that mirror the original hardcoded badge_catalog
// + rewards milestones so the app stays usable if Firestore is unreachable
// or the doc has not been seeded yet. Admins edit the doc via Firebase
// Console; clients receive updates through the Firestore stream.
// ---------------------------------------------------------------------------

class GamificationConfig {
  final List<BadgeDef> badges;
  final List<MilestoneDef> milestones;
  final int streakGraceDays;
  final int streakLookbackDays;

  const GamificationConfig({
    required this.badges,
    required this.milestones,
    required this.streakGraceDays,
    required this.streakLookbackDays,
  });

  Map<String, BadgeDef> get badgesById => {for (final b in badges) b.id: b};

  static GamificationConfig fromMap(Map<String, dynamic> data) {
    final rawBadges = (data['badges'] as List?) ?? const [];
    final badges = rawBadges
        .whereType<Map>()
        .map((m) => BadgeDef.fromMap(Map<String, dynamic>.from(m)))
        .toList(growable: false);

    final rawMilestones = (data['milestones'] as List?) ?? const [];
    final milestones = rawMilestones
        .whereType<Map>()
        .map((m) => MilestoneDef.fromMap(Map<String, dynamic>.from(m)))
        .toList(growable: false);

    final streak = (data['streak'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    return GamificationConfig(
      badges: badges.isEmpty ? defaults.badges : badges,
      milestones: milestones.isEmpty ? defaults.milestones : milestones,
      streakGraceDays: (streak['graceDays'] as num?)?.toInt() ??
          defaults.streakGraceDays,
      streakLookbackDays: (streak['lookbackDays'] as num?)?.toInt() ??
          defaults.streakLookbackDays,
    );
  }

  Map<String, dynamic> toMap() => {
        'badges': badges.map((b) => b.toMap()).toList(growable: false),
        'milestones':
            milestones.map((m) => m.toMap()).toList(growable: false),
        'streak': {
          'graceDays': streakGraceDays,
          'lookbackDays': streakLookbackDays,
        },
      };

  // Defaults mirror the original hardcoded values from
  // lib/core/constants/badge_catalog.dart and
  // lib/application/viewmodels/rewards/rewards_viewmodel.dart.
  static const GamificationConfig defaults = GamificationConfig(
    badges: [
      BadgeDef(
        id: 'first_step',
        emoji: '🌱',
        name: 'First Step',
        description: 'Complete your first tutoring session.',
        unlockHint: 'Complete 1 session',
        target: 1,
        progressField: 'sessionsCompleted',
      ),
      BadgeDef(
        id: 'curious_learner',
        emoji: '💬',
        name: 'Curious Learner',
        description: 'Ask MentorBot 50 questions across any subject.',
        unlockHint: 'Ask 50 questions',
        target: 50,
        progressField: 'totalQuestions',
      ),
      BadgeDef(
        id: 'dedicated_learner',
        emoji: '📚',
        name: 'Dedicated Learner',
        description: 'Complete 5 tutoring sessions.',
        unlockHint: 'Complete 5 sessions',
        target: 5,
        progressField: 'sessionsCompleted',
      ),
      BadgeDef(
        id: 'week_warrior',
        emoji: '🏆',
        name: 'Week Warrior',
        description: 'Maintain a 7-day study streak.',
        unlockHint: 'Study 7 days in a row',
        target: 7,
        progressField: 'streakDays',
      ),
      BadgeDef(
        id: 'month_master',
        emoji: '🗓️',
        name: 'Month Master',
        description: 'Maintain a 30-day study streak.',
        unlockHint: 'Study 30 days in a row',
        target: 30,
        progressField: 'streakDays',
      ),
      BadgeDef(
        id: 'diagram_detective',
        emoji: '🔍',
        name: 'Diagram Detective',
        description: 'Upload 10 diagrams for MentorBot to analyze.',
        unlockHint: 'Upload 10 diagrams',
        target: 10,
        progressField: 'diagramUploads',
      ),
      BadgeDef(
        id: 'subject_expert',
        emoji: '🎯',
        name: 'Subject Expert',
        description: 'Ask 100 questions in a single subject.',
        unlockHint: 'Ask 100 questions in one subject',
        target: 100,
        // Sentinel — read max of /users/{uid}.questionsPerSubject map.
        progressField: '_questionsPerSubjectMax',
      ),
    ],
    milestones: [
      MilestoneDef(points: 50, rewardHint: '🌱 Learner badge'),
      MilestoneDef(points: 100, rewardHint: '⭐ Rising Star badge'),
      MilestoneDef(points: 200, rewardHint: '📚 Bookworm bonus'),
      MilestoneDef(points: 500, rewardHint: '🏆 Week Warrior badge'),
      MilestoneDef(points: 1000, rewardHint: '💎 Premium trial day'),
      MilestoneDef(points: 2500, rewardHint: '🚀 Booster pack'),
      MilestoneDef(points: 5000, rewardHint: '👑 Grandmaster title'),
    ],
    streakGraceDays: 1,
    streakLookbackDays: 45,
  );
}

class BadgeDef {
  final String id;
  final String emoji;
  final String name;
  final String description;
  final String unlockHint;
  final int? target;

  /// /users/{uid} field consulted for locked-badge progress hints. Use
  /// the sentinel '_questionsPerSubjectMax' for the per-subject max read.
  final String? progressField;

  const BadgeDef({
    required this.id,
    required this.emoji,
    required this.name,
    required this.description,
    required this.unlockHint,
    this.target,
    this.progressField,
  });

  BadgeInfo toBadgeInfo() => BadgeInfo(
        id: id,
        emoji: emoji,
        name: name,
        description: description,
        unlockHint: unlockHint,
        target: target,
      );

  factory BadgeDef.fromMap(Map<String, dynamic> m) => BadgeDef(
        id: (m['id'] as String?) ?? '',
        emoji: (m['emoji'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        unlockHint: (m['unlockHint'] as String?) ?? '',
        target: (m['target'] as num?)?.toInt(),
        progressField: m['progressField'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'emoji': emoji,
        'name': name,
        'description': description,
        'unlockHint': unlockHint,
        if (target != null) 'target': target,
        if (progressField != null) 'progressField': progressField,
      };
}

class MilestoneDef {
  final int points;
  final String rewardHint;

  const MilestoneDef({required this.points, required this.rewardHint});

  factory MilestoneDef.fromMap(Map<String, dynamic> m) => MilestoneDef(
        points: (m['points'] as num?)?.toInt() ?? 0,
        rewardHint: (m['rewardHint'] as String?) ?? '🎁 Surprise reward',
      );

  Map<String, dynamic> toMap() => {
        'points': points,
        'rewardHint': rewardHint,
      };
}
