import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/core/constants/badge_catalog.dart';
import 'package:mentor_minds/core/constants/subject_colors.dart';
import 'package:mentor_minds/data/models/daily_challenge.dart';
import 'package:mentor_minds/data/models/badge_item.dart';
import 'package:mentor_minds/data/models/dashboard_user.dart';
import 'package:mentor_minds/data/models/material_item.dart';
import 'package:mentor_minds/data/models/points_history.dart';
import 'package:mentor_minds/data/models/rewards_snapshot.dart';
import 'package:mentor_minds/data/models/session_item.dart';
import 'package:mentor_minds/data/models/subject_progress.dart';
import 'package:mentor_minds/data/repositories/auth_repository.dart';
import 'package:mentor_minds/data/repositories/daily_challenges_repository.dart';
import 'package:mentor_minds/data/repositories/materials_repository.dart';
import 'package:mentor_minds/data/repositories/notifications_repository.dart';
import 'package:mentor_minds/data/repositories/sessions_repository.dart';
import 'package:mentor_minds/data/repositories/rewards_repository.dart';
import 'package:mentor_minds/data/repositories/users_repository.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class DashboardState {
  final bool isLoading;
  final String? error;

  final DashboardUser? user;
  final List<SessionItem> recentSessions;
  final List<MaterialItem> materials;
  final RewardsSnapshot rewards;
  final int streak;
  final int notificationCount;

  final DateTime dailyChallengeResetsAt;
  final DailyChallenge? dailyChallenge;

  // One-shot signal: set true when the daily login reward was just granted.
  // The screen shows the toast and calls ackDailyAward() to clear it.
  final bool justAwardedDailyPoints;
  final int dailyAwardAmount;

  const DashboardState({
    this.isLoading = true,
    this.error,
    this.user,
    this.recentSessions = const [],
    this.materials = const [],
    this.rewards = const RewardsSnapshot(),
    this.streak = 0,
    this.notificationCount = 0,
    required this.dailyChallengeResetsAt,
    this.dailyChallenge,
    this.justAwardedDailyPoints = false,
    this.dailyAwardAmount = 0,
  });

  // -------------------------------------------------------------------------
  // UI convenience getters
  // -------------------------------------------------------------------------

  String get firstName => user?.firstName ?? 'Learner';
  int get points => rewards.points;
  int get totalBadgeCount => rewards.badgeIds.length;

  String get greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  List<SubjectProgress> get subjects {
    final list = user?.subjects ?? const <String>[];
    final counts = user?.questionsPerSubject ?? const {};
    return list
        .map(
          (s) => SubjectProgress(
            name: s,
            progress: subjectQuestionProgress(counts, s),
            color: colorForSubject(s),
          ),
        )
        .toList(growable: false);
  }

  List<BadgeItem> get badges => (user?.badgeIds ?? rewards.badgeIds)
      .take(3)
      .map(badgeItemForId)
      .toList(growable: false);

  DashboardState copyWith({
    bool? isLoading,
    String? error,
    DashboardUser? user,
    List<SessionItem>? recentSessions,
    List<MaterialItem>? materials,
    RewardsSnapshot? rewards,
    int? streak,
    int? notificationCount,
    DateTime? dailyChallengeResetsAt,
    DailyChallenge? dailyChallenge,
    bool? justAwardedDailyPoints,
    int? dailyAwardAmount,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      user: clearUser ? null : (user ?? this.user),
      recentSessions: recentSessions ?? this.recentSessions,
      materials: materials ?? this.materials,
      rewards: rewards ?? this.rewards,
      streak: streak ?? this.streak,
      notificationCount: notificationCount ?? this.notificationCount,
      dailyChallengeResetsAt:
          dailyChallengeResetsAt ?? this.dailyChallengeResetsAt,
      dailyChallenge: dailyChallenge ?? this.dailyChallenge,
      justAwardedDailyPoints:
          justAwardedDailyPoints ?? this.justAwardedDailyPoints,
      dailyAwardAmount: dailyAwardAmount ?? this.dailyAwardAmount,
    );
  }
}

// ---------------------------------------------------------------------------
// ViewModel
// ---------------------------------------------------------------------------

class DashboardViewModel extends StateNotifier<DashboardState> {
  DashboardViewModel(
    this._usersRepo,
    this._sessionsRepo,
    this._materialsRepo,
    this._notificationsRepo,
    this._authRepo,
    this._rewardsRepo,
    this._dailyChallengesRepo,
  ) : super(DashboardState(
          dailyChallengeResetsAt: _nextDhakaMidnight(),
        )) {
    _init();
  }

  final UsersRepository _usersRepo;
  final SessionsRepository _sessionsRepo;
  final MaterialsRepository _materialsRepo;
  final NotificationsRepository _notificationsRepo;
  final AuthRepository _authRepo;
  final RewardsRepository _rewardsRepo;
  final DailyChallengesRepository _dailyChallengesRepo;

  StreamSubscription<DashboardUser>? _userSub;
  StreamSubscription<DailyChallenge>? _challengeSub;
  StreamSubscription<List<PointsHistory>>? _ledgerSub;
  final Set<String> _seenLedgerKeys = {};
  StreamSubscription<List<SessionItem>>? _sessionsSub;
  StreamSubscription<List<MaterialItem>>? _materialsSub;
  StreamSubscription<int>? _notifSub;

  // Track the last inputs we opened dependent streams for, so we only
  // resubscribe when the relevant user fields actually change.
  List<String> _lastSubjects = const [];
  String _lastRole = '';

  /// UTC+6 (Dhaka) midnight — matches daily challenge scheduler.
  static DateTime _nextDhakaMidnight() {
    final now = DateTime.now().toUtc();
    final dhaka = now.add(const Duration(hours: 6));
    final next = DateTime.utc(dhaka.year, dhaka.month, dhaka.day + 1);
    return next.subtract(const Duration(hours: 6));
  }

  // -------------------------------------------------------------------------
  // Init — kicks off all streams in parallel
  // -------------------------------------------------------------------------

  void _init() {
    final user = _authRepo.currentUser;
    if (user == null) {
      state = state.copyWith(
        isLoading: false,
        error: 'You are not signed in.',
      );
      return;
    }

    final uid = user.uid;
    _streamUser(uid);
    _streamRecentSessions(uid);
    // Materials + notifications depend on the user doc fields, so they
    // subscribe inside the user stream once subjects/role are known.

    // One-shot background work — intentionally fire-and-forget.
    unawaited(_fetchStreak(uid));
    _watchLedgerForDailyToast(uid);
    _streamDailyChallenge();
  }

  void _streamDailyChallenge() {
    _challengeSub?.cancel();
    _challengeSub = _dailyChallengesRepo.watchToday().listen((c) {
      if (!mounted) return;
      state = state.copyWith(
        dailyChallenge: c,
        dailyChallengeResetsAt: _nextDhakaMidnight(),
      );
    });
  }

  void _watchLedgerForDailyToast(String uid) {
    _ledgerSub?.cancel();
    _ledgerSub = _rewardsRepo.watchLedger(uid, limit: 8).listen((entries) {
      for (final entry in entries) {
        if (entry.action != 'daily_login') continue;
        final ts = entry.timestamp;
        if (ts == null) continue;
        final key = 'daily_login-${ts.millisecondsSinceEpoch}';
        if (_seenLedgerKeys.contains(key)) continue;
        _seenLedgerKeys.add(key);
        if (DateTime.now().difference(ts) > const Duration(minutes: 15)) {
          continue;
        }
        if (!mounted) return;
        state = state.copyWith(
          justAwardedDailyPoints: true,
          dailyAwardAmount: entry.pointsAwarded,
        );
      }
    });
  }

  // -------------------------------------------------------------------------
  // 1. User stream → name / points / badges / subjects / role
  // -------------------------------------------------------------------------

  void _streamUser(String uid) {
    _userSub = _usersRepo
        .watchDashboardUser(uid, _authRepo.currentUser?.displayName)
        .listen(
      (userObj) {
        state = state.copyWith(
          isLoading: false,
          user: userObj,
          rewards: RewardsSnapshot(
            points: userObj.points,
            badgeIds: userObj.badgeIds,
          ),
          clearError: true,
        );

        if (!_sameList(userObj.subjects, _lastSubjects)) {
          _lastSubjects = userObj.subjects;
          _streamRecentMaterials(userObj.subjects);
        }
        if (userObj.role != _lastRole) {
          _lastRole = userObj.role;
          _streamNotifications(userObj.role);
        }
      },
      onError: (_) {
        state = state.copyWith(
          isLoading: false,
          error: 'Could not load your profile. Pull to refresh.',
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // 2. Recent AI sessions (limit 3)
  // -------------------------------------------------------------------------

  void _streamRecentSessions(String uid) {
    _sessionsSub = _sessionsRepo
        .watchRecentSessions(uid, limit: 3)
        .listen(
      (sessions) {
        state = state.copyWith(recentSessions: sessions);
      },
      onError: (_) {
        // Non-fatal — leave prior sessions list alone.
      },
    );
  }

  // -------------------------------------------------------------------------
  // 3. Recent materials scoped to user.subjects (limit 6)
  //    Firestore `whereIn` supports up to 30 values; we cap for safety.
  // -------------------------------------------------------------------------

  void _streamRecentMaterials(List<String> subjects) {
    _materialsSub?.cancel();
    if (subjects.isEmpty) {
      state = state.copyWith(materials: const []);
      return;
    }

    _materialsSub = _materialsRepo
        .streamDashboardMaterialsBySubjects(subjects, limit: 6)
        .listen(
      (materials) {
        state = state.copyWith(materials: materials);
      },
      onError: (_) {
        // Non-fatal — likely a missing composite index on first run.
      },
    );
  }

  // -------------------------------------------------------------------------
  // Notifications — unread count for bell badge
  // -------------------------------------------------------------------------

  void _streamNotifications(String role) {
    _notifSub?.cancel();
    _notifSub = _notificationsRepo
        .watchUnreadCount(role)
        .listen(
      (count) {
        state = state.copyWith(notificationCount: count);
      },
      onError: (_) {
        // Non-fatal.
      },
    );
  }

  // -------------------------------------------------------------------------
  // 4. Streak — count consecutive days with messageCount > 0.
  //    Today is a grace day (empty today doesn't break the streak).
  // -------------------------------------------------------------------------

  Future<void> _fetchStreak(String uid) async {
    try {
      final docs = await _usersRepo.getUsageHistory(uid, limit: 45);

      final byKey = {
        for (final d in docs) d['id'] as String: d,
      };

      final now = DateTime.now();
      var streak = 0;
      var alive = true;

      for (var i = 0; i < 45 && alive; i++) {
        final day = DateTime(now.year, now.month, now.day - i);
        final key = _usageKey(day);
        final count =
            (byKey[key]?['messageCount'] as num?)?.toInt() ?? 0;

        if (count > 0) {
          streak++;
        } else if (i > 0) {
          alive = false;
        }
        // i == 0 && count == 0 → today grace, neither increment nor break.
      }

      if (!mounted) return;
      state = state.copyWith(streak: streak);
    } catch (_) {
      // Non-fatal — leave streak at previous value.
    }
  }

  // -------------------------------------------------------------------------
  // Public actions
  // -------------------------------------------------------------------------

  void ackDailyAward() {
    if (!state.justAwardedDailyPoints) return;
    state = state.copyWith(
      justAwardedDailyPoints: false,
      dailyAwardAmount: 0,
    );
  }

  Future<void> refresh() async {
    final uid = _authRepo.currentUser?.uid;
    if (uid == null) return;
    await _fetchStreak(uid);
    // Streams push fresh data automatically — no explicit re-read needed.
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  static String _usageKey(DateTime d) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${pad(d.month)}-${pad(d.day)}';
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _sessionsSub?.cancel();
    _materialsSub?.cancel();
    _notifSub?.cancel();
    _ledgerSub?.cancel();
    _challengeSub?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final dashboardViewModelProvider =
    StateNotifierProvider.autoDispose<DashboardViewModel, DashboardState>(
  (ref) => DashboardViewModel(
    ref.read(usersRepositoryProvider),
    ref.read(sessionsRepositoryProvider),
    ref.read(materialsRepositoryProvider),
    ref.read(notificationsRepositoryProvider),
    ref.read(authRepositoryProvider),
    ref.read(rewardsRepositoryProvider),
    ref.read(dailyChallengesRepositoryProvider),
  ),
);
