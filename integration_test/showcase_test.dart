// Showcase walkthrough — drives the real app against the Firebase Local
// Emulator Suite so a screen recording captures a watchable ~3-minute product
// tour. Run with the emulator suite up + a device/emulator, then start a
// screen recording and launch this test. On Android:
//
//   adb shell screenrecord --time-limit 180 /sdcard/demo.mp4 &   # start recording
//   flutter test integration_test/showcase_test.dart \
//     --dart-define=USE_EMULATOR=true \
//     --dart-define=GEMINI_API_KEY=demo -d emulator-5554
//
// Signs in as the pre-seeded student (student@mentorminds.test / Student1!),
// asks MentorBot two real questions (answered by the functions emulator in
// TUTOR_AI_CLIENT_MODE=fake), then tours every feature. Because each feature is
// a full-screen route reached from the dashboard bottom-nav (no persistent nav
// bar), the tour returns to the dashboard via the back arrow between sections.
// Every step is wrapped so a missing widget never aborts the tour (keeps the
// camera rolling).

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

const _email = 'student@mentorminds.test';
const _password = 'Student1!';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await configureEmulators();
    // Make the tour deterministic and avoid a login-time ANR on a loaded
    // emulator: mark onboarding done and pre-authenticate the seeded student so
    // the splash routes straight to the student dashboard. The login form drive
    // below stays as a harmless fallback if a session isn't present.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: _email, password: _password);
    } catch (_) {
      // Fall back to driving the login form on-screen.
    }
  });

  testWidgets('MentorMinds showcase tour', (tester) async {
    // Hold on the current screen for [seconds] of real wall-clock while
    // continuously pumping frames so animations render and the recorder
    // captures motion. Deliberately does NOT use pumpAndSettle(): the dashboard
    // has looping animations that never settle, which would hang the tour.
    Future<void> hold([int seconds = 3]) async {
      final deadline = DateTime.now().add(Duration(seconds: seconds));
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 80));
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
    }

    // Tap a dashboard bottom-nav destination by its label.
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

    // Return to the dashboard from a feature screen via its back arrow.
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
    Future<void> askMentorBot(String question, [int wait = 11]) async {
      final input = find.byType(TextField);
      if (input.evaluate().isEmpty) return;
      await tester.tap(input.last);
      await hold(1);
      await tester.enterText(input.last, question);
      await hold(3); // let the typed question sit on screen
      final send = find.byIcon(Icons.arrow_upward_rounded);
      if (send.evaluate().isNotEmpty) {
        await tester.tap(send.last);
      }
      await hold(wait); // functions-emulator round-trip + markdown render
      await scrollDown(-200, 4);
    }

    // ---- Boot + splash --------------------------------------------------
    app.main();
    await hold(6);

    // ---- Sign in as seeded student -------------------------------------
    final fields = find.byType(TextFormField);
    if (fields.evaluate().length >= 2) {
      await tester.enterText(fields.at(0), _email);
      await hold(2);
      await tester.enterText(fields.at(1), _password);
      await hold(2);
      // Dismiss the soft keyboard so the Sign In button (below the fields) is
      // no longer covered — otherwise the tap lands on the keyboard and misses.
      FocusManager.instance.primaryFocus?.unfocus();
      await hold(2);
      final signIn = find.text('Sign In');
      if (signIn.evaluate().isNotEmpty) {
        await tester.ensureVisible(signIn.first);
        await hold(1);
        await tester.tap(signIn.first);
      }
    }
    await hold(9); // land on dashboard, let streams populate

    // ---- Dashboard: hero, streak, subject rings, carousels --------------
    await scrollDown(-240, 3);
    await scrollDown(-240, 3);
    await scrollDown(-240, 3);
    await hold(3);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 900));
    await hold(4);

    // ---- AI Tutor: ask a real question, watch MentorBot answer -----------
    await tapNav('AI Tutor', 4);
    await hold(5); // MentorBot welcome + suggested prompts
    await askMentorBot('Solve the quadratic 2x² + 5x − 3 = 0', 12);
    // Linger on the richly-formatted worked solution (markdown + code block).
    await hold(4);
    await scrollDown(-200, 3);
    await hold(4);
    await scrollDown(200, 3);
    await hold(3);
    await goBack(3);

    // ---- Materials: browse the curriculum library -----------------------
    await tapNav('Materials', 4);
    await hold(2);
    await scrollDown(-260, 3);
    await scrollDown(-260, 3);
    await hold(3);
    await goBack(3);

    // ---- Rewards: points, badges, leaderboard ---------------------------
    await tapNav('Rewards', 4);
    await scrollDown(-240, 3);
    await hold(2);
    for (final t in const ['Badges', 'Leaderboard']) {
      final tab = find.text(t);
      if (tab.evaluate().isNotEmpty) {
        await tester.tap(tab.first);
        await hold(3);
        await scrollDown(-220, 3);
      }
    }
    await goBack(3);

    // ---- Profile: identity, level, settings -----------------------------
    await tapNav('Profile', 4);
    await scrollDown(-220, 3);
    await hold(3);
    await goBack(3);

    // ---- Close the loop on the dashboard --------------------------------
    await hold(5);
  });
}
