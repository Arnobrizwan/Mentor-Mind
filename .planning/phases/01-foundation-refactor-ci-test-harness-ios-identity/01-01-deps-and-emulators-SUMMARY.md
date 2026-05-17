---
phase: 01-foundation-refactor-ci-test-harness-ios-identity
plan: 01
subsystem: infra
tags: [flutter, pub, firebase, emulator, dependencies, gitignore, test-harness]

# Dependency graph
requires: []
provides:
  - Pinned Phase 1 test-harness dev_deps (mocktail, fake_cloud_firestore, firebase_auth_mocks, golden_toolkit, network_image_mock, integration_test) installed and resolved against Firebase Flutter SDK ^5.x.
  - flutter_riverpod ^2.6.1 promoted to direct dependency (clears the 12 depend_on_referenced_packages info hits inherited transitively via hooks_riverpod).
  - Codegen + DI packages (riverpod_annotation, get_it, injectable, riverpod_generator, injectable_generator, build_runner) deleted from pubspec.yaml per D-06 (vanilla StateNotifier decision).
  - Firebase Local Emulator Suite wired (auth:9099, firestore:8080, storage:9199, ui:4000) — Functions emulator deliberately omitted until Phase 2 per D-10.
  - tool/emulator-data/.gitkeep committed as the import/export target for Plan 09's deterministic seed.
  - T-1-SECRET closed — service-account.json verifiably gitignored via tool/seed/.gitignore:2 (defense-in-depth also from .gitignore:52 **/service-account*.json).
  - Emulator debug-log artifacts gitignored (firebase-debug.log, firestore-debug.log, ui-debug.log, database-debug.log, pubsub-debug.log, storage-debug.log, .firebase/) so subsequent boots do not leak into commits.
affects: [Plan 01-02 custom_lint plugin, Plan 01-08 anchor tests, Plan 01-09 emulator integration smoke, Plan 02 Functions emulator]

# Tech tracking
tech-stack:
  added:
    - mocktail ^1.0.5
    - fake_cloud_firestore ^3.1.0
    - firebase_auth_mocks ^0.14.2
    - golden_toolkit ^0.15.0 (discontinued upstream; locked by RESEARCH § Standard Stack)
    - network_image_mock ^2.1.1
    - integration_test (sdk:flutter)
    - flutter_riverpod ^2.6.1 (promoted from transitive to direct)
  patterns:
    - "Firebase Flutter SDK ^5.x compatibility pinning — fake_cloud_firestore ^3.x + firebase_auth_mocks ^0.14.x (NOT ^4.x / ^0.15.x which require Firebase SDK ^6.x)."
    - "Local Emulator Suite as the default backend for integration_test/ (full wiring in Plan 09)."

key-files:
  created:
    - tool/emulator-data/.gitkeep
  modified:
    - pubspec.yaml
    - pubspec.lock
    - firebase.json
    - .gitignore

key-decisions:
  - "Honoured D-06: deleted riverpod_annotation, get_it, injectable, riverpod_generator, injectable_generator, build_runner — vanilla StateNotifier is the Phase 1 ViewModel pattern; codegen migration bundled with Riverpod 2→3 in v1.1."
  - "Honoured D-07: promoted flutter_riverpod to direct dependency so depend_on_referenced_packages warnings clear."
  - "Honoured D-10: Functions emulator NOT in firebase.json — added in Phase 2 alongside the functions/ monorepo."
  - "Pinned test-harness versions per RESEARCH § Standard Stack — fake_cloud_firestore stays on ^3.1, firebase_auth_mocks stays on ^0.14.2; refusing to upgrade until Firebase SDK majors land in a future phase."
  - "Added emulator-debug.log family + .firebase/ to root .gitignore — caught after first boot wrote firestore-debug.log to repo root; mitigated before commit."

patterns-established:
  - "Pubspec hygiene: dependencies grouped by purpose with header comments (State management / Navigation / Firebase / UI / Utils / AI+image attach); dev_dependencies grouped (SDK / lints / test harness)."
  - "Emulator artifacts (.firebase/, *-debug.log) ignored at repo root by Firebase Emulator Suite convention."

requirements-completed: [CI-06, CI-07, QUAL-06]

# Metrics
duration: ~25min
completed: 2026-05-17
---

# Plan 01-01: Deps and Emulators Summary

**Firebase ^5.x-compatible test harness (6 dev_deps) + flutter_riverpod direct dep installed, codegen/DI deps excised, Firebase Local Emulator Suite (auth+firestore+storage+ui) wired and boot-verified.**

## Performance

- **Duration:** ~25 min (interactive mode, three checkpoint pauses)
- **Started:** 2026-05-17 (Asia/Kuala_Lumpur evening)
- **Completed:** 2026-05-17
- **Tasks:** 3 (1 verification-only, 2 with commits)
- **Files modified:** 4 (`pubspec.yaml`, `pubspec.lock`, `firebase.json`, `.gitignore`) + 1 created (`tool/emulator-data/.gitkeep`)

## Accomplishments

- Phase 1 test harness installed at versions compatible with current Firebase ^5.x stack — `fake_cloud_firestore ^3.1.0` and `firebase_auth_mocks ^0.14.2` deliberately held below `^4.x` / `^0.15.x` (which would require Firebase Flutter SDK ^6.x and break the build).
- Six codegen/DI packages removed in a single edit (D-06 vanilla decision) — pub resolution succeeds with zero conflicts.
- Firebase Local Emulator Suite wired in `firebase.json` and proven to boot end-to-end (Auth 9099 + Firestore 8080 + Storage 9199 + UI 4000); 12-second smoke captured proof-of-life for all three runtime emulators.
- T-1-SECRET mitigation locked in **before** any code edits — `tool/seed/service-account.json` confirmed gitignored via `git check-ignore -v`.
- Caught and gitignored the `*-debug.log` artifacts the emulator writes to repo root on every boot — would have been committed by accident on the next `git add`.

## Task Commits

1. **Task 1: Verify-versions + secret-gitignore preflight** — *no commit* (verification-only)
2. **Task 2: pubspec.yaml edits + `flutter pub get`** — `b57387a` (chore)
3. **Task 3: firebase.json emulators block + .gitkeep + .gitignore emulator artifacts** — `e39aa05` (chore)

## Files Created/Modified

- `pubspec.yaml` — removed 6 codegen/DI packages, added 7 entries (`flutter_riverpod` direct + 6 test-harness dev_deps). Diff: +10 / -8 lines.
- `pubspec.lock` — regenerated by `flutter pub get`; now contains `fake_cloud_firestore` and `firebase_auth_mocks` entries.
- `firebase.json` — pretty-printed (was minified), added top-level `emulators` block. Diff: +45 / -1 lines. `firestore` / `storage` / `flutter` keys preserved verbatim.
- `tool/emulator-data/.gitkeep` — created (zero bytes); reserves the directory for Plan 09's emulator export/import.
- `.gitignore` — added `firebase-debug.log`, `firestore-debug.log`, `ui-debug.log`, `database-debug.log`, `pubsub-debug.log`, `storage-debug.log`, `.firebase/`.

## Decisions Made

None beyond honouring the locked decisions D-06, D-07, D-10 from `01-CONTEXT.md`. One reactive decision: added emulator debug-log gitignore rules after the first boot proved Firebase Emulator Suite writes them to repo root — kept in this same task to avoid a stray uncommitted artifact.

## Deviations from Plan

### Auto-fixed Issues

**1. [Hygiene — repo-cleanliness] Emulator `*-debug.log` artifacts uncovered by first boot**
- **Found during:** Task 3 (12-second emulator boot smoke)
- **Issue:** First boot of the Firebase Local Emulator Suite wrote `firestore-debug.log` to the repo root. The file was untracked and would have been picked up by a future `git add -A` if not gitignored. The plan did not anticipate this side effect.
- **Fix:** Added the Firebase Emulator Suite's standard debug-log artifacts (`firebase-debug.log`, `firestore-debug.log`, `ui-debug.log`, `database-debug.log`, `pubsub-debug.log`, `storage-debug.log`, `.firebase/`) to root `.gitignore`. Deleted the existing `firestore-debug.log` from the working tree before commit.
- **Files modified:** `.gitignore` (+8 lines under a new "Firebase Emulator Suite (local-only artifacts)" header)
- **Verification:** `git check-ignore -v firestore-debug.log` returned `.gitignore:61:firestore-debug.log	firestore-debug.log` (matched the new rule).
- **Committed in:** `e39aa05` (bundled with Task 3's firebase.json commit — same operational scope)

**2. [Spec — acceptance regex defect, not blocking] `flutter pub outdated` regex `\b6\.` over-matches**
- **Found during:** Task 1 (preflight verification)
- **Issue:** Plan's acceptance regex `! grep -E '\b6\.' /tmp/p1-outdated.txt` is intended to catch Firebase SDK *major* 6 but actually matches *any* `.6.` substring — e.g. `cloud_firestore *5.6.12` (which is on major 5, the desired version) triggers a false positive on `.6.1` inside the minor/patch.
- **Fix:** Did NOT change the plan or regex — semantically the gate is met (all three SDKs on major 5 / 12, none on `^6.x`). Recorded as a plan defect for future regex tightening (e.g. `' 6\.'` or anchored field match).
- **Files modified:** none
- **Verification:** Manual inspection of `flutter pub outdated --no-dev-dependencies` rows for `cloud_firestore` (5.6.12), `firebase_auth` (5.7.0), `firebase_storage` (12.4.10) — all below Firebase Flutter SDK v6.
- **Committed in:** n/a (no edit)

---

**Total deviations:** 2 (1 auto-fixed hygiene, 1 spec defect noted only)
**Impact on plan:** No scope creep. Both surface ops-hygiene gaps the plan did not foresee but did not violate.

## Issues Encountered

- First emulator boot was slower than 12 seconds because Firebase CLI had to download `cloud-firestore-emulator-v1.20.2.jar` and `cloud-storage-rules-runtime-v1.1.3.jar` (one-time cost; cached in `~/.cache/firebase/emulators/`). The 14-second smoke window absorbed this; subsequent boots will be sub-second. Documented here so Plan 09 sets a longer ceiling on first-CI runs.
- `golden_toolkit ^0.15.0` is marked **discontinued** by pub.dev. RESEARCH § Standard Stack pinned it deliberately because no equivalent has stabilised; revisit during Phase 7 polish.

## User Setup Required

None. Local-only changes. The emulator jar downloads happen automatically on first `firebase emulators:start`.

## Next Phase Readiness

- ✓ Plan 01-02 (custom_lint plugin) can now reference the path-dep wiring contract — `pubspec.yaml` is clean and conflict-free.
- ✓ Plan 01-08 (anchor tests) and Plan 01-09 (emulator integration smoke) have their dev_dep prerequisites installed.
- ✓ Plan 01-09 has `tool/emulator-data/` ready as the export/import directory.
- ⚠ Functions emulator deliberately absent — Phase 2 must add `functions` to the `emulators` block when `functions/` lands.

## Evidence — `git check-ignore -v tool/seed/service-account.json`

```
tool/seed/.gitignore:2:service-account.json	tool/seed/service-account.json
```

## Evidence — `flutter pub outdated --no-dev-dependencies` Firebase SDK rows (pre-edit)

```
cloud_firestore *5.6.12
firebase_auth *5.7.0
firebase_storage *12.4.10
```

## Evidence — Emulator boot smoke (12-second window, post-edit)

```
✓ Auth emulator booted          (matched: 'auth: Stopping Authentication Emulator')
✓ Firestore emulator booted     (matched: 'firestore: Firestore Emulator logging to firestore-debug.log')
✓ Storage emulator booted       (matched: 'storage: Stopping Storage Emulator')
```

(First boot included one-time jar downloads of `cloud-firestore-emulator-v1.20.2.jar` and `cloud-storage-rules-runtime-v1.1.3.jar`; assertions confirmed all three runtime emulators were live when SIGTERM was sent.)

---
*Phase: 01-foundation-refactor-ci-test-harness-ios-identity*
*Plan: 01-01-deps-and-emulators*
*Completed: 2026-05-17*
