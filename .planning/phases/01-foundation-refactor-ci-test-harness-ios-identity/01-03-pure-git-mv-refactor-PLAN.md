---
phase: 01-foundation-refactor-ci-test-harness-ios-identity
plan: 03
type: execute
wave: 1
depends_on: ["01-01", "01-02"]
files_modified:
  - lib/features/**  (deleted via git mv)
  - lib/presentation/screens/**  (created via git mv — 11 screen files)
  - lib/application/viewmodels/**  (created via git mv — 11 viewmodel files)
  - lib/core/routes/app_router.dart  (import block fully rewritten)
autonomous: true
requirements: [ARCH-01]
requirements_addressed: [ARCH-01]
tags: [refactor, git_mv, layered_architecture, pr_a]

must_haves:
  truths:
    - "Every renamed file is reachable via `git log --follow` back to the commit that originally created it under `lib/features/`"
    - "`flutter analyze --fatal-warnings` exits 0 after the rename (no orphaned imports)"
    - "`dart run custom_lint` exits 0 on the new tree — the moved files do NOT import Firebase SDKs from presentation, because no body edits happened (D-14: pure git mv)"
    - "The legacy `lib/features/` directory does not exist on disk"
  artifacts:
    - path: "lib/presentation/screens/auth/login_screen.dart"
      provides: "Login screen at its new layered location"
      contains: "class LoginScreen"
    - path: "lib/application/viewmodels/dashboard/dashboard_viewmodel.dart"
      provides: "Dashboard ViewModel at its new layered location"
      contains: "class DashboardViewModel"
    - path: "lib/core/routes/app_router.dart"
      provides: "Updated router with 11 import paths rewritten to package:mentor_minds/presentation/screens/<feature>/<screen>.dart"
      contains: "package:mentor_minds/presentation/screens/"
  key_links:
    - from: "lib/core/routes/app_router.dart"
      to: "lib/presentation/screens/<feature>/<screen>.dart"
      via: "package import"
      pattern: "package:mentor_minds/presentation/screens/"
    - from: "lib/presentation/screens/<feature>/<screen>.dart"
      to: "lib/application/viewmodels/<feature>/<viewmodel>.dart"
      via: "package import"
      pattern: "package:mentor_minds/application/viewmodels/"
---

<objective>
PR-A: The pure `git mv` refactor (D-14). Move every file listed in PATTERNS.md § 1 from `lib/features/` to its corresponding location under `lib/presentation/screens/<feature>/` or `lib/application/viewmodels/<feature>/`, update every import path that referenced the old location, and DELETE the now-empty `lib/features/` tree — all in a single commit per batch so `git log --follow` preserves history (PITFALLS #5).

Purpose: This is the structural backbone of the entire phase. Splitting `git mv` from import-path updates across commits would break `git log --follow` for 22 files permanently. Splitting model extraction or body edits into this same commit set would conflate "did the file move?" with "did its content change?" — destroying bisect utility. Hence: pure rename + minimum-necessary import-path fixes, NOTHING else.

Output: 22 files at new locations, `git log --follow` continuity proven for 3+ representative files, `flutter analyze --fatal-warnings` green, `dart run custom_lint` green, `lib/features/` directory deleted.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-CONTEXT.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-PATTERNS.md
@CLAUDE.md
@lib/core/routes/app_router.dart

<interfaces>
<!-- Full source→target table from PATTERNS.md § 1 (lines 9-50). 22 files total. -->

11 Screens (lib/features/<x>/<x>_screen.dart → lib/presentation/screens/<x>/<x>_screen.dart):
  auth/login_screen.dart, auth/register_screen.dart, dashboard/dashboard_screen.dart,
  materials/materials_screen.dart, notifications/notifications_screen.dart,
  onboarding/onboarding_screen.dart, profile/profile_screen.dart,
  rewards/rewards_screen.dart, search/search_screen.dart,
  splash/splash_screen.dart, tutor/tutor_screen.dart

11 ViewModels (lib/features/<x>/<x>_viewmodel.dart → lib/application/viewmodels/<x>/<x>_viewmodel.dart):
  auth/auth_viewmodel.dart, dashboard/dashboard_viewmodel.dart,
  materials/materials_viewmodel.dart, notifications/notifications_viewmodel.dart,
  onboarding/onboarding_viewmodel.dart, profile/profile_viewmodel.dart,
  rewards/rewards_viewmodel.dart, rewards/gamification_viewmodel.dart (second VM in rewards),
  search/search_viewmodel.dart, splash/splash_viewmodel.dart,
  tutor/chat_viewmodel.dart (second VM in tutor)

Files that DO NOT MOVE:
  - lib/core/services/gemini_service.dart (stays — Phase 3 deletes it)
  - lib/core/** (entire core directory stays)
  - lib/main.dart (no changes — App Check is Phase 2)
  - lib/firebase_options.dart (regenerated in Plan 06 after bundle ID flip, not here)

Relative-import-depth shift:
  Before: lib/features/auth/login_screen.dart → '../../core/constants/app_colors.dart'
  After:  lib/presentation/screens/auth/login_screen.dart → '../../../core/constants/app_colors.dart'

  All 22 moved files use relative imports for lib/core/*; depth bumps from ../../ to ../../../.

Critical import-consumer file:
  lib/core/routes/app_router.dart imports ALL 11 screens. Its entire import block changes.
  The import path style changes from
    'package:mentor_minds/features/<x>/<x>_screen.dart'
  to
    'package:mentor_minds/presentation/screens/<x>/<x>_screen.dart'.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create target directory skeleton (no files moved yet)</name>
  <files>lib/presentation/screens/{auth,dashboard,materials,notifications,onboarding,profile,rewards,search,splash,tutor}/, lib/application/viewmodels/{auth,dashboard,materials,notifications,onboarding,profile,rewards,search,splash,tutor}/, lib/data/{models,repositories,services}/</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-PATTERNS.md (§ 1 — full source/target table)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md (§ Pattern 1: git mv Refactor — command pattern lines 290-320)
  </read_first>
  <action>
    Create the empty target directory skeleton. `git mv` cannot create destination parent directories; they must exist before the move.

    Run (from repo root):
    ```
    mkdir -p lib/presentation/screens/auth \
             lib/presentation/screens/dashboard \
             lib/presentation/screens/materials \
             lib/presentation/screens/notifications \
             lib/presentation/screens/onboarding \
             lib/presentation/screens/profile \
             lib/presentation/screens/rewards \
             lib/presentation/screens/search \
             lib/presentation/screens/splash \
             lib/presentation/screens/tutor
    mkdir -p lib/application/viewmodels/auth \
             lib/application/viewmodels/dashboard \
             lib/application/viewmodels/materials \
             lib/application/viewmodels/notifications \
             lib/application/viewmodels/onboarding \
             lib/application/viewmodels/profile \
             lib/application/viewmodels/rewards \
             lib/application/viewmodels/search \
             lib/application/viewmodels/splash \
             lib/application/viewmodels/tutor
    mkdir -p lib/data/models lib/data/repositories lib/data/services
    ```

    Do NOT add `.gitkeep` files — git will simply not track empty directories, but Task 2 will populate them before any commit, so the directory list above will be implicitly committed via the moved files. The `lib/data/*` directories WILL stay empty after this plan (Plans 04/05 populate them); they need `.gitkeep` files in those plans only if they remain empty at commit boundaries — for THIS plan, populating only presentation/ and application/ is fine.

    Do NOT touch `lib/features/` yet — that comes in Task 2.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -d lib/presentation/screens/auth &amp;&amp; test -d lib/presentation/screens/tutor &amp;&amp; test -d lib/application/viewmodels/rewards &amp;&amp; test -d lib/data/models &amp;&amp; test -d lib/data/repositories &amp;&amp; test -d lib/data/services</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ls -d lib/presentation/screens/*/ | wc -l | tr -d ' ' | xargs -I{} test {} -eq 10</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ls -d lib/application/viewmodels/*/ | wc -l | tr -d ' ' | xargs -I{} test {} -eq 10</automated>
  </verify>
  <acceptance_criteria>
    - All 10 presentation/screens/* and all 10 application/viewmodels/* subdirectories exist on disk.
    - All 3 data/* subdirectories (models, repositories, services) exist on disk.
    - `lib/features/` still exists and is untouched (verified by `test -d lib/features/auth`).
    - No `.gitkeep` files committed yet (the directories will be populated by Task 2 and Plans 04/05).
  </acceptance_criteria>
  <done>
    The empty target tree exists; Task 2 can `git mv` into it.
  </done>
</task>

<task type="auto">
  <name>Task 2: git mv 22 files + rewrite all consumer imports in a single commit</name>
  <files>lib/features/** (22 deletes), lib/presentation/screens/** (11 new), lib/application/viewmodels/** (11 new), lib/core/routes/app_router.dart (import block rewritten)</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-PATTERNS.md (§ 1 — full table of 22 source/target paths; § Critical import chain — app_router.dart is the single biggest consumer)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md (Pattern 1: git mv Refactor lines 290-328 — the "single commit" rule; § Common Pitfalls — Pitfall 1: separate commits destroy git log --follow)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-CONTEXT.md (D-14 — PR-1 is "pure structural change, no body logic edits"; § specifics: any "fix that one thing while I'm here" temptation is rejected)
    - /Users/arnobrizwan/Mentor-Mind/lib/core/routes/app_router.dart (current import block — all 11 imports need rewriting)
  </read_first>
  <action>
    The single critical task of this entire plan. Execute as one logical sequence; commit at the END after every check is green. DO NOT commit partial work — a `git mv` commit without the matching import-path fixes will not compile, and worse, `git log --follow` only tracks the rename if both happen together.

    Step A — Stage all 22 file moves:
    Execute the 22 `git mv` commands from PATTERNS.md § 1 (lines 17-43). Example for the auth feature:
    ```
    git mv lib/features/auth/login_screen.dart        lib/presentation/screens/auth/login_screen.dart
    git mv lib/features/auth/register_screen.dart     lib/presentation/screens/auth/register_screen.dart
    git mv lib/features/auth/auth_viewmodel.dart      lib/application/viewmodels/auth/auth_viewmodel.dart
    ```
    Repeat for dashboard, materials, notifications, onboarding, profile, rewards (3 files: rewards_screen, rewards_viewmodel, gamification_viewmodel), search, splash, tutor (3 files: tutor_screen, chat_viewmodel — wait, tutor has tutor_screen + chat_viewmodel per PATTERNS.md, NOT 3 files for tutor; confirm against the table).

    After all 22 `git mv` commands, the staging area shows 22 R (rename) entries. Do NOT commit yet — the tree does not compile.

    Step B — Fix relative imports inside the 22 moved files:
    Each moved file imports from `lib/core/*` using relative imports like `import '../../core/constants/app_colors.dart';` (depth from `lib/features/<feature>/`). After the move, the new depth from `lib/presentation/screens/<feature>/` (or `lib/application/viewmodels/<feature>/`) is one level deeper. Rewrite every `../../core/` to `../../../core/` inside the 22 moved files.

    Alternative (preferred for consistency with `app_router.dart`'s package-style imports): convert every relative `../../core/...` import inside the 22 moved files to absolute package imports `package:mentor_minds/core/...`. This avoids the depth-counting problem entirely and survives any future relocation.

    Pick ONE convention (relative-depth-bumped OR package-style) and apply it uniformly to all 22 files. Document the choice in SUMMARY.md.

    DO NOT touch ANY other content in these 22 files. No `withOpacity` fixes, no `mounted` adjustments, no comment cleanups, no whitespace tidying. The diff for each moved file must be: rename + import-path rewrite, nothing else. Spot-check this by running `git diff --cached -M --stat` and confirming each moved file shows a low number of additions/deletions (ideally just the import lines that changed).

    Step C — Rewrite consumer imports in `lib/core/routes/app_router.dart`:
    This file imports all 11 screens via `package:mentor_minds/features/<feature>/<feature>_screen.dart`. Rewrite each of the 11 import lines to `package:mentor_minds/presentation/screens/<feature>/<feature>_screen.dart`. The `package:` prefix style is correct — keep it; only the path segment after the package name changes from `features/<x>/` to `presentation/screens/<x>/`.

    Also search the rest of `lib/core/` for any other consumer imports of `package:mentor_minds/features/...` and rewrite them. Run:
    ```
    grep -rln 'package:mentor_minds/features/' lib/ test/ integration_test/ 2>/dev/null
    ```
    Every match (except literal strings inside test fixtures or documentation, which there are none yet) must be updated.

    Also rewrite cross-imports BETWEEN the 22 moved files. Examples:
    - A screen file imports its viewmodel: `package:mentor_minds/features/auth/auth_viewmodel.dart` → `package:mentor_minds/application/viewmodels/auth/auth_viewmodel.dart`
    - `chat_viewmodel.dart` imports nothing from another moved file but `tutor_screen.dart` imports `chat_viewmodel.dart` — rewrite to the new application/viewmodels/tutor/ path.
    - `rewards_screen.dart` may import both `rewards_viewmodel.dart` and `gamification_viewmodel.dart` — rewrite both.

    Step D — Delete the now-empty `lib/features/` tree:
    After all 22 `git mv` operations, `lib/features/` should contain only the 10 empty per-feature subdirectories. Remove them with `git rm -r lib/features/` (this only removes tracked emptiness; since no files remain, git just removes the directory structure from tracking).

    Step E — Verify before commit:
    1. `flutter analyze --fatal-warnings` — must exit 0. Any failure here is an unfixed import; resolve before committing.
    2. `dart run custom_lint` — must exit 0. (No Firebase imports should newly appear in lib/presentation/ because nothing has changed body-wise; if it RED-flags, you accidentally moved a file whose import block referenced Firebase, which is the existing-code violation that Plan 05 will fix. For Plan 03, the constraint is "no NEW custom_lint violations vs. the pre-move tree." If the rule already had violations in the pre-move tree they will persist post-move — that's fine; Plan 05 is the closure for ARCH-03.)

       Wait — re-check: the `layered_imports` rule polices `lib/presentation/**` and `lib/data/**`. Before this plan, NO files were under `lib/presentation/**`. After this plan, 11 screen files ARE under `lib/presentation/**` AND many of those screen files currently import Firebase SDKs directly (anti-pattern documented in CONVENTIONS.md). Therefore `dart run custom_lint` WILL be RED after this plan — and that is INTENDED. The rule fires; Plan 05 fixes the violations. The CI gate in Plan 10 will fail on this exact set of violations until Plan 05 lands.

       Update verification: after this plan, `dart run custom_lint` is EXPECTED to print `layered_imports` violations for screen files importing Firebase SDKs. The acceptance criterion below uses `grep -c` to count violations and compares against the count of screens that import Firebase — this is a tracking metric, not a green gate.

    3. `git log --follow` spot-check on 3 representative files (one from each layer-ish: a screen, a viewmodel, a viewmodel-with-second-companion):
       ```
       git log --follow --oneline -- lib/presentation/screens/dashboard/dashboard_screen.dart | wc -l
       git log --follow --oneline -- lib/application/viewmodels/auth/auth_viewmodel.dart    | wc -l
       git log --follow --oneline -- lib/application/viewmodels/rewards/gamification_viewmodel.dart | wc -l
       ```
       Each must return at least 2 lines (the move commit + at least one pre-move commit).

    Step F — Single commit:
    Commit message:
    ```
    refactor(arch): pure git mv lib/features/ → lib/presentation/screens/ + lib/application/viewmodels/ (PR-A, Phase 1 / ARCH-01)

    No body edits. No model extraction. No repo wiring. Subsequent plans (04 model
    extraction, 05 repository extraction) build on this commit.

    git log --follow preserved for all 22 moved files.
    ```

    Verify post-commit with `git diff HEAD~1 -M --stat` — the `-M` flag tells git to detect renames; the output must show 22 `R<NN>` rename entries (where `<NN>` is similarity %, ideally 100 except for the import-path adjustments).
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! test -d lib/features &amp;&amp; ls lib/presentation/screens/**/*.dart | wc -l | tr -d ' ' | xargs -I{} test {} -eq 11 &amp;&amp; ls lib/application/viewmodels/**/*.dart | wc -l | tr -d ' ' | xargs -I{} test {} -eq 11</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --fatal-warnings 2>&amp;1 | tee /tmp/p1-03-analyze.txt &amp;&amp; ! grep -qE '^\s*(error|warning) -' /tmp/p1-03-analyze.txt</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -RIn 'package:mentor_minds/features/' lib/ test/ integration_test/ 2>/dev/null</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; for f in lib/presentation/screens/dashboard/dashboard_screen.dart lib/application/viewmodels/auth/auth_viewmodel.dart lib/application/viewmodels/rewards/gamification_viewmodel.dart; do n=$(git log --follow --oneline -- "$f" | wc -l | tr -d ' '); test "$n" -ge 2 || { echo "FAIL: $f only has $n commits via --follow"; exit 2; }; done</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; git diff HEAD~1 -M --stat 2>&amp;1 | grep -cE '\=\>' | xargs -I{} test {} -ge 22</automated>
  </verify>
  <acceptance_criteria>
    - `lib/features/` directory does not exist (`! test -d lib/features`).
    - Exactly 11 `.dart` files exist under `lib/presentation/screens/**/` and exactly 11 under `lib/application/viewmodels/**/`.
    - `flutter analyze --fatal-warnings` exits 0 with no `error -` or `warning -` lines.
    - No file in `lib/`, `test/`, or `integration_test/` contains the string `package:mentor_minds/features/` (the old import path is fully purged).
    - `git log --follow --oneline -- <moved-file>` returns ≥2 commits for all three spot-checked files (`dashboard_screen.dart`, `auth_viewmodel.dart`, `gamification_viewmodel.dart`).
    - `git diff HEAD~1 -M --stat` shows at least 22 rename entries (`=>` arrow indicator).
    - `dart run custom_lint` produces a non-zero count of `layered_imports` violations from screen files importing Firebase SDKs (EXPECTED — Plan 05 closes these). Record the count in SUMMARY.md as a baseline.
    - The commit message starts with `refactor(arch):` and references PR-A + ARCH-01.
  </acceptance_criteria>
  <done>
    All 22 files are at their new layered locations, `git log --follow` works for every renamed file, `flutter analyze --fatal-warnings` is green, and the legacy `lib/features/` tree is gone. The `layered_imports` rule is now RED on screen files that import Firebase SDKs — Plan 05 closes those violations; the RED state is the intended "before" snapshot.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| git history boundary | `git log --follow` must continue to track each renamed file through the rename commit, or future archaeology breaks |
| no-body-edits boundary | If logic edits are mixed into the rename commit, `git bisect` for behavior regressions becomes unreliable |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-1-HISTORY | Repudiation | `git log --follow` continuity across 22 file renames | mitigate | Task 2 runs `git mv` + matching import-path fixes in a SINGLE commit per the D-14 PR-A rule; spot-check verifies ≥2 commits via `--follow` on 3 representative files |
| T-1-DIFF-CONTAMINATION | Tampering | Sneaking body edits into the rename commit | mitigate | Task 2 acceptance criterion explicitly forbids non-import edits; `git diff --cached -M --stat` is reviewed before commit; CONTEXT.md § specifics line "any temptation to 'fix that one thing while I'm here' in PR-1 is rejected" |
| T-1-LAYER-BASELINE | Information Disclosure | The pre-Plan-05 RED state of `layered_imports` rule | accept | Plan 05 (ARCH-03) is the closure for these violations; Plan 03 records the baseline count in SUMMARY.md; CI workflow in Plan 10 will fail on this delta until Plan 05 merges — that's the intended design |
</threat_model>

<verification>
- `flutter analyze --fatal-warnings` exits 0 post-commit.
- `git log --follow` returns ≥2 commits for 3 representative renamed files.
- No `package:mentor_minds/features/` strings remain anywhere under `lib/`, `test/`, or `integration_test/`.
- `lib/features/` does not exist.
- 11 screens under `lib/presentation/screens/**/` + 11 viewmodels under `lib/application/viewmodels/**/`.
- The `dart run custom_lint` baseline RED count is captured in SUMMARY.md (becomes the target for Plan 05 to zero out).
</verification>

<success_criteria>
- D-14 PR-A constraint honored: a single commit contains ONLY rename + import-path fixes, nothing else.
- ARCH-01 file-layout requirement (presentation/application split) met for all 22 files.
- `git log --follow` continuity preserved.
- Downstream plans (04 model extraction, 05 repo extraction) can build on this commit with confidence that file moves are settled.
</success_criteria>

<output>
Create `.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-03-pure-git-mv-refactor-SUMMARY.md` when done. Record: the literal output of `git diff HEAD~1 -M --stat`, the `git log --follow --oneline` snippet for the three spot-checked files, the `dart run custom_lint` baseline count of `layered_imports` violations (this is the closure target for Plan 05), and the import convention chosen (relative-depth-bumped vs. package-style) for the moved files.
</output>
