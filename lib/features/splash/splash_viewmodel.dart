import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class SplashState {
  final bool isLoading;
  final String? userRole;
  final String? error;

  const SplashState({
    this.isLoading = false,
    this.userRole,
    this.error,
  });

  SplashState copyWith({
    bool? isLoading,
    String? userRole,
    String? error,
  }) {
    return SplashState(
      isLoading: isLoading ?? this.isLoading,
      userRole: userRole ?? this.userRole,
      error: error,           // explicit null allowed to clear error
    );
  }
}

// ---------------------------------------------------------------------------
// Destination enum
// ---------------------------------------------------------------------------

enum SplashDestination {
  onboarding,
  login,
  studentDashboard,
  teacherDashboard,
  admin,
}

// ---------------------------------------------------------------------------
// ViewModel
// ---------------------------------------------------------------------------

class SplashViewModel extends StateNotifier<SplashState> {
  SplashViewModel() : super(const SplashState());

  Future<SplashDestination> resolveDestination() async {
    state = state.copyWith(isLoading: true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        return await _resolveRoleDestination(user.uid);
      }

      return await _resolveUnauthDestination();
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Something went wrong. Please sign in again.',
      );
      return SplashDestination.login;
    }
  }

  Future<SplashDestination> _resolveRoleDestination(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final role = (doc.data()?['role'] as String?)?.trim() ?? 'student';
      state = state.copyWith(isLoading: false, userRole: role);

      return switch (role) {
        'admin'            => SplashDestination.admin,
        'teacher'          => SplashDestination.teacherDashboard,
        'student'          => SplashDestination.studentDashboard,
        'premium_student'  => SplashDestination.studentDashboard,
        _                  => SplashDestination.studentDashboard,
      };
    } on FirebaseException {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load your profile. Please sign in again.',
      );
      return SplashDestination.login;
    }
  }

  Future<SplashDestination> _resolveUnauthDestination() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    state = state.copyWith(isLoading: false);
    return onboardingComplete
        ? SplashDestination.login
        : SplashDestination.onboarding;
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

// Intentionally NOT autoDispose: the splash screen uses ref.read (not watch),
// so an autoDispose provider gets disposed during the await inside
// resolveDestination(), causing a "used after dispose" throw on the next
// state = ... that then hangs the splash sequence.
final splashViewModelProvider =
    StateNotifierProvider<SplashViewModel, SplashState>(
  (ref) => SplashViewModel(),
);
