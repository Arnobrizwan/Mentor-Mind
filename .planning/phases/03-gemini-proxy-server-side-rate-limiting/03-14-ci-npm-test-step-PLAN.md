---
phase: 03-gemini-proxy-server-side-rate-limiting
plan: 14
type: execute
wave: 6
depends_on: ["03-01"]
files_modified:
  - .github/workflows/ci.yml
autonomous: true
requirements: []
pr_group: PR-3
tags: [github_actions_ci, npm_test_step, jest_in_ci, functions_job_extend, path_filter_preserved, ci_03_extend, mirror_plan_02_10]

must_haves:
  truths:
    - "Phase 2 Plan 02-10 (functions: job lift) is the foundation; this plan EXTENDS that job — adds the `npm test` step AFTER the existing `npm run build` step"
    - "Phase 2 D-CONTEXT D-19 PR sequencing honored: the `npm test` step lives in the same `functions:` job as `npm ci`/`npm run lint`/`npm run build` — gated by `dorny/paths-filter@v4` on `functions/**` changes"
    - "Plan 03-01 already added `jest`, `ts-jest`, `@types/jest`, `@firebase/rules-unit-testing` to functions/devDeps + the `\"test\": \"jest\"` script — this plan wires them into CI"
    - "The conditional gate `if: steps.filter.outputs.functions == 'true'` from Plan 02-10 is preserved on the new step — PRs that don't touch `functions/**` skip the test step (no Jest cold-start cost)"
    - "Plans 03-03/03-05/03-06/03-07's unit tests run in CI: gemini.test.ts (8 cases), rate_limit.test.ts (13 cases), idempotency.test.ts (6 cases), usage_log.test.ts (4 cases), quota.test.ts (5 cases) — total ~35 tests + Jest cold (~5-7s) ≈ 12-15s additional CI time"
    - "Plan 03-09's rules.test.ts requires the Firestore emulator — this plan does NOT spawn the emulator in CI (Phase 7 polish); rules tests stay LOCAL-DEV-ONLY for now. The `npm test` invocation will SKIP rules.test.ts because the emulator is absent and the test bails on missing FIRESTORE_EMULATOR_HOST"
    - "Optionally: the `npm test` invocation uses `--testPathIgnorePatterns=rules` to deterministically skip rules.test.ts in CI; OR rules.test.ts itself bails fast if FIRESTORE_EMULATOR_HOST is unset (both achieve the same end state — decide at execute time)"
    - "T-1-SECRET preserved: zero references to GOOGLE_APPLICATION_CREDENTIALS / FIREBASE_TOKEN / GCP_SA_KEY / APP_CHECK_DEBUG_TOKEN — the test step is purely npm test, no secrets needed"
    - "Mirror of plan 02-10: same shape (one step added to an existing job; `if:` conditional preserved); same commit-message style (`feat(ci): ...`)"
    - "Plan 03-12 already removed `--dart-define=GEMINI_API_KEY` from this file — this plan adds the `npm test` step WITHOUT re-introducing the env var"
  artifacts:
    - path: ".github/workflows/ci.yml"
      provides: "MODIFIED — adds one step `Run Jest tests` after the `Lint + build TypeScript` step in the `functions:` job"
      contains: "npm test"
  key_links:
    - from: ".github/workflows/ci.yml `Run Jest tests` step"
      to: "functions/jest.config.js (plan 03-01)"
      via: "`cd functions && npm test` resolves Jest via ts-jest preset"
      pattern: "npm test"
    - from: ".github/workflows/ci.yml `Run Jest tests` step"
      to: "functions/src/__tests__/*.test.ts (plans 03-02/03/05/06/07)"
      via: "Jest discovers via testMatch glob `**/__tests__/**/*.test.ts`"
      pattern: "__tests__"
---

<objective>
Extend the `functions:` job in `.github/workflows/ci.yml` (lifted by Phase 2 Plan 02-10) with one new step that runs `npm test` after the existing `npm run build` step. The new step inherits the same `if: steps.filter.outputs.functions == 'true'` conditional from the Phase 2 lift, so PRs that don't touch `functions/**` skip the test step (no Jest cold-start cost on unrelated PRs). The Firestore-emulator-dependent `rules.test.ts` (plan 03-09) is excluded from this CI invocation either via `--testPathIgnorePatterns=rules` or via the rules test bailing on missing `FIRESTORE_EMULATOR_HOST` — both yield green CI; live rules tests stay local-dev-only until a future Phase 7 polish wires the emulator into CI.

Purpose: CI-03 was closed by Phase 2 Plan 02-10 (lint + build). Phase 3 introduces unit tests for gemini.ts / rate_limit.ts / index.ts handler / quota.ts — every PR touching `functions/**` must run these tests to catch regressions before merge. Without this CI step, the Phase 3 unit-test suite ships but is purely a local-dev gate.

Output: One file modified — `.github/workflows/ci.yml`. One commit. After commit + push, the next PR touching `functions/**` runs `cd functions && npm test` in addition to the existing `npm ci` / `npm run lint` / `npm run build`. The total `functions:` job wall-time stays under 90s on a warm cache.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-CONTEXT.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-RESEARCH.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-PATTERNS.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-10-ci-functions-job-lift-PLAN.md
@.github/workflows/ci.yml
@CLAUDE.md

<interfaces>
<!-- Builds on Plan 02-10's functions: job. Adds ONE new step after `Lint + build TypeScript`. -->

.github/workflows/ci.yml — CURRENT state (Phase 2 Plan 02-10 — relevant `functions:` block):

```yaml
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

.github/workflows/ci.yml — DESIRED state (one new step added after `Lint + build TypeScript`):

```yaml
  functions:
    name: Cloud Functions lint + build + test (CI-03)
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

      - name: Run Jest tests
        if: steps.filter.outputs.functions == 'true'
        run: cd functions && npm test -- --testPathIgnorePatterns=rules
```

Key changes:
  1. UPDATE job `name:` from `Cloud Functions lint + build (CI-03)` to `Cloud Functions lint + build + test (CI-03)`.
  2. ADD a new step `Run Jest tests` AFTER `Lint + build TypeScript`. The step:
     - Inherits the same `if:` conditional.
     - Runs `cd functions && npm test -- --testPathIgnorePatterns=rules`.
     - The `--testPathIgnorePatterns=rules` arg excludes `rules.test.ts` (plan 03-09) which requires the Firestore emulator. Live rules tests stay local-dev-only.

Why `--testPathIgnorePatterns=rules` (not a different mechanism):
  - Excluding by path is explicit and visible in the workflow file (a reader sees exactly what's NOT run).
  - The alternative (env-var guard inside rules.test.ts that early-returns if FIRESTORE_EMULATOR_HOST is unset) is also acceptable but couples the test file to CI knowledge — preferred to keep tests CI-agnostic.
  - When a Phase 7 polish wires the Firestore emulator into CI, this one-line change removes the `--testPathIgnorePatterns=rules` arg; everything else stays the same.

What this plan does NOT do:
  - Does NOT add the Firestore emulator to CI — Phase 7 polish.
  - Does NOT add the `flutter test integration_test/mentor_bot_smoke_test.dart` step — no iOS simulator on Linux runners; future macOS-runner concern (plan 03-13 explicitly notes this).
  - Does NOT change the `flutter:` job — CI-01 + CI-02 stay as Phase 1 set them.
  - Does NOT add coverage flags — Phase 7 polish.
  - Does NOT add the APP_CHECK_DEBUG_TOKEN secret consumption — Phase 7 (when production-path enforcement is needed in CI).
  - Does NOT add a separate `rules:` job — Phase 7 polish (emulator-aware).
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add `Run Jest tests` step to .github/workflows/ci.yml functions: job after `Lint + build TypeScript`; preserve all other steps; update job name; verify YAML parses + local dry-run of npm test</name>
  <files>.github/workflows/ci.yml</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.github/workflows/ci.yml (CURRENT — confirm Phase 2 Plan 02-10's lifted shape; locate the `Lint + build TypeScript` step)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-10-ci-functions-job-lift-PLAN.md (Phase 2 — the foundation this plan extends)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md (row `03-14-ci-npm-test-step` line 67 — Automated Command verbatim)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-01-jest-harness-bootstrap-PLAN.md (plan 03-01 — confirm `"test": "jest"` script exists in functions/package.json)
    - /Users/arnobrizwan/Mentor-Mind/functions/package.json (confirm `"test": "jest"` script)
  </read_first>
  <action>
    Step A — Read .github/workflows/ci.yml. Confirm:
      - The `functions:` job exists with the Phase 2 lift shape.
      - The `Lint + build TypeScript` step is present.
      - The `if: steps.filter.outputs.functions == 'true'` guard is on the install + lint+build steps.
      - The job name is currently `Cloud Functions lint + build (CI-03)`.

    Step B — Edit ci.yml:
      1. UPDATE the job `name:` from `Cloud Functions lint + build (CI-03)` to `Cloud Functions lint + build + test (CI-03)`.
      2. ADD the new step AFTER the existing `Lint + build TypeScript` step:
         ```yaml
              - name: Run Jest tests
                if: steps.filter.outputs.functions == 'true'
                run: cd functions && npm test -- --testPathIgnorePatterns=rules
         ```
         Match the existing 8-space indentation (4-space yaml + 4-space list dash) used by the other steps in the job.

      Preserve EVERYTHING else: the `flutter:` job, the `Filter paths` step, the `setup-node` step, the install step, the lint+build step, the `concurrency:` block, the `on:` triggers, the top-level `name: CI`.

    Step C — Validate YAML parses:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      ( node -e "const yaml=require('js-yaml'); yaml.load(require('fs').readFileSync('.github/workflows/ci.yml','utf8')); console.log('ok')" 2>&amp;1 \
        || python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml')); print('ok')" 2>&amp;1 ) | grep -q '^ok$'
      ```

    Step D — Local dry-run of the new step's underlying command:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind/functions
      nvm use 20  # match the workflow's setup-node@v4 with node-version: '20'
      # Sanity check that the test invocation works locally with the
      # --testPathIgnorePatterns=rules flag (which is what CI will run).
      npm test -- --testPathIgnorePatterns=rules 2>&amp;1 | tee /tmp/p3-14-npmtest.log
      # Expect: All tests pass; rules.test.ts is NOT in the list of executed tests.
      grep -qE 'Tests:\s+([0-9]+) passed' /tmp/p3-14-npmtest.log
      ! grep -q 'rules.test.ts' /tmp/p3-14-npmtest.log
      ```

    Step E — Verify no GEMINI_API_KEY re-introduced (plan 03-12 scrubbed it; this plan must not bring it back):
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      ! grep -E 'GEMINI_API_KEY' .github/workflows/ci.yml
      ```

    Step F — Confirm the existing flutter: job is unchanged (regression check):
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      grep -q 'flutter-version:..3\.41\.3' .github/workflows/ci.yml
      grep -q 'flutter test --coverage' .github/workflows/ci.yml
      grep -q 'dart run custom_lint' .github/workflows/ci.yml
      grep -q 'timeout-minutes: 15' .github/workflows/ci.yml  # flutter timeout preserved
      ```

    Step G — Confirm T-1-SECRET preserved (Phase 1 invariant):
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      ! grep -qE 'tool/seed/service-account|GOOGLE_APPLICATION_CREDENTIALS|FIREBASE_TOKEN|GCP_SA_KEY|APP_CHECK_DEBUG_TOKEN' .github/workflows/ci.yml
      ```

    Step H — actionlint (if available, optional):
      ```bash
      command -v actionlint &amp;&amp; actionlint .github/workflows/ci.yml || echo "(actionlint not installed; skipping)"
      ```

    Step I — Commit:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      git add .github/workflows/ci.yml
      git commit -m "feat(ci): add npm test step to functions: job (Phase 3 PR-3; CI-03 extend; mirror of Plan 02-10)"
      ```
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'name: Run Jest tests' .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'cd functions &amp;&amp; npm test' .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE '\-\-testPathIgnorePatterns=rules' .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "Cloud Functions lint + build + test" .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "steps\.filter\.outputs\.functions == 'true'" .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'dorny/paths-filter@v4' .github/workflows/ci.yml &amp;&amp; grep -q "node-version: '20'" .github/workflows/ci.yml &amp;&amp; grep -q "cache: 'npm'" .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'cd functions &amp;&amp; npm ci' .github/workflows/ci.yml &amp;&amp; grep -q 'cd functions &amp;&amp; npm run lint &amp;&amp; npm run build' .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -E 'GEMINI_API_KEY' .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -qE 'tool/seed/service-account|GOOGLE_APPLICATION_CREDENTIALS|FIREBASE_TOKEN|GCP_SA_KEY|APP_CHECK_DEBUG_TOKEN' .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ( node -e "const yaml=require('js-yaml'); yaml.load(require('fs').readFileSync('.github/workflows/ci.yml','utf8')); console.log('ok')" 2>&amp;1 || python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml')); print('ok')" 2>&amp;1 ) | grep -q '^ok$'</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'flutter-version:..3\.41\.3' .github/workflows/ci.yml &amp;&amp; grep -q 'flutter test --coverage' .github/workflows/ci.yml &amp;&amp; grep -q 'dart run custom_lint' .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; npm test -- --testPathIgnorePatterns=rules 2>&amp;1 | tee /tmp/p3-14-v-npmtest.log | grep -qE 'Tests:\s+[0-9]+ passed'</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -q 'rules.test.ts' /tmp/p3-14-v-npmtest.log 2>/dev/null</automated>
  </verify>
  <acceptance_criteria>
    - `.github/workflows/ci.yml` parses as valid YAML.
    - `functions:` job has a new `Run Jest tests` step AFTER `Lint + build TypeScript`.
    - Step `run` is `cd functions && npm test -- --testPathIgnorePatterns=rules`.
    - Step is gated by `if: steps.filter.outputs.functions == 'true'`.
    - Job name updated to `Cloud Functions lint + build + test (CI-03)`.
    - All Phase 2 Plan 02-10 elements preserved: `dorny/paths-filter@v4`, `node-version: '20'`, `cache: 'npm'`, `cache-dependency-path: functions/package-lock.json`, `cd functions && npm ci`, `cd functions && npm run lint && npm run build`.
    - flutter: job unchanged (Flutter 3.41.3 pin, flutter test --coverage, dart run custom_lint preserved).
    - T-1-SECRET preserved (no service-account / FIREBASE_TOKEN / GCP_SA_KEY / GEMINI_API_KEY / APP_CHECK_DEBUG_TOKEN).
    - Local dry-run `npm test -- --testPathIgnorePatterns=rules` exits 0 AND rules.test.ts is not in the executed test list.
  </acceptance_criteria>
  <done>
    CI-03 extended: every PR touching `functions/**` now runs `npm ci` → `npm run lint` → `npm run build` → `npm test`. The Phase 3 unit-test suite (~35 cases) catches regressions before merge. Plan 03-15 closeout verifies that the next PR's GitHub Actions run completes green.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| CI runner ⇄ npm test | The test step inherits the cached `node_modules` from the install step; Jest runs in-process on the runner. No network deps for the test invocation (the Vertex client is mocked via `GeminiClient` interface — plan 03-03 / 03-21). |
| CI runner ⇄ Firestore emulator (NOT used) | The `--testPathIgnorePatterns=rules` exclusion means rules.test.ts (plan 03-09) is not run in CI. Live rules verification stays local-dev-only. |
| CI runner ⇄ secrets | The functions: job uses ZERO secrets (T-1-SECRET preserved). Phase 3 introduces no new secret requirements. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-1-SECRET | Information Disclosure | (PRESERVED from Phase 1) Mounting service-account.json / FIREBASE_TOKEN in CI | mitigate | Verify gate `! grep -qE 'tool/seed/service-account\|FIREBASE_TOKEN\|GCP_SA_KEY\|GEMINI_API_KEY' .github/workflows/ci.yml` continues to pass. |
| T-3-14-FLAKY-TEST | Repudiation | A future Phase 3 test flakes; CI red on unrelated PRs touching functions/** | mitigate | All Phase 3 unit tests use in-memory mocks (no real Firestore, no real Vertex). The Jest tests are deterministic. Plan 03-15 closeout walks each test SUMMARY. |
| T-3-14-RULES-TEST-SILENT-SKIP | Repudiation | Future contributor adds `rules.test.ts` (or a new emulator-dependent test); the `--testPathIgnorePatterns=rules` exclusion silently skips it; CI passes despite the test never running | mitigate | Plan 03-15 closeout includes a `npm test --listTests` exercise to enumerate which tests CI actually runs. Phase 7 polish: wire emulator into CI so the exclusion is removed. |
| T-3-14-TIMEOUT-BREACH | Denial of Service | functions: job exceeds 10-minute timeout | accept | Phase 3 tests add ~12-15s to a job that was previously ~30-45s (cold). Total &lt; 90s. 10-minute timeout has 8+ minutes of headroom. |
| T-3-14-CACHE-POISON | Tampering | A poisoned npm cache entry on the GitHub Actions runner ships malicious test runner | accept | Cache key derives from `functions/package-lock.json` hash. Risk equivalent to T-2-10-CACHE-POISON. |
</threat_model>

<verification>
- .github/workflows/ci.yml has the new `Run Jest tests` step.
- Step uses `cd functions && npm test -- --testPathIgnorePatterns=rules`.
- Step gated by `if: steps.filter.outputs.functions == 'true'`.
- Job name updated.
- Phase 2 Plan 02-10 elements preserved.
- flutter: job unchanged.
- T-1-SECRET preserved.
- No GEMINI_API_KEY.
- Local dry-run npm test exits 0; rules.test.ts skipped.
</verification>

<success_criteria>
- CI-03 extended: PR push runs the Phase 3 unit-test suite.
- ~35 unit tests + Jest cold ≈ 12-15s additional CI time.
- Plan 03-15 closeout confirms a real GitHub Actions run on a PR-3 commit is green.
- Phase 7 polish path documented (Firestore emulator → rules tests in CI).
</success_criteria>

<output>
Create `.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-14-ci-npm-test-step-SUMMARY.md` when done. Record:
1. The BEFORE content of the `functions:` job block (Phase 2 Plan 02-10 state).
2. The AFTER content (full new block with the `Run Jest tests` step appended).
3. The YAML-parse exit code.
4. The local `npm test --testPathIgnorePatterns=rules` exit code + the Jest summary line.
5. Confirmation that rules.test.ts was NOT in the executed test list (intentional exclusion).
6. Confirmation that the flutter: job is unchanged (4 grep gates).
7. T-1-SECRET grep output (must be empty).
8. The first GitHub Actions run URL on the PR-3 commit (if push was performed) and the green/red status of the `Cloud Functions lint + build + test (CI-03)` check.
9. Commit SHA.
10. Forward-pointer: Phase 7 polish wires Firestore emulator into CI so rules.test.ts also runs; remove the `--testPathIgnorePatterns=rules` arg at that time.
</output>
</content>
