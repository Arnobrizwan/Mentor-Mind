// Showcase walkthrough — drives the real app against the Firebase Local
// Emulator Suite so a screen recording captures a watchable per-role product
// tour. One run tours ONE role, selected via --dart-define=ROLE=<role>, so the
// four role segments can be recorded separately and concatenated into a single
// ~3-minute all-roles showcase.
//
//   ROLE ∈ { student | premium | teacher | admin }
//
//   adb shell screenrecord --time-limit 179 /sdcard/demo.mp4 &   # start recording
//   flutter test integration_test/showcase_test.dart \
//     --dart-define=USE_EMULATOR=true --dart-define=GEMINI_API_KEY=demo \
//     --dart-define=ROLE=teacher -d emulator-5554
//
// setUpAll pre-authenticates the matching seeded account so the splash routes
// straight to that role's home (avoids a login-time ANR on a loaded emulator).
// Every step is wrapped so a missing widget never aborts the tour.

@Tags(<String>['emulator', 'integration'])
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mentor_minds/firebase_options.dart';
import 'package:mentor_minds/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

import '../test/_helpers/emulator_setup.dart';

const _role = String.fromEnvironment('ROLE', defaultValue: 'student');

// Seeded credentials (tool/seed/seed.js).
const _accounts = <String, List<String>>{
  'student': ['student@mentorminds.test', 'Student1!'],
  'premium': ['premium@mentorminds.test', 'Premium1!'],
  'teacher': ['teacher@mentorminds.test', 'Teacher1!'],
  'admin': ['admin@mentorminds.test', 'Admin1!'],
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await configureEmulators();
    final creds = _accounts[_role] ?? _accounts['student']!;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: creds[0], password: creds[1]);
    } catch (_) {
      // Falls through — the tour degrades gracefully if sign-in fails.
    }
  });

  testWidgets('MentorMinds showcase tour ($_role)', (tester) async {
    // Hold on the current screen for [seconds] of real wall-clock while
    // pumping frames so animations render (never pumpAndSettle: the dashboard
    // has looping animations that would hang the tour).
    Future<void> hold([int seconds = 3]) async {
      final deadline = DateTime.now().add(Duration(seconds: seconds));
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 80));
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
    }

    // Tap a bottom-nav destination by its label.
    Future<void> tapNav(String label, [int settle = 4]) async {
      final dest = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      );
      final target = dest.evaluate().isNotEmpty ? dest : find.text(label);
      if (target.evaluate().isNotEmpty) {
        await tester.tap(target.first);
        await hold(settle);
      }
    }

    // Tap any visible text label (used for in-screen tabs like Badges).
    Future<void> tapText(String label, [int settle = 3]) async {
      final f = find.text(label);
      if (f.evaluate().isNotEmpty) {
        await tester.tap(f.first);
        await hold(settle);
      }
    }

    // Return to the previous screen via the app-bar back arrow.
    Future<void> goBack([int settle = 3]) async {
      final back = find.byIcon(Icons.arrow_back_rounded);
      if (back.evaluate().isNotEmpty) {
        await tester.tap(back.first);
        await hold(settle);
      }
    }

    Future<void> scrollDown([double dy = -320, int settle = 2]) async {
      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable.first, Offset(0, dy));
        await hold(settle);
      }
    }

    // Ask MentorBot a question and dwell while the answer renders.
    Future<void> askMentorBot(String question, [int wait = 12]) async {
      final input = find.byType(TextField);
      if (input.evaluate().isEmpty) return;
      await tester.tap(input.last);
      await hold(1);
      await tester.enterText(input.last, question);
      await hold(3);
      final send = find.byIcon(Icons.arrow_upward_rounded);
      if (send.evaluate().isNotEmpty) {
        await tester.tap(send.last);
      }
      await hold(wait); // functions-emulator round-trip + markdown render
      await scrollDown(-200, 4);
    }

    // ---- Boot: splash routes to the role's home ------------------------
    app.main();
    await hold(9); // generous settle so heavy role screens finish first paint

    if (_role == 'teacher') {
      // Teacher home: approval status, subject materials, recent uploads.
      await scrollDown(-220, 3);
      await scrollDown(-220, 3);
      await hold(2);
      await tapNav('Library', 4); // materials in their subjects
      await scrollDown(-260, 3);
      await hold(2);
      await goBack(3);
      await tapNav('Inbox', 4);
      await hold(3);
      await scrollDown(-200, 3);
      await goBack(3);
      await tapNav('Profile', 4);
      await scrollDown(-200, 3);
      await hold(3);
      await goBack(3);
    } else if (_role == 'admin') {
      // Admin console — heavy first paint (users + 14d analytics); let it fully
      // settle before touring the tabs (IndexedStack, no back navigation).
      await hold(12);
      for (final tab in const [
        'Dashboard',
        'Users',
        'Content',
        'Notifications',
        'Analytics',
        'Config',
      ]) {
        await tapNav(tab, 5);
        await scrollDown(-200, 2);
        await hold(2);
      }
    } else if (_role == 'premium') {
      // Premium student (Parvez, A-Level) — richer dashboard, unlimited AI.
      // (The working AI answer is demonstrated in the student segment; here we
      // showcase the premium account's distinct dashboard, tutor access and
      // profile without re-sending a question.)
      await scrollDown(-240, 3);
      await scrollDown(-240, 3);
      await hold(2);
      await tapNav('AI Tutor', 4);
      await hold(4); // premium tutor: no daily-limit banner, image attach
      await goBack(3);
      await tapNav('Rewards', 4);
      await scrollDown(-220, 3);
      await goBack(3);
      await tapNav('Profile', 4);
      await scrollDown(-200, 3);
      await hold(3);
      await goBack(3);
    } else {
      // Student (default): dashboard → AI answer → materials → rewards → profile.
      await scrollDown(-240, 3);
      await scrollDown(-240, 3);
      await hold(2);
      await tapNav('AI Tutor', 4);
      await hold(4);
      await askMentorBot('Solve the quadratic 2x² + 5x − 3 = 0', 12);
      await hold(3);
      await scrollDown(-200, 3);
      await hold(3);
      await goBack(3);
      await tapNav('Materials', 4);
      await scrollDown(-260, 3);
      await hold(2);
      await goBack(3);
      await tapNav('Rewards', 4);
      await scrollDown(-220, 2);
      await tapText('Badges', 3);
      await tapText('Leaderboard', 3);
      await goBack(3);
      await tapNav('Profile', 4);
      await scrollDown(-200, 3);
      await hold(2);
      await goBack(3);
      await hold(3);
    }
  });
}
