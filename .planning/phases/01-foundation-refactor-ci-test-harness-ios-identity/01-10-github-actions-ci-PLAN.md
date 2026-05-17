---
phase: 01-foundation-refactor-ci-test-harness-ios-identity
plan: 10
type: execute
wave: 3
depends_on: ["01-02", "01-05", "01-09"]
files_modified:
  - .github/workflows/ci.yml
autonomous: true
requirements: [CI-01, CI-02, CI-03]
requirements_addressed: [CI-01, CI-02, CI-03]
tags: [github_actions, ci, flutter_action, coverage_upload, functions_path_filter, t_1_secret]

must_haves:
  truths:
    - "D-13: CI gates in Phase 1 — `flutter analyze --fatal-warnings`, `dart run custom_lint`, `flutter test --coverage`, plus a conditional `functions/**` TypeScript lint+build job (stub in Phase 1; activates in Phase 2). All four gates merge-blocking on PRs targeting `main`"
    - "`.github/workflows/ci.yml` exists and runs on every `pull_request` against `main` AND every `push` to `main`"
    - "The Flutter job runs (in order): `flutter pub get`, `flutter analyze --fatal-warnings`, `dart run custom_lint`, `flutter test --coverage` — each as a separate step (so a failure pinpoints the broken gate)"
    - "Coverage artifact `coverage/lcov.info` is uploaded via `actions/upload-artifact@v4`"
    - "A separate `functions` job runs ONLY when `functions/**` changes (CI-03; no-op stub for Phase 1 because `functions/` does not exist yet — added in Phase 2)"
    - "Flutter is pinned to `3.41.3` via `subosito/flutter-action@v2 with: flutter-version: '3.41.3'` (RESEARCH § Sources line 1056)"
    - "CI MUST NOT mount `tool/seed/service-account.json` or reference any production Firebase project credentials — T-1-SECRET closure"
    - "`pub` cache + Pods cache enabled via `subosito/flutter-action@v2`'s `cache: true` (RESEARCH § Pattern 5)"
  artifacts:
    - path: ".github/workflows/ci.yml"
      provides: "GitHub Actions workflow with flutter + functions jobs"
      contains: "subosito/flutter-action|flutter analyze --fatal-warnings|dart run custom_lint|flutter test --coverage|upload-artifact"
  key_links:
    - from: ".github/workflows/ci.yml flutter job"
      to: "tool/lints/ (custom_lint plugin from Plan 02)"
      via: "dart run custom_lint step"
      pattern: "dart run custom_lint"
    - from: ".github/workflows/ci.yml functions job"
      to: "functions/ (does not exist in Phase 1)"
      via: "paths-ignore / path-filter conditional"
      pattern: "functions/"
---

<objective>
Add the GitHub Actions CI workflow that gates every PR on `flutter analyze --fatal-warnings`, `dart run custom_lint`, and `flutter test --coverage` (CI-01 + CI-02), with a separate path-filtered job for `functions/**` changes (CI-03 — a no-op stub job in Phase 1 because the `functions/` directory will not exist until Phase 2). Coverage artifact is uploaded; pub and pods are cached. T-1-SECRET closure: the workflow MUST NOT mount any service-account credentials.

Purpose: Plans 01-09 build the layered tree, repo seams, lint rule, anchor tests, and emulator integration. None of those automatic guards run on a PR unless GitHub Actions executes them. This plan is the "automate the green gate" plan. With it merged, every subsequent phase has a baseline guarantee that PRs which break the lint or test surface fail CI before merge.

Output: One `.github/workflows/ci.yml` file. After commit + push, opening any PR against `main` triggers the workflow; the Flutter job must complete green; the Functions job is conditionally skipped (no `functions/` directory yet).
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
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-02-custom-lint-plugin-PLAN.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-05-repository-extraction-PLAN.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-08-test-harness-anchors-PLAN.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-09-emulator-integration-smoke-PLAN.md
@CLAUDE.md
@pubspec.yaml
@analysis_options.yaml

<interfaces>
<!-- Canonical workflow from RESEARCH § Pattern 5 lines 510-561 + PATTERNS.md § .github/workflows/ci.yml lines 561-606 -->

Workflow shape (Phase 1 final form):

```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

# Concurrency: cancel in-progress CI runs for the same PR/branch on new pushes.
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  flutter:
    name: Flutter analyze + lint + test
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: '3.41.3'
          cache: true

      - name: Resolve dependencies
        run: flutter pub get

      - name: Resolve tool/lints/ dependencies
        run: cd tool/lints && dart pub get
        # tool/lints/ is a path-dep under dev_dependencies; its own deps must resolve
        # for `dart run custom_lint` to find the plugin classes.

      - name: Static analysis
        run: flutter analyze --fatal-warnings
        # --fatal-warnings (NOT --fatal-infos) per D-13: 167 info-level hits are
        # legitimate Phase 7 burndown work; failing on them would red-light P1 CI.

      - name: Custom lint (layered_imports)
        run: dart run custom_lint
        # Plan 02's project-local custom_lint rule + riverpod_lint; runs as a
        # SEPARATE step from flutter analyze per RESEARCH Pitfall 4.

      - name: Unit + widget tests with coverage
        run: flutter test --coverage
        # Excludes integration_test/ by default — that runs locally only in Phase 1
        # because GitHub-hosted Linux runners cannot run an iOS simulator.

      - name: Upload coverage artifact
        if: success()
        uses: actions/upload-artifact@v4
        with:
          name: coverage-lcov
          path: coverage/lcov.info
          if-no-files-found: error
          retention-days: 30

  functions:
    name: Cloud Functions lint + build (stub until Phase 2)
    runs-on: ubuntu-latest
    timeout-minutes: 10
    # Path-filter: only run when functions/ files change. Phase 1: directory does
    # not exist, so this job is effectively dormant; Phase 2 fills it in.
    # GitHub Actions does NOT support `if: contains(github.event.head_commit.modified, 'functions/')`
    # reliably for PRs (`head_commit` is empty on pull_request events). The idiomatic
    # solution is `dorny/paths-filter@v3` which inspects the PR diff. For Phase 1
    # (no functions/ directory) the simplest correct solution is a NO-OP step with
    # an `if` guard that always evaluates `false` — replaced in Phase 2 with the
    # real lint+build steps under the paths-filter conditional.
    if: false  # Phase 1: directory does not exist; replaced in Phase 2
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: echo "Functions CI stub — no-op until Phase 2"
      # Phase 2 will replace with:
      #   - name: Install functions deps
      #     run: cd functions && npm ci
      #   - name: Lint + build TypeScript
      #     run: cd functions && npm run lint && npm run build
```

Version pins (RESEARCH § Pattern 5 lines 553-557, all VERIFIED via GitHub API):
  - `actions/checkout@v4`
  - `subosito/flutter-action@v2`         (v2.23.0 latest stable as of research)
  - `actions/setup-node@v4`              (v4 stable; v6 exists but adds nothing P1 needs)
  - `actions/upload-artifact@v4`

Flutter version pin:
  - `flutter-version: '3.41.3'` matches the SDK constraint in pubspec.yaml + the local dev SDK confirmed in RESEARCH § Environment Availability line 951.

Concurrency clause:
  - `cancel-in-progress: true` saves runner minutes when a developer pushes follow-up commits to the same PR. Group key is `github.ref` so different PRs run independently.

T-1-SECRET (CONTEXT.md threat model — "CI MUST NOT mount tool/seed/service-account.json"):
  - The workflow does NOT use the `secrets:` GitHub feature.
  - `flutter pub get` and `flutter test` do not require any Firebase credentials — the test surface uses `fake_cloud_firestore` and `firebase_auth_mocks` (in-process; no network).
  - The integration test (`integration_test/login_smoke_test.dart`) is NOT run on CI in Phase 1 because Linux runners cannot host an iOS simulator. Plan 09's emulator test is a local-dev-only loop for Phase 1; Phase 7 may add a macOS GitHub runner for full CI integration.
  - No GitHub Secret needs to be configured for Phase 1.

CI-04, CI-05, CI-07 partial-satisfaction:
  - CI-04 (smoke widget test per screen) is partially satisfied by Plan 08's dashboard_screen_test.dart anchor.
  - CI-05 (unit test per viewmodel) is partially satisfied by Plan 08's auth_viewmodel_test.dart + onboarding_viewmodel_test.dart anchors.
  - CI-07 (test deps installed) is satisfied by Plan 01 + Plan 08.
  - This plan's `flutter test --coverage` step runs all four anchor tests on every PR; if Phase 7 adds 11 more screen tests + 10 more viewmodel tests, the same CI step runs them automatically without workflow changes.

`pub get` / Pod cache:
  - `subosito/flutter-action@v2 with: cache: true` enables both the Flutter SDK cache AND the pub cache automatically. No separate `actions/cache@v4` step needed.
  - Pods cache is iOS-only and not relevant for Linux CI in Phase 1.

Workflow file location:
  - `.github/workflows/ci.yml` (the `.github/` directory does NOT exist in the repo today per PATTERNS.md line 562 "No .github/ directory exists in the repo. This is greenfield."). Creating the directory is implicit when writing the file.

Pitfalls (RESEARCH § Common Pitfalls 4 — "dart run custom_lint not part of flutter analyze"):
  - The two are SEPARATE CI steps. Combining them with `flutter analyze --fatal-warnings && dart run custom_lint` in one step would still work but loses the per-step failure granularity that GitHub Actions shows in the PR check list.

Out of scope:
  - Slack / Discord webhook notifications on failed runs — not in CI-01..07.
  - Auto-merge / auto-rebase bot — out of scope.
  - Releases / Cocoapods publishing — out of scope.
  - macOS runner for `flutter build ios` validation — Plan 06 ran the iOS build locally; CI macOS runner is Phase 7 or later (cost: ~$0.08/minute vs ubuntu-latest free).
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Author .github/workflows/ci.yml</name>
  <files>.github/workflows/ci.yml</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md (§ Pattern 5: GitHub Actions CI Workflow lines 510-561; § Common Pitfalls — Pitfall 4: separate custom_lint step; § Sources — verified action versions lines 1054-1057)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-PATTERNS.md (§ .github/workflows/ci.yml — canonical workflow lines 561-606)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-CONTEXT.md (D-13 — CI gates: `flutter analyze --fatal-warnings`, `flutter test --coverage`, `dart run custom_lint`, conditional functions build)
    - /Users/arnobrizwan/Mentor-Mind/pubspec.yaml (current state — confirm Flutter SDK constraint matches 3.41.3 pin)
    - /Users/arnobrizwan/Mentor-Mind/analysis_options.yaml (confirm Plan 02 wired custom_lint plugin — required for `dart run custom_lint` to find rules)
    - /Users/arnobrizwan/Mentor-Mind/.gitignore (confirm `.github/` is not somehow ignored)
  </read_first>
  <action>
    Step A — Confirm the `.github/` directory does not exist:
      `ls .github 2>/dev/null` should return non-zero. If `.github/` already exists for other reasons (issue templates, etc.), only create `.github/workflows/ci.yml` without disturbing siblings.

    Step B — Write `.github/workflows/ci.yml` using the workflow shape from `<interfaces>`. Two named jobs:

      Job 1 — `flutter`:
        1. `actions/checkout@v4`
        2. `subosito/flutter-action@v2` with `channel: stable`, `flutter-version: '3.41.3'`, `cache: true`
        3. `flutter pub get`
        4. `cd tool/lints && dart pub get`  (Plan 02's plugin package needs its own deps resolved)
        5. `flutter analyze --fatal-warnings`
        6. `dart run custom_lint`
        7. `flutter test --coverage`
        8. `actions/upload-artifact@v4` with `name: coverage-lcov`, `path: coverage/lcov.info`, `if-no-files-found: error`, `retention-days: 30`, gated by `if: success()` so failed test runs don't litter empty artifacts.
        Set `timeout-minutes: 15` on the job.

      Job 2 — `functions`:
        Set `if: false` (Phase 1 stub — directory does not exist).
        Include a comment block explaining the Phase 2 replacement plan and pointing at the canonical paths-filter pattern (`dorny/paths-filter@v3`).
        Single no-op step: `run: echo "Functions CI stub — no-op until Phase 2"`.
        Set `timeout-minutes: 10`.

      Top-level:
        - `name: CI`
        - `on: { pull_request: { branches: [main] }, push: { branches: [main] } }`
        - `concurrency: { group: ci-${{ github.ref }}, cancel-in-progress: true }`

    Step C — Validate YAML locally:
      `node -e "const y=require('js-yaml'); y.load(require('fs').readFileSync('.github/workflows/ci.yml','utf8'))"`
      (If `js-yaml` is not installed, fall back to: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"`.)
      Must complete without error.

    Step D — Optional: lint with `actionlint` if available locally:
      `actionlint .github/workflows/ci.yml` — if `actionlint` is on PATH, run it; otherwise skip (the YAML parse + Step E end-to-end test suffice). actionlint catches issues like wrong action versions or invalid `if:` expressions BEFORE pushing.

    Step E — Drift check — confirm the steps mirror what local dev runs:
      Confirm each CI step has a local equivalent already established:
        - `flutter pub get` — Plan 01 Task 2 ran this.
        - `cd tool/lints && dart pub get` — Plan 02 Task 1 ran this.
        - `flutter analyze --fatal-warnings` — Plan 03/04/05 Task verifiers all ran this.
        - `dart run custom_lint` — Plan 02 Task 3 + Plan 05 Task 3 both ran this.
        - `flutter test --coverage` — Plan 08 Task 4 ran this.
      If any step has no local equivalent, surface it — CI should mirror dev's local pre-commit checks.

    Commit message: `feat(ci): add GitHub Actions workflow — analyze + custom_lint + test --coverage + functions stub (Phase 1 / CI-01, CI-02, CI-03)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ( node -e "const yaml=require('js-yaml'); yaml.load(require('fs').readFileSync('.github/workflows/ci.yml','utf8')); console.log('ok')" 2>&amp;1 || python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml')); print('ok')" 2>&amp;1 ) | grep -q '^ok$'</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'flutter-version:.*3\.41\.3' .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'flutter analyze --fatal-warnings' .github/workflows/ci.yml &amp;&amp; grep -q 'dart run custom_lint' .github/workflows/ci.yml &amp;&amp; grep -q 'flutter test --coverage' .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'upload-artifact@v4' .github/workflows/ci.yml &amp;&amp; grep -q 'coverage/lcov\.info' .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'subosito/flutter-action@v2' .github/workflows/ci.yml &amp;&amp; grep -q 'actions/checkout@v4' .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -qE 'tool/seed/service-account|GOOGLE_APPLICATION_CREDENTIALS|FIREBASE_TOKEN|GCP_SA_KEY' .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -A2 '^\s*functions:' .github/workflows/ci.yml | grep -q 'if:'</automated>
  </verify>
  <acceptance_criteria>
    - `.github/workflows/ci.yml` exists and is valid YAML.
    - Flutter version is pinned to `3.41.3` (matches local SDK).
    - All four CI gate commands appear as separate steps: `flutter analyze --fatal-warnings`, `dart run custom_lint`, `flutter test --coverage`, plus the `upload-artifact` step for coverage.
    - Action version pins are present: `actions/checkout@v4`, `subosito/flutter-action@v2`, `actions/upload-artifact@v4`.
    - Workflow does NOT reference `service-account.json`, `GOOGLE_APPLICATION_CREDENTIALS`, `FIREBASE_TOKEN`, or `GCP_SA_KEY` (T-1-SECRET closure).
    - `functions` job has an `if:` guard (Phase 1 stub).
  </acceptance_criteria>
  <done>
    The workflow file is on disk, parses as valid YAML, and references every CI gate required by D-13. Pushing this commit to the remote will trigger GitHub Actions on the next PR or push to main.
  </done>
</task>

<task type="auto">
  <name>Task 2: End-to-end dry-run — run every CI step locally before pushing</name>
  <files>(no edits — verification only)</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.github/workflows/ci.yml (the workflow Task 1 just created — re-read to confirm step ordering)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md (§ Validation Sign-Off — full suite green before /gsd:verify-work)
  </read_first>
  <action>
    Execute every CI step LOCALLY in the same order CI runs them. If any step fails locally, it will fail in CI — and we want to know now, not after the push.

    Run:
      1. `flutter pub get` — must exit 0.
      2. `cd tool/lints && dart pub get && cd -` — must exit 0.
      3. `flutter analyze --fatal-warnings` — must exit 0 with no `error -` or `warning -` lines.
      4. `dart run custom_lint` — must exit 0 with NO `layered_imports` violations (Plan 05 Task 3 closed this).
      5. `flutter test --coverage` — must exit 0; `coverage/lcov.info` must exist and be non-empty.

    Capture exit code + log for each step to `/tmp/p1-10-step-{N}.log`.

    Then:
      6. Confirm the integration_test/login_smoke_test.dart is NOT picked up by `flutter test` (only by `flutter test integration_test/`):
         `flutter test --dry-run 2>&1 | grep -c integration_test/` should be 0.
         If non-zero, the integration test is being attempted in a unit-test context — adjust `dart_test.yaml` to exclude integration_test/ from the default selector, OR confirm the test has `tags: ['emulator']` and dart_test.yaml's `default_skip` field skips emulator-tagged tests by default. (Plan 09 Task 1 added the `integration:` tag; the default `flutter test` includes all tests unless told otherwise — confirm with the dry-run.)
         Acceptable fallback: integration_test/ files are placed at `integration_test/` (NOT `test/integration/`); Flutter's `flutter test` only runs files under `test/`. Verify the directory layout.

      7. Confirm no Phase-1 source file references the production Firebase project credentials in a way that would land them in CI logs:
         `grep -RIn 'service-account\.json\|GOOGLE_APPLICATION_CREDENTIALS\|FIREBASE_TOKEN' .github/ lib/ test/ integration_test/ 2>/dev/null` — must return 0 lines (T-1-SECRET).

    Step C — Commit + push readiness check:
      Confirm `.github/workflows/ci.yml` is staged and `git diff --cached --stat` shows the new file. Do NOT push yet — pushing is the developer's choice (this plan finishes when the workflow file lands on the main branch).

    If all 7 checks pass, commit (if not already) with `feat(ci): add GitHub Actions workflow ...` (or amend the Task 1 commit if it hasn't been pushed yet).
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter pub get 2>&amp;1 | tee /tmp/p1-10-step-1.log &amp;&amp; ! grep -Ei 'version solving failed|conflict' /tmp/p1-10-step-1.log</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/tool/lints &amp;&amp; dart pub get 2>&amp;1 | tee /tmp/p1-10-step-2.log &amp;&amp; ! grep -Ei 'failed|error' /tmp/p1-10-step-2.log</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --fatal-warnings 2>&amp;1 | tee /tmp/p1-10-step-3.log &amp;&amp; ! grep -qE '^\s*(error|warning) -' /tmp/p1-10-step-3.log</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; dart run custom_lint 2>&amp;1 | tee /tmp/p1-10-step-4.log &amp;&amp; ! grep -q 'layered_imports' /tmp/p1-10-step-4.log</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; rm -f coverage/lcov.info; flutter test --coverage 2>&amp;1 | tee /tmp/p1-10-step-5.log &amp;&amp; test -s coverage/lcov.info</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -RIn 'service-account\.json\|GOOGLE_APPLICATION_CREDENTIALS\|FIREBASE_TOKEN' .github/ lib/ test/ integration_test/ 2>/dev/null</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ls -la .github/workflows/ci.yml</automated>
  </verify>
  <acceptance_criteria>
    - Step 1 (`flutter pub get`) exits 0.
    - Step 2 (`cd tool/lints && dart pub get`) exits 0.
    - Step 3 (`flutter analyze --fatal-warnings`) exits 0.
    - Step 4 (`dart run custom_lint`) reports zero `layered_imports` lines (Plan 05 closure preserved).
    - Step 5 (`flutter test --coverage`) exits 0; `coverage/lcov.info` exists and is non-empty.
    - Zero references to production Firebase credentials anywhere in `.github/`, `lib/`, `test/`, or `integration_test/` (T-1-SECRET).
    - `.github/workflows/ci.yml` is staged for commit (or committed).
  </acceptance_criteria>
  <done>
    All five CI gates run green locally. The workflow file mirrors local dev's pre-commit sequence. T-1-SECRET is closed. Pushing the commit to GitHub triggers the workflow on the next PR or `main` push; the developer can monitor at https://github.com/<owner>/Mentor-Mind/actions.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| CI runner ⇄ repo | GitHub Actions runners have read+write access to the cloned repo + secrets stored under `Settings → Secrets`; the workflow must never write workflow files (no `actions/checkout` with `token: ${{ secrets.GH_TOKEN }}` write-back) |
| CI runner ⇄ Firebase project | The workflow has no Firebase credentials by design (T-1-SECRET); any future need to deploy from CI must use a least-privilege service account, NEVER `tool/seed/service-account.json` |
| coverage artifact ⇄ external storage | `actions/upload-artifact@v4` stores the artifact on GitHub's own storage; retention is 30 days per the workflow config; no external upload (Coveralls, Codecov) in Phase 1 |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-1-SECRET | Information Disclosure | Mounting `tool/seed/service-account.json` or any Firebase service account in CI logs / env vars / cache | mitigate | Task 1 writes the workflow with ZERO references to service-account.json, GOOGLE_APPLICATION_CREDENTIALS, FIREBASE_TOKEN, or GCP_SA_KEY; Task 2 greps `.github/`, `lib/`, `test/`, `integration_test/` for these terms and asserts zero matches; CI does not run the emulator integration test in Phase 1 (no need for an emulator-bind service account) |
| T-1-LINT-FALSE-POS | Tampering | A future workflow edit that drops the `dart run custom_lint` step would silently disable the layered_imports gate; PRs could re-introduce Firebase imports in presentation/ undetected | mitigate | Plan 11's closeout task re-greps the workflow file for `dart run custom_lint` and asserts the step survives; any reduction below the four-gate set (analyze + custom_lint + test + upload-artifact) flags a regression |
| T-1-ACTION-PIN | Tampering (supply chain) | An unpinned GitHub Action could pull a malicious tag at workflow run time | mitigate | All actions pinned to major versions (`@v4`, `@v2`); RESEARCH § Sources line 1054-1057 verified the latest stable tags; for higher-paranoia repos, pinning to a specific SHA (e.g. `actions/checkout@a12a3943...`) is recommended — out of scope for Phase 1, can be added in Phase 7 hardening |
| T-1-RUNNER-CACHE-POISON | Tampering | `subosito/flutter-action@v2 with: cache: true` pulls cached pub deps from the GitHub Actions cache; a poisoned cache entry could ship malicious code | accept | The cache key is derived from `pubspec.lock` hash; lockfile changes invalidate the cache; for Phase 1 the risk is low (no production deploys from CI) |
| T-1-COVERAGE-LEAK | Information Disclosure | `coverage/lcov.info` artifact could contain source file paths revealing internal directory layout | accept | Source paths are already visible in the public repo (no proprietary code beyond Gemini API key handling which is `--dart-define`d, not in source); coverage paths are not sensitive |
</threat_model>

<verification>
- `.github/workflows/ci.yml` exists and parses as valid YAML.
- Flutter version pinned to 3.41.3.
- All four CI gate commands appear as separate steps.
- Action version pins are present (`@v4`, `@v2`).
- Zero references to Firebase/Google service-account credentials anywhere in the repo's CI-relevant paths.
- `functions` job has an `if:` guard (Phase 1 stub; replaced in Phase 2).
- All 5 local-equivalent CI steps run green locally (Task 2 verification).
</verification>

<success_criteria>
- CI-01 closed: `flutter analyze --fatal-warnings` runs on every PR.
- CI-02 closed: `flutter test --coverage` runs on every PR; `coverage/lcov.info` uploaded as an artifact.
- CI-03 closed: `functions` job structured to run on path changes (no-op stub in Phase 1; real lint+build in Phase 2).
- QUAL-04 partially satisfied: `dart run custom_lint` runs as a separate CI step (the rule itself is Plan 02; this plan wires it into the workflow).
- T-1-SECRET closed: workflow has no credential mounts.
- Plan 11 (phase closeout) can confirm "CI is alive" by checking the workflow file's existence + dry-run results.
</success_criteria>

<output>
Create `.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-10-github-actions-ci-SUMMARY.md` when done. Record: the full `.github/workflows/ci.yml` file content (committed verbatim), the YAML-parse confirmation output, the five local CI-step exit codes + the last 3 lines of each step's log (`/tmp/p1-10-step-{N}.log`), the literal grep output for T-1-SECRET (must be empty), and the `coverage/lcov.info` row count after the local dry-run.
</output>
