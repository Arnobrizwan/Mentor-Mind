// Anchor 2 — OnboardingViewModel unit test.
// Exercises: mocktail (dep import proves resolution) + SharedPreferences mock.
// No Firebase, no network calls.

// ignore: unused_import
import 'package:mocktail/mocktail.dart'; // import proves mocktail dep resolves (CI-07)
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mentor_minds/application/viewmodels/onboarding/onboarding_viewmodel.dart';

@Tags(['unit'])

void main() {
  group('OnboardingViewModel', () {
    setUp(() {
      // Wire the SharedPreferences plugin to return an empty in-memory store.
      // Required because OnboardingViewModel.completeOnboarding calls
      // SharedPreferences.getInstance() internally.
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state has no level selected', () {
      final vm = OnboardingViewModel();
      expect(vm.state.selectedLevel, isNull);
      expect(vm.state.selectedSubjects, isEmpty);
    });

    test('setLevel updates selectedLevel in state', () {
      final vm = OnboardingViewModel();
      vm.setLevel('O Level');
      expect(vm.state.selectedLevel, 'O Level');
    });

    test('toggleSubject adds subject when not selected', () {
      final vm = OnboardingViewModel();
      vm.toggleSubject('Mathematics');
      expect(vm.state.selectedSubjects, contains('Mathematics'));
    });

    test('toggleSubject removes subject when already selected', () {
      final vm = OnboardingViewModel();
      vm.toggleSubject('Mathematics');
      vm.toggleSubject('Mathematics');
      expect(vm.state.selectedSubjects, isNot(contains('Mathematics')));
    });
  });
}
