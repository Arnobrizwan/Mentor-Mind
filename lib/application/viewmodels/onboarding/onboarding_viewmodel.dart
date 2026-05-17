import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const kSubjects = [
  'Mathematics',
  'Physics',
  'Chemistry',
  'Biology',
  'English',
  'ICT',
  'Accounting',
  'Economics',
  'History',
  'Geography',
];

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class OnboardingState {
  final int currentPage;
  final String? selectedLevel;
  final Set<String> selectedSubjects;

  const OnboardingState({
    this.currentPage = 0,
    this.selectedLevel,
    this.selectedSubjects = const {},
  });

  bool get canContinueFromLevel => selectedLevel != null;
  bool get canStartLearning => selectedSubjects.isNotEmpty;

  OnboardingState copyWith({
    int? currentPage,
    String? selectedLevel,
    Set<String>? selectedSubjects,
  }) {
    return OnboardingState(
      currentPage: currentPage ?? this.currentPage,
      selectedLevel: selectedLevel ?? this.selectedLevel,
      selectedSubjects: selectedSubjects ?? this.selectedSubjects,
    );
  }
}

// ---------------------------------------------------------------------------
// ViewModel
// ---------------------------------------------------------------------------

class OnboardingViewModel extends StateNotifier<OnboardingState> {
  OnboardingViewModel() : super(const OnboardingState());

  void setPage(int page) {
    state = state.copyWith(currentPage: page);
  }

  void setLevel(String level) {
    state = state.copyWith(selectedLevel: level);
  }

  void toggleSubject(String subject) {
    final updated = Set<String>.from(state.selectedSubjects);
    if (updated.contains(subject)) {
      updated.remove(subject);
    } else {
      updated.add(subject);
    }
    state = state.copyWith(selectedSubjects: updated);
  }

  Future<void> completeOnboarding(GoRouter router) async {
    final prefs = await SharedPreferences.getInstance();
    final subjectsJson = jsonEncode(state.selectedSubjects.toList());

    await Future.wait([
      prefs.setString('onboarding_level', state.selectedLevel ?? ''),
      prefs.setString('onboarding_subjects', subjectsJson),
      prefs.setBool('onboarding_complete', true),
    ]);

    final uri = Uri(
      path: '/auth/register',
      queryParameters: {
        'level': state.selectedLevel ?? '',
        'subjects': state.selectedSubjects.toList().join(','),
      },
    );
    router.go(uri.toString());
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final onboardingViewModelProvider =
    StateNotifierProvider.autoDispose<OnboardingViewModel, OnboardingState>(
  (ref) => OnboardingViewModel(),
);
