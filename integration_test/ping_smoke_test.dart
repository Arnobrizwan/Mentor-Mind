// Anchor: emulator-backed ping callable smoke test (Phase 2 / FUNC-02 / D-12).
//
// Calls the `ping` callable through the Firebase Functions emulator and asserts
// the response shape { ok: true, timestamp: <int>, region: 'asia-south1' }
// plus emulator latency < 1 second.
//
// Required runtime context:
//   1. `firebase emulators:start --only auth,firestore,storage,functions` running
//      on the host machine (functions port 5001 per firebase.json).
//   2. `--dart-define=USE_EMULATOR=true` on the flutter test invocation:
//        flutter test integration_test/ping_smoke_test.dart \
//          --dart-define=USE_EMULATOR=true -d <device-id>
//
// WITHOUT the emulator running, the test fails at setUpAll with a connection
// error — preferable to silently hitting production.
//
// App Check note (RESEARCH Pitfall 6 / CONTEXT D-13):
//   The Functions emulator BYPASSES App Check enforcement. This test does NOT
//   register a debug token, does NOT consume APP_CHECK_DEBUG_TOKEN, and does NOT
//   call FirebaseAppCheck.instance.activate. Phase 2 verifies plumbing only
//   (callable round-trip). Phase 3's production deploy is when enforceAppCheck:true
//   actually gates real callers.
//
// Unauthenticated by design:
//   App Check verifies the *device*, not the *user*. No user seeding needed
//   (contrast with login_smoke_test.dart which seeds a student user — D-11).
//
// Tagged `emulator` + `integration` so CI can opt in/out via dart_test.yaml.

@Tags(<String>['emulator', 'integration'])
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mentor_minds/firebase_options.dart';

import '../test/_helpers/emulator_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Initialize Firebase ONCE for the test process, then immediately redirect
    // every SDK call to localhost via useFunctionsEmulator (inside
    // configureEmulators). The production project is contacted exactly once
    // for bootstrap config — no user data ever crosses.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await configureEmulators();
    // Ping is unauthenticated by design (App Check verifies the *device*,
    // not the *user*). No App Check activate() — the Functions emulator
    // bypasses App Check enforcement (RESEARCH Pitfall 6); enforceAppCheck:true
    // on the server is exercised by Phase 3's production deploy, not here.
  });

  testWidgets(
    'ping smoke — emulator round trip',
    (tester) async {
      final stopwatch = Stopwatch()..start();
      final result = await FirebaseFunctions.instance
          .httpsCallable('ping')
          .call<dynamic>();
      stopwatch.stop();

      // The callable returns Map<Object?, Object?> at runtime, not
      // Map<String, dynamic> — the cast is required (RESEARCH Pattern 8).
      final data =
          (result.data as Map<Object?, Object?>).cast<String, dynamic>();

      expect(data['ok'], isTrue);
      expect(data['timestamp'], isA<int>());
      expect(data['region'], equals('asia-south1'));
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason:
            'Emulator latency < 1s is the canary — Phase 3 production target is < 10s',
      );
    },
    tags: ['emulator', 'integration'],
  );
}
