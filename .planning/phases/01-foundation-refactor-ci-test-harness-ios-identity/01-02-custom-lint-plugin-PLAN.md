---
phase: 01-foundation-refactor-ci-test-harness-ios-identity
plan: 02
type: execute
wave: 0
depends_on: ["01-01"]
files_modified:
  - pubspec.yaml
  - analysis_options.yaml
  - tool/lints/pubspec.yaml
  - tool/lints/lib/mentormind_lints.dart
  - tool/lints/lib/src/layered_imports.dart
autonomous: true
requirements: [ARCH-01, QUAL-04]
requirements_addressed: [ARCH-01, QUAL-04]
tags: [custom_lint, riverpod_lint, layered_architecture, ci_gate]

must_haves:
  truths:
    - "D-08: Layer enforcement uses `custom_lint` + `riverpod_lint` + a project-local custom_lint rule package (`tool/lints/`); rule bans Firebase SDK imports in `lib/presentation/**` and bans `lib/data/**` importing `lib/presentation/**`"
    - "`dart run custom_lint` exits 0 on the current (pre-refactor) tree, proving the plugin loads and the rule is wired"
    - "Adding a Firebase SDK import inside any file under `lib/presentation/` causes `dart run custom_lint` to report a `layered_imports` violation with the offending line/file"
    - "Adding an import of `package:mentor_minds/presentation/...` inside any file under `lib/data/` causes `dart run custom_lint` to report a `layered_imports` violation"
  artifacts:
    - path: "tool/lints/pubspec.yaml"
      provides: "Project-local custom_lint plugin package manifest"
      contains: "custom_lint_builder"
    - path: "tool/lints/lib/mentormind_lints.dart"
      provides: "createPlugin() entry point that registers the layered_imports rule"
      contains: "PluginBase"
    - path: "tool/lints/lib/src/layered_imports.dart"
      provides: "DartLintRule implementation banning Firebase imports in presentation and data->presentation imports"
      contains: "DartLintRule"
    - path: "analysis_options.yaml"
      provides: "Custom_lint plugin registration for IDE + CLI"
      contains: "custom_lint"
  key_links:
    - from: "pubspec.yaml (host)"
      to: "tool/lints/"
      via: "dev_dependencies: { mentormind_lints: { path: tool/lints } }"
      pattern: "mentormind_lints:\\s*\\n\\s*path:\\s*tool/lints"
    - from: "analysis_options.yaml"
      to: "custom_lint runner"
      via: "analyzer.plugins: [custom_lint]"
      pattern: "plugins:.*custom_lint"
---

<objective>
Wave 0 lint scaffolding. Author the project-local `custom_lint` plugin package at `tool/lints/`, wire it into the host `pubspec.yaml` + `analysis_options.yaml`, and prove with a temporary "canary" file that the `layered_imports` rule fires on (a) Firebase SDK imports under `lib/presentation/**` and (b) `lib/data/**` files that import from `lib/presentation/**`. Removes the canary after the proof.

Purpose: This rule is the structural guard that prevents any later phase from regressing the layered import discipline (T-1-LAYER). It MUST land BEFORE the `git mv` refactor in Plan 03 so the CI gate can catch a slip the moment the refactor moves files into `lib/presentation/`. We deliberately don't make the rule fail on Plan 02's tree (the tree is still `lib/features/`); the rule starts catching violations the instant Plan 03 moves files into `lib/presentation/`.

Output: A passing `dart run custom_lint` on the current tree, plus a proven-firing rule via the canary test that we then revert.
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
@CLAUDE.md
@analysis_options.yaml
@pubspec.yaml

<interfaces>
<!-- custom_lint_builder API surface (RESEARCH § Pattern 4, lines 444-508) -->

Plugin entry point shape (`tool/lints/lib/mentormind_lints.dart`):
```
PluginBase createPlugin() => _MentorMindLints();
class _MentorMindLints extends PluginBase {
  List<LintRule> getLintRules(CustomLintConfigs configs) => [LayeredImportsRule()];
}
```

Rule shape (`tool/lints/lib/src/layered_imports.dart`):
```
class LayeredImportsRule extends DartLintRule {
  LayeredImportsRule() : super(code: const LintCode(
    name: 'layered_imports',
    problemMessage: '...',
    correctionMessage: '...',
    errorSeverity: ErrorSeverity.ERROR,
  ));
  void run(CustomLintResolver, ErrorReporter, CustomLintContext) {
    context.registry.addImportDirective((node) => ...);
  }
}
```

Banned import predicates (D-08):
1. If current file path contains `/lib/presentation/` AND import URI starts with
   `package:cloud_firestore`, `package:firebase_auth`, `package:firebase_storage`,
   or `package:firebase_messaging` → report violation.
2. If current file path contains `/lib/data/` AND import URI starts with
   `package:mentor_minds/presentation/` → report violation.

Exemptions:
- `lib/core/**` is NOT linted by this rule (it is the cross-layer foundation).
- `lib/application/**` is NOT linted by THIS rule (presentation→data passes through
  application; the rule's job is presentation-vs-data, not transitive layering).
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Scaffold tool/lints/ plugin package and wire host pubspec.yaml</name>
  <files>tool/lints/pubspec.yaml, tool/lints/lib/mentormind_lints.dart, tool/lints/lib/src/layered_imports.dart, pubspec.yaml</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/pubspec.yaml (current state — must merge, not overwrite)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-PATTERNS.md (§ tool/lints — package structure + pubspec.yaml wiring lines 507-540)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md (Pattern 4: custom_lint Layer Enforcement Rule lines 444-508; § Standard Stack — Lint Dev Dependencies lines 165-170)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-CONTEXT.md (D-08 — layer rule definition; D-13 — CI gate)
    - pub.dev docs for `custom_lint_builder ^0.7.0` API surface (DartLintRule, PluginBase, ErrorReporter, CustomLintContext) — fetch with Context7 if syntax is unclear (RESEARCH Assumption A1 + A5)
  </read_first>
  <action>
    Create three new files under `tool/lints/` per the package structure in PATTERNS.md (lines 511-540), then wire the dev_dependencies into the host `pubspec.yaml`.

    1. `tool/lints/pubspec.yaml`:
       - `name: mentormind_lints`
       - `version: 0.0.1`
       - `publish_to: none`
       - `environment.sdk: '>=3.0.0 <4.0.0'`
       - `dependencies: { custom_lint_builder: ^0.7.0, analyzer: ^7.0.0 }`

    2. `tool/lints/lib/mentormind_lints.dart`:
       - Single top-level `PluginBase createPlugin() => _MentorMindLints();`
       - `_MentorMindLints extends PluginBase` whose `getLintRules(CustomLintConfigs configs)` returns `[LayeredImportsRule()]`.
       - Re-exports `src/layered_imports.dart` so consumers see only one symbol.

    3. `tool/lints/lib/src/layered_imports.dart`:
       - `class LayeredImportsRule extends DartLintRule` with rule id `layered_imports`, severity `ErrorSeverity.ERROR`.
       - In `run(resolver, reporter, context)` register `context.registry.addImportDirective((node) {...})`.
       - Use `resolver.source.uri` (the file being linted) to derive the path. Predicates from the `<interfaces>` block above.
       - Banned URI prefixes for `/lib/presentation/` files: `package:cloud_firestore`, `package:firebase_auth`, `package:firebase_storage`, `package:firebase_messaging`.
       - Banned URI prefix for `/lib/data/` files: `package:mentor_minds/presentation/`.
       - Use `reporter.atNode(node, code)` (or the equivalent `reporter.reportErrorForNode` in older custom_lint_builder APIs — verify against the installed `^0.7.0` package once `pub get` lands).

    4. Edit host `pubspec.yaml` `dev_dependencies` to ADD:
       - `custom_lint: ^0.7.7`
       - `riverpod_lint: ^2.6.5`
       - `mentormind_lints:\n    path: tool/lints` (path dependency to the local package).

       DO NOT change anything else in `pubspec.yaml` — Plan 01 already set the rest. Leave `flutter_riverpod`, the six test-harness deps, and the removed codegen deps exactly as Plan 01 left them.

    5. Run `flutter pub get` at the repo root. Then run `dart pub get` inside `tool/lints/` to resolve the plugin package's own deps.
  </action>
  <verify>
    <automated>test -f /Users/arnobrizwan/Mentor-Mind/tool/lints/pubspec.yaml &amp;&amp; test -f /Users/arnobrizwan/Mentor-Mind/tool/lints/lib/mentormind_lints.dart &amp;&amp; test -f /Users/arnobrizwan/Mentor-Mind/tool/lints/lib/src/layered_imports.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -E '^\s*(custom_lint|riverpod_lint|mentormind_lints):' pubspec.yaml | wc -l | tr -d ' ' | xargs -I{} test {} -ge 3</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter pub get 2>&amp;1 | tee /tmp/p1-02-pubget.txt &amp;&amp; ! grep -Ei 'version solving failed|conflict|error:' /tmp/p1-02-pubget.txt</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/tool/lints &amp;&amp; dart pub get 2>&amp;1 | tee /tmp/p1-02-toolpubget.txt &amp;&amp; ! grep -Ei 'failed|error' /tmp/p1-02-toolpubget.txt</automated>
  </verify>
  <acceptance_criteria>
    - The three new files exist at the exact paths above (test command succeeds).
    - `tool/lints/pubspec.yaml` declares `custom_lint_builder: ^0.7.0` and `analyzer: ^7.0.0` (grep both lines).
    - Host `pubspec.yaml` `dev_dependencies` contains AT LEAST three lines matching `^\s*(custom_lint|riverpod_lint|mentormind_lints):` (the path-dep counts because its key sits on its own line).
    - `flutter pub get` exits 0 with no "version solving failed", "conflict", or "error:" lines.
    - `cd tool/lints && dart pub get` exits 0 with no "failed" or "error" output (confirms `custom_lint_builder` resolves at `^0.7.0`).
    - `tool/lints/lib/src/layered_imports.dart` contains the literal string `layered_imports` (the rule id) and one or more of `cloud_firestore`/`firebase_auth`/`firebase_storage`/`firebase_messaging` (the banned import URI list).
  </acceptance_criteria>
  <done>
    Plugin package is scaffolded, host pubspec wires it, both `pub get` invocations resolve cleanly. The rule code exists but has not yet been proven to fire — that is Task 3.
  </done>
</task>

<task type="auto">
  <name>Task 2: analysis_options.yaml — wire custom_lint analyzer plugin</name>
  <files>analysis_options.yaml</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/analysis_options.yaml (current state — template defaults only, must not lose `package:flutter_lints/flutter.yaml`)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-PATTERNS.md (§ Wire into analysis_options.yaml lines 542-549)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md (§ analysis_options.yaml with custom_lint plugin lines 858-871; § Common Pitfalls — Pitfall 4: custom_lint is separate from flutter analyze)
  </read_first>
  <action>
    Edit `analysis_options.yaml` to register the `custom_lint` analyzer plugin. The current file is a near-empty `include: package:flutter_lints/flutter.yaml` template.

    Add to the top-level YAML structure:
    ```
    analyzer:
      plugins:
        - custom_lint
    ```

    DO NOT touch the existing `include:` line; DO NOT add `errors:` overrides; DO NOT add `linter:` rule changes — those are Phase 7 territory.

    After saving, confirm the file is still parseable as YAML and that `flutter analyze --fatal-warnings` still completes (the existing 167 info-level warnings remain — they are info, not warning).
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; node -e "const y=require('fs').readFileSync('analysis_options.yaml','utf8'); if(!/analyzer:\s*\n\s+plugins:\s*\n\s+-\s+custom_lint/.test(y)){process.exit(2)}; if(!/include:\s+package:flutter_lints\/flutter\.yaml/.test(y)){process.exit(3)}; console.log('ok')"</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --fatal-warnings 2>&amp;1 | tee /tmp/p1-02-analyze.txt &amp;&amp; ( grep -q 'No issues found' /tmp/p1-02-analyze.txt || ! grep -qE '^\s*(error|warning) -' /tmp/p1-02-analyze.txt )</automated>
  </verify>
  <acceptance_criteria>
    - `analysis_options.yaml` contains the exact 3-line block `analyzer:` / `  plugins:` / `    - custom_lint` (matched by the regex check).
    - The pre-existing `include: package:flutter_lints/flutter.yaml` line is preserved (regex check).
    - `flutter analyze --fatal-warnings` exits 0 and produces no `error -` or `warning -` lines (the existing info-level hits are NOT promoted by adding the plugin).
  </acceptance_criteria>
  <done>
    Custom_lint is registered with the analyzer; IDEs and `dart run custom_lint` will both load the project-local rule; the existing `flutter analyze` surface is unchanged.
  </done>
</task>

<task type="auto">
  <name>Task 3: Prove the layered_imports rule fires (canary test, then revert)</name>
  <files>(no permanent file changes — canary is created and reverted within this task)</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md (§ Common Pitfalls — Pitfall 4: `dart run custom_lint` is separate from `flutter analyze`)
    - /Users/arnobrizwan/Mentor-Mind/tool/lints/lib/src/layered_imports.dart (created in Task 1 — must understand its predicate to construct the canary)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md (§ Per-Task Verification Map: 03-layer-lint-rule — `dart run custom_lint` exits 0 is the green gate; this task proves the rule is alive by inducing a RED state and then restoring GREEN)
  </read_first>
  <action>
    Two-phase canary test that proves the rule is alive. The rule's job is to fire on `lib/presentation/**` and `lib/data/**`, but those directories don't exist yet (Plan 03 creates them). To prove the rule loads and triggers, create temporary canary files at the exact paths the rule will police, run the linter, then delete the canaries.

    Step A — Baseline GREEN: Run `dart run custom_lint` against the current tree (`lib/features/...` only — no `lib/presentation/` or `lib/data/` exist yet). The expected outcome is "No issues found" or exit 0 — the rule has no files to lint.

    Step B — Induce RED with a Firebase-import canary:
    1. Create `lib/presentation/__canary__.dart` containing one line:
       `import 'package:cloud_firestore/cloud_firestore.dart'; void main(){}` (the body just satisfies the parser).
    2. Run `dart run custom_lint` and capture stdout to `/tmp/p1-02-canary-pres.log`.
    3. Confirm the log contains the strings `layered_imports` AND `__canary__.dart` (i.e. the rule reported the violation on that file).
    4. Delete `lib/presentation/__canary__.dart` and the now-empty `lib/presentation/` directory.

    Step C — Induce RED with a data→presentation canary:
    1. Create `lib/data/__canary__.dart` containing:
       `import 'package:mentor_minds/presentation/foo.dart'; void main(){}`
       (The import target does not need to exist — `custom_lint` analyzes the import directive itself, not whether the resolved file is on disk; the analyzer will flag an unresolved import as a separate, lower-priority error which we ignore.)
    2. Run `dart run custom_lint` and capture stdout to `/tmp/p1-02-canary-data.log`.
    3. Confirm the log contains `layered_imports` AND `__canary__.dart`.
    4. Delete `lib/data/__canary__.dart` and the now-empty `lib/data/` directory.

    Step D — Final GREEN: Re-run `dart run custom_lint`. Confirm exit 0 with no `layered_imports` lines. Confirm `git status` shows zero net changes in `lib/` (canaries fully deleted; the directories `lib/presentation/` and `lib/data/` exist only after Plan 03's `mkdir -p`).

    DO NOT commit any canary file. The only artifact this task leaves behind is the captured log files in `/tmp/` (referenced in SUMMARY).
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; dart run custom_lint 2>&amp;1 | tee /tmp/p1-02-baseline.log &amp;&amp; ! grep -q 'layered_imports' /tmp/p1-02-baseline.log</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; mkdir -p lib/presentation &amp;&amp; printf "import 'package:cloud_firestore/cloud_firestore.dart';\nvoid main(){}\n" > lib/presentation/__canary__.dart &amp;&amp; dart run custom_lint 2>&amp;1 | tee /tmp/p1-02-canary-pres.log; rm -f lib/presentation/__canary__.dart; rmdir lib/presentation 2>/dev/null; grep -q 'layered_imports' /tmp/p1-02-canary-pres.log &amp;&amp; grep -q '__canary__\.dart' /tmp/p1-02-canary-pres.log</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; mkdir -p lib/data &amp;&amp; printf "import 'package:mentor_minds/presentation/foo.dart';\nvoid main(){}\n" > lib/data/__canary__.dart &amp;&amp; dart run custom_lint 2>&amp;1 | tee /tmp/p1-02-canary-data.log; rm -f lib/data/__canary__.dart; rmdir lib/data 2>/dev/null; grep -q 'layered_imports' /tmp/p1-02-canary-data.log &amp;&amp; grep -q '__canary__\.dart' /tmp/p1-02-canary-data.log</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; dart run custom_lint 2>&amp;1 | tee /tmp/p1-02-final.log &amp;&amp; ! grep -q 'layered_imports' /tmp/p1-02-final.log &amp;&amp; test -z "$(git status --porcelain lib/presentation lib/data 2>/dev/null)"</automated>
  </verify>
  <acceptance_criteria>
    - Baseline run: `dart run custom_lint` against the current tree produces zero lines containing `layered_imports`.
    - Presentation canary RED proof: the captured log contains both `layered_imports` and `__canary__.dart`, proving the rule fired on the Firebase import.
    - Data canary RED proof: the captured log contains both `layered_imports` and `__canary__.dart`, proving the rule fired on the data→presentation import.
    - Final GREEN: post-cleanup `dart run custom_lint` produces zero `layered_imports` lines AND `git status --porcelain lib/presentation lib/data` is empty (no leftover canary files, no leftover directories).
    - The `/tmp/p1-02-*.log` capture files exist as evidence and are referenced in the SUMMARY artifact.
  </acceptance_criteria>
  <done>
    The `layered_imports` rule is provably alive on both predicates. The tree is back to its pre-canary state. Plan 03 can move files into `lib/presentation/` and `lib/data/` knowing that any forbidden import will be caught immediately by `dart run custom_lint` in CI (Plan 10 wires the CI step).
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| presentation layer ⇄ data layer | The structural boundary the rule polices; without it, viewmodels can be bypassed by widgets calling Firestore directly |
| pubspec dev_dependency surface | `custom_lint` and `riverpod_lint` execute at build/IDE time |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-1-LAYER | Elevation of Privilege | Presentation→Firestore bypass; data→presentation cyclic import | mitigate | `layered_imports` custom_lint rule bans both directions; Plan 10 wires `dart run custom_lint` as a blocking CI step; Task 3 proves the rule fires on both predicates |
| T-1-LINT-FALSE-NEG | Tampering | A rule that loads silently but never fires would produce a green-CI false-negative | mitigate | Task 3 canary test deliberately INDUCES the rule to fire and asserts the violation is reported; without the canary, a no-op rule would never be detected |
| T-1-PKG-LINT | Tampering (supply chain) | `custom_lint`, `riverpod_lint`, `custom_lint_builder` | accept | Pinned to versions verified against pub.dev in RESEARCH § Package Legitimacy Audit; `riverpod_lint 2.x` matches our `riverpod 2.6.1` (riverpod_lint 3.x would require riverpod 3.x and break the build); no `[ASSUMED]`/`[SUS]` packages in the install set |
</threat_model>

<verification>
- `dart run custom_lint` exits 0 on the pre-refactor tree (Task 3 baseline check).
- Two canary tests prove the rule fires on both banned-import predicates (Task 3 RED proofs).
- `flutter analyze --fatal-warnings` still passes — adding the analyzer plugin does not change the existing analyze surface (Task 2 check).
- No file outside `files_modified` is left modified at end of plan (Task 3 final `git status --porcelain` check).
</verification>

<success_criteria>
- `tool/lints/` is a self-contained Dart package that declares the `layered_imports` rule and resolves cleanly under both the host and its own `pub get`.
- The host `pubspec.yaml` wires `custom_lint`, `riverpod_lint`, and `mentormind_lints` (path dep) as `dev_dependencies` per D-08.
- `analysis_options.yaml` registers `custom_lint` as an analyzer plugin per D-08.
- The rule provably fires on (a) Firebase SDK imports inside `lib/presentation/**` and (b) `lib/data/**` files importing `lib/presentation/**` — verified by induced-violation canary tests that are then reverted.
- T-1-LAYER mitigation is operational before any file moves to `lib/presentation/` or `lib/data/`.
</success_criteria>

<output>
Create `.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-02-custom-lint-plugin-SUMMARY.md` when done. Record: the three new file paths and their final line counts, the exact `analysis_options.yaml` diff, the literal output of the baseline and final `dart run custom_lint` runs, and snippets from the two canary RED logs proving `layered_imports` fired on both predicates.
</output>
