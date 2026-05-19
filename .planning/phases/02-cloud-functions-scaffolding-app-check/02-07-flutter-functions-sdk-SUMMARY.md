---
phase: 02-cloud-functions-scaffolding-app-check
plan: "07"
subsystem: infra
tags: [cloud_functions, firebase_functions, ping_repository, ping_response, riverpod_provider, asia_south1, layered_imports, repository_pattern, safe_cast]

requires:
  - phase: 01-foundation-refactor-ci-test-harness-ios-identity
    provides: "lib/data/services/firebase_providers.dart pattern; lib/data/repositories/users_repository.dart pattern; layered_imports custom_lint rule (D-04, D-01, D-08)"
  - phase: 02-cloud-functions-scaffolding-app-check plan 06
    provides: "firebase_app_check ^0.3.2+9 in pubspec.yaml — preceding Firebase dep block entry for insertion point"
provides:
  - "cloud_functions: ^5.6.2 (locked to 5.x; NOT 6.x) in pubspec.yaml + pubspec.lock"
  - "firebaseFunctionsProvider — Provider<FirebaseFunctions> pinned to region 'asia-south1'"
  - "PingResponse — typed domain model {ok, timestamp, region} with safe-cast fromMap factory"
  - "PingRepository — wraps httpsCallable('ping').call(), returns PingResponse, never raw HttpsCallableResult"
  - "pingRepositoryProvider — Provider<PingRepository> at bottom of ping_repository.dart"
affects:
  - "02-08 (emulator wiring — calls useFunctionsEmulator on FirebaseFunctions.instance)"
  - "02-09 (ping smoke test — instantiates PingRepository via pingRepositoryProvider)"
  - "Phase 3 MentorBotRepository — follows same Provider + Repository + Model shape established here"

tech-stack:
  added:
    - "cloud_functions: ^5.6.2 (resolved 5.6.2)"
  patterns:
    - "SDK singleton exposed as Provider<T> — firebaseFunctionsProvider mirrors firebase_providers.dart"
    - "Named required constructor param: PingRepository({required FirebaseFunctions functions})"
    - "Non-obvious Map<Object?, Object?>.cast<String, dynamic>() for HttpsCallableResult.data"
    - "Safe-cast fromMap: (map['key'] as T?) ?? default — never bare as T"
    - "num? → .toInt() for integer fields that may arrive as double on wire"
    - "ref.read (not .watch) for SDK instance providers in Repository providers"
    - "No autoDispose on SDK singleton or stateless repository providers"

key-files:
  created:
    - lib/data/services/firebase_functions_provider.dart
    - lib/data/models/ping_response.dart
    - lib/data/repositories/ping_repository.dart
  modified:
    - pubspec.yaml (added cloud_functions: ^5.6.2)
    - pubspec.lock (resolved cloud_functions 5.6.2)

key-decisions:
  - "cloud_functions pinned to ^5.6.2 (NOT ^6.x) — ^6 would force firebase_core ^4.x, breaking lockstep with all other Firebase deps (RESEARCH Pitfall 3)"
  - "firebaseFunctionsProvider uses FirebaseFunctions.instanceFor(region: 'asia-south1') — region-scoped instance distinct from FirebaseFunctions.instance; matches Plan 02-03's server-side region pin"
  - "HttpsCallableResult.data cast via (result.data as Map<Object?, Object?>).cast<String, dynamic>() — simplifying to as Map<String, dynamic> fails at runtime (RESEARCH Pattern 8)"
  - "PingRepository returns Future<PingResponse>, never raw HttpsCallableResult — enforces Phase 1 D-02 (repositories return domain models)"
  - "pingRepositoryProvider reads firebaseFunctionsProvider (not watches) — SDK instances are stable for app lifetime"

patterns-established:
  - "callable-repository shape: class XxxRepository({required FirebaseFunctions functions}) with typed return + Map<Object?, Object?> cast + Provider<XxxRepository> at file bottom"
  - "region-pinned Functions provider: instanceFor(region: ...) separate from default .instance used for emulator wiring"
  - "safe-cast fromMap: (map['key'] as T?) ?? default for all primitive fields in callable response models"

requirements-completed: [FUNC-06]

duration: 4min
completed: 2026-05-19
---

# Phase 2 Plan 07: Flutter Functions SDK Summary

**cloud_functions 5.6.2 wired through firebaseFunctionsProvider (asia-south1) + PingRepository returning typed PingResponse via safe Map<Object?,Object?> cast**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-05-19T09:42:54+08:00
- **Completed:** 2026-05-19T09:46:36+08:00
- **Tasks:** 4
- **Files modified:** 5 (pubspec.yaml, pubspec.lock, + 3 new Dart files)

## Accomplishments

- Added `cloud_functions: ^5.6.2` to pubspec.yaml (resolves to exactly 5.6.2 in lockfile); no firebase_core version conflict
- Created `firebaseFunctionsProvider` using `FirebaseFunctions.instanceFor(region: 'asia-south1')` — region-scoped, matching Plan 02-03's server-side callable region
- Created `PingResponse` domain model with all three fields safe-cast (`as bool? ?? false`, `as num? ?? 0 .toInt()`, `as String? ?? ''`)
- Created `PingRepository` with the non-obvious `Map<Object?, Object?>.cast<String, dynamic>()` cast documented inline; `pingRepositoryProvider` at bottom reads `firebaseFunctionsProvider` via `ref.read`
- `dart run custom_lint` exits 0 — no `layered_imports` violations (`cloud_functions` confined to `lib/data/` only)
- `flutter analyze --no-fatal-infos` exits 0 across the tree (151 info-level pre-existing warnings, 0 errors/warnings)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add cloud_functions to pubspec.yaml + pub get** — `247f6fb` (feat)
2. **Task 2: Create firebase_functions_provider.dart** — `8a2b57d` (feat)
3. **Task 3: Create ping_response.dart** — `5885e84` (feat)
4. **Task 4: Create ping_repository.dart** — `2ebf320` (feat)

**Plan metadata:** see docs commit below

## Files Created/Modified

- `pubspec.yaml` — added `cloud_functions: ^5.6.2` after `firebase_app_check: ^0.3.2+9`
- `pubspec.lock` — locked `cloud_functions` at `5.6.2`
- `lib/data/services/firebase_functions_provider.dart` — `Provider<FirebaseFunctions>` via `instanceFor(region: 'asia-south1')` with banner comment explaining test override seam, region pin, and emulator dual-instance interaction
- `lib/data/models/ping_response.dart` — `class PingResponse` with `bool ok`, `int timestamp`, `String region`; `factory PingResponse.fromMap` with safe-cast for all three fields
- `lib/data/repositories/ping_repository.dart` — `class PingRepository` with `Future<PingResponse> ping()` calling `httpsCallable('ping').call<dynamic>()`, non-obvious `Map<Object?,Object?>` cast, and `pingRepositoryProvider` at bottom

## pubspec.yaml diff (one added line)

```yaml
  firebase_app_check: ^0.3.2+9
  cloud_functions: ^5.6.2     # <-- added by this plan
```

pubspec.lock entry:
```yaml
  cloud_functions:
    dependency: "direct main"
    description:
      name: cloud_functions
      url: "https://pub.dev"
    version: "5.6.2"
```

## Verification Results

| Check | Result |
|-------|--------|
| `cloud_functions: ^5.x` in pubspec.yaml | PASS |
| No `^6.x` or higher in pubspec.yaml | PASS |
| `flutter pub get` exits 0, no solver conflicts | PASS |
| pubspec.lock records `cloud_functions` at 5.6.2 | PASS |
| `firebase_functions_provider.dart` exists | PASS |
| Contains `instanceFor(region: 'asia-south1')` | PASS |
| `firebaseFunctionsProvider` declared as `Provider<FirebaseFunctions>` | PASS |
| Imports `cloud_functions` + `flutter_riverpod` only | PASS |
| `ping_response.dart` exists | PASS |
| `factory PingResponse.fromMap` present | PASS |
| `(map['timestamp'] as num?)?.toInt()` safe-cast | PASS |
| `(map['ok'] as bool?)` safe-cast | PASS |
| `ping_repository.dart` exists | PASS |
| `httpsCallable('ping')` call present | PASS |
| `Future<PingResponse> ping()` return type | PASS |
| `Map<Object?, Object?>).cast<String, dynamic>()` non-obvious cast | PASS |
| `PingResponse.fromMap(data)` decode | PASS |
| `pingRepositoryProvider` with `ref.read(firebaseFunctionsProvider)` | PASS |
| Package-style imports for both internal files | PASS |
| `flutter analyze --no-fatal-infos` exits 0 (0 errors, 0 warnings) | PASS |
| `dart run custom_lint` exits 0, 0 `layered_imports` violations | PASS |

## Decisions Made

- `cloud_functions ^5.6.2` (not `^6.x`): `^6.x` requires `firebase_core ^4.x`, which conflicts with all existing Firebase deps pinned to `^3.x`. RESEARCH Pitfall 3 documents this constraint explicitly.
- `instanceFor(region: 'asia-south1')` vs `FirebaseFunctions.instance`: The region-scoped instance is a distinct object. Plan 02-08's `useFunctionsEmulator` call targets `FirebaseFunctions.instance` (the default) in `lib/main.dart`; the emulator redirect applies to all instances created before the ProviderScope reads the region-scoped one, so the dual-instance interaction is safe.
- `ref.read` (not `ref.watch`) in `pingRepositoryProvider`: SDK instances are stable for the app lifetime; watching would be wasteful and semantically wrong.

## Deviations from Plan

None - plan executed exactly as written. Tasks 1-3 were found already committed from a prior session; Task 4 (ping_repository.dart) was untracked and committed as part of this execution.

## Issues Encountered

None.

## Threat Mitigations Verified

| Threat | Status |
|--------|--------|
| T-2-LAYER-BREACH: viewmodel imports cloud_functions directly | MITIGATED — `dart run custom_lint` exits 0, 0 violations |
| T-2-07-RAW-SDK-LEAK: raw HttpsCallableResult returned | MITIGATED — `Future<PingResponse>` return type, compiler enforces |
| T-2-07-REGION-DRIFT: client region mismatches server | MITIGATED — both ends literal `'asia-south1'` grepped + confirmed |
| T-2-07-WRONG-CAST: simplified cast breaks at runtime | MITIGATED — `Map<Object?,Object?>` cast documented with inline comment |
| T-2-07-VERSION-DRIFT-CLOUD: ^6.x breaks firebase_core lockstep | MITIGATED — verify gate passes, lock file shows 5.6.2 |

## Known Stubs

None — all three new files are fully implemented (not stubs).

## Threat Flags

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The `firebaseFunctionsProvider` and `PingRepository` are entirely within the existing threat surface (callable SDK path already planned in Phase 2 scope).

## Next Phase Readiness

- Plan 02-08 can now call `FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001)` in `lib/main.dart`'s `USE_EMULATOR` block — the SDK import (`package:cloud_functions/cloud_functions.dart`) is now a declared dependency.
- Plan 02-09 integration test can instantiate `PingRepository` via `pingRepositoryProvider` and assert `PingResponse.ok == true` from the Functions emulator.
- Phase 3 `MentorBotRepository` follows the same shape: `class MentorBotRepository({required FirebaseFunctions functions})` + typed domain model + `Provider<MentorBotRepository>`.

## Self-Check

| Item | Status |
|------|--------|
| `lib/data/services/firebase_functions_provider.dart` exists | FOUND |
| `lib/data/models/ping_response.dart` exists | FOUND |
| `lib/data/repositories/ping_repository.dart` exists | FOUND |
| Commit `247f6fb` exists in git log | FOUND |
| Commit `8a2b57d` exists in git log | FOUND |
| Commit `5885e84` exists in git log | FOUND |
| Commit `2ebf320` exists in git log | FOUND |

## Self-Check: PASSED

---
*Phase: 02-cloud-functions-scaffolding-app-check*
*Completed: 2026-05-19*
