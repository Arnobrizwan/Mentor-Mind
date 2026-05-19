---
phase: 02-cloud-functions-scaffolding-app-check
plan: 09
subsystem: integration_test
tags: [integration_test, ping_smoke, emulator_integration, app_check_bypass_documented, ping_response_shape_assert, latency_under_1s]
requirements_satisfied: [FUNC-02, FUNC-06]
dependency_graph:
  requires:
    - 02-06  # firebase_app_check in pubspec (compile-time consistency)
    - 02-07  # cloud_functions in pubspec; PingRepository; PingResponse model
    - 02-08  # emulator_setup.dart extended with useFunctionsEmulator
  provides:
    - integration_test/ping_smoke_test.dart
  affects:
    - CI smoke gate (when iOS simulator available)
    - Phase 3 regression canary (ping callable round-trip)
tech_stack:
  added: []
  patterns:
    - "@Tags(['emulator','integration']) library-scope tag annotation (Dart 3)"
    - "IntegrationTestWidgetsFlutterBinding.ensureInitialized() + setUpAll Firebase init"
    - "FirebaseFunctions.instance.httpsCallable().call<dynamic>() with Map cast"
    - "Stopwatch latency assertion lessThan(1000)"
key_files:
  created:
    - integration_test/ping_smoke_test.dart
  modified: []
decisions:
  - "Used direct FirebaseFunctions.instance SDK call (not PingRepository via ProviderContainer) — simpler for the plumbing-only Phase 2 gate; Phase 3 MentorBotViewModel test will exercise the repository layer"
  - "No App Check activate() in test — emulator bypasses enforcement (RESEARCH Pitfall 6 / D-13); activation deferred to Phase 3 production deploy"
  - "Relative import '../test/_helpers/emulator_setup.dart' preserved — matches Phase 1 login_smoke_test pattern; file lives under test/ not lib/ so package: import is not valid"
  - "login_smoke_test.dart left untouched (D-24 honored)"
metrics:
  duration: "< 5 minutes"
  completed_date: "2026-05-19"
  tasks_completed: 1
  files_created: 1
  files_modified: 0
---

# Phase 02 Plan 09: ping-smoke-test Summary

**One-liner:** Emulator integration test calling `httpsCallable('ping')` that asserts `{ok:true, timestamp:int, region:'asia-south1'}` + latency < 1s, tagged for dart_test.yaml tag-based CI opt-in.

## Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Write ping_smoke_test.dart + verify analyze | a2efb69 | integration_test/ping_smoke_test.dart (created) |

## Artifact: integration_test/ping_smoke_test.dart

Full content as written:

```dart
// Anchor: emulator-backed ping callable smoke test (Phase 2 / FUNC-02 / D-12).
//
// ... (header comments elided for brevity — see file)

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
```

## Static Gate Results

| Gate | Result |
|------|--------|
| File exists: `integration_test/ping_smoke_test.dart` | PASS |
| `@Tags(<String>['emulator', 'integration'])` present | PASS |
| `library;` directive present | PASS |
| `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` present | PASS |
| `configureEmulators()` called in setUpAll | PASS |
| `httpsCallable('ping')` literal present | PASS |
| `data['ok']` asserted | PASS |
| `data['timestamp']` asserted (isA<int>()) | PASS |
| `data['region']` asserted ('asia-south1') | PASS |
| `lessThan(1000)` + `Stopwatch` present | PASS |
| No `FirebaseAppCheck.instance.activate` (code) | PASS |
| No `APP_CHECK_DEBUG_TOKEN` (code) | PASS |
| Relative import `'../test/_helpers/emulator_setup.dart'` | PASS |
| `flutter analyze --no-fatal-infos` exit code | 0 — "No issues found!" |
| `integration_test/login_smoke_test.dart` unchanged (D-24) | PASS |

## Live Emulator Run

Live run deferred to local dev / first CI execution per Phase 1 precedent.

- No booted iOS simulator found during executor run (`xcrun simctl list devices booted` returned empty).
- `functions/lib/index.js` confirmed present on branch — emulator can be started locally.
- Manual local run instructions (from PLAN.md Step F):
  1. Terminal 1: `nvm use 20 && firebase emulators:start --only auth,firestore,storage,functions`
     Wait for: `functions[asia-south1-ping]: https function initialized`
  2. Terminal 2: `flutter test integration_test/ping_smoke_test.dart --dart-define=USE_EMULATOR=true -d <iOS-simulator-UDID>`
  3. Expected: `00:0X +1: All tests passed!`

iOS simulator UDID used: N/A (deferred).

## Deviations from Plan

None — plan executed exactly as written.

## Decisions Made

1. Direct `FirebaseFunctions.instance` SDK call (not `PingRepository` via `ProviderContainer`) — simpler for Phase 2 plumbing gate; Phase 3 MentorBotRepository test will exercise the repository layer.
2. No App Check activation in test — emulator bypasses enforcement per RESEARCH Pitfall 6 and CONTEXT D-13. Phase 3 production deploy is the enforcement gate.

## Known Stubs

None. The test file contains no hardcoded placeholder data — the assertions drive off the live emulator response.

## Threat Flags

None. The test file introduces no new network endpoints, auth paths, file access patterns, or schema changes beyond what the threat model in the PLAN already documents (T-2-09-PROD-CONTACT mitigated by immediate configureEmulators() call after initializeApp; T-2-09-NO-DEBUG-TOKEN-LEAK mitigated by verify gate).

## Self-Check: PASSED

- `integration_test/ping_smoke_test.dart` confirmed present on disk.
- Commit `a2efb69` confirmed in git log.
- `flutter analyze --no-fatal-infos` returned exit 0.
- `integration_test/login_smoke_test.dart` unchanged from HEAD.
