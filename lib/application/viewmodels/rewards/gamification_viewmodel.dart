import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/application/viewmodels/config/remote_config_providers.dart';
import 'package:mentor_minds/data/models/badge_info.dart';
import 'package:mentor_minds/data/models/gamification_config.dart';
import 'package:mentor_minds/data/models/points_history.dart';
import 'package:mentor_minds/data/models/rewards_doc.dart';
import 'package:mentor_minds/data/repositories/auth_repository.dart';
import 'package:mentor_minds/data/repositories/rewards_repository.dart';

// ---------------------------------------------------------------------------
// Badge catalog — canonical list comes from /config/gamification (via
// currentGamificationConfigProvider). Earned-badge events fire when the
// /rewards/{uid}.badges set grows; the matching BadgeInfo is resolved from
// the live config. Eligibility is computed server-side from /users/{uid}.
// ---------------------------------------------------------------------------

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
    this.allBadges = const [],
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
    this._ref,
    this._authRepo,
    this._rewardsRepo,
  ) : super(GamificationState(
          allBadges: _ref
              .read(currentGamificationConfigProvider)
              .badges
              .map((b) => b.toBadgeInfo())
              .toList(growable: false),
        )) {
    final uid = _authRepo.currentUser?.uid;
    if (uid != null) {
      loadRewards(uid);
      _ledgerSub = _rewardsRepo.watchLedger(uid).listen((history) {
        state = state.copyWith(history: history);
      });
    }
  }

  final Ref _ref;
  final AuthRepository _authRepo;
  final RewardsRepository _rewardsRepo;

  GamificationConfig get _gamConfig =>
      _ref.read(currentGamificationConfigProvider);

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
        final cfg = _gamConfig;
        for (final id in nextBadges.difference(_previousBadgeIds)) {
          final def = cfg.badgesById[id];
          if (def != null && !_badgeEarnedController.isClosed) {
            _badgeEarnedController.add(def.toBadgeInfo());
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
    ref,
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
