// Anchor 5: emulator-backed sign-in smoke test (Phase 1 / CI-06 / D-09).
//
// Boots the real app against the Firebase Local Emulator Suite, signs in as
// a pre-seeded student, asserts the dashboard is reached. The boot path is
// `lib/main.dart`'s production main() — gated by --dart-define=USE_EMULATOR=true
// which both this test and lib/main.dart honor.
//
// Required runtime context:
//   1. `firebase emulators:start --only auth,firestore,storage` running on the
//      host machine (ports 9099 / 8080 / 9199 per firebase.json).
//   2. `--dart-define=USE_EMULATOR=true` on the flutter test invocation:
//        flutter test integration_test/login_smoke_test.dart \
//          --dart-define=USE_EMULATOR=true -d <device-id>
//
// Without the emulator running, the test fails at setUpAll with a connect
// timeout — preferable to silently hitting production.
//
// Tagged `emulator` + `integration` so CI can opt in/out via dart_test.yaml.

@Tags(<String>['emulator', 'integration'])
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mentor_minds/firebase_options.dart';
import 'package:mentor_minds/main.dart' as app;

import '../test/_helpers/emulator_setup.dart';

const _smokeEmail = 'smoke@example.com';
const _smokePassword = 'smoke-password';
const _smokeFirstName = 'Smoke';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Initialize Firebase ONCE for the test process, then immediately redirect
    // every Auth/Firestore/Storage call to localhost via use*Emulator (inside
    // configureEmulators). The production project is contacted exactly once
    // for bootstrap config — no user data ever crosses.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await configureEmulators();

    // Idempotent pre-seed: create the test user if not already present, then
    // write the matching /users/{uid} doc so the dashboard's role-routing
    // (student/teacher/admin) finds a valid profile.
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _smokeEmail,
        password: _smokePassword,
      );
    } catch (_) {
      // Test user already exists from an earlier emulator run with --import.
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'role': 'student',
        'name': '$_smokeFirstName Tester',
        'email': _smokeEmail,
        'level': 'O Level',
        'subjects': <String>['Math'],
        'points': 0,
        'badges': const <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // Start each test run from signed-out state so the LoginScreen renders.
    await FirebaseAuth.instance.signOut();
  });

  testWidgets(
    'sign-in smoke — emulator → dashboard',
    (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Email field (TextFormField #0 in LoginScreen), then password (#1),
      // then the 'Sign In' primary CTA — labels verified in lib/presentation/
      // screens/auth/login_screen.dart.
      await tester.enterText(
        find.byType(TextFormField).at(0),
        _smokeEmail,
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        _smokePassword,
      );
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // DashboardScreen greeting is "<time>, <firstName>! 👋" — match the
      // first-name substring so we don't depend on local time-of-day.
      expect(
        find.textContaining(_smokeFirstName),
        findsWidgets,
        reason: 'Expected dashboard greeting containing the test user first name',
      );
    },
  );
}
