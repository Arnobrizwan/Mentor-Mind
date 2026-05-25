import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/core/constants/badge_catalog.dart';
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
    for (final b in kBadgeCatalog) {
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

  int? _progressForBadge(String badgeId, Map<String, dynamic> data, int _) {
    return badgeProgressCurrent(badgeId, data);
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
