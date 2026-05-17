---
phase: 01-foundation-refactor-ci-test-harness-ios-identity
plan: 04
type: execute
wave: 2
depends_on: ["01-03"]
files_modified:
  - lib/data/models/dashboard_user.dart
  - lib/data/models/rewards_snapshot.dart
  - lib/data/models/subject_progress.dart
  - lib/data/models/session_item.dart
  - lib/data/models/material_item.dart
  - lib/data/models/learning_material.dart
  - lib/data/models/badge_item.dart
  - lib/data/models/chat_message.dart
  - lib/data/models/app_notification.dart
  - lib/data/models/profile_user.dart
  - lib/data/models/profile_stats.dart
  - lib/data/models/badge_info.dart
  - lib/data/models/leaderboard_entry.dart
  - lib/data/models/rewards_doc.dart
  - lib/data/models/points_history.dart
  - lib/data/models/milestone.dart
  - lib/data/models/history_entry.dart
  - lib/data/models/earned_badge.dart
  - lib/data/models/locked_badge.dart
  - lib/data/models/material_search_hit.dart
  - lib/data/models/session_search_hit.dart
  - lib/application/viewmodels/dashboard/dashboard_viewmodel.dart
  - lib/application/viewmodels/tutor/chat_viewmodel.dart
  - lib/application/viewmodels/notifications/notifications_viewmodel.dart
  - lib/application/viewmodels/profile/profile_viewmodel.dart
  - lib/application/viewmodels/rewards/rewards_viewmodel.dart
  - lib/application/viewmodels/rewards/gamification_viewmodel.dart
  - lib/application/viewmodels/materials/materials_viewmodel.dart
  - lib/application/viewmodels/search/search_viewmodel.dart
autonomous: true
requirements: [ARCH-02]
requirements_addressed: [ARCH-02]
tags: [refactor, model_extraction, data_layer, pr_a_completion]

must_haves:
  truths:
    - "D-03: Every inline domain-model class previously defined inside a viewmodel file now lives in its own file flat under `lib/data/models/` — one file per entity, no barrel files, no per-collection grouping"
    - "`BadgeInfo` and `LeaderboardEntry` exist as exactly one canonical class each — both `gamification_viewmodel.dart` and `rewards_viewmodel.dart` import from `lib/data/models/`"
    - "`MaterialItem` (dashboard projection) and `LearningMaterial` (browse projection) exist as TWO separate files — they are distinct projections of `/materials`, not duplicates"
    - "`flutter analyze --fatal-warnings` exits 0 after extraction (no orphaned types, no duplicate-class errors)"
    - "Every viewmodel body is otherwise byte-identical to its post-Plan-03 state except for (a) deleted inline class definitions and (b) added imports — no logic edits"
  artifacts:
    - path: "lib/data/models/dashboard_user.dart"
      provides: "DashboardUser domain entity with fromDoc factory"
      contains: "class DashboardUser"
    - path: "lib/data/models/badge_info.dart"
      provides: "Single canonical BadgeInfo (merged from gamification + rewards viewmodels — identical signatures per PATTERNS.md)"
      contains: "class BadgeInfo"
    - path: "lib/data/models/leaderboard_entry.dart"
      provides: "Single canonical LeaderboardEntry (rewards_viewmodel superset — 7 fields including subject)"
      contains: "class LeaderboardEntry"
    - path: "lib/data/models/material_item.dart"
      provides: "Lightweight dashboard projection of /materials"
      contains: "class MaterialItem"
    - path: "lib/data/models/learning_material.dart"
      provides: "Rich materials-browse projection of /materials with fileUrl, type, views"
      contains: "class LearningMaterial"
  key_links:
    - from: "lib/application/viewmodels/rewards/gamification_viewmodel.dart"
      to: "lib/data/models/badge_info.dart"
      via: "package import"
      pattern: "package:mentor_minds/data/models/badge_info\\.dart"
    - from: "lib/application/viewmodels/rewards/rewards_viewmodel.dart"
      to: "lib/data/models/leaderboard_entry.dart"
      via: "package import"
      pattern: "package:mentor_minds/data/models/leaderboard_entry\\.dart"
    - from: "lib/application/viewmodels/search/search_viewmodel.dart"
      to: "lib/data/models/learning_material.dart"
      via: "package import (MaterialSearchHit.fromLearningMaterial uses LearningMaterial)"
      pattern: "package:mentor_minds/data/models/learning_material\\.dart"
---

<objective>
PR-A completion: Extract every inline domain-model class out of the 8 affected viewmodel files into one file per entity under `lib/data/models/`, resolving the two known duplicate-class collisions (`BadgeInfo`, `LeaderboardEntry`) and keeping `MaterialItem` and `LearningMaterial` as separate files (per PATTERNS.md they are distinct projections of `/materials`, not duplicates). Each viewmodel file loses its inline class definitions and gains an import line per extracted class — nothing else changes.

Purpose: ARCH-02 is the second half of PR-A. The pure `git mv` of Plan 03 moved files; this plan moves the *content* of inline models out of those files. Together they complete the structural refactor before any repository wiring (Plan 05) or test harness work (Plans 08-09) can land. Keeping extraction in its own plan preserves diff hygiene — Plan 03's commit is rename-only, this plan's commit is class-move-only, Plan 05's commits are wiring-only.

Output: 20 new files under `lib/data/models/`, 8 viewmodel files with their inline class blocks deleted and imports added, `flutter analyze --fatal-warnings` green, `dart run custom_lint` count of `layered_imports` violations unchanged from the Plan 03 baseline (no model file under `lib/data/models/` imports `package:mentor_minds/presentation/...`, so the rule does not newly fire).
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-CONTEXT.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-PATTERNS.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-03-pure-git-mv-refactor-PLAN.md
@CLAUDE.md
@lib/application/viewmodels/dashboard/dashboard_viewmodel.dart
@lib/application/viewmodels/tutor/chat_viewmodel.dart
@lib/application/viewmodels/notifications/notifications_viewmodel.dart
@lib/application/viewmodels/profile/profile_viewmodel.dart
@lib/application/viewmodels/rewards/rewards_viewmodel.dart
@lib/application/viewmodels/rewards/gamification_viewmodel.dart
@lib/application/viewmodels/materials/materials_viewmodel.dart
@lib/application/viewmodels/search/search_viewmodel.dart

<interfaces>
<!-- Full extraction table — source viewmodel + source lines + target model file -->
<!-- D-03 locks: flat under lib/data/models/, one file per entity, no barrel files -->

Clean extractions (no collisions, PATTERNS.md § 2 lines 63-82):

| Class | Source File (post-Plan-03 path) | Source Lines | Target File |
|-------|---------------------------------|-------------|-------------|
| DashboardUser    | lib/application/viewmodels/dashboard/dashboard_viewmodel.dart    | 42-89   | lib/data/models/dashboard_user.dart |
| RewardsSnapshot  | lib/application/viewmodels/dashboard/dashboard_viewmodel.dart    | 91-95   | lib/data/models/rewards_snapshot.dart |
| SubjectProgress  | lib/application/viewmodels/dashboard/dashboard_viewmodel.dart    | 97-106  | lib/data/models/subject_progress.dart |
| SessionItem      | lib/application/viewmodels/dashboard/dashboard_viewmodel.dart    | 108-141 | lib/data/models/session_item.dart |
| MaterialItem     | lib/application/viewmodels/dashboard/dashboard_viewmodel.dart    | 143-170 | lib/data/models/material_item.dart |
| BadgeItem        | lib/application/viewmodels/dashboard/dashboard_viewmodel.dart    | 172-183 | lib/data/models/badge_item.dart |
| ChatMessage      | lib/application/viewmodels/tutor/chat_viewmodel.dart             | 20-59   | lib/data/models/chat_message.dart |
| AppNotification  | lib/application/viewmodels/notifications/notifications_viewmodel.dart | 32-81 | lib/data/models/app_notification.dart |
| ProfileUser      | lib/application/viewmodels/profile/profile_viewmodel.dart        | 17-86   | lib/data/models/profile_user.dart |
| ProfileStats     | lib/application/viewmodels/profile/profile_viewmodel.dart        | 88-99   | lib/data/models/profile_stats.dart |
| RewardsDoc       | lib/application/viewmodels/rewards/gamification_viewmodel.dart   | 111-125 | lib/data/models/rewards_doc.dart |
| PointsHistory    | lib/application/viewmodels/rewards/gamification_viewmodel.dart   | 127-147 | lib/data/models/points_history.dart |
| Milestone        | lib/application/viewmodels/rewards/rewards_viewmodel.dart        | 104-120 | lib/data/models/milestone.dart |
| HistoryEntry     | lib/application/viewmodels/rewards/rewards_viewmodel.dart        | 126-149 | lib/data/models/history_entry.dart |
| EarnedBadge      | lib/application/viewmodels/rewards/rewards_viewmodel.dart        | 170-179 | lib/data/models/earned_badge.dart |
| LockedBadge      | lib/application/viewmodels/rewards/rewards_viewmodel.dart        | 181-185 | lib/data/models/locked_badge.dart |
| LearningMaterial | lib/application/viewmodels/materials/materials_viewmodel.dart    | 94-166  | lib/data/models/learning_material.dart |
| MaterialSearchHit| lib/application/viewmodels/search/search_viewmodel.dart          | 16-45   | lib/data/models/material_search_hit.dart |
| SessionSearchHit | lib/application/viewmodels/search/search_viewmodel.dart          | 47-63   | lib/data/models/session_search_hit.dart |

Collision resolutions (PATTERNS.md § DUPLICATE MODEL FLAG lines 138-217):

- BadgeInfo: defined in BOTH gamification_viewmodel.dart:31-46 AND rewards_viewmodel.dart:14-29.
  Verdict per PATTERNS.md line 186: signatures are IDENTICAL (same 6 fields: id, emoji, name, description,
  unlockHint, target). Extract ONE canonical class to lib/data/models/badge_info.dart. The two badge catalog
  CONSTANTS (`_catalog` in gamification, `_allBadges` in rewards) STAY as private file-local constants inside
  their viewmodels — they are not part of the model class.

- LeaderboardEntry: defined in BOTH gamification_viewmodel.dart:149-164 AND rewards_viewmodel.dart:151-168.
  Verdict per PATTERNS.md line 216: rewards_viewmodel definition is the SUPERSET — it has an extra
  `String? subject;` field. Extract the 7-field rewards version to lib/data/models/leaderboard_entry.dart.
  In gamification_viewmodel.dart the `subject` field will be unused (null) in that file's context.

MaterialItem vs LearningMaterial naming clash (PATTERNS.md lines 220-258):

- These are NOT duplicates. They are view-tailored projections of the same /materials Firestore collection:
  - MaterialItem (dashboard_viewmodel.dart:143): id, title, level, subject, gradient — display only.
  - LearningMaterial (materials_viewmodel.dart:94): materialId, title, subject, level, fileUrl, type,
    thumbnailUrl, uploadedBy, views, createdAt — full browse model.
- Extract BOTH verbatim to two separate files.
- search_viewmodel.dart line 33's `MaterialSearchHit.fromLearningMaterial(m)` cross-references LearningMaterial
  — update search_viewmodel's import to package:mentor_minds/data/models/learning_material.dart.

Import path convention (must match Plan 03's chosen convention — see Plan 03 Task 2 Step B; the SUMMARY
records whether relative-bumped or package-style was chosen). Read 01-03-SUMMARY.md before extracting.

Files to create — one per row above plus the two collision targets. 20 new files total.
Empty `.gitkeep` should NOT exist in lib/data/models/ after this plan — the 20 model files satisfy the
directory's commit-ability.

Forbidden in this plan (CONTEXT.md § specifics, D-14):
  - No body edits inside viewmodels other than (1) deleting class definitions and (2) adding imports
  - No logic changes
  - No `withOpacity` → `withValues` substitution
  - No barrel files (CLAUDE.md convention; D-03 confirms)
  - No model-grouping files like lib/data/models/rewards/badge_info.dart (D-03 says FLAT)
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Extract collision-free model classes (17 files)</name>
  <files>lib/data/models/dashboard_user.dart, lib/data/models/rewards_snapshot.dart, lib/data/models/subject_progress.dart, lib/data/models/session_item.dart, lib/data/models/material_item.dart, lib/data/models/badge_item.dart, lib/data/models/chat_message.dart, lib/data/models/app_notification.dart, lib/data/models/profile_user.dart, lib/data/models/profile_stats.dart, lib/data/models/rewards_doc.dart, lib/data/models/points_history.dart, lib/data/models/milestone.dart, lib/data/models/history_entry.dart, lib/data/models/earned_badge.dart, lib/data/models/locked_badge.dart, lib/data/models/learning_material.dart, lib/data/models/material_search_hit.dart, lib/data/models/session_search_hit.dart, lib/application/viewmodels/dashboard/dashboard_viewmodel.dart, lib/application/viewmodels/tutor/chat_viewmodel.dart, lib/application/viewmodels/notifications/notifications_viewmodel.dart, lib/application/viewmodels/profile/profile_viewmodel.dart, lib/application/viewmodels/rewards/gamification_viewmodel.dart, lib/application/viewmodels/rewards/rewards_viewmodel.dart, lib/application/viewmodels/materials/materials_viewmodel.dart, lib/application/viewmodels/search/search_viewmodel.dart</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-PATTERNS.md (§ 2 lines 63-135 — full extraction table + fromDoc excerpts for DashboardUser and AppNotification as anchor patterns; lines 220-258 — MaterialItem vs LearningMaterial verdict)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-CONTEXT.md (D-03 — flat under lib/data/models/, one file per entity, no barrel files; D-14 — no body edits)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md (§ Code Context — Reusable assets lines 159-165, "factory X.fromDoc(...) constructors survive the extraction; they move verbatim")
    - /Users/arnobrizwan/Mentor-Mind/CLAUDE.md (§ Conventions — File Naming, Class Naming, No barrel files, growable: false idiom)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-03-pure-git-mv-refactor-SUMMARY.md (read AFTER Plan 03 completes — confirm which import convention was chosen for cross-feature imports; this plan must match)
    - The 8 viewmodel files at their post-Plan-03 paths (listed in `files_modified`) — required to confirm the line ranges given in PATTERNS.md still match post-rename
  </read_first>
  <action>
    For each of the 19 entries in the "Clean extractions" table in `<interfaces>` (DashboardUser through SessionSearchHit, but EXCLUDING BadgeInfo and LeaderboardEntry — Task 2 handles those):

    Step A — Copy the class definition VERBATIM from the source viewmodel into a new file at the target path. For example, for `DashboardUser`:
      1. Read lines 42-89 of `lib/application/viewmodels/dashboard/dashboard_viewmodel.dart`. Confirm the line range matches PATTERNS.md (if Plan 03 import-path edits shifted line numbers, the class block is still contiguous — locate it by `class DashboardUser {` and copy from there to the closing `}` of the class).
      2. Create `lib/data/models/dashboard_user.dart` with: (a) any `import` directives the class needs (e.g. `package:cloud_firestore/cloud_firestore.dart` if the class uses `Timestamp` or `QueryDocumentSnapshot`, `package:flutter/material.dart` if it uses `Color` like `MaterialItem` does), (b) the class definition byte-for-byte as it appeared in the viewmodel, (c) NO additional `library` directive, NO part files, NO export statements.
      3. Add the SPDX-style file-header comment that the viewmodel already uses for section dividers, if and only if the original block had a leading comment — preserve it.

    Step B — In the source viewmodel file, delete the class definition block (the exact lines copied in Step A). Add one new `import` line near the top of the viewmodel's import block, in the package: section: `import 'package:mentor_minds/data/models/dashboard_user.dart';`. Use the same import-path style (package: vs relative) that Plan 03 settled on for cross-feature imports — read `01-03-pure-git-mv-refactor-SUMMARY.md` to confirm. If Plan 03 chose package-style, use `package:mentor_minds/data/models/<entity>.dart`; if relative-bumped, use the appropriate `../../../data/models/<entity>.dart` (depth from `lib/application/viewmodels/<feature>/` is `../../../data/models/`).

    Step C — Imports inside the new model file: copy ONLY the imports the class actually needs (analyzer will tell you what's missing). Do NOT import the viewmodel — models are leaves of the dependency graph. Specifically:
      - `dashboard_user.dart`: probably no imports needed (pure Dart class).
      - `material_item.dart`: needs `package:flutter/material.dart` (for `Color`).
      - `session_item.dart` / `app_notification.dart` / `chat_message.dart`: need `package:cloud_firestore/cloud_firestore.dart` (for `Timestamp`, `QueryDocumentSnapshot<Map<String,dynamic>>`).
      - `learning_material.dart`: needs `package:cloud_firestore/cloud_firestore.dart` and possibly an enum `MaterialType` — if the enum is defined in materials_viewmodel.dart, EXTRACT IT TOO into `lib/data/models/learning_material.dart` (the enum belongs with its model). Confirm by reading the actual source.
      - `material_search_hit.dart`: needs an import of `package:mentor_minds/data/models/learning_material.dart` for the `fromLearningMaterial(LearningMaterial m)` factory.

    Step D — Repeat for all 19 clean-extraction entries. Group commits sensibly (one commit per source viewmodel file is fine — e.g. "extract 6 models from dashboard_viewmodel.dart"); the SUMMARY records the commit boundaries.

    DO NOT touch anything else in the viewmodel files. No reformatting, no comment cleanup, no whitespace changes, no `withOpacity` fixes. The viewmodel diff per file should be: N imports added + N class blocks deleted.

    Spot-check after each viewmodel edit: `flutter analyze lib/application/viewmodels/<feature>/<vm>.dart` should report 0 errors (info-level hits may persist — that's fine, this plan does not target those).
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ls lib/data/models/*.dart 2>/dev/null | wc -l | tr -d ' ' | xargs -I{} test {} -ge 19</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; for f in dashboard_user rewards_snapshot subject_progress session_item material_item badge_item chat_message app_notification profile_user profile_stats rewards_doc points_history milestone history_entry earned_badge locked_badge learning_material material_search_hit session_search_hit; do test -f "lib/data/models/${f}.dart" || { echo "MISSING: lib/data/models/${f}.dart"; exit 2; }; done</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -nE '^class (DashboardUser|RewardsSnapshot|SubjectProgress|SessionItem|MaterialItem|BadgeItem|ChatMessage|AppNotification|ProfileUser|ProfileStats|RewardsDoc|PointsHistory|Milestone|HistoryEntry|EarnedBadge|LockedBadge|LearningMaterial|MaterialSearchHit|SessionSearchHit)\b' lib/application/viewmodels/**/*.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --fatal-warnings 2>&amp;1 | tee /tmp/p1-04-t1-analyze.txt &amp;&amp; ! grep -qE '^\s*(error|warning) -' /tmp/p1-04-t1-analyze.txt</automated>
  </verify>
  <acceptance_criteria>
    - At least 19 `.dart` files exist under `lib/data/models/` (the 19 clean extractions; the 2 collision targets land in Task 2).
    - Each of the 19 named target files exists (per-file `test -f` check).
    - No viewmodel under `lib/application/viewmodels/**` still declares any of the 19 extracted classes at the top level (grep returns zero matches for `^class <Name>` anywhere under viewmodels).
    - `flutter analyze --fatal-warnings` exits 0 with no `error -` or `warning -` lines — the analyzer confirms imports resolve and types are consistent.
    - No new file under `lib/data/models/` imports anything from `lib/presentation/` or `lib/application/` (models are leaves; verified in Task 3's lint sweep).
  </acceptance_criteria>
  <done>
    19 of 21 inline classes are extracted, each in its own flat file under `lib/data/models/`. Viewmodel bodies have lost the class declarations and gained import lines — nothing else. `flutter analyze --fatal-warnings` is green. Task 2 handles the two remaining collision cases.
  </done>
</task>

<task type="auto">
  <name>Task 2: Resolve BadgeInfo + LeaderboardEntry collisions (2 canonical files)</name>
  <files>lib/data/models/badge_info.dart, lib/data/models/leaderboard_entry.dart, lib/application/viewmodels/rewards/gamification_viewmodel.dart, lib/application/viewmodels/rewards/rewards_viewmodel.dart</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-PATTERNS.md (§ DUPLICATE MODEL FLAG lines 138-217 — full text of both BadgeInfo definitions and the verdict "signatures identical, extract one canonical"; full text of both LeaderboardEntry definitions and the verdict "rewards_viewmodel definition is the superset — 7 fields with `subject`")
    - /Users/arnobrizwan/Mentor-Mind/lib/application/viewmodels/rewards/gamification_viewmodel.dart (current state at post-Plan-03 path)
    - /Users/arnobrizwan/Mentor-Mind/lib/application/viewmodels/rewards/rewards_viewmodel.dart (current state at post-Plan-03 path)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md (§ Open Questions item 1 lines 930-934 — the planner-recommended field reconciliation; § Assumptions Log A6 — fields are compatible)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-CONTEXT.md (D-03 — flat, one file per entity)
  </read_first>
  <action>
    Two extractions, each consuming TWO source files. Order matters: do BadgeInfo first because PATTERNS.md confirms the signatures are byte-identical and the extraction is mechanical; then LeaderboardEntry which requires the superset selection.

    Step A — BadgeInfo canonicalization:
      1. Read both definitions side-by-side: `gamification_viewmodel.dart` (the class block starting at `class BadgeInfo {`, ~6 fields) and `rewards_viewmodel.dart` (same class). Confirm with a literal text comparison that the two class bodies are character-identical except possibly surrounding whitespace. PATTERNS.md line 186 asserts this; verify locally as a sanity check.
      2. Create `lib/data/models/badge_info.dart` containing a single `class BadgeInfo` with the six fields: `id`, `emoji`, `name`, `description`, `unlockHint`, `target` (the last nullable `int?`). Const constructor with all `required` named parameters except `target` (which is optional). No `fromDoc` factory — `BadgeInfo` is a catalog descriptor, not a Firestore-decoded type. Copy comment headers if either source file had them.
      3. In `gamification_viewmodel.dart`: delete the inline `class BadgeInfo {...}` block (lines ~31-46 per PATTERNS.md). Add `import 'package:mentor_minds/data/models/badge_info.dart';` near the top. DO NOT touch the private `_catalog` constant — it stays inside this viewmodel as `List<BadgeInfo> _catalog = const [...]`.
      4. In `rewards_viewmodel.dart`: same — delete the inline `class BadgeInfo {...}` block (lines ~14-29), add the import. The `_allBadges` private constant stays as a file-local catalog.
      5. Run `flutter analyze --fatal-warnings`. Expect 0 errors. The two private catalogs now both reference the canonical `BadgeInfo` type from `lib/data/models/badge_info.dart`, which is what we want.

    Step B — LeaderboardEntry canonicalization:
      1. Compare the two definitions: gamification's 6-field version vs rewards' 7-field version. PATTERNS.md line 209 documents the difference: rewards has an extra `final String? subject;` field (top-subject tag).
      2. Create `lib/data/models/leaderboard_entry.dart` containing the 7-field SUPERSET (the rewards version): `uid`, `name`, `avatarUrl` (nullable), `points`, `subject` (nullable), `rank`, `isCurrentUser`. Const constructor. Optional `fromDoc`/`toMap` if the original rewards_viewmodel definition had them — copy verbatim; do not add.
      3. In `rewards_viewmodel.dart`: delete the inline `class LeaderboardEntry {...}` block (lines ~151-168), add `import 'package:mentor_minds/data/models/leaderboard_entry.dart';`.
      4. In `gamification_viewmodel.dart`: delete the inline 6-field `class LeaderboardEntry {...}` block (lines ~149-164), add the same import. Where the gamification viewmodel constructs `LeaderboardEntry` instances (likely in a `_buildLeaderboard()` or similar method), no constructor call edits are needed — the canonical class has `subject` as nullable, so existing constructor calls that omit it still compile (the field defaults to `null`).
      5. Run `flutter analyze --fatal-warnings`. Expect 0 errors. If any `LeaderboardEntry(...)` constructor call in gamification_viewmodel now fails because it was passing positional args that no longer line up, the call uses ALL-named arguments per the codebase convention (CLAUDE.md § Function & Method Design — named parameters for >2 args). If positional args were used, they would have been a code smell flagged by Plan 03's analyze; the conversion to all-named is part of the move but no behavior changes.

    Step C — Sanity grep + final analyze:
      Confirm both classes now exist exactly once in `lib/data/models/` and zero times elsewhere:
        `grep -rln "^class BadgeInfo" lib/` → must return exactly one path: `lib/data/models/badge_info.dart`.
        `grep -rln "^class LeaderboardEntry" lib/` → must return exactly one path: `lib/data/models/leaderboard_entry.dart`.
      Run `flutter analyze --fatal-warnings` to confirm green.

    Commit message: `refactor(models): canonicalize BadgeInfo + LeaderboardEntry (Phase 1 / ARCH-02; merge per PATTERNS.md duplicate-model flag)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f lib/data/models/badge_info.dart &amp;&amp; test -f lib/data/models/leaderboard_entry.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; n=$(grep -rln "^class BadgeInfo\b" lib/ | wc -l | tr -d ' '); test "$n" -eq 1 &amp;&amp; grep -rln "^class BadgeInfo\b" lib/ | grep -q '^lib/data/models/badge_info\.dart$'</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; n=$(grep -rln "^class LeaderboardEntry\b" lib/ | wc -l | tr -d ' '); test "$n" -eq 1 &amp;&amp; grep -rln "^class LeaderboardEntry\b" lib/ | grep -q '^lib/data/models/leaderboard_entry\.dart$'</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -c 'package:mentor_minds/data/models/badge_info\.dart' lib/application/viewmodels/rewards/gamification_viewmodel.dart lib/application/viewmodels/rewards/rewards_viewmodel.dart | awk -F: '{sum+=$2} END{exit (sum>=2)?0:1}'</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --fatal-warnings 2>&amp;1 | tee /tmp/p1-04-t2-analyze.txt &amp;&amp; ! grep -qE '^\s*(error|warning) -' /tmp/p1-04-t2-analyze.txt</automated>
  </verify>
  <acceptance_criteria>
    - `lib/data/models/badge_info.dart` exists and contains exactly one `class BadgeInfo` declaration.
    - `lib/data/models/leaderboard_entry.dart` exists and contains exactly one `class LeaderboardEntry` declaration with 7 fields including `subject`.
    - `grep -rln "^class BadgeInfo\b" lib/` returns exactly one path: `lib/data/models/badge_info.dart` (the inline definitions in both rewards viewmodels are gone).
    - `grep -rln "^class LeaderboardEntry\b" lib/` returns exactly one path: `lib/data/models/leaderboard_entry.dart`.
    - Both `gamification_viewmodel.dart` and `rewards_viewmodel.dart` import `package:mentor_minds/data/models/badge_info.dart` (combined count across both files ≥ 2).
    - `flutter analyze --fatal-warnings` exits 0 with no `error -` or `warning -` lines.
  </acceptance_criteria>
  <done>
    Both duplicate-class collisions are resolved per PATTERNS.md verdicts: `BadgeInfo` is one identical-signature class, `LeaderboardEntry` is the 7-field superset. Both rewards viewmodels import from the canonical model files. The two private badge catalogs (`_catalog`, `_allBadges`) remain inside their respective viewmodels — they are file-local data, not part of the model layer.
  </done>
</task>

<task type="auto">
  <name>Task 3: Final analyze + custom_lint sweep + model layer invariant check</name>
  <files>(no edits — verification only)</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md (§ Per-Task Verification Map — row 04-model-extraction; "All inline domain models live in lib/data/models/ and round-trip via fromDoc/toMap")
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-02-custom-lint-plugin-PLAN.md (must_haves — the layered_imports rule's exact predicate; `lib/data/**` cannot import `lib/presentation/...`)
  </read_first>
  <action>
    Run the three invariant checks that prove ARCH-02 is closed and that the model extraction did not introduce a new layered_imports violation.

    Step A — File count + path invariants:
      - Confirm 20 or 21 .dart files exist under `lib/data/models/` (19 clean + 2 collision = 21; a file count of 20 is acceptable IF the source verification confirms `LockedBadge` was inlined into `EarnedBadge.dart` or similar — but PATTERNS.md lists them separately, so 21 is the expected default). Record the actual count in SUMMARY.md.
      - Confirm no model file imports anything from `lib/presentation/` or `lib/application/`.

    Step B — `dart run custom_lint` delta:
      Compare current `dart run custom_lint` output against the Plan 03 baseline (recorded in 01-03-SUMMARY.md as the `layered_imports` violation count from screen files importing Firebase SDKs). The delta after this plan MUST be zero — model extraction does not change which Firebase imports live under `lib/presentation/`. Run the linter and verify the count of `layered_imports` lines is unchanged (or has only decreased if any moved screen happened to lose a Firebase import indirectly — which it should not for pure model extraction).

    Step C — Pre-Plan-05 baseline doc:
      Record in SUMMARY.md the COUNT of viewmodel files (under `lib/application/viewmodels/**`) that still directly import any of:
        - `package:cloud_firestore/`
        - `package:firebase_auth/`
        - `package:firebase_storage/`
      These are the imports Plan 05 will replace with repository providers. The baseline is "all of them except `splash_viewmodel.dart` and `onboarding_viewmodel.dart`" (the latter only uses SharedPreferences). Record the exact list so Plan 05 has a closed work-set.

    Commit message for any Task 1/2 work not yet committed: `refactor(models): complete ARCH-02 — extract 21 inline classes to lib/data/models/ (Phase 1)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; n=$(ls lib/data/models/*.dart 2>/dev/null | wc -l | tr -d ' '); test "$n" -ge 20</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -RIn -E "import 'package:mentor_minds/(presentation|application)/" lib/data/models/ 2>/dev/null</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; dart run custom_lint 2>&amp;1 | tee /tmp/p1-04-t3-lint.log; baseline=$(grep -c 'layered_imports' .planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-03-pure-git-mv-refactor-SUMMARY.md 2>/dev/null || echo 0); current=$(grep -c 'layered_imports' /tmp/p1-04-t3-lint.log || echo 0); echo "baseline=$baseline current=$current"; test "$current" -le "$baseline" 2>/dev/null || test "$current" -ge 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --fatal-warnings 2>&amp;1 | tee /tmp/p1-04-t3-analyze.txt &amp;&amp; ! grep -qE '^\s*(error|warning) -' /tmp/p1-04-t3-analyze.txt</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -RIln "^import 'package:(cloud_firestore|firebase_auth|firebase_storage)/" lib/application/viewmodels/ | tee /tmp/p1-04-t3-vm-firebase-imports.txt | wc -l | tr -d ' '</automated>
  </verify>
  <acceptance_criteria>
    - 20 or more `.dart` files exist under `lib/data/models/` (19 clean + 2 collision; LockedBadge may or may not get its own file based on whether it was inline-grouped with EarnedBadge — record the count).
    - No file under `lib/data/models/` imports anything from `lib/presentation/` or `lib/application/` (model layer is a graph leaf; verified via grep).
    - `dart run custom_lint` output for `layered_imports` lines is unchanged or strictly lower than the Plan 03 baseline (recorded count in `01-03-SUMMARY.md`). The count must NOT increase.
    - `flutter analyze --fatal-warnings` exits 0 with no `error -` or `warning -` lines.
    - `/tmp/p1-04-t3-vm-firebase-imports.txt` contains the list of viewmodels still directly importing Firebase SDKs — this is the closed work-set for Plan 05 and is copied into SUMMARY.md.
  </acceptance_criteria>
  <done>
    ARCH-02 is closed. All inline models are extracted into `lib/data/models/` as flat per-entity files per D-03. The two known collisions (`BadgeInfo`, `LeaderboardEntry`) are resolved per PATTERNS.md verdicts. `MaterialItem` and `LearningMaterial` remain separate files per PATTERNS.md verdict. The model layer is a clean graph leaf (no imports from application or presentation). Plan 05 can begin repository extraction with a known list of viewmodels that still directly call Firebase SDKs.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| viewmodel → model layer | Models are leaves of the dependency graph; any back-edge (model importing viewmodel/screen) would create a cycle and is forbidden by the layered_imports rule |
| duplicate-class boundary | The two collision targets (BadgeInfo, LeaderboardEntry) must collapse to exactly one canonical class each — a residual second definition silently shadows imports and breaks at runtime when Firestore decodes into the "wrong" class |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-1-DUPCLASS | Tampering | Two-of-each `BadgeInfo` / `LeaderboardEntry` definitions in the source tree | mitigate | Task 2 deletes both inline definitions, creates one canonical class per entity; Task 3 `grep -rln "^class BadgeInfo\b" lib/` invariant asserts exactly one definition exists, located at `lib/data/models/badge_info.dart` |
| T-1-MODELCYCLE | Tampering | A model file accidentally importing from `lib/presentation/` or `lib/application/` would create a cycle (data → presentation → application → data) and silently allow presentation to call into the application layer through a "model" backdoor | mitigate | Task 3 greps for any such import in `lib/data/models/` and asserts zero matches; `layered_imports` rule from Plan 02 will catch this at CI time once `lib/data/**` is populated |
| T-1-BODYEDIT | Tampering | Sneaking logic edits into the same commit as model extraction (analogous to T-1-DIFF-CONTAMINATION from Plan 03) | mitigate | Task 1 acceptance criterion: viewmodel diffs are "N imports added + N class blocks deleted" — any other change in a viewmodel diff is a violation; SUMMARY.md records per-file line-counts to make this visible |
</threat_model>

<verification>
- 20+ files exist under `lib/data/models/` (19 clean extractions + 2 collision targets).
- Zero residual inline class definitions for the 21 extracted classes anywhere outside `lib/data/models/`.
- `flutter analyze --fatal-warnings` exits 0.
- `dart run custom_lint` count of `layered_imports` lines is ≤ the Plan 03 baseline.
- Zero model files import from `lib/presentation/` or `lib/application/`.
- Pre-Plan-05 baseline of viewmodels still directly importing Firebase SDKs is recorded in SUMMARY.md.
</verification>

<success_criteria>
- D-03 honored: all extracted models live FLAT under `lib/data/models/`, one file per entity, no barrel files.
- D-14 honored: viewmodel diffs are strictly "delete class block + add import" — no logic edits.
- Two known collisions (`BadgeInfo`, `LeaderboardEntry`) resolved per PATTERNS.md verdicts.
- `MaterialItem` vs `LearningMaterial` kept as SEPARATE files per PATTERNS.md verdict (they are distinct projections).
- ARCH-02 is closed.
- Plan 05 has a known, finite list of viewmodels to refactor onto repository providers (T-1-LAYER closure target).
</success_criteria>

<output>
Create `.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-04-model-extraction-SUMMARY.md` when done. Record: the literal `ls lib/data/models/` output, the line-count for each new model file, per-viewmodel diff stats (N imports added, N class blocks deleted, total lines removed), the `grep -rln "^class BadgeInfo\b" lib/` and equivalent LeaderboardEntry invariant outputs, the `flutter analyze` exit code, the `dart run custom_lint` count of `layered_imports` lines vs the Plan 03 baseline, and the verbatim contents of `/tmp/p1-04-t3-vm-firebase-imports.txt` (the closed work-set for Plan 05).
</output>
