---
phase: 02-cloud-functions-scaffolding-app-check
plan: "06"
subsystem: infra
tags: [firebase_app_check, app_attest, device_check, ios_security, kReleaseMode, FUNC-03]

# Dependency graph
requires:
  - phase: 02-cloud-functions-scaffolding-app-check
    plan: "03"
    provides: "Cloud Functions with enforceAppCheck:true server-side enforcement (PR-1)"
provides:
  - "firebase_app_check ^0.3.2+9 dependency (resolved 0.3.2+10) in pubspec.yaml"
  - "FirebaseAppCheck.instance.activate() in lib/main.dart — kReleaseMode ? AppleProvider.appAttestWithDeviceCheckFallback : AppleProvider.debug"
  - "Client-side App Check token emission for all callables with enforceAppCheck:true"
affects:
  - "02-07 (cloud_functions wiring — calls callables that now require App Check tokens)"
  - "02-08 (useFunctionsEmulator block — placed AFTER the activate() call)"
  - "02-09 (ping_smoke_test — emulator bypasses App Check per RESEARCH Pitfall 6; test unaffected)"
  - "Phase 3 (production deploy — first end-to-end DeviceCheck token validation)"

# Tech tracking
tech-stack:
  added:
    - "firebase_app_check 0.3.2+10 (Flutter SDK plugin wrapping Firebase App Check)"
  patterns:
    - "kReleaseMode ternary for provider selection: release uses DeviceCheck-backed attestation, debug uses UUID debug token"
    - "Activation ordering: Firebase.initializeApp → FirebaseAppCheck.activate → USE_EMULATOR block → runApp"

key-files:
  created: []
  modified:
    - "pubspec.yaml — added firebase_app_check: ^0.3.2+9 in Firebase deps block"
    - "lib/main.dart — added 2 imports + 13-line activate block with appAttestWithDeviceCheckFallback/debug provider"

key-decisions:
  - "D-02 AMENDED 2026-05-19: Used AppleProvider.appAttestWithDeviceCheckFallback (NOT bare appAttest) because Apple Developer account is FREE — DeviceCheck fallback works without paid enrollment; App Attest capability + appattest.environment entitlement require paid tier"
  - "Runner.entitlements NOT modified — DeviceCheck does not consult the appattest.environment key; entitlement change was dropped by D-02 amendment"
  - "Xcode App Attest capability NOT added — DeviceCheck is built into iOS and needs no explicit capability opt-in"
  - "Pinned firebase_app_check to ^0.3.x (not ^0.4.x) to maintain firebase_core ^3.x lockstep (RESEARCH Pitfall 3)"

patterns-established:
  - "kReleaseMode ternary pattern for build-mode provider selection — follows T-2-DEBUG-IN-PROD threat mitigation"
  - "Activation site: immediately after Firebase init try/catch, before any emulator setup or runApp"

requirements-completed: [FUNC-03]

# Metrics
duration: 9min
completed: 2026-05-19
---

# Phase 2 Plan 06: App Check Client Activation Summary

**Firebase App Check activated on iOS with `AppleProvider.appAttestWithDeviceCheckFallback` (release) / `AppleProvider.debug` (debug) — completing the client-side half of the `enforceAppCheck:true` round-trip shipped in Plan 02-03**

## Performance

- **Duration:** 9 min
- **Started:** 2026-05-19T01:30:31Z
- **Completed:** 2026-05-19T01:39:16Z
- **Tasks:** 2
- **Files modified:** 2 (pubspec.yaml, lib/main.dart) + pubspec.lock

## Accomplishments

- Added `firebase_app_check: ^0.3.2+9` to pubspec.yaml; resolved to `0.3.2+10` without version-solver conflicts against `firebase_core 3.15.2`
- Inserted `FirebaseAppCheck.instance.activate(appleProvider: kReleaseMode ? AppleProvider.appAttestWithDeviceCheckFallback : AppleProvider.debug)` in `lib/main.dart` at the correct position (after Firebase init, before emulator setup and runApp)
- Mitigated T-2-APPCHECK-BYPASS (client now emits tokens) and T-2-DEBUG-IN-PROD (kReleaseMode gates the debug provider to non-release builds)
- `flutter analyze --no-fatal-infos` exits 0; `flutter build ios --no-codesign` exits 0 (59.3 MB Runner.app)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add firebase_app_check to pubspec.yaml + run flutter pub get** - `6a72ea2` (feat)
2. **Task 2: Add FirebaseAppCheck.instance.activate(...) to lib/main.dart** - `23bbee8` (feat)

**Plan metadata:** (next commit — docs)

## Files Created/Modified

- `/Users/arnobrizwan/Mentor-Mind/pubspec.yaml` — Added `firebase_app_check: ^0.3.2+9` after `google_sign_in: ^6.2.1` in Firebase deps block
- `/Users/arnobrizwan/Mentor-Mind/pubspec.lock` — Updated to record `firebase_app_check: "0.3.2+10"` (+ platform interface and web variants)
- `/Users/arnobrizwan/Mentor-Mind/lib/main.dart` — Added 2 imports + 13-line activate block

## Diff Summary

### pubspec.yaml (one line added)
```
+  firebase_app_check: ^0.3.2+9
```
Inserted after `google_sign_in: ^6.2.1`.

### lib/main.dart (2 import lines + 13-line activate block)

Import additions:
```dart
+import 'package:firebase_app_check/firebase_app_check.dart';
 import 'package:firebase_auth/firebase_auth.dart';
...
 import 'package:firebase_storage/firebase_storage.dart';
+import 'package:flutter/foundation.dart';
```

Activate block inserted between Firebase init try/catch and USE_EMULATOR block:
```dart
  // App Check — emits a token per-call for any callable with enforceAppCheck.
  // Release builds use App Attest where available (iOS 14+ Secure Enclave),
  // silently falling back to DeviceCheck on devices/accounts where App Attest
  // is not provisioned. Debug builds use the Debug provider — auto-generates
  // a UUID token that must be registered in Firebase Console (BACKEND_SETUP §6).
  // The Functions emulator bypasses App Check validation (RESEARCH Pitfall 6).
  // Provider choice locked by free-Apple-Developer-account decision; see CONTEXT D-02.
  await FirebaseAppCheck.instance.activate(
    appleProvider: kReleaseMode
        ? AppleProvider.appAttestWithDeviceCheckFallback
        : AppleProvider.debug,
  );
```

## flutter pub get Output (Task 1)
```
+ firebase_app_check 0.3.2+10 (0.4.4+1 available)
+ firebase_app_check_platform_interface 0.1.1+10 (0.4.0+1 available)
+ firebase_app_check_web 0.2.0+14 (0.2.4+2 available)
Changed 3 dependencies!
```
No version-solver conflicts. `firebase_core` remains at `3.15.2`.

## flutter analyze --no-fatal-infos
Exit code: **0**
151 info-level issues (all pre-existing `withOpacity`/`prefer_const_constructors` warnings from Phase 1 — none introduced by this plan). No errors or warnings from this plan's changes.

## flutter build ios --no-codesign
Exit code: **0**
```
Running pod install...                                             25.6s
Running Xcode build...
Xcode build done.                                           441.0s
Built build/ios/iphoneos/Runner.app (59.3MB)
```

## ios/Runner/Runner.entitlements — UNCHANGED

`git diff HEAD -- ios/Runner/Runner.entitlements` returns empty.

**Note:** D-02 amendment (2026-05-19) dropped the originally planned `com.apple.developer.devicecheck.appattest.environment = production` entitlement. The chosen provider (`AppleProvider.appAttestWithDeviceCheckFallback`) uses DeviceCheck as its fallback, which does NOT consult the `appattest.environment` key. The entitlement is only required for the pure `AppleProvider.appAttest` provider, which needs a paid Apple Developer account (App Attest is gated to paid enrollment). DeviceCheck is available on all accounts.

## Xcode App Attest Capability — NOT Added

DeviceCheck capability is built into iOS and requires no explicit Xcode capability opt-in. If paid Apple Developer enrollment lands later (Phase 6+), revisit to upgrade to pure `AppleProvider.appAttest` + the App Attest capability + `com.apple.developer.devicecheck.appattest.environment` entitlement.

## Decisions Made

1. **Used `appAttestWithDeviceCheckFallback` (not bare `appAttest`)** — Apple Developer account is free; App Attest requires paid enrollment. DeviceCheck (the fallback) works on free accounts and is built into iOS 11+. The `appAttestWithDeviceCheckFallback` provider silently uses DeviceCheck when App Attest is unavailable, preserving `enforceAppCheck:true` semantics without the paid-tier gate. (CONTEXT D-02 amendment, 2026-05-19)

2. **Pinned to `^0.3.2+9` (not `^0.4.x`)** — `firebase_app_check ^0.4.x` would require `firebase_core ^4.x`, which is incompatible with the existing `firebase_core 3.15.2` lockstep across all Firebase packages. (RESEARCH Pitfall 3)

3. **kReleaseMode ternary** — Ensures the Debug provider is never shipped in release builds. `kReleaseMode` is a `const bool` from `package:flutter/foundation.dart` evaluated at compile time; the debug branch is tree-shaken in release builds.

## Deviations from Plan

None — plan executed exactly as written. The D-02 amendment was already incorporated into the plan before execution; no mid-execution course corrections were needed.

## Threat Surface Scan

No new surface introduced beyond what the plan's threat model documents. The activate() call is initialization-time plumbing with no network endpoints, auth paths, or schema changes. The existing T-2-APPCHECK-BYPASS and T-2-DEBUG-IN-PROD threats are now mitigated.

## Known Stubs

None — this plan is pure initialization wiring. No UI, no data flows, no placeholder values.

## Issues Encountered

None.

## User Setup Required

**Debug token registration is required before using the Debug provider in a simulator/device.** When running a debug build, the Firebase App Check SDK prints a UUID to the Xcode console:

```
[Firebase/AppCheck][I-FAA001001] Firebase App Check debug token: <UUID>
```

Register this UUID in Firebase Console → App Check → Apps → MentorMinds → Debug tokens. See `BACKEND_SETUP.md §6` (Plan 02-05) for the full procedure. This is a one-time step per development machine.

## Next Phase Readiness

- Plan 02-07 (cloud_functions wiring) can now safely add `cloud_functions` to pubspec.yaml and create `FirebaseFunctionsProvider`; the App Check token emission hook is in place
- Plan 02-08 (useFunctionsEmulator) inserts its code AFTER the activate() block — ordering is already correct
- Plan 02-09 (ping smoke test) runs against the emulator, which bypasses App Check validation per RESEARCH Pitfall 6 — no token registration needed for CI
- Production deploy in Phase 3 will exercise the full DeviceCheck attestation round-trip end-to-end

---
*Phase: 02-cloud-functions-scaffolding-app-check*
*Completed: 2026-05-19*
