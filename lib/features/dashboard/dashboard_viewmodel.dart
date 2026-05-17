import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';

// ---------------------------------------------------------------------------
// Subject → brand color mapping (shared helper)
// ---------------------------------------------------------------------------

const _subjectColors = <String, Color>{
  'Mathematics': Color(0xFF3B82F6),
  'Physics':     Color(0xFF8B5CF6),
  'Chemistry':   Color(0xFF22C55E),
  'Biology':     Color(0xFF14B8A6),
  'English':     Color(0xFFEC4899),
  'ICT':         Color(0xFF06B6D4),
  'Accounting':  Color(0xFFF59E0B),
  'Economics':   Color(0xFFEF4444),
  'History':     Color(0xFFA855F7),
  'Geography':   Color(0xFF10B981),
};

Color _colorForSubject(String s) => _subjectColors[s] ?? AppColors.kPrimary;

List<Color> _gradientForSubject(String s) {
  final base = _colorForSubject(s);
  final hsl = HSLColor.fromColor(base);
  final darker = hsl
      .withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0))
      .toColor();
  return [base, darker];
}

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class DashboardUser {
  final String uid;
  final String name;
  final String firstName;
  final String role;
  final int points;
  final List<String> subjects;
  final String level;
  final List<String> badgeIds;

  const DashboardUser({
    required this.uid,
    required this.name,
    required this.firstName,
    required this.role,
    required this.points,
    required this.subjects,
    required this.level,
    required this.badgeIds,
  });

  factory DashboardUser.fromDoc(
    String uid,
    Map<String, dynamic> data,
    String? authDisplayName,
  ) {
    final rawName = (data['name'] as String?)?.trim();
    final name = (rawName?.isNotEmpty ?? false)
        ? rawName!
        : (authDisplayName?.trim().isNotEmpty == true
            ? authDisplayName!.trim()
            : 'Learner');
    return DashboardUser(
      uid: uid,
      name: name,
      firstName: name.split(RegExp(r'\s+')).first,
      role: (data['role'] as String?)?.trim() ?? 'student',
      points: (data['points'] as num?)?.toInt() ?? 0,
      subjects: ((data['subjects'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      level: (data['level'] as String?) ?? '',
      badgeIds: ((data['badges'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
    );
  }
}

class RewardsSnapshot {
  final int points;
  final List<String> badgeIds;
  const RewardsSnapshot({this.points = 0, this.badgeIds = const []});
}

class SubjectProgress {
  final String name;
  final double progress; // 0..1
  final Color color;
  const SubjectProgress({
    required this.name,
    required this.progress,
    required this.color,
  });
}

class SessionItem {
  final String id;
  final String subject;
  final Color subjectColor;
  final String question;
  final DateTime timestamp;
  const SessionItem({
    required this.id,
    required this.subject,
    required this.subjectColor,
    required this.question,
    required this.timestamp,
  });

  factory SessionItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final subject = (data['subject'] as String?) ?? 'General';
    final question = (data['lastQuestion'] as String?) ??
        (data['title'] as String?) ??
        'Recent question';
    final ts = (data['updatedAt'] as Timestamp?)?.toDate() ??
        (data['createdAt'] as Timestamp?)?.toDate() ??
        DateTime.now();
    return SessionItem(
      id: doc.id,
      subject: subject,
      subjectColor: _colorForSubject(subject),
      question: question,
      timestamp: ts,
    );
  }
}

class MaterialItem {
  final String id;
  final String title;
  final String level;
  final String subject;
  final List<Color> gradient;
  const MaterialItem({
    required this.id,
    required this.title,
    required this.level,
    required this.subject,
    required this.gradient,
  });

  factory MaterialItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final subject = (data['subject'] as String?) ?? 'General';
    return MaterialItem(
      id: doc.id,
      title: (data['title'] as String?) ?? 'Untitled',
      level: (data['level'] as String?) ?? '',
      subject: subject,
      gradient: _gradientForSubject(subject),
    );
  }
}

class BadgeItem {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  const BadgeItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

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
    return list
        .map(
          (s) => SubjectProgress(
            name: s,
            progress: _stubProgress(s),
            color: _colorForSubject(s),
          ),
        )
        .toList(growable: false);
  }

  List<BadgeItem> get badges =>
      rewards.badgeIds.take(3).map(_mapBadge).toList(growable: false);

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
      justAwardedDailyPoints:
          justAwardedDailyPoints ?? this.justAwardedDailyPoints,
      dailyAwardAmount: dailyAwardAmount ?? this.dailyAwardAmount,
    );
  }
}

// Demo/stub progress per subject — deterministic variation until real
// per-subject progress tracking lands.
double _stubProgress(String subject) {
  final hash = subject.codeUnits.fold<int>(0, (a, b) => a + b);
  return 0.15 + (hash % 75) / 100;
}

BadgeItem _mapBadge(String id) {
  return switch (id) {
    'first_login' => const BadgeItem(
        id: 'first_login',
        name: 'First Login',
        icon: Icons.rocket_launch_rounded,
        color: AppColors.kGold,
      ),
    'streak_3' => const BadgeItem(
        id: 'streak_3',
        name: '3-Day Streak',
        icon: Icons.local_fire_department_rounded,
        color: AppColors.kError,
      ),
    'streak_7' => const BadgeItem(
        id: 'streak_7',
        name: '7-Day Streak',
        icon: Icons.local_fire_department_rounded,
        color: AppColors.kError,
      ),
    'first_quiz' => const BadgeItem(
        id: 'first_quiz',
        name: 'First Quiz',
        icon: Icons.quiz_rounded,
        color: AppColors.kAccent,
      ),
    'top_scorer' => const BadgeItem(
        id: 'top_scorer',
        name: 'Top Scorer',
        icon: Icons.emoji_events_rounded,
        color: AppColors.kGold,
      ),
    _ => BadgeItem(
        id: id,
        name: id,
        icon: Icons.workspace_premium_rounded,
        color: AppColors.kGold,
      ),
  };
}

// ---------------------------------------------------------------------------
// ViewModel
// ---------------------------------------------------------------------------

class DashboardViewModel extends StateNotifier<DashboardState> {
  DashboardViewModel()
      : super(DashboardState(
          dailyChallengeResetsAt: _nextMidnight(DateTime.now()),
        )) {
    _init();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sessionsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _materialsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notifSub;

  // Track the last inputs we opened dependent streams for, so we only
  // resubscribe when the relevant user fields actually change.
  List<String> _lastSubjects = const [];
  String _lastRole = '';

  static DateTime _nextMidnight(DateTime now) =>
      DateTime(now.year, now.month, now.day + 1);

  // -------------------------------------------------------------------------
  // Init — kicks off all streams in parallel
  // -------------------------------------------------------------------------

  void _init() {
    final user = _auth.currentUser;
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
    unawaited(_awardDailyLoginIfNeeded(uid));
  }

  // -------------------------------------------------------------------------
  // 1. User stream → name / points / badges / subjects / role
  // -------------------------------------------------------------------------

  void _streamUser(String uid) {
    _userSub = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
      (doc) {
        final data = doc.data();
        if (data == null) {
          state = state.copyWith(
            isLoading: false,
            error: 'Your profile is missing. Please contact support.',
          );
          return;
        }

        final userObj = DashboardUser.fromDoc(
          uid,
          data,
          _auth.currentUser?.displayName,
        );

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
    _sessionsSub = _firestore
        .collection('sessions')
        .where('userId', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .limit(3)
        .snapshots()
        .listen(
      (snap) {
        state = state.copyWith(
          recentSessions:
              snap.docs.map(SessionItem.fromDoc).toList(growable: false),
        );
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

    final capped = subjects.take(10).toList();
    _materialsSub = _firestore
        .collection('materials')
        .where('subject', whereIn: capped)
        .orderBy('createdAt', descending: true)
        .limit(6)
        .snapshots()
        .listen(
      (snap) {
        state = state.copyWith(
          materials:
              snap.docs.map(MaterialItem.fromDoc).toList(growable: false),
        );
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
    _notifSub = _firestore
        .collection('notifications')
        .where('recipientRole', whereIn: ['all', role])
        .where('read', isEqualTo: false)
        .snapshots()
        .listen(
      (snap) {
        state = state.copyWith(notificationCount: snap.size);
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
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('usage')
          .orderBy(FieldPath.documentId, descending: true)
          .limit(45)
          .get();

      final byKey = {
        for (final d in snap.docs) d.id: d.data(),
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
  // Daily login reward — +5 pts once per calendar day
  // -------------------------------------------------------------------------

  Future<void> _awardDailyLoginIfNeeded(String uid) async {
    try {
      final todayKey = _usageKey(DateTime.now());
      final usageRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('usage')
          .doc(todayKey);

      final usageDoc = await usageRef.get();
      if (usageDoc.data()?['loginRewarded'] == true) return;

      final userRef = _firestore.collection('users').doc(uid);
      final rewardsRef = _firestore.collection('rewards').doc(uid);

      final batch = _firestore.batch();
      batch.set(
        usageRef,
        {
          'date': todayKey,
          'loginRewarded': true,
          'loginRewardedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      batch.update(userRef, {'points': FieldValue.increment(5)});
      // Keep /rewards/{uid}.points in sync — the rewards doc is the ledger.
      batch.set(
        rewardsRef,
        {
          'userId': uid,
          'points': FieldValue.increment(5),
          'history': FieldValue.arrayUnion([
            {
              'type': 'daily_login',
              'points': 5,
              'date': todayKey,
            }
          ]),
        },
        SetOptions(merge: true),
      );
      await batch.commit();

      if (!mounted) return;
      state = state.copyWith(
        justAwardedDailyPoints: true,
        dailyAwardAmount: 5,
      );
    } catch (_) {
      // Non-fatal — we'll retry on next app open.
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
    final uid = _auth.currentUser?.uid;
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
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final dashboardViewModelProvider =
    StateNotifierProvider.autoDispose<DashboardViewModel, DashboardState>(
  (ref) => DashboardViewModel(),
);
