import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException, FirebaseException;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mentor_minds/data/models/profile_stats.dart';
import 'package:mentor_minds/data/models/profile_user.dart';
import 'package:mentor_minds/data/models/subscription_doc.dart';
import 'package:mentor_minds/data/repositories/auth_repository.dart';
import 'package:mentor_minds/data/repositories/billing_repository.dart';
import 'package:mentor_minds/data/repositories/sessions_repository.dart';
import 'package:mentor_minds/data/repositories/storage_repository.dart';
import 'package:mentor_minds/data/repositories/subscriptions_repository.dart';
import 'package:mentor_minds/data/repositories/users_repository.dart';
import 'package:url_launcher/url_launcher.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class ProfileState {
  final ProfileUser? user;
  final ProfileStats stats;
  final bool isLoading;
  final bool isEditing;
  final bool uploadingAvatar;
  final String? error;

  const ProfileState({
    this.user,
    this.stats = ProfileStats.empty,
    this.isLoading = true,
    this.isEditing = false,
    this.uploadingAvatar = false,
    this.error,
  });

  bool get isBusy => isEditing || uploadingAvatar;

  ProfileState copyWith({
    ProfileUser? user,
    ProfileStats? stats,
    bool? isLoading,
    bool? isEditing,
    bool? uploadingAvatar,
    String? error,
    bool clearError = false,
  }) {
    return ProfileState(
      user: user ?? this.user,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      isEditing: isEditing ?? this.isEditing,
      uploadingAvatar: uploadingAvatar ?? this.uploadingAvatar,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ---------------------------------------------------------------------------
// ViewModel
// ---------------------------------------------------------------------------

class ProfileViewModel extends StateNotifier<ProfileState> {
  ProfileViewModel(
    this._authRepo,
    this._usersRepo,
    this._sessionsRepo,
    this._storageRepo,
    this._billingRepo,
    this._subscriptionsRepo,
  ) : super(const ProfileState()) {
    final uid = _authRepo.currentUser?.uid;
    if (uid != null) loadProfile(uid);
  }

  final AuthRepository _authRepo;
  final UsersRepository _usersRepo;
  final SessionsRepository _sessionsRepo;
  final StorageRepository _storageRepo;
  final BillingRepository _billingRepo;
  final SubscriptionsRepository _subscriptionsRepo;

  StreamSubscription<ProfileUser>? _userSub;
  StreamSubscription<SubscriptionDoc>? _subSub;
  String? _boundUid;

  // -------------------------------------------------------------------------
  // loadProfile(uid)
  // -------------------------------------------------------------------------

  void loadProfile(String uid) {
    if (_boundUid == uid && _userSub != null) return;
    _boundUid = uid;
    _userSub?.cancel();

    state = state.copyWith(isLoading: true, clearError: true);

    _userSub = _usersRepo
        .watchProfileUser(uid)
        .listen(
      (user) {
        state = state.copyWith(
          isLoading: false,
          user: user,
          clearError: true,
        );
      },
      onError: (_) {
        state = state.copyWith(
          isLoading: false,
          error: 'Could not load your profile. Pull to retry.',
        );
      },
    );

    fetchStats(uid);

    _subSub?.cancel();
    _subSub = _subscriptionsRepo.watchSubscription(uid).listen((sub) {
      final user = state.user;
      if (user == null) return;
      final type = sub.isPremiumActive ? 'premium' : 'free';
      if (user.subscriptionType != type) {
        state = state.copyWith(user: user.copyWith(subscriptionType: type));
      }
    });
  }

  /// Re-subscribes the profile stream after a load error (the initial bind
  /// guard in [loadProfile] would otherwise treat the dead stream as live).
  void retryLoad() {
    final uid = _boundUid;
    if (uid == null) return;
    _userSub?.cancel();
    _userSub = null;
    loadProfile(uid);
  }

  /// PAY-06 — open Stripe Checkout in external browser (Safari).
  Future<String?> startPremiumCheckout() async {
    try {
      final url = await _billingRepo.createCheckoutSession();
      if (url.isEmpty) {
        state = state.copyWith(error: 'Could not start checkout.');
        return null;
      }
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        state = state.copyWith(error: 'Could not open browser.');
        return null;
      }
      return url;
    } catch (e) {
      state = state.copyWith(error: 'Checkout failed: $e');
      return null;
    }
  }

  /// PAY-07 — Stripe Customer Portal in external browser.
  Future<String?> openSubscriptionPortal() async {
    try {
      final url = await _billingRepo.createPortalSession();
      if (url.isEmpty) {
        state = state.copyWith(error: 'No subscription to manage.');
        return null;
      }
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        state = state.copyWith(error: 'Could not open browser.');
        return null;
      }
      return url;
    } catch (e) {
      state = state.copyWith(error: 'Portal failed: $e');
      return null;
    }
  }

  /// PAY-04 — refresh ID token after premium flip (call when app resumes).
  Future<void> refreshAuthToken() async {
    await _authRepo.currentUser?.getIdToken(true);
  }

  // -------------------------------------------------------------------------
  // updateProfile(name, avatarFile?)
  // -------------------------------------------------------------------------

  Future<bool> updateProfile({
    required String name,
    XFile? avatarFile,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(error: 'Name cannot be empty');
      return false;
    }
    final user = _authRepo.currentUser;
    if (user == null) return false;

    state = state.copyWith(isEditing: true, clearError: true);

    try {
      final updates = <String, dynamic>{
        'name': trimmed,
        'displayName': trimmed,
      };

      if (avatarFile != null) {
        state = state.copyWith(uploadingAvatar: true);
        final url = await _storageRepo.uploadImage(
          uid: user.uid,
          file: File(avatarFile.path),
          suffix: 'avatar.jpg',
        );
        updates['avatarUrl'] = url;
        updates['photoUrl'] = url; // keep legacy field in sync
        await _authRepo.updatePhotoURL(url);
        state = state.copyWith(uploadingAvatar: false);
      }

      await _usersRepo.setUserFields(user.uid, updates);
      await _authRepo.updateDisplayName(trimmed);

      state = state.copyWith(isEditing: false);
      return true;
    } on FirebaseException catch (e) {
      debugPrint('updateProfile FirebaseException: ${e.code} — ${e.message}');
      state = state.copyWith(
        isEditing: false,
        uploadingAvatar: false,
        error: e.code == 'unauthorized'
            ? 'Storage permission denied. Check Storage rules.'
            : 'Update failed: ${e.message ?? e.code}',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isEditing: false,
        uploadingAvatar: false,
        error: 'Update failed: $e',
      );
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // changePassword(current, new)
  // -------------------------------------------------------------------------

  /// Returns null on success, user-facing error string otherwise.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _authRepo.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      return 'You are signed out. Please log in again.';
    }
    if (newPassword.length < 8) {
      return 'New password must be at least 8 characters';
    }

    state = state.copyWith(isEditing: true, clearError: true);
    try {
      await _authRepo.reauthenticateWithPassword(email, currentPassword);
      await _authRepo.updatePassword(newPassword);
      state = state.copyWith(isEditing: false);
      return null;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isEditing: false);
      return switch (e.code) {
        'wrong-password' ||
        'invalid-credential' =>
          'Your current password is incorrect',
        'weak-password' => 'New password is too weak',
        'requires-recent-login' =>
          'For security, please sign out and back in, then try again',
        _ => e.message ?? 'Could not update password (${e.code})',
      };
    } catch (e) {
      state = state.copyWith(isEditing: false);
      return 'Could not update password: $e';
    }
  }

  // -------------------------------------------------------------------------
  // updateSubjects / updateLevel / toggleNotifications
  // -------------------------------------------------------------------------

  Future<bool> updateSubjects(List<String> subjects) async {
    final uid = _authRepo.currentUser?.uid;
    if (uid == null) return false;
    state = state.copyWith(isEditing: true, clearError: true);
    try {
      await _usersRepo.setUserFields(uid, {'subjects': subjects});
      state = state.copyWith(isEditing: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isEditing: false,
        error: 'Could not update subjects: $e',
      );
      return false;
    }
  }

  Future<bool> updateLevel(String level) async {
    final uid = _authRepo.currentUser?.uid;
    if (uid == null) return false;
    state = state.copyWith(isEditing: true, clearError: true);
    try {
      await _usersRepo.setUserFields(uid, {'level': level});
      state = state.copyWith(isEditing: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isEditing: false,
        error: 'Could not update level: $e',
      );
      return false;
    }
  }

  Future<bool> toggleNotifications(bool enabled) async {
    final uid = _authRepo.currentUser?.uid;
    if (uid == null) return false;
    try {
      await _usersRepo.setUserFields(uid, {'notificationsEnabled': enabled});
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Could not update notifications: $e');
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // logout()
  // -------------------------------------------------------------------------

  /// Signs out of both providers and clears local prefs except the
  /// `onboarding_complete` flag. Caller should navigate to /auth/login.
  Future<void> logout() async {
    await _authRepo.signOut();

    try {
      final prefs = await SharedPreferences.getInstance();
      final onboardingComplete = prefs.getBool('onboarding_complete');
      await prefs.clear();
      if (onboardingComplete != null) {
        await prefs.setBool('onboarding_complete', onboardingComplete);
      }
    } catch (_) {/* best-effort — never block logout on prefs */}
  }

  // -------------------------------------------------------------------------
  // deleteAccount()
  // -------------------------------------------------------------------------

  /// Returns null on success; user-facing error string otherwise.
  /// Caller should navigate to /onboarding on success.
  Future<String?> deleteAccount() async {
    final user = _authRepo.currentUser;
    if (user == null) return 'You are already signed out.';

    state = state.copyWith(isEditing: true, clearError: true);
    try {
      final uid = user.uid;

      // 1. Delete user-owned docs while security rules still permit it.
      //    Spec calls for /users/{uid}; we also clean up /rewards/{uid} and
      //    any owned /sessions so they don't become orphaned.
      //    getSessionRefs returns D-02 batch-exception DocumentReferences.
      final sessionRefs = await _sessionsRepo.getSessionRefs(uid);
      final batch = _usersRepo.startBatch();
      for (final ref in sessionRefs) {
        batch.delete(ref);
      }
      batch.delete(_usersRepo.rewardsDocRef(uid));
      batch.delete(_usersRepo.userDocRef(uid));
      await batch.commit();

      // 2. ARCH-06 / Plan 07: avatar storage delete is intentionally skipped on account deletion.
      //    The upload path is `uploads/{uid}/{ts}_avatar.jpg` where the timestamp is opaque to the
      //    viewmodel. A reliable client-side delete would require either (a) recording the upload
      //    path on `/users/{uid}.avatarStoragePath`, or (b) a Storage list-and-delete sweep.
      //    Both are deferred to Phase 4+. Orphan objects are <100KB each and rate-limited by the
      //    user's own delete-account frequency (typically once per account in the user's lifetime).
      //    See: T-1-ORPHAN in 01-07-avatar-and-google-signin-PLAN.md.

      // 3. Delete the auth user (also signs out of Google if applicable).
      await _authRepo.deleteAccount();

      state = state.copyWith(isEditing: false);
      return null;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isEditing: false);
      if (e.code == 'requires-recent-login') {
        return 'For security, please sign in again and retry deletion.';
      }
      return e.message ?? 'Could not delete account (${e.code})';
    } catch (e) {
      state = state.copyWith(isEditing: false);
      return 'Could not delete account: $e';
    }
  }

  // -------------------------------------------------------------------------
  // fetchStats(uid)
  // -------------------------------------------------------------------------

  Future<void> fetchStats(String uid) async {
    try {
      final results = await Future.wait([
        _sessionsRepo.countSessions(uid),
        _usersRepo.getUsageHistory(uid),
      ]);

      final sessionCount = results[0] as int;
      final usageDocs = results[1] as List<Map<String, dynamic>>;
      final streak = _computeStreak(usageDocs.map((d) => d['id'] as String).toList());
      final points = state.user?.points ?? 0;

      state = state.copyWith(
        stats: ProfileStats(
          sessionCount: sessionCount,
          points: points,
          streakDays: streak,
        ),
      );
    } catch (e) {
      debugPrint('fetchStats error: $e');
      // Leave stats at their previous value — no user-facing error, stats
      // are not blocking.
    }
  }

  /// Usage doc IDs are expected to be `yyyy-MM-dd` strings. Counts the
  /// longest run of consecutive days ending today or yesterday — if they
  /// haven't logged today yet, yesterday still counts as an unbroken streak.
  int _computeStreak(List<String> usageDateIds) {
    if (usageDateIds.isEmpty) return 0;
    final days = <DateTime>{};
    for (final id in usageDateIds) {
      final parts = id.split('-');
      if (parts.length != 3) continue;
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y == null || m == null || d == null) continue;
      days.add(DateTime(y, m, d));
    }
    if (days.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    DateTime cursor;
    if (days.contains(today)) {
      cursor = today;
    } else if (days.contains(yesterday)) {
      cursor = yesterday;
    } else {
      return 0;
    }

    var streak = 0;
    while (days.contains(cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // -------------------------------------------------------------------------
  // Misc
  // -------------------------------------------------------------------------

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _subSub?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Provider — NOT autoDispose (see splash_viewmodel.dart for rationale).
// ---------------------------------------------------------------------------

final profileViewModelProvider =
    StateNotifierProvider<ProfileViewModel, ProfileState>(
  (ref) => ProfileViewModel(
    ref.read(authRepositoryProvider),
    ref.read(usersRepositoryProvider),
    ref.read(sessionsRepositoryProvider),
    ref.read(storageRepositoryProvider),
    ref.read(billingRepositoryProvider),
    ref.read(subscriptionsRepositoryProvider),
  ),
);
