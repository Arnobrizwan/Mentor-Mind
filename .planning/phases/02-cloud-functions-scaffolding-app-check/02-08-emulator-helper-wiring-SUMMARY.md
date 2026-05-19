---
phase: 02-cloud-functions-scaffolding-app-check
plan: 08
subsystem: testing
tags: [cloud_functions, firebase_functions, emulator, useFunctionsEmulator, port_5001, integration_test]

# Dependency graph
requires:
  - phase: 02-cloud-functions-scaffolding-app-check
    plan: 04
    provides: "firebase.json with emulators.functions.port = 5001"
  - phase: 02-cloud-functions-scaffolding-app-check
    plan: 07
    provides: "cloud_functions pubspec dependency + firebaseFunctionsProvider"
  - phase: 01-foundation-refactor-ci-test-harness-ios-identity
    plan: 09
    provides: "test/_helpers/emulator_setup.dart with configureEmulators() + lib-must-not-import-test invariant"
provides:
  - "FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001) wired in both test helper and lib/main.dart"
  - "configureEmulators() extended — Plan 02-09's ping_smoke_test.dart setUpAll gets redirect for free"
  - "lib/main.dart USE_EMULATOR guard extended — flutter run --dart-define=USE_EMULATOR=true reaches Functions emulator"
affects:
  - "02-09-ping-smoke-test"
  - "02-10-ci-functions-job"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "useFunctionsEmulator called on FirebaseFunctions.instance (not instanceFor) — redirect applies at platform-channel level before region-scoped instance is first read"
    - "Intentional 1-line duplication between lib/main.dart and test/_helpers/emulator_setup.dart — lib MUST NOT import test (Phase 1 invariant D-11)"
    - "useFunctionsEmulator is synchronous (no await) — different from useAuthEmulator / useStorageEmulator"

key-files:
  created: []
  modified:
    - "test/_helpers/emulator_setup.dart"
    - "lib/main.dart"
    - "ios/Podfile.lock"

key-decisions:
  - "Call useFunctionsEmulator on FirebaseFunctions.instance (not instanceFor) — platform-channel redirect applies before any region-scoped instance reads; RESEARCH Pattern 7 + Pitfall 2"
  - "1-line duplication between lib/main.dart and test/_helpers/emulator_setup.dart accepted — lib MUST NOT import test; duplication avoids entangling production code with test-only behavior"
  - "No await on useFunctionsEmulator — synchronous call confirmed in RESEARCH Pattern 7"

patterns-established:
  - "Emulator redirect ordering: Firebase.initializeApp -> AppCheck.activate -> useFunctionsEmulator -> runApp (T-2-08-PROD-CONTACT mitigated)"
  - "lib-test separation preserved: lib/main.dart has zero test/ imports (T-2-08-LIB-IMPORTS-TEST mitigated)"

requirements-completed: [FUNC-06]

# Metrics
duration: 8min
completed: 2026-05-19
---

# Phase 02 Plan 08: Emulator Helper Wiring Summary

**FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001) wired in both configureEmulators() and lib/main.dart's USE_EMULATOR guard — Plan 02-09's ping smoke test can now reach the local Functions emulator**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-05-19T00:00:00Z
- **Completed:** 2026-05-19T00:08:00Z
- **Tasks:** 2
- **Files modified:** 3 (test/_helpers/emulator_setup.dart, lib/main.dart, ios/Podfile.lock)

## Accomplishments
- Extended `configureEmulators()` in `test/_helpers/emulator_setup.dart` with `FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001)` and `cloud_functions` import
- Extended `lib/main.dart`'s `USE_EMULATOR` if-block with matching line + `cloud_functions` import — intentional duplication (lib MUST NOT import test)
- Preserved all Phase 1 emulator wiring (Firestore/Auth/Storage at 8080/9099/9199)
- Ordering invariant verified: `Firebase.initializeApp` (L29) → `AppCheck.activate` (L43) → `useFunctionsEmulator` (L62) → `runApp` (L65)
- All acceptance gates passed: flutter analyze (0 errors/warnings), dart run custom_lint (no issues), no test imports in lib/main.dart

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend test/_helpers/emulator_setup.dart** - `6aedd31` (feat)
2. **Task 2: Extend lib/main.dart USE_EMULATOR block** - `cfc0bcb` (feat)

**Plan metadata:** (see below)

## Files Created/Modified
- `test/_helpers/emulator_setup.dart` — Added `cloud_functions` import (alphabetical) + `FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001)` line in `configureEmulators()` body; banner comment updated with `functions: localhost:5001`
- `lib/main.dart` — Added `cloud_functions` import (alphabetical between `cloud_firestore` and `firebase_app_check`) + `FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001)` after Storage emulator line; no test/ imports (invariant preserved)
- `ios/Podfile.lock` — Updated with `cloud_functions (5.6.2)` CocoaPod resolved alongside `firebase_app_check`

## Full Diffs

### test/_helpers/emulator_setup.dart
```diff
+import 'package:cloud_functions/cloud_functions.dart';
 import 'package:firebase_auth/firebase_auth.dart';
...
-// Ports must match firebase.json emulators block:
-//   auth:      localhost:9099
-//   firestore: localhost:8080
-//   storage:   localhost:9199
+// Ports must match firebase.json emulators block:
+//   auth:      localhost:9099
+//   firestore: localhost:8080
+//   storage:   localhost:9199
+//   functions: localhost:5001
...
   await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
+  FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
 }
```

### lib/main.dart
```diff
 import 'package:cloud_firestore/cloud_firestore.dart';
+import 'package:cloud_functions/cloud_functions.dart';
 import 'package:firebase_app_check/firebase_app_check.dart';
...
     await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
+    FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
   }
```

## Ordering Invariant (awk gate output)
```
init=29 activate=43 useFunctionsEmulator=62 runApp=65 OK
```

## Decisions Made
- Used `FirebaseFunctions.instance` (not `instanceFor(region:'asia-south1')`) for the emulator redirect — the platform-channel redirect applies globally before any region-scoped instance is read; RESEARCH Pattern 7 + Pitfall 2
- Accepted intentional duplication of 1 line between `lib/main.dart` and `test/_helpers/emulator_setup.dart` — Phase 1 invariant forbids lib from importing test; a shared helper under `lib/core/` would entangle production code with test-only behavior

## Deviations from Plan

None - both files were pre-wired by a prior session; only committed Task 2 (lib/main.dart + Podfile.lock were unstaged). Task 1 commit `6aedd31` was already present. All plan instructions executed exactly as specified.

## Verification Results

| Gate | Result |
|------|--------|
| `useFunctionsEmulator` in emulator_setup.dart | PASS |
| `useFunctionsEmulator` in lib/main.dart | PASS |
| `cloud_functions` import in emulator_setup.dart | PASS |
| `cloud_functions` import in lib/main.dart | PASS |
| No await on useFunctionsEmulator (both files) | PASS |
| No test/ imports in lib/main.dart | PASS |
| Ordering invariant (initializeApp < activate < ue < runApp) | PASS |
| `flutter analyze --no-fatal-infos` exit 0 (0 errors, 0 warnings) | PASS |
| `dart run custom_lint` — 0 layered_imports violations | PASS |

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Both emulator files wired at port 5001 — Plan 02-09's `ping_smoke_test.dart` can call `configureEmulators()` in `setUpAll` and invoke `httpsCallable('ping')` against the local emulator
- `flutter run --dart-define=USE_EMULATOR=true` now routes Functions calls to `localhost:5001`
- Phase 1 login_smoke_test continues to work (Firestore/Auth/Storage wiring preserved)

---
*Phase: 02-cloud-functions-scaffolding-app-check*
*Completed: 2026-05-19*
