import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/data/models/badge_info.dart';
import 'package:mentor_minds/data/models/points_history.dart';
import 'package:mentor_minds/data/models/rewards_doc.dart';
import 'package:mentor_minds/data/repositories/auth_repository.dart';
import 'package:mentor_minds/data/repositories/rewards_repository.dart';

// ---------------------------------------------------------------------------
// Point awards per action. Authoritative — writers elsewhere in the app
// call awardPoints(uid, '<action>') and the value is looked up here so we
// never let callers pick their own point values.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Badge catalog — canonical list for gamification. Eligibility is computed
// from scalar counters on /users/{uid}. If a counter is missing, the check
// is simply skipped (the badge stays locked).
// ---------------------------------------------------------------------------

const _catalog = <BadgeInfo>[
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

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class GamificationState {
  final RewardsDoc? rewards;
  final List<String> badges;
  final List<BadgeInfo> allBadges;
  final List<PointsHistory> history;
  final bool isLoading;
  final String? error;

  const GamificationState({
    this.rewards,
    this.badges = const [],
    this.allBadges = _catalog,
    this.history = const [],
    this.isLoading = true,
    this.error,
  });

  GamificationState copyWith({
    RewardsDoc? rewards,
    List<String>? badges,
    List<BadgeInfo>? allBadges,
    List<PointsHistory>? history,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return GamificationState(
      rewards: rewards ?? this.rewards,
      badges: badges ?? this.badges,
      allBadges: allBadges ?? this.allBadges,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ---------------------------------------------------------------------------
// ViewModel
// ---------------------------------------------------------------------------

class GamificationViewModel extends StateNotifier<GamificationState> {
  GamificationViewModel(
    this._authRepo,
    this._rewardsRepo,
  ) : super(const GamificationState()) {
    final uid = _authRepo.currentUser?.uid;
    if (uid != null) {
      loadRewards(uid);
      _ledgerSub = _rewardsRepo.watchLedger(uid).listen((history) {
        state = state.copyWith(history: history);
      });
    }
  }

  final AuthRepository _authRepo;
  final RewardsRepository _rewardsRepo;

  StreamSubscription<RewardsDoc>? _rewardsSub;
  StreamSubscription<List<PointsHistory>>? _ledgerSub;
  Set<String> _previousBadgeIds = {};

  /// Celebration events — one emission per newly-earned badge. The UI
  /// listens and shows an overlay. Kept here (not in state) so transient
  /// events don't accumulate in state and re-fire on rebuilds.
  final _badgeEarnedController = StreamController<BadgeInfo>.broadcast();
  Stream<BadgeInfo> get badgeEarnedStream => _badgeEarnedController.stream;

  // -------------------------------------------------------------------------
  // loadRewards(uid) — stream /rewards where userId == uid. Creates the doc
  // if it doesn't exist yet so a fresh user has somewhere to write history.
  // -------------------------------------------------------------------------

  void loadRewards(String uid) {
    _rewardsSub?.cancel();
    state = state.copyWith(isLoading: true, clearError: true);

    _rewardsSub = _rewardsRepo.watchRewards(uid).listen(
      (doc) async {
        if (doc == RewardsDoc.empty) {
          // Bootstrap a rewards doc with id == uid so subsequent writes are
          // idempotent and don't race on creation.
          try {
            await _rewardsRepo.bootstrapRewards(uid);
          } catch (e) {
            debugPrint('loadRewards bootstrap error: $e');
          }
          return; // Wait for the stream to redeliver the new doc.
        }

        final history = [...doc.history]
          ..sort((a, b) {
            final ax = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bx = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bx.compareTo(ax);
          });

        final nextBadges = doc.badges.toSet();
        for (final id in nextBadges.difference(_previousBadgeIds)) {
          final badge = _catalog.where((b) => b.id == id).firstOrNull;
          if (badge != null && !_badgeEarnedController.isClosed) {
            _badgeEarnedController.add(badge);
          }
        }
        _previousBadgeIds = nextBadges;

        state = state.copyWith(
          isLoading: false,
          rewards: doc,
          badges: doc.badges,
          history: history,
          clearError: true,
        );
      },
      onError: (e) {
        state = state.copyWith(
          isLoading: false,
          error: 'Could not load rewards: $e',
        );
      },
    );
  }

  // Phase 4: points/badges are server-authoritative — no client writes.

  Future<List<PointsHistory>> fetchHistory(String uid) async {
    try {
      final history = await _rewardsRepo.watchLedger(uid).first;
      state = state.copyWith(history: history);
      return history;
    } catch (e) {
      debugPrint('fetchHistory error: $e');
      return const [];
    }
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _rewardsSub?.cancel();
    _ledgerSub?.cancel();
    _badgeEarnedController.close();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final gamificationViewModelProvider =
    StateNotifierProvider<GamificationViewModel, GamificationState>(
  (ref) => GamificationViewModel(
    ref.read(authRepositoryProvider),
    ref.read(rewardsRepositoryProvider),
  ),
);

/// Streams a [BadgeInfo] every time the user earns a new badge. Widgets
/// that render celebration overlays watch this.
final badgeEarnedEventProvider = StreamProvider<BadgeInfo>((ref) {
  final vm = ref.watch(gamificationViewModelProvider.notifier);
  return vm.badgeEarnedStream;
});
