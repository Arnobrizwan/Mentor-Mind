---
phase: 01-foundation-refactor-ci-test-harness-ios-identity
plan: 04
subsystem: data
tags: [refactor, model_extraction, data_layer, pr_a_completion, ARCH-02]

# Dependency graph
requires:
  - phase: 01-03-pure-git-mv-refactor
    provides: lib/application/viewmodels/ tree + lib/data/models/ empty directory
provides:
  - lib/data/models/ — 21 flat per-entity model files (D-03 compliant)
  - lib/data/models/badge_info.dart — canonical BadgeInfo (merged from gamification + rewards)
  - lib/data/models/leaderboard_entry.dart — canonical LeaderboardEntry (7-field superset)
  - Viewmodel files stripped of inline class definitions; all import from lib/data/models/
  - Screen files updated with direct model imports for extracted types
affects:
  - Plan 01-05 (repository extraction — 10 viewmodels still directly import Firebase SDKs)
  - Plan 01-08 (anchor tests — test/data/models/ can now hold model-layer unit tests)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Flat model layer — all domain entities live directly under lib/data/models/, one file per entity, no barrel files, no per-collection grouping (D-03)"
    - "Model layer is a graph leaf — no model file imports from lib/presentation/ or lib/application/"
    - "MaterialType enum extracted to lib/data/models/learning_material.dart; screens that reference it use `hide MaterialType` on flutter/material.dart import"

key-files:
  created:
    - lib/data/models/app_notification.dart
    - lib/data/models/badge_info.dart
    - lib/data/models/badge_item.dart
    - lib/data/models/chat_message.dart
    - lib/data/models/dashboard_user.dart
    - lib/data/models/earned_badge.dart
    - lib/data/models/history_entry.dart
    - lib/data/models/leaderboard_entry.dart
    - lib/data/models/learning_material.dart
    - lib/data/models/locked_badge.dart
    - lib/data/models/material_item.dart
    - lib/data/models/material_search_hit.dart
    - lib/data/models/milestone.dart
    - lib/data/models/points_history.dart
    - lib/data/models/profile_stats.dart
    - lib/data/models/profile_user.dart
    - lib/data/models/rewards_doc.dart
    - lib/data/models/rewards_snapshot.dart
    - lib/data/models/session_item.dart
    - lib/data/models/session_search_hit.dart
    - lib/data/models/subject_progress.dart
  modified:
    - lib/application/viewmodels/dashboard/dashboard_viewmodel.dart (6 classes deleted, 6 imports added)
    - lib/application/viewmodels/tutor/chat_viewmodel.dart (inline already removed; import confirmed)
    - lib/application/viewmodels/notifications/notifications_viewmodel.dart (1 class deleted, 1 import confirmed)
    - lib/application/viewmodels/profile/profile_viewmodel.dart (2 classes deleted, 2 imports added)
    - lib/application/viewmodels/rewards/gamification_viewmodel.dart (4 classes deleted, 4 imports added)
    - lib/application/viewmodels/rewards/rewards_viewmodel.dart (6 classes deleted, 6 imports added)
    - lib/application/viewmodels/materials/materials_viewmodel.dart (LearningMaterial + MaterialType deleted, 1 import added)
    - lib/application/viewmodels/search/search_viewmodel.dart (2 classes deleted, 3 imports added)
    - lib/presentation/screens/tutor/tutor_screen.dart (import added: chat_message.dart)
    - lib/presentation/screens/rewards/rewards_screen.dart (imports added: earned_badge, history_entry, leaderboard_entry, locked_badge, milestone)
    - lib/presentation/screens/dashboard/dashboard_screen.dart (imports added: badge_item, material_item, session_item, subject_progress)
    - lib/presentation/screens/materials/materials_screen.dart (import added: learning_material)
    - lib/presentation/screens/profile/profile_screen.dart (imports added: profile_stats, profile_user)
    - lib/presentation/screens/notifications/notifications_screen.dart (import added: app_notification)
    - lib/presentation/screens/search/search_screen.dart (imports added: learning_material, material_search_hit, session_search_hit)

key-decisions:
  - "Extracted LeaderboardEntry uses the 7-field rewards_viewmodel superset (subject: String?). gamification_viewmodel constructor calls updated to pass subject: null — this is required for compile compatibility with the canonical class, not a logic change."
  - "MaterialType enum is extracted alongside LearningMaterial into lib/data/models/learning_material.dart — the enum belongs with the model that defines its usage. Screens that need MaterialType add hide MaterialType to their flutter/material.dart import."
  - "Removed unused _gradientForSubject function from dashboard_viewmodel.dart — the function was only called by the inline MaterialItem.fromDoc which moved to material_item.dart. Its removal is part of the class extraction footprint, not a body logic edit."
  - "search_viewmodel.dart previously imported materials_viewmodel.dart for LearningMaterial, MaterialType, and subjectColorFor. After extraction, it imports from lib/data/models/ directly, eliminating the cross-viewmodel import."

requirements-completed: [ARCH-02]

# Metrics
duration: ~50min
completed: 2026-05-17
---

# Plan 01-04: Model Extraction (PR-A completion) Summary

**21 inline domain-model classes extracted from 8 viewmodel files into flat files under `lib/data/models/`. Two duplicate-class collisions resolved per PATTERNS.md verdicts. ARCH-02 closed.**

## Performance

- **Duration:** ~50 min
- **Started:** 2026-05-17T13:30:32Z
- **Completed:** 2026-05-17
- **Tasks:** 3 (Tasks 1+2 implemented together; Task 3 verification)
- **Model files created:** 21
- **Viewmodel files modified:** 8
- **Screen files modified:** 7 (cascade fix — screens import model types directly)

## Accomplishments

- **21 model files created** under `lib/data/models/` — flat layout per D-03, one file per entity, no barrel files.
- **8 viewmodel files cleaned** — inline class definitions removed, `package:mentor_minds/data/models/<entity>.dart` imports added.
- **BadgeInfo collision resolved** — identical signatures confirmed (same 6 fields). One canonical class in `lib/data/models/badge_info.dart`. Private badge catalogs (`_catalog`, `_allBadges`) remain inside their viewmodels.
- **LeaderboardEntry collision resolved** — `rewards_viewmodel.dart` 7-field superset is canonical. `gamification_viewmodel.dart` now passes `subject: null` to comply with the required field.
- **MaterialItem vs LearningMaterial kept separate** — confirmed as distinct projections per PATTERNS.md verdict.
- **Model layer is a graph leaf** — no model file imports from `lib/presentation/` or `lib/application/`.
- **flutter analyze: 155 issues** — matches post-Plan-03 baseline exactly (151 info + 1 warning + 3 errors).
- **dart run custom_lint: 2 layered_imports violations** — same as Plan-03 baseline. No new violations from model extraction.
- **7 screen files updated** — cascade fix: screens now import model types directly from `lib/data/models/` rather than relying on viewmodel re-export (Dart does not re-export imported types).

## Task Commits

- **Tasks 1 + 2 + 3:** staged but pending commit (see Deviations section)

**Note:** git commit operations were blocked by the environment's kluster code review requirement during this execution session. All changes are staged and verified. The commit is ready to be made by the user with:
```
git commit -m "refactor(models): extract 21 inline domain-model classes to lib/data/models/ (ARCH-02, Phase 1)"
```

## Model File Inventory (`ls lib/data/models/`)

```
app_notification.dart    badge_info.dart         badge_item.dart
chat_message.dart        dashboard_user.dart      earned_badge.dart
history_entry.dart       leaderboard_entry.dart  learning_material.dart
locked_badge.dart        material_item.dart       material_search_hit.dart
milestone.dart           points_history.dart      profile_stats.dart
profile_user.dart        rewards_doc.dart         rewards_snapshot.dart
session_item.dart        session_search_hit.dart  subject_progress.dart
```

Total: 21 files (19 clean extractions + 2 collision resolutions)

## Per-Viewmodel Diff Stats

| Viewmodel | Classes Removed | Imports Added | Notes |
|-----------|-----------------|---------------|-------|
| dashboard_viewmodel.dart | DashboardUser, RewardsSnapshot, SubjectProgress, SessionItem, MaterialItem, BadgeItem | 6 | Also removed unused _gradientForSubject (only called by MaterialItem.fromDoc) |
| chat_viewmodel.dart | ChatMessage (already extracted prior) | 1 | Import already present |
| notifications_viewmodel.dart | AppNotification (already extracted prior) | 1 | Import already present |
| profile_viewmodel.dart | ProfileUser, ProfileStats | 2 | — |
| gamification_viewmodel.dart | BadgeInfo, RewardsDoc, PointsHistory, LeaderboardEntry | 4 | LeaderboardEntry constructor calls updated with subject: null |
| rewards_viewmodel.dart | BadgeInfo, Milestone, HistoryEntry, LeaderboardEntry, EarnedBadge, LockedBadge | 6 | — |
| materials_viewmodel.dart | LearningMaterial (+ MaterialType enum + extension + subjectColorFor) | 1 | MaterialType moved to learning_material.dart |
| search_viewmodel.dart | MaterialSearchHit, SessionSearchHit | 3 | Removed cross-viewmodel import of materials_viewmodel; added 3 model imports |

## Cascade Fix: Screen Files

The following screens directly use model types that moved from viewmodels to `lib/data/models/`. Since Dart does not implicitly re-export imported types, each screen needed explicit imports added:

| Screen | Models Imported |
|--------|----------------|
| tutor_screen.dart | chat_message (ChatMessage, MessageRole, MessageFeedback) |
| rewards_screen.dart | earned_badge, history_entry, leaderboard_entry, locked_badge, milestone |
| dashboard_screen.dart | badge_item, material_item, session_item, subject_progress |
| materials_screen.dart | learning_material (LearningMaterial, MaterialType) |
| profile_screen.dart | profile_stats, profile_user |
| notifications_screen.dart | app_notification |
| search_screen.dart | learning_material (MaterialType, subjectColorFor), material_search_hit, session_search_hit |

## Invariant Checks

### BadgeInfo singleton
```
grep -rln "^class BadgeInfo\b" lib/ → lib/data/models/badge_info.dart (only)
```

### LeaderboardEntry singleton
```
grep -rln "^class LeaderboardEntry\b" lib/ → lib/data/models/leaderboard_entry.dart (only)
```

### No model imports from presentation/application
```
grep -RIn "import 'package:mentor_minds/(presentation|application)/" lib/data/models/
→ (no matches)
```

### flutter analyze
```
155 issues found (matches post-Plan-03 baseline: 151 info + 1 warning + 3 errors)
```

### dart run custom_lint
```
2 issues found (layered_imports baseline unchanged):
  lib/presentation/screens/notifications/notifications_screen.dart:1:1
  lib/presentation/screens/notifications/notifications_screen.dart:2:1
```

## Pre-Plan-05 Baseline: Viewmodels Still Directly Importing Firebase SDKs

These 10 viewmodels call Firebase SDKs directly — the closed work-set for Plan 05:

```
lib/application/viewmodels/splash/splash_viewmodel.dart
lib/application/viewmodels/materials/materials_viewmodel.dart
lib/application/viewmodels/auth/auth_viewmodel.dart
lib/application/viewmodels/rewards/rewards_viewmodel.dart
lib/application/viewmodels/dashboard/dashboard_viewmodel.dart
lib/application/viewmodels/search/search_viewmodel.dart
lib/application/viewmodels/rewards/gamification_viewmodel.dart
lib/application/viewmodels/tutor/chat_viewmodel.dart
lib/application/viewmodels/profile/profile_viewmodel.dart
lib/application/viewmodels/notifications/notifications_viewmodel.dart
```

`onboarding_viewmodel.dart` is NOT in the list — it only uses SharedPreferences, not Firebase SDKs.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Screen files required direct model imports (cascade fix)**
- **Found during:** Task 1 verification (flutter analyze)
- **Issue:** `tutor_screen.dart` had 8 errors for `ChatMessage`, `MessageFeedback`, `MessageRole` undefined — these types moved from `chat_viewmodel.dart` inline to `lib/data/models/chat_message.dart`. Dart does not re-export imported types through viewmodel imports. Same pattern repeated across 6 more screens.
- **Fix:** Added explicit `import 'package:mentor_minds/data/models/<entity>.dart'` to each affected screen. This is strictly additive (import lines only) — no screen logic changed.
- **Files modified:** 7 screen files
- **Verification:** `flutter analyze` 155 issues (no errors from extraction)

**2. [Rule 3 - Blocking] LeaderboardEntry constructor missing `subject` field in gamification_viewmodel**
- **Found during:** Task 2 (BadgeInfo + LeaderboardEntry canonicalization)
- **Issue:** The gamification_viewmodel.dart had a 6-field `LeaderboardEntry` constructor call. The canonical 7-field superset has `required this.subject`. The missing field would have been a compile error.
- **Fix:** Added `subject: null` to the `LeaderboardEntry(...)` constructor call in `fetchLeaderboard()` in `gamification_viewmodel.dart`.
- **Files modified:** `lib/application/viewmodels/rewards/gamification_viewmodel.dart`
- **Note:** This is not a logic change — it's required for compiler compatibility with the superset class. The PLAN (Task 2 Step B) explicitly anticipates this: "no constructor call edits are needed — the canonical class has `subject` as nullable, so existing constructor calls that omit it still compile (the field defaults to null)". However, since the field is `required`, omitting it fails to compile rather than defaulting. The fix (adding `subject: null`) matches the plan's stated intent.

**3. [Rule 3 - Blocking] `_gradientForSubject` became unused after MaterialItem extraction**
- **Found during:** Task 3 verification (flutter analyze warning)
- **Issue:** `dashboard_viewmodel.dart` contained `_gradientForSubject` which was only called by the inline `MaterialItem.fromDoc` factory. After extraction, the factory moved to `material_item.dart` (with its own copy of the helper). The function in the viewmodel became unused, triggering a new `unused_element` warning — raising the analyze count to 156.
- **Fix:** Removed `_gradientForSubject` from `dashboard_viewmodel.dart`. `_colorForSubject` remains (used by `DashboardState.subjects` getter via `_colorForSubject`).
- **Files modified:** `lib/application/viewmodels/dashboard/dashboard_viewmodel.dart`
- **Verification:** `flutter analyze` returned to 155 issues.

**4. [Rule 3 - Blocking] `material_search_hit.dart` ambiguous MaterialType import**
- **Found during:** Task 1 verification (flutter analyze error)
- **Issue:** `lib/data/models/material_search_hit.dart` imported both `flutter/material.dart` (for `Color`) and `learning_material.dart` (which defines `MaterialType`). Flutter's `material.dart` also defines a `MaterialType` enum — causing `ambiguous_import` error.
- **Fix:** Changed `import 'package:flutter/material.dart';` to `import 'package:flutter/material.dart' hide MaterialType;` in `material_search_hit.dart`.
- **Files modified:** `lib/data/models/material_search_hit.dart`

**5. [Rule 3 - Blocking] search_viewmodel cross-viewmodel import removal**
- **Found during:** Task 1 (extracting MaterialSearchHit, SessionSearchHit from search_viewmodel)
- **Issue:** `search_viewmodel.dart` imported `materials_viewmodel.dart` to access `LearningMaterial`, `MaterialType`, and `subjectColorFor`. After extraction, these live in `lib/data/models/learning_material.dart`. The cross-viewmodel import would have been a layered_imports violation going forward.
- **Fix:** Replaced `import 'package:mentor_minds/application/viewmodels/materials/materials_viewmodel.dart'` with `import 'package:mentor_minds/data/models/learning_material.dart'` (plus the two new model imports). Re-added `flutter/material.dart` and `AppColors` which were removed in error (search_viewmodel uses `AppColors.kPrimary` and Flutter text spans).
- **Files modified:** `lib/application/viewmodels/search/search_viewmodel.dart`

**6. [Process] Git commit blocked by kluster code review requirement**
- **Found during:** Task 1 commit
- **Issue:** The user's global CLAUDE.md mandates `kluster_code_review_auto` execution after every file change, before commits can proceed. The kluster tool is not available in this agent's toolset. Git commit bash commands were denied by the environment sandbox.
- **Fix:** None possible without kluster access. All changes are staged (`git status` shows all files in index). The commit is ready; user must execute:
  ```
  git commit -m "refactor(models): extract 21 inline domain-model classes to lib/data/models/ (ARCH-02, Phase 1)"
  ```
- **Impact:** The SUMMARY.md and state updates cannot be committed either. User must also commit the planning artifacts after the implementation commit.

## Known Stubs

None — no stub patterns introduced by this plan. The model extraction is verbatim class moves; no placeholder data was introduced.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes. The model extraction is a pure structural move; it does not change the data flow or trust boundaries.

## Self-Check

### Files exist:
- lib/data/models/badge_info.dart — FOUND
- lib/data/models/leaderboard_entry.dart — FOUND
- lib/data/models/learning_material.dart — FOUND
- lib/data/models/material_item.dart — FOUND
- All 21 model files — FOUND (ls count = 21)

### No inline class definitions remain in viewmodels:
- grep -rn "^class (DashboardUser|BadgeInfo|LeaderboardEntry|...)" lib/application/viewmodels/ — NO MATCHES

### flutter analyze: 155 issues — MATCHES BASELINE

### dart run custom_lint: 2 layered_imports — MATCHES BASELINE

### No model imports from presentation/application: CONFIRMED

## Self-Check: PASSED

All acceptance criteria met. The one deviation (git commit blocked) is an environment constraint, not a code correctness issue.

---
*Phase: 01-foundation-refactor-ci-test-harness-ios-identity*
*Plan: 01-04-model-extraction*
*Completed: 2026-05-17*
