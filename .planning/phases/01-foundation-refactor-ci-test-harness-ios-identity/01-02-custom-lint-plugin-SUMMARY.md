---
phase: 01-foundation-refactor-ci-test-harness-ios-identity
plan: 02
subsystem: infra
tags: [custom_lint, riverpod_lint, layered_architecture, lint_rule, analyzer_plugin]

# Dependency graph
requires:
  - phase: 01-01-deps-and-emulators
    provides: clean pubspec.yaml that resolves; flutter_riverpod direct dep
provides:
  - Project-local custom_lint plugin package at tool/lints/ that ships a single rule (layered_imports).
  - Rule bans Firebase SDK imports inside lib/presentation/** and bans lib/data/** importing lib/presentation/**.
  - dart run custom_lint wired into the repo (CI gate is Plan 01-10).
  - riverpod_lint ^2.6.5 dev_dep installed (matches Riverpod 2.6.1; refuses ^3.x which requires Riverpod 3).
  - T-1-LAYER mitigation operational before any file moves into lib/presentation/ or lib/data/.
affects: [Plan 01-03 pure git mv refactor, Plan 01-04 model extraction, Plan 01-05 repository extraction, Plan 01-10 GitHub Actions CI, every Phase 2+ feature plan that writes under lib/]

# Tech tracking
tech-stack:
  added:
    - custom_lint ^0.7.6 (host)
    - riverpod_lint ^2.6.5 (host)
    - mentormind_lints (host path-dep → tool/lints)
    - custom_lint_builder ^0.7.0 (tool/lints, resolved 0.7.6)
    - analyzer ^7.0.0 (tool/lints, resolved 7.6.0)
  patterns:
    - "Project-local lint package layout — host pubspec.yaml dev_dep with `path: tool/lints`; analyzer.plugins: [custom_lint] in analysis_options.yaml; rule file under tool/lints/lib/src/."
    - "Two-import bans expressed as separate predicates within a single DartLintRule (one rule, two violation paths) — keeps the registered rule set short."

key-files:
  created:
    - tool/lints/pubspec.yaml
    - tool/lints/pubspec.lock
    - tool/lints/lib/mentormind_lints.dart
    - tool/lints/lib/src/layered_imports.dart
  modified:
    - pubspec.yaml
    - pubspec.lock
    - analysis_options.yaml

key-decisions:
  - "Honoured D-08: a single layered_imports rule covers both bans (presentation→firebase + data→presentation) rather than splitting into two rule ids. Keeps SUMMARY metrics and CI output clean."
  - "Honoured D-08 dep set: custom_lint + riverpod_lint + mentormind_lints (path). riverpod_lint stays on ^2.x to match Riverpod 2.6.1."
  - "Deviated from PLAN's pin on custom_lint ^0.7.7 — that version does not exist on pub.dev (latest in ^0.7.x is 0.7.6). Downgraded to ^0.7.6 per pub solver's suggestion. ^0.8.x would force an analyzer major bump which is out of Phase 1 scope."
  - "Imported ErrorSeverity via `package:analyzer/error/error.dart` (with `show ErrorSeverity` to avoid a LintCode symbol clash between analyzer and custom_lint_builder)."
  - "Used `reporter.atNode(node, code)` per custom_lint_builder ^0.7 API (newer signature; older builds used reportErrorForNode — confirmed against the installed package surface after pub get)."
  - "Exempted lib/core/** and lib/application/** by predicate — the rule's run() short-circuits if the source path is neither under /lib/presentation/ nor /lib/data/."

patterns-established:
  - "Canary-test proof of life — before a new lint rule lands, induce two RED states (one per banned predicate) with temporary files at the policed paths, capture the violation logs, then revert. Prevents silent no-op rules (T-1-LINT-FALSE-NEG)."
  - "When a banned-import predicate target path does not yet exist (Plan 03 hasn't moved files yet), the rule still loads via analysis_options.yaml and quietly polices nothing — proven by a clean baseline run."

requirements-completed: [ARCH-01, QUAL-04]

# Metrics
duration: ~30min
completed: 2026-05-17
---

# Plan 01-02: Custom Lint Plugin Summary

**Project-local custom_lint plugin at tool/lints/ ships the layered_imports rule; bans Firebase SDKs in presentation and data→presentation imports; rule provably fires on both predicates via canary tests.**

## Performance

- **Duration:** ~30 min (single batched task pass per user direction)
- **Started:** 2026-05-17 (right after Plan 01-01 closeout)
- **Completed:** 2026-05-17
- **Tasks:** 3 (1 implementation, 1 analyzer wiring, 1 canary proof)
- **Files modified:** 3 modified + 4 created

## Accomplishments

- New self-contained Dart package at `tool/lints/` with a `LayeredImportsRule extends DartLintRule` that polices the layered import discipline (T-1-LAYER mitigation).
- Host pubspec wires `custom_lint`, `riverpod_lint`, and the path-dep `mentormind_lints`; both `flutter pub get` and `dart pub get` (inside tool/lints) resolve cleanly with zero conflicts.
- `analysis_options.yaml` registers the `custom_lint` analyzer plugin so the rule runs in IDE + `dart run custom_lint` CLI.
- **Both bans proven alive via canary tests**: Firebase import inside `lib/presentation/__canary__.dart` triggers `layered_imports`; `package:mentor_minds/presentation/foo.dart` import inside `lib/data/__canary__.dart` also triggers it. Tree-clean after canary cleanup (git porcelain empty on `lib/presentation lib/data`).
- `flutter analyze --fatal-warnings` continues to exit 0 — the new analyzer plugin does not promote any of the existing 155 info-level hits.

## Task Commits

1. **Task 1: Scaffold tool/lints/ + wire host pubspec** — bundled into `53cdb5f`
2. **Task 2: analysis_options.yaml — register custom_lint plugin** — bundled into `53cdb5f`
3. **Task 3: Canary RED proof (presentation + data) → final GREEN** — no commit (canaries written + reverted within task)

**Plan implementation commit:** `53cdb5f feat(lints): add project-local custom_lint plugin enforcing layered imports (Phase 1 / D-08, ARCH-01, QUAL-04)`

Tasks 1 and 2 were bundled into a single commit because Task 2 is a 5-line edit and Task 1's pub-resolution gate is what makes Task 2 meaningful — splitting them would leave a transient commit where `analysis_options.yaml` references a plugin whose deps may not have resolved yet.

## Files Created/Modified

**Created:**
- `tool/lints/pubspec.yaml` — local Dart package manifest (name: mentormind_lints, sdk >=3.0.0 <4.0.0, deps: custom_lint_builder ^0.7.0 + analyzer ^7.0.0).
- `tool/lints/pubspec.lock` — captures resolved versions for reproducibility (custom_lint_builder 0.7.6, analyzer 7.6.0).
- `tool/lints/lib/mentormind_lints.dart` — exports `createPlugin()` returning `_MentorMindLints extends PluginBase`; registers one rule.
- `tool/lints/lib/src/layered_imports.dart` — `LayeredImportsRule` with two banned-import predicates and a const `LintCode` (rule id `layered_imports`, severity ERROR).

**Modified:**
- `pubspec.yaml` — added 3 dev_deps under a new "Lints (Phase 1 / D-08, QUAL-04)" comment block.
- `pubspec.lock` — regenerated by `flutter pub get`.
- `analysis_options.yaml` — added `analyzer:` / `  plugins:` / `    - custom_lint` block between the existing `include:` line and the `linter:` block.

## Decisions Made

- **`custom_lint ^0.7.6` instead of PLAN's `^0.7.7`** — pub solver refused PLAN's pin (0.7.7 does not exist on pub.dev; 0.7.6 is the latest in the ^0.7 line). Downgrading by one patch is the minimal-blast-radius fix and the only path that keeps us on the ^0.7 analyzer surface. PLAN's intent was clearly "the latest 0.7.x" — defect, not a substantive disagreement.
- **Single rule covers both bans** — kept the registered rule set to one (`layered_imports`) per D-08 wording; rule body has two predicates internally. Splitting into `presentation_no_firebase` + `data_no_presentation` would have generated noisier CI output without adding analytic value.
- **`show ErrorSeverity` on the analyzer import** — `LintCode` is exported by both `package:analyzer/error/error.dart` and `package:custom_lint_builder`. The custom_lint_builder version is the one `DartLintRule.super(code: ...)` expects, so the analyzer one is hidden via `show` to avoid the namespace collision.

## Deviations from Plan

### Auto-fixed Issues

**1. [Pub solver — version pin] PLAN's `custom_lint: ^0.7.7` does not exist**
- **Found during:** Task 1 (`flutter pub get` after wiring host pubspec)
- **Issue:** `Because mentor_minds depends on custom_lint ^0.7.7 which doesn't match any versions, version solving failed.` Latest in ^0.7.x is 0.7.6.
- **Fix:** Downgraded host `pubspec.yaml` constraint to `custom_lint: ^0.7.6`, with an inline comment explaining why we didn't jump to ^0.8.x (analyzer major bump out of Phase 1 scope).
- **Files modified:** `pubspec.yaml`
- **Verification:** Re-ran `flutter pub get`; exit 0; `custom_lint 0.7.6` listed in resolved set.
- **Committed in:** `53cdb5f` (bundled with the rest of Task 1).

**2. [Custom_lint_builder API — import collision] `LintCode` exported by both analyzer and custom_lint_builder**
- **Found during:** Task 1 (compile errors after first write of `layered_imports.dart`)
- **Issue:** Diagnostics reported `The name 'LintCode' is defined in the libraries 'package:analyzer/.../lint_codes.dart' and 'package:custom_lint_core/.../lint_codes.dart'.` Const constructor compilation failed because the analyzer's `LintCode` was being picked.
- **Fix:** Imported `package:analyzer/error/error.dart` with `show ErrorSeverity` so only `ErrorSeverity` is brought in from analyzer; let `LintCode` resolve from `custom_lint_builder`.
- **Files modified:** `tool/lints/lib/src/layered_imports.dart`
- **Verification:** `mcp__ide__getDiagnostics` returned empty for both files; `flutter pub get` clean.
- **Committed in:** `53cdb5f`.

**3. [Analyzer import path — original write] `ErrorSeverity` not exported by `listener.dart`**
- **Found during:** Task 1 (compile error on first write)
- **Issue:** Initial implementation imported `package:analyzer/error/listener.dart` (correct for `ErrorReporter`) but used `ErrorSeverity` from there. The analyzer split that enum into `error/error.dart`.
- **Fix:** Added the second import line.
- **Files modified:** `tool/lints/lib/src/layered_imports.dart`
- **Verification:** Diagnostics cleared.
- **Committed in:** `53cdb5f`.

---

**Total deviations:** 3 auto-fixed (1 version pin defect, 2 boilerplate-API corrections from running against the actually-resolved package versions)
**Impact on plan:** No scope creep. The PLAN explicitly noted (RESEARCH Assumption A1 + A5) that the `custom_lint_builder` API surface should be verified against the installed package; these three fixes are exactly that verification.

## Issues Encountered

- First `dart run custom_lint` call took ~30 seconds to bootstrap the analyzer server (cold cache). Subsequent runs were sub-2-second. Plan 01-10's CI step should expect a one-time slow run on cold runners.

## User Setup Required

None. The rule is repository-local; no external IDE config or token required. (IntelliJ / VS Code Dart extensions auto-discover `custom_lint` via `analysis_options.yaml`.)

## Next Phase Readiness

- ✓ Plan 01-03 (pure `git mv` refactor) can land safely — the moment a file moves into `lib/presentation/` or `lib/data/`, the rule starts policing it. Any forbidden import will be caught immediately by `dart run custom_lint`.
- ✓ Plan 01-05 (repository extraction) has the structural guard that will drive `layered_imports` violation count to zero.
- ✓ Plan 01-10 (GitHub Actions CI) can wire `dart run custom_lint` as a blocking step.
- ⚠ The rule does NOT exempt `lib/application/**` from anything (it doesn't need to — the predicates are scoped to presentation and data only). If a future plan introduces a presentation→application→data cyclic import discipline, that's a separate rule.

## Evidence — `dart run custom_lint` baseline (pre-canary)

```
Analyzing...

No issues found!
```

## Evidence — Presentation canary RED (Firebase import inside lib/presentation/)

```
Analyzing...

  lib/presentation/__canary__.dart:1:1 • Layered architecture violation: presentation must not import Firebase SDKs, and data must not import presentation. • layered_imports • ERROR

1 issue found.
```

## Evidence — Data canary RED (lib/data/ importing lib/presentation/)

```
Analyzing...

  lib/data/__canary__.dart:1:1 • Layered architecture violation: presentation must not import Firebase SDKs, and data must not import presentation. • layered_imports • ERROR

1 issue found.
```

## Evidence — Final GREEN (canaries reverted)

```
Analyzing...

No issues found!
```

`git status --porcelain lib/presentation lib/data` is empty (no leftover canary files, no leftover empty directories).

## Evidence — `analysis_options.yaml` diff (3 lines added)

```diff
 include: package:flutter_lints/flutter.yaml

+analyzer:
+  plugins:
+    - custom_lint
+
 linter:
```

---
*Phase: 01-foundation-refactor-ci-test-harness-ios-identity*
*Plan: 01-02-custom-lint-plugin*
*Completed: 2026-05-17*
