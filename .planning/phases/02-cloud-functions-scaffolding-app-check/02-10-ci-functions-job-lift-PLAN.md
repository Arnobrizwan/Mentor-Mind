---
phase: 02-cloud-functions-scaffolding-app-check
plan: 10
type: execute
wave: 5
depends_on: ["02-01"]
files_modified:
  - .github/workflows/ci.yml
autonomous: true
requirements: [FUNC-01, FUNC-06]
pr_group: PR-3
tags: [github_actions_ci, functions_job_lift, paths_filter, npm_ci, dorny_paths_filter_v4, node20, ci_03]

must_haves:
  truths:
    - "Phase 1 CI-03 closure: replace the `if: false` stub in .github/workflows/ci.yml `functions:` job with actual `cd functions && npm ci && npm run lint && npm run build` steps gated by `dorny/paths-filter@v4` on `functions/**` changes"
    - "Action versions pinned: `dorny/paths-filter@v4`, `actions/setup-node@v4`, `actions/checkout@v4` (RESEARCH §Supporting + Phase 1 ci.yml conventions)"
    - "Node 20 pinned via `actions/setup-node@v4 with: node-version: '20'` matching functions/package.json engines"
    - "Cache enabled: `cache: 'npm'` + `cache-dependency-path: functions/package-lock.json` — speeds re-runs after `npm ci`"
    - "T-1-SECRET (Phase 1) closure preserved: workflow has ZERO references to GOOGLE_APPLICATION_CREDENTIALS / FIREBASE_TOKEN / GCP_SA_KEY / service-account.json"
    - "Phase 2's emulator integration test (Plan 02-09) is NOT run in CI — Linux runners cannot host iOS simulators; the integration test is a local-dev / future macOS-runner concern"
    - "T-2-CI-TOKEN-LEAK mitigated: APP_CHECK_DEBUG_TOKEN secret is NOT consumed by Phase 2 CI (D-13); Phase 3 will wire it once production callables exist"
    - "D-19 honored: PR-3 includes the CI lift"
  artifacts:
    - path: ".github/workflows/ci.yml"
      provides: "functions: job is no longer an if:false stub — runs `npm ci && npm run lint && npm run build` on PRs touching `functions/**`"
      contains: "dorny/paths-filter@v4"
  key_links:
    - from: ".github/workflows/ci.yml `functions:` job"
      to: "functions/package-lock.json (Plan 02-01)"
      via: "cache-dependency-path + npm ci"
      pattern: "functions/package-lock.json"
    - from: ".github/workflows/ci.yml dorny/paths-filter@v4 filter"
      to: "functions/** directory tree (created by Plan 02-01)"
      via: "filters: functions: ['functions/**']"
      pattern: "functions/\\*\\*"
---

<objective>
Replace the Phase 1 stub `functions:` job in `.github/workflows/ci.yml` (currently `if: false` + an echo step) with the canonical Phase 2 shape: `dorny/paths-filter@v4` gates the job on `functions/**` changes, then `actions/setup-node@v4` (Node 20) + `npm ci` + `npm run lint` + `npm run build` run conditionally. Job name changes from `Cloud Functions lint + build (stub until Phase 2)` to `Cloud Functions lint + build (CI-03)`.

Purpose: Phase 1 left the `functions:` job as an `if: false` no-op so the workflow plumbing was in place from day one. Plan 02-01 created functions/package.json + package-lock.json; Plan 02-02 / 02-03 added compiled TypeScript. This plan finishes CI-03 by enabling the lint + build gate. After commit, every PR touching `functions/**` runs TypeScript lint + tsc; PRs not touching `functions/**` skip the heavy work via the paths filter.

Output: One file modified — `.github/workflows/ci.yml`. After commit + push, the next PR's "Cloud Functions lint + build (CI-03)" check runs `cd functions && npm ci && npm run lint && npm run build` against the committed package-lock.json. PRs that don't touch `functions/**` skip the install/build steps and the job completes quickly as a no-op (the paths-filter result is consumed by `if:` guards on each step).
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-CONTEXT.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-RESEARCH.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-PATTERNS.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-VALIDATION.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-01-functions-monorepo-scaffold-PLAN.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-10-github-actions-ci-PLAN.md
@.github/workflows/ci.yml
@CLAUDE.md

<interfaces>
<!-- Self-modify pattern from 02-PATTERNS.md Group 7 lines 347-397 + RESEARCH Pattern 10 lines 569-603 -->

.github/workflows/ci.yml — CURRENT state (Phase 1; relevant section lines 99-115):
  ```yaml
    functions:
      name: Cloud Functions lint + build (stub until Phase 2)
      runs-on: ubuntu-latest
      timeout-minutes: 10
      if: false  # Phase 1: functions/ does not exist; replaced in Phase 2

      steps:
        - uses: actions/checkout@v4

        - uses: actions/setup-node@v4
          with:
            node-version: '20'

        - name: Functions CI stub
          run: echo "Functions CI stub — no-op until Phase 2"
          # Phase 2 will replace this with:
          #   cd functions && npm ci && npm run lint && npm run build
  ```

.github/workflows/ci.yml — DESIRED state (replace the entire `functions:` block):
  ```yaml
    # ─────────────────────────────────────────────────────────────────────────────
    # Job 2 — Cloud Functions: lint + build (CI-03)
    # Gated on changes under functions/** via dorny/paths-filter@v4. PRs that don't
    # touch functions/ skip the install/build steps via per-step `if:` guards;
    # the job itself still runs (the filter step is cheap).
    # ─────────────────────────────────────────────────────────────────────────────
    functions:
      name: Cloud Functions lint + build (CI-03)
      runs-on: ubuntu-latest
      timeout-minutes: 10

      steps:
        - uses: actions/checkout@v4

        - name: Filter paths
          uses: dorny/paths-filter@v4
          id: filter
          with:
            filters: |
              functions:
                - 'functions/**'

        - uses: actions/setup-node@v4
          if: steps.filter.outputs.functions == 'true'
          with:
            node-version: '20'
            cache: 'npm'
            cache-dependency-path: functions/package-lock.json

        - name: Install functions dependencies
          if: steps.filter.outputs.functions == 'true'
          run: cd functions && npm ci

        - name: Lint + build TypeScript
          if: steps.filter.outputs.functions == 'true'
          run: cd functions && npm run lint && npm run build
  ```

Key changes:
  1. REMOVE `if: false` at the job level.
  2. Rename `name:` from `Cloud Functions lint + build (stub until Phase 2)` to `Cloud Functions lint + build (CI-03)`.
  3. REPLACE the existing `actions/setup-node@v4` and `Functions CI stub` steps with:
     a. NEW: `dorny/paths-filter@v4` step that sets `steps.filter.outputs.functions` to `true` if any file under `functions/**` changed in the PR.
     b. CONDITIONAL `actions/setup-node@v4` (now adds `cache: 'npm'` + `cache-dependency-path: functions/package-lock.json`).
     c. NEW conditional step: `Install functions dependencies` running `cd functions && npm ci`.
     d. NEW conditional step: `Lint + build TypeScript` running `cd functions && npm run lint && npm run build`.

Anything else stays untouched — the `flutter:` job (CI-01, CI-02), the concurrency block, the `on:` triggers, the top-level `name: CI`.

Action version notes (RESEARCH-verified):
  - `dorny/paths-filter@v4` (v4.0.1 latest stable; RESEARCH §Supporting line 128 + GitHub Marketplace verification).
  - `actions/setup-node@v4` (was v4 in Phase 1; unchanged).
  - `actions/checkout@v4` (Phase 1; unchanged).

Cache strategy:
  - `cache: 'npm'` tells setup-node@v4 to enable npm cache.
  - `cache-dependency-path: functions/package-lock.json` makes the cache key derive from this lockfile (instead of the default root package-lock.json which doesn't exist).
  - First CI run on `functions/**` changes is slow (~30s install); subsequent runs reuse the cache (~5s install).

What this plan does NOT do:
  - Does NOT add a flutter integration_test job (Phase 2's ping_smoke_test.dart is local-dev only; no iOS simulator on Linux runners).
  - Does NOT add the `APP_CHECK_DEBUG_TOKEN` secret usage (D-13 — reserved for Phase 3 when CI calls production-path enforcement).
  - Does NOT alter the `flutter:` job (CI-01 + CI-02 stay as Phase 1 set them).
  - Does NOT add Codecov / Coveralls (Phase 7 polish).
  - Does NOT remove the `concurrency:` block or change `on:` triggers.
  - Does NOT add macOS runners (deferred to Phase 7 per Phase 1 commentary).

Concurrency note:
  - The Phase 1 `concurrency.group: ci-${{ github.ref }}` cancels in-progress runs for the same ref. With Phase 2's functions job added, a PR push cancels in-progress flutter+functions jobs and starts fresh. This is the correct behavior for cost + signal — no change needed.

actionlint smoke (optional):
  - If `actionlint` is on PATH locally, run `actionlint .github/workflows/ci.yml` — catches typos in `if:` expressions, unsupported action versions, etc.
  - actionlint is NOT installed by default; skip if not available. The YAML parse + grep gates in the verify block cover the structural checks.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Lift the functions: job stub in .github/workflows/ci.yml to real npm ci + lint + build steps gated by paths-filter</name>
  <files>.github/workflows/ci.yml</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.github/workflows/ci.yml (CURRENT — confirm Phase 1's exact stub shape at lines 83-115; specifically the `functions:` job with `if: false`)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-PATTERNS.md (§Group 7 — lines 347-397: full Phase 2 replacement shape)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-RESEARCH.md (§Pattern 10 lines 569-603 — canonical functions job shape; §Supporting — dorny/paths-filter@v4 confirmed)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-10-github-actions-ci-PLAN.md (Phase 1 invariants T-1-SECRET, T-1-ACTION-PIN — preserve)
    - /Users/arnobrizwan/Mentor-Mind/functions/package-lock.json (confirm it exists from Plan 02-01 — required by `npm ci`)
  </read_first>
  <action>
    Step A — Read the current .github/workflows/ci.yml. Confirm:
      - The `flutter:` job (lines 19-81) is intact and untouched by this plan.
      - The `functions:` job (lines 99-115) has `if: false` and the echo stub.

    Step B — Replace the entire `functions:` job (and its preceding comment block lines 83-98 if needed) with the canonical shape from `<interfaces>` Step 2.

      Use the Edit tool to replace the existing `functions:` block. Match the Phase 1 indentation (2 spaces for top-level job key; 4 spaces for fields under the job; 6 spaces for step list items).

      Preserve the leading comment block style (the `# ──────────────────────...` separator above the job). The Phase 1 file uses this convention; align the Phase 2 replacement to it.

    Step C — Validate YAML:
      ```bash
      node -e "const yaml=require('js-yaml'); yaml.load(require('fs').readFileSync('.github/workflows/ci.yml','utf8')); console.log('ok')"
      ```
      OR fallback:
      ```bash
      python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml')); print('ok')"
      ```
      Must print `ok`. Choose whichever interpreter is available locally.

    Step D — Confirm the `flutter:` job is unchanged:
      ```bash
      # Phase 1's flutter job has 8 steps and a 15-minute timeout. Verify none of those changed.
      grep -c '^\s*- ' .github/workflows/ci.yml  # total step count should be ~12 (8 in flutter + ~5 in functions)
      grep -q 'timeout-minutes: 15' .github/workflows/ci.yml  # flutter timeout preserved
      grep -q 'flutter-version:..3\.41\.3' .github/workflows/ci.yml  # Flutter pinning preserved
      ```

    Step E — Lint with `actionlint` if available (optional):
      ```bash
      command -v actionlint && actionlint .github/workflows/ci.yml || echo "(actionlint not installed; skipping)"
      ```

    Step F — Local dry-run of the functions job steps (validates the workflow's logic against the actual repo):
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind/functions
      nvm use 20  # match the workflow's setup-node@v4 with node-version: '20'
      npm ci 2>&amp;1 | tail -5
      npm run lint 2>&amp;1 | tail -10
      npm run build 2>&amp;1 | tail -10
      # All three must exit 0. If any fails locally, it WILL fail in CI.
      ```

    Step G — Smoke test the path filter triggers — confirm:
      The filter pattern `functions/**` matches every file Plan 02-01 / 02-02 / 02-03 created. A PR touching ONLY lib/ (no functions/ changes) should skip the install + build steps. Cannot fully verify locally without a real GitHub Actions run; the verification command below greps for the literal `'functions/**'` pattern in the workflow.

    Step H — Commit:
      `git add .github/workflows/ci.yml`
      Commit message: `feat(ci): lift functions: job stub — npm ci + lint + build gated by dorny/paths-filter@v4 (Phase 2 PR-3 / CI-03; FUNC-01)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -nE '^\s*if:\s*false\s*' .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'dorny/paths-filter@v4' .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "node-version: '20'" .github/workflows/ci.yml &amp;&amp; grep -q "cache: 'npm'" .github/workflows/ci.yml &amp;&amp; grep -q "cache-dependency-path: functions/package-lock.json" .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'cd functions &amp;&amp; npm ci' .github/workflows/ci.yml &amp;&amp; grep -q 'cd functions &amp;&amp; npm run lint &amp;&amp; npm run build' .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "filters:" .github/workflows/ci.yml &amp;&amp; grep -qE "functions/\*\*" .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "steps\.filter\.outputs\.functions == 'true'" .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ( node -e "const yaml=require('js-yaml'); yaml.load(require('fs').readFileSync('.github/workflows/ci.yml','utf8')); console.log('ok')" 2>&amp;1 || python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml')); print('ok')" 2>&amp;1 ) | grep -q '^ok$'</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -qE 'tool/seed/service-account|GOOGLE_APPLICATION_CREDENTIALS|FIREBASE_TOKEN|GCP_SA_KEY' .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'flutter-version:..3\.41\.3' .github/workflows/ci.yml &amp;&amp; grep -q 'flutter test --coverage' .github/workflows/ci.yml &amp;&amp; grep -q 'dart run custom_lint' .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; npm ci 2>&amp;1 | tail -5 | tee /tmp/p2-10-npmci.log; test $? -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; npm run lint 2>&amp;1 | tail -5 | tee /tmp/p2-10-lint.log; test $? -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; npm run build 2>&amp;1 | tail -5 | tee /tmp/p2-10-build.log; test $? -eq 0</automated>
  </verify>
  <acceptance_criteria>
    - .github/workflows/ci.yml is valid YAML.
    - The `functions:` job no longer has `if: false`.
    - Contains literal references to `dorny/paths-filter@v4`, `node-version: '20'`, `cache: 'npm'`, `cache-dependency-path: functions/package-lock.json`, `cd functions && npm ci`, `cd functions && npm run lint && npm run build`.
    - The `functions/**` path filter pattern is present.
    - Each install/build step has `if: steps.filter.outputs.functions == 'true'` gate.
    - T-1-SECRET preserved: zero references to service-account.json / GOOGLE_APPLICATION_CREDENTIALS / FIREBASE_TOKEN / GCP_SA_KEY.
    - The `flutter:` job is unchanged: Flutter 3.41.3 pin + flutter test --coverage + dart run custom_lint all still present.
    - Local dry-runs `cd functions && npm ci`, `npm run lint`, `npm run build` ALL exit 0 — if they fail locally, they will fail in CI.
  </acceptance_criteria>
  <done>
    .github/workflows/ci.yml is lifted from Phase 1 stub to Phase 2 final form. Every PR touching functions/** will run the TypeScript lint + build gate. The Phase 1 flutter analyze + custom_lint + test --coverage gates continue to run unchanged on every PR. T-1-SECRET (Phase 1) and T-2-CI-TOKEN-LEAK (Phase 2) closures both preserved.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| CI runner ⇄ npm registry | `npm ci` fetches all transitive deps fresh per run; integrity hashes in functions/package-lock.json (Plan 02-01) prevent tampering. |
| CI runner ⇄ committed package-lock.json | Cache key derived from the lockfile; tampering with the lock invalidates the cache and forces a fresh install. |
| CI runner ⇄ Firebase / GCP | The workflow has NO Firebase credentials by design (T-1-SECRET from Phase 1 preserved). Phase 2 ships ZERO additional credentials to CI. |
| CI runner ⇄ APP_CHECK_DEBUG_TOKEN secret | The secret is NOT consumed by this workflow (Phase 2 — D-13). Phase 3 will add it as a `--dart-define` only on jobs that call production-path enforcement. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-1-SECRET | Information Disclosure | (PRESERVED from Phase 1) Mounting service-account.json / FIREBASE_TOKEN / GCP_SA_KEY in CI logs or env vars | mitigate | Verify gate `! grep -qE 'tool/seed/service-account\|GOOGLE_APPLICATION_CREDENTIALS\|FIREBASE_TOKEN\|GCP_SA_KEY' .github/workflows/ci.yml` continues to pass after the Phase 2 lift. |
| T-2-CI-TOKEN-LEAK | Information Disclosure | APP_CHECK_DEBUG_TOKEN secret accidentally consumed by Phase 2 CI step and exposed via `set -x` debug output or echoed to logs | mitigate | Plan 02-10 does NOT consume the secret (D-13). Verify: `! grep -q 'APP_CHECK_DEBUG_TOKEN' .github/workflows/ci.yml`. Phase 3 will use `${{ secrets.APP_CHECK_DEBUG_TOKEN }}` ONLY inside masked `run:` steps where Bash variable expansion does not leak. |
| T-2-10-ACTION-PIN | Tampering (supply chain) | A breaking upstream change in dorny/paths-filter@v4 or actions/setup-node@v4 silently propagates | accept | Major-version pinning (`@v4`) is the Phase 1 standard; SHA-pinning is a Phase 7 hardening item. RESEARCH §Supporting line 128 verified `dorny/paths-filter@v4.0.1` exists on GitHub Marketplace. |
| T-2-10-CACHE-POISON | Tampering | A poisoned npm cache entry on the GitHub Actions runner ships malicious code | accept | Cache key derives from `functions/package-lock.json` hash; integrity hashes inside the lock catch tampering. Risk equivalent to Phase 1 T-1-RUNNER-CACHE-POISON (which is accept). |
| T-2-10-LINT-FALSE-POS | Tampering | A future workflow edit drops the `npm run lint` step, silently disabling the @typescript-eslint type-aware preset gate | mitigate | Plan 02-11 (phase closeout) re-greps the workflow file for `npm run lint`. Any reduction below the 4-step set (checkout, paths-filter, setup-node, install, lint+build) flags a regression. |
| T-2-10-FUNCTIONS-DEP-DRIFT | Tampering | functions/package-lock.json is out of date relative to functions/package.json — `npm ci` fails in CI but works locally | mitigate | Local dry-run in Task 1 Step F runs `npm ci` against the lockfile; if it fails locally, the workflow is not committed. Developers must run `npm install` (then commit the regenerated lock) whenever they edit functions/package.json. |
</threat_model>

<verification>
- .github/workflows/ci.yml is valid YAML.
- `functions:` job no longer has `if: false`.
- Contains dorny/paths-filter@v4 + Node 20 + cache config + npm ci + npm run lint + npm run build.
- `functions/**` path filter pattern present.
- Conditional `steps.filter.outputs.functions == 'true'` guards on install/build steps.
- T-1-SECRET preserved (zero credential references).
- T-2-CI-TOKEN-LEAK closed (no APP_CHECK_DEBUG_TOKEN reference).
- `flutter:` job unchanged.
- Local dry-runs of `npm ci`, `npm run lint`, `npm run build` all exit 0.
</verification>

<success_criteria>
- CI-03 closed: the `functions:` job actually runs `npm ci && npm run lint && npm run build` on PRs touching `functions/**`.
- FUNC-01 + FUNC-06 (CI half) met.
- T-1-SECRET preserved across the Phase 1 → Phase 2 transition.
- T-2-CI-TOKEN-LEAK mitigated (no debug token consumption in Phase 2 CI).
- Plan 02-11 phase-closeout verifies that the next PR's GitHub Actions run completes green.
- Phase 3 inherits a working CI gate for any TypeScript changes — adding `mentorBotChat` callable + tests will surface lint/build issues on the PR.
</success_criteria>

<output>
Create `.planning/phases/02-cloud-functions-scaffolding-app-check/02-10-ci-functions-job-lift-SUMMARY.md` when done. Record:
1. The BEFORE content of the `functions:` job block (lines 83-115 from Phase 1).
2. The AFTER content (full new block).
3. The YAML-parse exit code.
4. The local `npm ci`, `npm run lint`, `npm run build` exit codes (must all be 0).
5. The T-1-SECRET grep output (must be empty).
6. The first GitHub Actions run URL on the PR-3 commit (if push was performed) and the green/red status of the "Cloud Functions lint + build (CI-03)" check.
</output>
