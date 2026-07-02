import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/application/viewmodels/config/remote_config_providers.dart';
import 'package:mentor_minds/core/constants/badge_catalog.dart';
import 'package:mentor_minds/data/models/earned_badge.dart';
import 'package:mentor_minds/data/models/gamification_config.dart';
import 'package:mentor_minds/data/models/history_entry.dart';
import 'package:mentor_minds/data/models/points_history.dart';
import 'package:mentor_minds/data/models/leaderboard_entry.dart';
import 'package:mentor_minds/data/models/locked_badge.dart';
import 'package:mentor_minds/data/models/milestone.dart';
import 'package:mentor_minds/data/repositories/auth_repository.dart';
import 'package:mentor_minds/data/repositories/rewards_repository.dart';
import 'package:mentor_minds/data/repositories/users_repository.dart';

// ---------------------------------------------------------------------------
// Badge catalog + milestone ladder both come from /config/gamification via
// currentGamificationConfigProvider. Earned badge IDs come from /rewards/{uid}
// and are joined against the live catalog to render earned/locked cards.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class RewardsState {
  final bool isLoading;
  final String? error;
  final int points;
  final int streak;
  final List<EarnedBadge> earned;
  final List<LockedBadge> locked;
  final List<HistoryEntry> history;
  final Milestone nextMilestone;

  const RewardsState({
    this.isLoading = true,
    this.error,
    this.points = 0,
    this.streak = 0,
    this.earned = const [],
    this.locked = const [],
    this.history = const [],
    this.nextMilestone = Milestone.maxed,
  });

  RewardsState copyWith({
    bool? isLoading,
    String? error,
    int? points,
    int? streak,
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
      streak: streak ?? this.streak,
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
    this._ref,
    this._authRepo,
    this._usersRepo,
    this._rewardsRepo,
  ) : super(const RewardsState()) {
    final uid = _authRepo.currentUser?.uid;
    if (uid != null) _bind(uid);
  }

  final Ref _ref;
  final AuthRepository _authRepo;
  final UsersRepository _usersRepo;
  final RewardsRepository _rewardsRepo;

  GamificationConfig get _gamConfig =>
      _ref.read(currentGamificationConfigProvider);

  StreamSubscription<Map<String, dynamic>>? _rewardsSub;
  StreamSubscription<Map<String, dynamic>>? _userSub;
  StreamSubscription<List<PointsHistory>>? _ledgerSub;

  // Latest raw docs — the server writes badge ids/points to /rewards/{uid}
  // but the badge PROGRESS counters (sessionsCompleted, totalQuestions,
  // streakDays, diagramUploads, questionsPerSubject) live on /users/{uid},
  // so locked-badge progress must merge both.
  Map<String, dynamic> _latestRewards = const {};
  Map<String, dynamic> _latestUser = const {};
  bool _rewardsLoaded = false;

  void _bind(String uid) {
    _rewardsSub?.cancel();
    _userSub?.cancel();
    _latestRewards = const {};
    _latestUser = const {};
    _rewardsLoaded = false;
    state = state.copyWith(isLoading: true, clearError: true);

    // Rewards doc — badges + history + authoritative points.
    _rewardsSub = _rewardsRepo
        .watchRewardsRaw(uid)
        .listen(
      (data) {
        _latestRewards = data;
        _rewardsLoaded = true;
        _mergeRewards();
      },
      onError: (_) {
        state = state.copyWith(
          isLoading: false,
          error: 'Could not load rewards. Pull to retry.',
        );
      },
    );

    // Users doc — badge progress counters + fallback points.
    _userSub = _usersRepo
        .watchUserDocRaw(uid)
        .listen(
      (data) {
        _latestUser = data;
        if (_rewardsLoaded) {
          // Re-derive locked-badge progress with the fresh counters.
          _mergeRewards();
        } else {
          final pointsFromUser = (data['points'] as num?)?.toInt();
          if (pointsFromUser != null && state.points == 0) {
            state = state.copyWith(
              points: pointsFromUser,
              nextMilestone: _computeMilestone(pointsFromUser),
            );
          }
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

  void _mergeRewards() {
    final data = _latestRewards;
    // Progress counters come from /users/{uid}; anything the rewards doc
    // also carries wins on key clashes.
    final progressSource = <String, dynamic>{..._latestUser, ...data};
    final points = (data['points'] as num?)?.toInt() ??
        (_latestUser['points'] as num?)?.toInt() ??
        state.points;
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

    final cfg = _gamConfig;
    final now = DateTime.now();
    final earned = <EarnedBadge>[];
    final locked = <LockedBadge>[];
    for (final def in cfg.badges) {
      final info = def.toBadgeInfo();
      if (earnedIds.contains(def.id)) {
        final earnedAt = earnedAtMap[def.id];
        final recent = earnedAt != null &&
            now.difference(earnedAt).inDays < 3;
        earned.add(EarnedBadge(
          info: info,
          earnedAt: earnedAt,
          recentlyEarned: recent,
        ));
      } else {
        locked.add(LockedBadge(
          info: info,
          currentProgress: _progressForBadge(def, progressSource, points),
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
      streak: (progressSource['streakDays'] as num?)?.toInt() ?? state.streak,
      earned: earned,
      locked: locked,
      nextMilestone: _computeMilestone(points),
      clearError: true,
    );
  }

  int? _progressForBadge(BadgeDef def, Map<String, dynamic> data, int _) {
    return badgeProgressCurrent(def, data);
  }

  Milestone _computeMilestone(int points) {
    for (final m in _gamConfig.milestones) {
      if (points < m.points) {
        return Milestone(
          target: m.points,
          current: points,
          rewardHint: m.rewardHint,
        );
      }
    }
    return Milestone.maxed;
  }

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
    ref,
    ref.read(authRepositoryProvider),
    ref.read(usersRepositoryProvider),
    ref.read(rewardsRepositoryProvider),
  ),
);

// Top-10 leaderboard by points (spec: Rewards screen shows the leaderboard).
// One-shot future — refresh by invalidating the provider (pull-to-refresh).
final leaderboardProvider = FutureProvider.autoDispose<
    ({List<LeaderboardEntry> top, LeaderboardEntry? currentUserRow})>(
  (ref) async {
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
    if (uid == null) {
      return (top: const <LeaderboardEntry>[], currentUserRow: null);
    }
    return ref.watch(usersRepositoryProvider).getLeaderboard(uid);
  },
);
