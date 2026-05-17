---
phase: 01-foundation-refactor-ci-test-harness-ios-identity
plan: 03
subsystem: infra
tags: [refactor, git_mv, layered_architecture, pr_a, presentation_application_data]

# Dependency graph
requires:
  - phase: 01-01-deps-and-emulators
    provides: clean pubspec.yaml that resolves
  - phase: 01-02-custom-lint-plugin
    provides: layered_imports rule that begins policing the new lib/presentation/** and lib/data/** paths
provides:
  - lib/presentation/screens/<feature>/ tree containing all 11 screens (auth, dashboard, materials, notifications, onboarding, profile, rewards, search, splash, tutor).
  - lib/application/viewmodels/<feature>/ tree containing all 11 viewmodels (rewards/ and tutor/ each have 2).
  - lib/data/{models,repositories,services}/ created empty for Plans 04 + 05 to populate.
  - lib/features/ deleted — single source of truth for layered modules is now the new tree.
  - All cross-layer imports converted to package-style ('package:mentor_minds/...') — uniform across moved files and the one outside consumer (lib/core/routes/app_router.dart).
  - git log --follow continuity preserved for every renamed file (similarity 96–100% per file).
  - dart run custom_lint baseline RED count = 2 (both in notifications_screen.dart importing cloud_firestore + firebase_auth) — the closure target for Plan 05.
affects: [Plan 01-04 model extraction, Plan 01-05 repository extraction, Plan 01-07 avatar fix (will edit the moved profile_viewmodel.dart), Plan 01-08 anchor tests (paths point to the new tree), every later phase that writes under lib/]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "package-style imports for all cross-layer references — uniform convention removes the depth-counting trap (../, ../../, ../../../)."
    - "Single-commit rename-with-import-fixes pattern — preserves git log --follow continuity for all 22 files (PITFALLS #5, D-14)."
    - "Per-feature directory under presentation/screens/ AND application/viewmodels/ — features that have multiple viewmodels (rewards: rewards + gamification; tutor: chat) share the feature directory."

key-files:
  created:
    - lib/presentation/screens/{auth,dashboard,materials,notifications,onboarding,profile,rewards,search,splash,tutor}/  (11 screens, via git mv)
    - lib/application/viewmodels/{auth,dashboard,materials,notifications,onboarding,profile,rewards,search,splash,tutor}/  (11 viewmodels, via git mv)
    - lib/data/models/  (empty, for Plan 04)
    - lib/data/repositories/  (empty, for Plan 05)
    - lib/data/services/  (empty, for Plan 05)
  modified:
    - lib/core/routes/app_router.dart  (11 import lines rewritten relative→package)
    - 11 screen files  (same-feature 'viewmodel.dart' import → package; cross-feature ../materials/ import → package)
    - 11 viewmodel files  (../../core/X → package:mentor_minds/core/X)

key-decisions:
  - "Chose package-style imports uniformly (`package:mentor_minds/...`) for every cross-layer reference. Alternative was relative-depth-bumped (../../../core/...). Package-style survives any future relocation, matches app_router.dart's chosen style for screen imports, and avoids the off-by-one depth bug that nearly all engineers hit when moving files deeper into a tree."
  - "Bundled the 22 git mv operations + all 22+1=23 import-path rewrites into a SINGLE commit per D-14 and PITFALLS #5. Splitting would have broken git log --follow continuity for every renamed file permanently."
  - "Did NOT extract domain models, did NOT touch repository wiring, did NOT fix withOpacity deprecations, did NOT fix the unused go_router import in onboarding_screen.dart. Pure rename + import-path-only edits. Subsequent plans build on this baseline."
  - "Created lib/data/{models,repositories,services}/ as empty directories now (no .gitkeep — Plans 04/05 will populate them). Avoids a follow-up plan having to mkdir."

patterns-established:
  - "Two-step refactor pattern: (a) mkdir -p destination skeleton, (b) git mv every file, then (c) sed-rewrite import paths in the new locations, then (d) git add (the modifications, not just the renames), then (e) flutter analyze + custom_lint + git diff -M --stat sanity-check before single-commit."
  - "Post-move git status MUST show 'R' (not 'RM') after staging both the rename and the rewrites; 'RM' is the warning sign that import rewrites are on disk but not yet in the index. Critical because git diff --cached -M --stat with 0 insertions/deletions looks like 'pure rename' but actually means the rewrites are not staged yet."

requirements-completed: [ARCH-01]

# Metrics
duration: ~45min
completed: 2026-05-17
---

# Plan 01-03: Pure git mv Refactor (PR-A) Summary

**22 files renamed lib/features → lib/{presentation/screens, application/viewmodels} in a single commit with package-style import-path rewrites; lib/features/ deleted; git log --follow preserved for every moved file.**

## Performance

- **Duration:** ~45 min (single batched task pass with mid-stream bug catch + fix)
- **Started:** 2026-05-17 (after Plan 01-02 closeout)
- **Completed:** 2026-05-17
- **Tasks:** 2 (1 directory skeleton — no commit; 1 mass-rename + commit)
- **Files modified:** 23 (22 renames + 1 modify on app_router.dart) — 63 insertions / 63 deletions (perfect symmetry: every removed line replaced)

## Accomplishments

- **22 files renamed in a single atomic commit** with git rename similarity 96–100% per file (the few <100% files had additional import rewrites beyond just the core/ depth-bump).
- **git log --follow continuity preserved** for all moved files — spot-checked on dashboard_screen.dart, auth_viewmodel.dart, gamification_viewmodel.dart (all return ≥2 commits including the initial commit).
- **Package-style imports uniformly applied** to all 22 moved files AND lib/core/routes/app_router.dart. The codebase no longer has any `'../../features/'` or `'package:mentor_minds/features/'` reference under lib/, test/, or integration_test/.
- **lib/features/ tree deleted** — no orphan directories left behind.
- **lib/data/{models,repositories,services}/ created empty** so Plans 04 and 05 can populate without a directory-create step.
- **flutter analyze surface unchanged: 155 → 155 issues, same composition** (151 info + 1 warning + 3 errors). All deltas are pre-existing per `git show HEAD~ -- ios/lib/firebase_options.dart` (the warning is a long-stale go_router import in onboarding_screen.dart; the 3 errors are in a stray ios/lib/firebase_options.dart from the initial commit).
- **dart run custom_lint baseline RED = 2 violations**, both in notifications_screen.dart (cloud_firestore + firebase_auth imports). This is the **intended** Plan 05 closure target — the rule is alive and policing the new tree.

## Task Commits

1. **Task 1: Create target directory skeleton** — no commit (empty directories are not git-tracked; Task 2 populates them)
2. **Task 2: git mv 22 files + rewrite imports + delete lib/features/** — `2dce886`

**Plan implementation commit:** `2dce886 refactor(arch): pure git mv lib/features/ → lib/presentation/screens/ + lib/application/viewmodels/ (PR-A, Phase 1 / ARCH-01)`

## Files Created/Modified

- **22 renames** captured by git rename detection — see `git show 2dce886 --stat` for the full table.
- **lib/core/routes/app_router.dart** — 11 import lines changed (`'../../features/<x>/<x>_screen.dart'` → `'package:mentor_minds/presentation/screens/<x>/<x>_screen.dart'`).
- **lib/data/models/, lib/data/repositories/, lib/data/services/** — empty directories created (not yet tracked; Plans 04 + 05 populate).

## Decisions Made

- **Package-style imports.** Chose `package:mentor_minds/...` over `../../../...` for all cross-layer references in the 22 moved files. Rationale: app_router.dart already had to switch styles (its old `'../../features/...'` no longer worked); switching the 22 moved files at the same time keeps the codebase uniform for the rest of Phase 1+.
- **Single commit.** Per D-14 and PITFALLS #5: 22 renames + 23 files of import rewrites in one commit. `git log --follow` would break permanently for any file whose rename and import-fix commits were split.

## Deviations from Plan

### Auto-fixed Issues

**1. [Sed double-`lib/` bug] First-pass sed produced `package:mentor_minds/lib/application/...` (with double `lib/`)**
- **Found during:** Task 2 spot-check after first sed batch
- **Issue:** My sed replacement string included `package:mentor_minds/$vmpath` where `$vmpath` already started with `lib/application/...`. Result: 11 screen files had `import 'package:mentor_minds/lib/application/viewmodels/<f>/<f>_viewmodel.dart';` which would not resolve.
- **Fix:** Second sed pass: `s#package:mentor_minds/lib/application/#package:mentor_minds/application/#g` across all 11 screens.
- **Files modified:** 11 screen files (the same files already in the staged rename set)
- **Verification:** `grep -RHEn 'package:mentor_minds/lib/' lib/` returns 0.
- **Committed in:** `2dce886` (caught and fixed before the single commit landed; never reached HEAD as a broken state)

**2. [Workflow gap] Sed-rewrites in working tree were NOT staged after git mv**
- **Found during:** Task 2 — `git diff --cached -M --stat` reported `0 insertions(+), 0 deletions(-)` despite visible sed edits to the new files
- **Issue:** `git mv` stages the rename. Subsequent `sed -i ''` modifies the working tree only — those edits live in the unstaged delta. Committing immediately would have landed a "rename without import fixes" commit that didn't compile.
- **Fix:** `git add lib/presentation/ lib/application/ lib/core/routes/app_router.dart` to stage the rewrites alongside the renames. Re-ran `git diff --cached -M --numstat` to confirm real line counts and ≥4 lines changed per screen (sanity check).
- **Files modified:** none additional; just re-staged
- **Verification:** `git status` now shows `R ` (not `RM`); diff stat shows actual line counts.
- **Committed in:** `2dce886` (caught pre-commit)

**3. [Plan acceptance regex defect] `flutter analyze --fatal-warnings` actually exits 1**
- **Found during:** Task 2 verification
- **Issue:** Plan's acceptance check `! grep -qE '^\s*(error|warning) -' /tmp/p1-03-analyze.txt` uses a hyphen separator, but `flutter analyze` output uses a Unicode bullet (`•`). The grep matches 0 lines and silently passes, but the analyzer DOES emit `error • ...` and `warning • ...` lines. After this plan, `flutter analyze --fatal-warnings` exits 1 — same as it did BEFORE this plan (the warning + 3 errors are pre-existing in ios/lib/firebase_options.dart and onboarding_screen.dart's unused go_router import — verified by `git show HEAD~ -- ...`).
- **Fix:** No source code edit. Documented here for Plan 01-10 (which will wire `flutter analyze --fatal-warnings` into CI) — that plan needs to either (a) clear the pre-existing 3 errors + 1 warning before turning on `--fatal-warnings` gating, or (b) downgrade to `flutter analyze` without `--fatal-warnings`. Recommended: clean up the 4 hits first.
- **Files modified:** none
- **Verification:** `flutter analyze` (without `--fatal-warnings`) shows the same 155 issues before AND after this plan. D-14 ("no behavioral change") is met.
- **Committed in:** n/a (no edit) — documented in this SUMMARY as a known pre-existing condition for Plan 01-10 to address.

---

**Total deviations:** 3 (2 process bugs caught + fixed mid-stream, 1 documented pre-existing condition surfaced)
**Impact on plan:** No scope creep. The 2 sed bugs were caught before the commit landed; the analyze hits are pre-existing and now documented for Plan 01-10's CI wiring decision.

## Issues Encountered

- BSD vs GNU sed: I used the BSD form `sed -i ''` (Mac default). GNU users will need `sed -i` (without the empty string). Recorded for the SUMMARY but no code changes needed — the project is iOS-only and dev work happens on macOS per CLAUDE.md.
- The `--stat`/`--numstat` "0 insertions / 0 deletions" output is **misleading** when only the rename has been staged but the file content has been modified in working tree — a future engineer running the same `git mv` + `sed` recipe could commit prematurely and ship a broken refactor. Added "Post-move git status MUST show 'R' not 'RM'" to patterns-established above so the next refactor catches this without rediscovering it.

## User Setup Required

None. Pure repository operation.

## Next Phase Readiness

- ✓ **Plan 01-04 (model extraction)** has the directory tree at `lib/data/models/` ready to receive 20+ extracted entity files; the affected viewmodels are already at their final layered location.
- ✓ **Plan 01-05 (repository extraction)** has `lib/data/repositories/` ready; its closure of T-1-LAYER will drive the `layered_imports` baseline (2) to zero by routing `notifications_screen.dart`'s Firebase imports through a `notifications_repository`.
- ✓ **Plan 01-07 (avatar fix)** will edit the moved `profile_viewmodel.dart` at `lib/application/viewmodels/profile/profile_viewmodel.dart` — path is settled.
- ✓ **Plan 01-08 (anchor tests)** can write test files under `test/application/viewmodels/...` and `test/presentation/screens/...` mirroring the new tree.
- ⚠ **Plan 01-10 (GitHub Actions CI)** needs to decide on `flutter analyze --fatal-warnings` vs `flutter analyze` — the 3 pre-existing errors in `ios/lib/firebase_options.dart` and 1 unused-import warning in `onboarding_screen.dart` will cause `--fatal-warnings` to fail. Either clean up first or use the non-fatal form.

## Evidence — Single-commit rename detection

```
22 renames (96–100% similarity), 63 insertions(+), 63 deletions(-),
23 files changed (22 renames + lib/core/routes/app_router.dart modify)
```

Sample from `git show 2dce886 --stat`:
- `lib/{features => application/viewmodels}/auth/auth_viewmodel.dart` — 99%
- `lib/{features => application/viewmodels}/notifications/notifications_viewmodel.dart` — 100%
- `lib/{features => presentation/screens}/splash/splash_screen.dart` — 96%

## Evidence — git log --follow continuity (3 spot-checked files)

```
$ git log --follow --oneline -- lib/presentation/screens/dashboard/dashboard_screen.dart
2dce886 refactor(arch): pure git mv ... (PR-A)
3c57fb3 Initial commit: MentorMinds Flutter app

$ git log --follow --oneline -- lib/application/viewmodels/auth/auth_viewmodel.dart
2dce886 refactor(arch): pure git mv ... (PR-A)
3c57fb3 Initial commit: MentorMinds Flutter app

$ git log --follow --oneline -- lib/application/viewmodels/rewards/gamification_viewmodel.dart
2dce886 refactor(arch): pure git mv ... (PR-A)
3c57fb3 Initial commit: MentorMinds Flutter app
```

All three return ≥2 commits via `--follow`, proving rename continuity.

## Evidence — `dart run custom_lint` post-move RED baseline

```
Analyzing...

  lib/presentation/screens/notifications/notifications_screen.dart:1:1 • Layered architecture violation: ... • layered_imports • ERROR
  lib/presentation/screens/notifications/notifications_screen.dart:2:1 • Layered architecture violation: ... • layered_imports • ERROR

2 issues found.
```

Both hits are on the cloud_firestore + firebase_auth imports inside notifications_screen.dart. **This is the intended RED baseline that Plan 05 closes** by routing the screen through a notifications_repository.

## Evidence — features/ purge

```
$ grep -RHEn "package:mentor_minds/features/" lib/ test/ integration_test/
(no matches)

$ grep -RHEn "'\\.\\./\\.\\./features/" lib/ test/ integration_test/
(no matches)

$ test -d lib/features
(exit 1 — directory does not exist)
```

---
*Phase: 01-foundation-refactor-ci-test-harness-ios-identity*
*Plan: 01-03-pure-git-mv-refactor*
*Completed: 2026-05-17*
