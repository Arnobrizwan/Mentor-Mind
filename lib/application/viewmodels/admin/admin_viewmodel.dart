import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/data/models/usage_log_day.dart';
import 'package:mentor_minds/data/repositories/admin_repository.dart';
import 'package:mentor_minds/data/repositories/auth_repository.dart';
import 'package:mentor_minds/data/repositories/users_repository.dart';
import 'package:mentor_minds/data/services/firebase_providers.dart';

class AdminUserRow {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String subscriptionType;
  final int points;
  final bool isApproved;
  final List<String> subjects;

  const AdminUserRow({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.subscriptionType,
    required this.points,
    this.isApproved = true,
    this.subjects = const [],
  });
}

class AdminState {
  final bool isLoading;
  final bool isAuthorized;
  final String? error;
  final List<AdminUserRow> users;
  final DocumentSnapshot<Map<String, dynamic>>? lastUserDoc;
  final bool hasMoreUsers;
  final bool analyticsLoading;
  final List<UsageLogDay> usageLogDays;
  final String? analyticsError;

  // Teacher approval queue (role == 'teacher' && isApproved == false). Streamed
  // separately from the paginated user list so admins always see fresh signups.
  final List<AdminUserRow> pendingTeachers;

  // Live KPIs for the dashboard tab. Backed by Firestore aggregate counts.
  final int? totalUsersCount;
  final int? premiumUsersCount;
  final int? materialsCount;

  const AdminState({
    this.isLoading = true,
    this.isAuthorized = false,
    this.error,
    this.users = const [],
    this.lastUserDoc,
    this.hasMoreUsers = true,
    this.analyticsLoading = false,
    this.usageLogDays = const [],
    this.analyticsError,
    this.pendingTeachers = const [],
    this.totalUsersCount,
    this.premiumUsersCount,
    this.materialsCount,
  });

  int get totalCallsLast14Days =>
      usageLogDays.fold<int>(0, (total, d) => total + d.calls);

  double get totalCostLast14Days => usageLogDays.fold<double>(
        0,
        (total, d) => total + d.estimatedCostUsd,
      );

  AdminState copyWith({
    bool? isLoading,
    bool? isAuthorized,
    String? error,
    List<AdminUserRow>? users,
    DocumentSnapshot<Map<String, dynamic>>? lastUserDoc,
    bool? hasMoreUsers,
    bool? analyticsLoading,
    List<UsageLogDay>? usageLogDays,
    String? analyticsError,
    List<AdminUserRow>? pendingTeachers,
    int? totalUsersCount,
    int? premiumUsersCount,
    int? materialsCount,
    bool clearError = false,
    bool clearAnalyticsError = false,
  }) =>
      AdminState(
        isLoading: isLoading ?? this.isLoading,
        isAuthorized: isAuthorized ?? this.isAuthorized,
        error: clearError ? null : (error ?? this.error),
        users: users ?? this.users,
        lastUserDoc: lastUserDoc ?? this.lastUserDoc,
        hasMoreUsers: hasMoreUsers ?? this.hasMoreUsers,
        analyticsLoading: analyticsLoading ?? this.analyticsLoading,
        usageLogDays: usageLogDays ?? this.usageLogDays,
        analyticsError:
            clearAnalyticsError ? null : (analyticsError ?? this.analyticsError),
        pendingTeachers: pendingTeachers ?? this.pendingTeachers,
        totalUsersCount: totalUsersCount ?? this.totalUsersCount,
        premiumUsersCount: premiumUsersCount ?? this.premiumUsersCount,
        materialsCount: materialsCount ?? this.materialsCount,
      );
}

class AdminViewModel extends StateNotifier<AdminState> {
  AdminViewModel(
    this._authRepo,
    this._usersRepo,
    this._adminRepo,
    this._firestore,
  ) : super(const AdminState()) {
    _init();
  }

  final AuthRepository _authRepo;
  final UsersRepository _usersRepo;
  final AdminRepository _adminRepo;
  final FirebaseFirestore _firestore;

  static const _pageSize = 50;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _pendingTeachersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _premiumCountSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _materialsCountSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _totalUsersCountSub;

  Future<void> _init() async {
    final uid = _authRepo.currentUser?.uid;
    if (uid == null) {
      state = state.copyWith(isLoading: false, isAuthorized: false);
      return;
    }
    try {
      // Force a token refresh so freshly-set custom claims (role=admin) are
      // present — a token minted at sign-in may not carry them yet.
      final token = await _authRepo.currentUser?.getIdTokenResult(true);
      final claims = token?.claims;
      final claimAdmin = claims != null && claims['role'] == 'admin';
      final userDoc = await _usersRepo.getUserDocRaw(uid);
      final docAdmin = (userDoc?['role'] as String?) == 'admin';
      final ok = claimAdmin == true && docAdmin == true;
      state = state.copyWith(
        isLoading: false,
        isAuthorized: ok,
        error: ok ? null : 'Not authorized',
      );
      if (ok) {
        _attachLiveStreams();
        // Load per-tab data in the background so the console's first paint is
        // immediate — eagerly awaiting users + 14-day analytics here janked the
        // main thread hard enough to ANR on constrained emulators.
        unawaited(loadUsers(reset: true));
        unawaited(loadUsageAnalytics());
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isAuthorized: false,
        error: 'Could not verify admin access: $e',
      );
    }
  }

  Future<void> loadUsageAnalytics({int days = 14}) async {
    if (!state.isAuthorized) return;
    state = state.copyWith(
      analyticsLoading: true,
      clearAnalyticsError: true,
    );
    try {
      final snap = await _firestore
          .collection('system')
          .orderBy(FieldPath.documentId)
          .startAt([ 'usage_log_' ])
          .endAt([ 'usage_log_\uf8ff' ])
          .limit(days)
          .get();
      final rows = snap.docs
          .where((d) => d.id.startsWith('usage_log_'))
          .map((d) => UsageLogDay.fromDoc(d.id, d.data()))
          .toList(growable: false);
      state = state.copyWith(
        analyticsLoading: false,
        usageLogDays: rows,
      );
    } catch (e) {
      state = state.copyWith(
        analyticsLoading: false,
        analyticsError: 'Could not load usage analytics: $e',
      );
    }
  }

  Future<void> loadUsers({bool reset = false}) async {
    if (!state.isAuthorized) return;
    try {
      Query<Map<String, dynamic>> q = _firestore
          .collection('users')
          .orderBy(FieldPath.documentId)
          .limit(_pageSize);
      if (!reset && state.lastUserDoc != null) {
        q = q.startAfterDocument(state.lastUserDoc!);
      }
      final snap = await q.get();
      final rows = snap.docs.map((d) {
        final data = d.data();
        return AdminUserRow(
          uid: d.id,
          name: (data['name'] as String?) ?? 'User',
          email: (data['email'] as String?) ?? '',
          role: (data['role'] as String?) ?? 'student',
          subscriptionType:
              (data['subscriptionType'] as String?) ?? 'free',
          points: (data['points'] as num?)?.toInt() ?? 0,
          isApproved: (data['isApproved'] as bool?) ?? true,
          subjects: ((data['subjects'] as List?) ?? const [])
              .map((e) => e.toString())
              .toList(growable: false),
        );
      }).toList(growable: false);

      state = state.copyWith(
        users: reset ? rows : [...state.users, ...rows],
        lastUserDoc: snap.docs.isEmpty ? state.lastUserDoc : snap.docs.last,
        hasMoreUsers: snap.docs.length >= _pageSize,
        clearError: true,
      );
    } catch (e) {
      debugPrint('loadUsers: $e');
      state = state.copyWith(error: 'Could not load users');
    }
  }

  Future<void> togglePremium(AdminUserRow row) async {
    final makePremium = row.subscriptionType != 'premium';
    try {
      await _adminRepo.setPremium(row.uid, makePremium);
      final updated = state.users
          .map(
            (u) => u.uid == row.uid
                ? AdminUserRow(
                    uid: u.uid,
                    name: u.name,
                    email: u.email,
                    role: u.role,
                    subscriptionType: makePremium ? 'premium' : 'free',
                    points: u.points,
                    isApproved: u.isApproved,
                    subjects: u.subjects,
                  )
                : u,
          )
          .toList(growable: false);
      state = state.copyWith(users: updated);
    } catch (e) {
      state = state.copyWith(error: 'setPremium failed: $e');
    }
  }

  Future<void> sendBroadcast({
    required String title,
    required String body,
    required String recipientRole,
  }) async {
    try {
      await _adminRepo.sendBroadcast(
        title: title,
        body: body,
        recipientRole: recipientRole,
      );
    } catch (e) {
      state = state.copyWith(error: 'Broadcast failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Live streams — pending-teacher queue + 3 dashboard KPI counts.
  // Wired only after auth check passes (firestore.rules require isAdmin()).
  // ---------------------------------------------------------------------------

  void _attachLiveStreams() {
    _pendingTeachersSub?.cancel();
    _pendingTeachersSub = _firestore
        .collection('users')
        .where('role', isEqualTo: 'teacher')
        .where('isApproved', isEqualTo: false)
        .snapshots()
        .listen(
      (snap) {
        if (!mounted) return;
        final rows = snap.docs.map((d) {
          final data = d.data();
          return AdminUserRow(
            uid: d.id,
            name: (data['name'] as String?) ?? 'Teacher',
            email: (data['email'] as String?) ?? '',
            role: 'teacher',
            subscriptionType:
                (data['subscriptionType'] as String?) ?? 'free',
            points: (data['points'] as num?)?.toInt() ?? 0,
            isApproved: false,
            subjects: ((data['subjects'] as List?) ?? const [])
                .map((e) => e.toString())
                .toList(growable: false),
          );
        }).toList(growable: false);
        state = state.copyWith(pendingTeachers: rows);
      },
      onError: (e) => debugPrint('pendingTeachers stream: $e'),
    );

    _totalUsersCountSub?.cancel();
    _totalUsersCountSub = _firestore.collection('users').snapshots().listen(
      (snap) {
        if (!mounted) return;
        state = state.copyWith(totalUsersCount: snap.size);
      },
      onError: (e) => debugPrint('totalUsers stream: $e'),
    );

    _premiumCountSub?.cancel();
    _premiumCountSub = _firestore
        .collection('users')
        .where('subscriptionType', isEqualTo: 'premium')
        .snapshots()
        .listen(
      (snap) {
        if (!mounted) return;
        state = state.copyWith(premiumUsersCount: snap.size);
      },
      onError: (e) => debugPrint('premiumCount stream: $e'),
    );

    _materialsCountSub?.cancel();
    _materialsCountSub =
        _firestore.collection('materials').snapshots().listen(
      (snap) {
        if (!mounted) return;
        state = state.copyWith(materialsCount: snap.size);
      },
      onError: (e) => debugPrint('materialsCount stream: $e'),
    );
  }

  // Approve a pending teacher by flipping isApproved on their user doc.
  // Firestore rules (`/users/{uid}` update) allow admins to write any field,
  // so this is a direct doc write rather than a callable.
  Future<void> approveTeacher(AdminUserRow row) async {
    try {
      await _firestore
          .collection('users')
          .doc(row.uid)
          .update({'isApproved': true});
      // Pending stream will auto-remove this row when the snapshot listener
      // fires; nothing else to do here.
    } catch (e) {
      state = state.copyWith(error: 'approveTeacher failed: $e');
    }
  }

  @override
  void dispose() {
    _pendingTeachersSub?.cancel();
    _totalUsersCountSub?.cancel();
    _premiumCountSub?.cancel();
    _materialsCountSub?.cancel();
    super.dispose();
  }
}

final adminViewModelProvider =
    StateNotifierProvider.autoDispose<AdminViewModel, AdminState>(
  (ref) => AdminViewModel(
    ref.read(authRepositoryProvider),
    ref.read(usersRepositoryProvider),
    ref.read(adminRepositoryProvider),
    ref.read(firestoreProvider),
  ),
);
