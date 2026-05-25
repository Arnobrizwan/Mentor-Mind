import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/data/models/badge_info.dart';
import 'package:mentor_minds/data/models/earned_badge.dart';
import 'package:mentor_minds/data/models/history_entry.dart';
import 'package:mentor_minds/data/models/points_history.dart';
import 'package:mentor_minds/data/models/locked_badge.dart';
import 'package:mentor_minds/data/models/milestone.dart';
import 'package:mentor_minds/data/repositories/auth_repository.dart';
import 'package:mentor_minds/data/repositories/rewards_repository.dart';
import 'package:mentor_minds/data/repositories/users_repository.dart';

// ---------------------------------------------------------------------------
// Static badge catalog — the full set of achievable badges. Earned badge IDs
// come from /rewards/{uid}.badges; we join against this catalog to render
// cards for both earned and locked states.
// ---------------------------------------------------------------------------

const _allBadges = <BadgeInfo>[
  BadgeInfo(
    id: 'first_login',
    emoji: '🎓',
    name: 'First Steps',
    description: 'Welcome aboard! You signed up and joined MentorMinds.',
    unlockHint: 'Sign up to earn',
  ),
  BadgeInfo(
    id: 'streak_3',
    emoji: '🔥',
    name: 'Spark',
    description: 'Study three days in a row to keep the momentum going.',
    unlockHint: 'Study 3 days in a row',
    target: 3,
  ),
  BadgeInfo(
    id: 'streak_7',
    emoji: '🏆',
    name: 'Week Warrior',
    description: 'A full week of daily study. Habits are forming.',
    unlockHint: 'Study 7 days in a row',
    target: 7,
  ),
  BadgeInfo(
    id: 'streak_30',
    emoji: '🗓️',
    name: 'Marathon Mind',
    description: 'A full month of daily learning. Few make it this far.',
    unlockHint: 'Study 30 days in a row',
    target: 30,
  ),
  BadgeInfo(
    id: 'ai_questions_10',
    emoji: '💬',
    name: 'Curious',
    description: 'Asked MentorBot 10 questions. Curiosity is the first step.',
    unlockHint: 'Ask 10 questions to MentorBot',
    target: 10,
  ),
  BadgeInfo(
    id: 'ai_questions_50',
    emoji: '🤖',
    name: 'Tutor Tamer',
    description: 'Asked MentorBot 50 questions. You know how to get answers.',
    unlockHint: 'Ask 50 questions to MentorBot',
    target: 50,
  ),
  BadgeInfo(
    id: 'materials_viewed_10',
    emoji: '📚',
    name: 'Bookworm',
    description: 'Viewed 10 different study materials.',
    unlockHint: 'View 10 materials',
    target: 10,
  ),
  BadgeInfo(
    id: 'points_100',
    emoji: '⭐',
    name: 'Rising Star',
    description: 'Earned your first 100 points.',
    unlockHint: 'Earn 100 points',
    target: 100,
  ),
];

// ---------------------------------------------------------------------------
// Milestones ladder — progress bar targets the next threshold after current
// points. If the user has passed all of them, we show "Max tier" state.
// ---------------------------------------------------------------------------

const _milestones = <int>[50, 100, 200, 500, 1000, 2500, 5000];

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class RewardsState {
  final bool isLoading;
  final String? error;
  final int points;
  final List<EarnedBadge> earned;
  final List<LockedBadge> locked;
  final List<HistoryEntry> history;
  final Milestone nextMilestone;

  const RewardsState({
    this.isLoading = true,
    this.error,
    this.points = 0,
    this.earned = const [],
    this.locked = const [],
    this.history = const [],
    this.nextMilestone = Milestone.maxed,
  });

  RewardsState copyWith({
    bool? isLoading,
    String? error,
    int? points,
    List<EarnedBadge>? earned,
    List<LockedBadge>? locked,
    List<HistoryEntry>? history,
    Milestone? nextMilestone,
    bool clearError = false,
  }) {
    return RewardsState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      points: points ?? this.points,
      earned: earned ?? this.earned,
      locked: locked ?? this.locked,
      history: history ?? this.history,
      nextMilestone: nextMilestone ?? this.nextMilestone,
    );
  }
}

// ---------------------------------------------------------------------------
// ViewModel
// ---------------------------------------------------------------------------

class RewardsViewModel extends StateNotifier<RewardsState> {
  RewardsViewModel(
    this._authRepo,
    this._usersRepo,
    this._rewardsRepo,
  ) : super(const RewardsState()) {
    final uid = _authRepo.currentUser?.uid;
    if (uid != null) _bind(uid);
  }

  final AuthRepository _authRepo;
  final UsersRepository _usersRepo;
  final RewardsRepository _rewardsRepo;

  StreamSubscription<Map<String, dynamic>>? _rewardsSub;
  StreamSubscription<Map<String, dynamic>>? _userSub;
  StreamSubscription<List<PointsHistory>>? _ledgerSub;

  void _bind(String uid) {
    _rewardsSub?.cancel();
    _userSub?.cancel();
    state = state.copyWith(isLoading: true, clearError: true);

    // Rewards doc — badges + history + authoritative points.
    _rewardsSub = _rewardsRepo
        .watchRewardsRaw(uid)
        .listen(
      (data) {
        _mergeRewards(data);
      },
      onError: (_) {
        state = state.copyWith(
          isLoading: false,
          error: 'Could not load rewards. Pull to retry.',
        );
      },
    );

    // Users doc — fallback for points and subject tag.
    _userSub = _usersRepo
        .watchUserDocRaw(uid)
        .listen(
      (data) {
        final pointsFromUser = (data['points'] as num?)?.toInt();
        if (pointsFromUser != null && state.points == 0) {
          state = state.copyWith(points: pointsFromUser);
          state = state.copyWith(
            nextMilestone: _computeMilestone(pointsFromUser),
          );
        }
      },
      onError: (_) {/* non-fatal */},
    );

    _ledgerSub = _rewardsRepo.watchLedger(uid).listen((ledger) {
      final history = ledger
          .map(
            (e) => HistoryEntry(
              action: e.action,
              icon: HistoryEntry.iconForAction(e.action),
              points: e.pointsAwarded,
              timestamp: e.timestamp,
            ),
          )
          .toList(growable: false);
      state = state.copyWith(history: history);
    });
  }

  void _mergeRewards(Map<String, dynamic> data) {
    final points = (data['points'] as num?)?.toInt() ?? state.points;
    final earnedIds = ((data['badges'] as List?) ?? const [])
        .map((e) => e.toString())
        .toSet();
    final earnedAtMap = <String, DateTime?>{};
    final rawEarnedAt = data['earnedAt'];
    if (rawEarnedAt is Map) {
      rawEarnedAt.forEach((key, value) {
        // Timestamp.toDate() — cloud_firestore Timestamp is handled by the
        // repository layer. We receive raw maps; the timestamp is already
        // decoded to DateTime in the watchRewardsRaw stream.
        if (value is DateTime) {
          earnedAtMap[key.toString()] = value;
        }
      });
    }

    final now = DateTime.now();
    final earned = <EarnedBadge>[];
    final locked = <LockedBadge>[];
    for (final b in _allBadges) {
      if (earnedIds.contains(b.id)) {
        final earnedAt = earnedAtMap[b.id];
        final recent = earnedAt != null &&
            now.difference(earnedAt).inDays < 3;
        earned.add(EarnedBadge(
          info: b,
          earnedAt: earnedAt,
          recentlyEarned: recent,
        ));
      } else {
        locked.add(LockedBadge(
          info: b,
          currentProgress: _progressForBadge(b.id, data, points),
        ));
      }
    }

    // Earned: most recent first.
    earned.sort((a, b) {
      final ax = a.earnedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bx = b.earnedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bx.compareTo(ax);
    });

    state = state.copyWith(
      isLoading: false,
      points: points,
      earned: earned,
      locked: locked,
      nextMilestone: _computeMilestone(points),
      clearError: true,
    );
  }

  int? _progressForBadge(String badgeId, Map<String, dynamic> data, int points) {
    // Opportunistic progress hints from data we already have. Absence just
    // hides the progress bar — we don't fail.
    switch (badgeId) {
      case 'points_100':
        return points.clamp(0, 100);
      case 'streak_3':
      case 'streak_7':
      case 'streak_30':
        final streak = (data['streakDays'] as num?)?.toInt();
        return streak;
      case 'ai_questions_10':
      case 'ai_questions_50':
        return (data['aiQuestionsAsked'] as num?)?.toInt();
      case 'materials_viewed_10':
        return (data['materialsViewed'] as num?)?.toInt();
    }
    return null;
  }

  Milestone _computeMilestone(int points) {
    for (final target in _milestones) {
      if (points < target) {
        return Milestone(
          target: target,
          current: points,
          rewardHint: _rewardHintFor(target),
        );
      }
    }
    return Milestone.maxed;
  }

  String _rewardHintFor(int milestone) => switch (milestone) {
        50 => '🌱 Learner badge',
        100 => '⭐ Rising Star badge',
        200 => '📚 Bookworm bonus',
        500 => '🏆 Week Warrior badge',
        1000 => '💎 Premium trial day',
        2500 => '🚀 Booster pack',
        5000 => '👑 Grandmaster title',
        _ => '🎁 Surprise reward',
      };

  Future<void> refresh() async {
    final uid = _authRepo.currentUser?.uid;
    if (uid == null) return;
    _bind(uid);
  }

  @override
  void dispose() {
    _rewardsSub?.cancel();
    _userSub?.cancel();
    _ledgerSub?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final rewardsViewModelProvider =
    StateNotifierProvider<RewardsViewModel, RewardsState>(
  (ref) => RewardsViewModel(
    ref.read(authRepositoryProvider),
    ref.read(usersRepositoryProvider),
    ref.read(rewardsRepositoryProvider),
  ),
);
