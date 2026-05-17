import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/data/models/badge_info.dart';
import 'package:mentor_minds/data/models/leaderboard_entry.dart';
import 'package:mentor_minds/data/models/points_history.dart';
import 'package:mentor_minds/data/models/rewards_doc.dart';
import 'package:mentor_minds/data/repositories/auth_repository.dart';
import 'package:mentor_minds/data/repositories/rewards_repository.dart';
import 'package:mentor_minds/data/repositories/users_repository.dart';

// ---------------------------------------------------------------------------
// Point awards per action. Authoritative — writers elsewhere in the app
// call awardPoints(uid, '<action>') and the value is looked up here so we
// never let callers pick their own point values.
// ---------------------------------------------------------------------------

const _pointsMap = <String, int>{
  'daily_login': 5,
  'complete_session': 10,
  'five_questions_session': 15,
  'upload_diagram': 20,
  'daily_challenge': 25,
  'streak_7': 50,
  'streak_30': 200,
  'earn_badge': 30,
};

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
  final List<LeaderboardEntry> leaderboard;
  final List<PointsHistory> history;
  final bool isLoading;
  final String? error;

  const GamificationState({
    this.rewards,
    this.badges = const [],
    this.allBadges = _catalog,
    this.leaderboard = const [],
    this.history = const [],
    this.isLoading = true,
    this.error,
  });

  GamificationState copyWith({
    RewardsDoc? rewards,
    List<String>? badges,
    List<BadgeInfo>? allBadges,
    List<LeaderboardEntry>? leaderboard,
    List<PointsHistory>? history,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return GamificationState(
      rewards: rewards ?? this.rewards,
      badges: badges ?? this.badges,
      allBadges: allBadges ?? this.allBadges,
      leaderboard: leaderboard ?? this.leaderboard,
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
    this._usersRepo,
    this._rewardsRepo,
  ) : super(const GamificationState()) {
    final uid = _authRepo.currentUser?.uid;
    if (uid != null) loadRewards(uid);
  }

  final AuthRepository _authRepo;
  final UsersRepository _usersRepo;
  final RewardsRepository _rewardsRepo;

  StreamSubscription<RewardsDoc>? _rewardsSub;

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

  // -------------------------------------------------------------------------
  // awardPoints(uid, action) — atomic points + history write, then runs the
  // badge eligibility check. Returns the points awarded so callers can play
  // a celebration animation.
  // -------------------------------------------------------------------------

  Future<int> awardPoints(String uid, String action) async {
    final points = _pointsMap[action];
    if (points == null) {
      debugPrint('awardPoints: unknown action "$action"');
      return 0;
    }

    try {
      await _rewardsRepo.awardPoints(uid, action, points);

      // Badge check runs after the write commits. Recursion is bounded
      // because 'earn_badge' only awards points; it doesn't unlock more
      // badges on its own, and each badge is awarded at most once.
      await checkAndAwardBadges(uid);
      return points;
    } catch (e) {
      debugPrint('awardPoints error: $e');
      state = state.copyWith(error: 'Could not award points: $e');
      return 0;
    }
  }

  // -------------------------------------------------------------------------
  // checkAndAwardBadges(uid) — compares catalog thresholds against stats on
  // /users/{uid}. For each newly earned badge: writes the id to both arrays,
  // emits a celebration event, and tacks on the 'earn_badge' bonus via
  // awardPoints (which will loop back here; the loop terminates because no
  // new badges will fire the second time).
  // -------------------------------------------------------------------------

  Future<void> checkAndAwardBadges(String uid) async {
    try {
      final results = await Future.wait<dynamic>([
        _rewardsRepo.getUserDocRaw(uid),
        _rewardsRepo.sessionsCountQuery(uid).get(),
      ]);
      final userData =
          (results[0] as Map<String, dynamic>?) ?? const <String, dynamic>{};
      // AggregateQuerySnapshot — accessed via .count (returns int?)
      final dynamic aggSnap = results[1];
      final sessionsCount = (aggSnap?.count as int?) ?? 0;

      final alreadyEarned = ((userData['badges'] as List?) ?? const [])
          .map((e) => e.toString())
          .toSet();

      final stats = _BadgeStats(
        sessionsCount: sessionsCount,
        totalQuestions:
            (userData['totalQuestions'] as num?)?.toInt() ?? 0,
        streakDays: (userData['streakDays'] as num?)?.toInt() ?? 0,
        uploads: (userData['diagramUploads'] as num?)?.toInt() ?? 0,
        maxQuestionsInOneSubject:
            _maxInMap(userData['questionsPerSubject']),
      );

      final newlyEarned = <BadgeInfo>[];
      for (final badge in _catalog) {
        if (alreadyEarned.contains(badge.id)) continue;
        if (_isEligible(badge.id, stats)) newlyEarned.add(badge);
      }

      if (newlyEarned.isEmpty) return;

      final ids = newlyEarned.map((b) => b.id).toList();
      final earnedAt = <String, dynamic>{
        for (final b in newlyEarned) b.id: DateTime.now(),
      };

      final batch = _rewardsRepo.startBatch();
      _rewardsRepo.addBadgesBatch(batch, uid, ids, earnedAt);
      await batch.commit();

      for (final badge in newlyEarned) {
        if (!_badgeEarnedController.isClosed) {
          _badgeEarnedController.add(badge);
        }
        // 30-point bonus per earned badge. This will recursively call
        // checkAndAwardBadges once more, but the alreadyEarned set now
        // includes these ids so it will return immediately with no-op.
        await awardPoints(uid, 'earn_badge');
      }
    } catch (e) {
      debugPrint('checkAndAwardBadges error: $e');
    }
  }

  bool _isEligible(String badgeId, _BadgeStats s) {
    switch (badgeId) {
      case 'first_step':
        return s.sessionsCount >= 1;
      case 'curious_learner':
        return s.totalQuestions >= 50;
      case 'dedicated_learner':
        return s.sessionsCount >= 5;
      case 'week_warrior':
        return s.streakDays >= 7;
      case 'month_master':
        return s.streakDays >= 30;
      case 'diagram_detective':
        return s.uploads >= 10;
      case 'subject_expert':
        return s.maxQuestionsInOneSubject >= 100;
    }
    return false;
  }

  int _maxInMap(dynamic raw) {
    if (raw is! Map) return 0;
    var max = 0;
    for (final v in raw.values) {
      final n = (v is num) ? v.toInt() : 0;
      if (n > max) max = n;
    }
    return max;
  }

  // -------------------------------------------------------------------------
  // fetchLeaderboard() — top 10 by points desc, marks the current user row.
  // -------------------------------------------------------------------------

  Future<List<LeaderboardEntry>> fetchLeaderboard() async {
    final currentUid = _authRepo.currentUser?.uid;
    if (currentUid == null) return const [];
    try {
      final result = await _usersRepo.getLeaderboard(currentUid, limit: 10);
      state = state.copyWith(leaderboard: result.top);
      return result.top;
    } catch (e) {
      debugPrint('fetchLeaderboard error: $e');
      state = state.copyWith(error: 'Could not load leaderboard: $e');
      return const [];
    }
  }

  // -------------------------------------------------------------------------
  // fetchHistory(uid) — one-shot pull from /rewards/{uid}.history.
  // loadRewards already streams this; this method exists for callers that
  // want a snapshot without subscribing.
  // -------------------------------------------------------------------------

  Future<List<PointsHistory>> fetchHistory(String uid) async {
    try {
      final doc = await _rewardsRepo.getUserDocRaw(uid);
      if (doc == null) return const [];
      // Fetch history from the rewards doc directly.
      final rewardsDoc = await _rewardsRepo.watchRewards(uid).first;
      final history = [...rewardsDoc.history]
        ..sort((a, b) {
          final ax = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bx = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bx.compareTo(ax);
        });
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
    _badgeEarnedController.close();
    super.dispose();
  }
}

class _BadgeStats {
  final int sessionsCount;
  final int totalQuestions;
  final int streakDays;
  final int uploads;
  final int maxQuestionsInOneSubject;
  const _BadgeStats({
    required this.sessionsCount,
    required this.totalQuestions,
    required this.streakDays,
    required this.uploads,
    required this.maxQuestionsInOneSubject,
  });
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final gamificationViewModelProvider =
    StateNotifierProvider<GamificationViewModel, GamificationState>(
  (ref) => GamificationViewModel(
    ref.read(authRepositoryProvider),
    ref.read(usersRepositoryProvider),
    ref.read(rewardsRepositoryProvider),
  ),
);

/// Streams a [BadgeInfo] every time the user earns a new badge. Widgets
/// that render celebration overlays watch this.
final badgeEarnedEventProvider = StreamProvider<BadgeInfo>((ref) {
  final vm = ref.watch(gamificationViewModelProvider.notifier);
  return vm.badgeEarnedStream;
});
