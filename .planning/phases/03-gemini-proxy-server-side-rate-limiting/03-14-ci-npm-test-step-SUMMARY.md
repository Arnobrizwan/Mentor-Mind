---
phase: 03-gemini-proxy-server-side-rate-limiting
plan: 14
subsystem: ci
tags: [github_actions_ci, npm_test_step, jest_in_ci, functions_job_extend, path_filter_preserved]
dependency_graph:
  requires: ["03-01-jest-harness-bootstrap"]
  provides: ["CI-03-extended-with-jest"]
  affects: [".github/workflows/ci.yml"]
tech_stack:
  added: []
  patterns: ["dorny/paths-filter@v4 conditional gating", "--testPathIgnorePatterns exclusion for emulator-dependent tests"]
key_files:
  modified:
    - .github/workflows/ci.yml
decisions:
  - "Use --testPathIgnorePatterns=rules (explicit CLI flag) rather than FIRESTORE_EMULATOR_HOST guard inside rules.test.ts — keeps tests CI-agnostic and makes the exclusion visible to workflow readers"
  - "Preserve same if: conditional from Plan 02-10 — PRs not touching functions/** skip Jest cold-start cost"
metrics:
  duration: "~5 minutes"
  completed: "2026-05-20"
  tasks_completed: 1
  tasks_total: 1
  files_modified: 1
---

# Phase 3 Plan 14: CI npm test step Summary

**One-liner:** Extended CI-03 functions: job with `npm test -- --testPathIgnorePatterns=rules` step after the existing lint+build, wiring 38 Phase 3 unit tests into every PR touching `functions/**`.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add Run Jest tests step to .github/workflows/ci.yml functions: job | 18aad01 | .github/workflows/ci.yml |

## What Changed

### BEFORE — functions: job block (Phase 2 Plan 02-10 state)

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

### AFTER — functions: job block (this plan)

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

## Verification Results

### YAML validation

YAML parsed successfully via js-yaml (from functions/node_modules/js-yaml). Exit code: 0.

### Local npm test dry-run

Command: `cd functions && npm test -- --testPathIgnorePatterns=rules`

```
Test Suites: 5 passed, 5 total
Tests:       38 passed, 38 total
Snapshots:   0 total
Time:        4.444 s
```

Exit code: 0

### rules.test.ts exclusion

`rules.test.ts` was NOT in the executed test list — correctly excluded by `--testPathIgnorePatterns=rules`. The Firestore emulator-dependent rules tests remain local-dev-only until Phase 7 polish wires the emulator into CI.

### Flutter job unchanged (4 grep gates)

- `flutter-version: '3.41.3'` — PASS
- `flutter test --coverage` — PASS
- `dart run custom_lint` — PASS
- `timeout-minutes: 15` — PASS

### T-1-SECRET check

Output: empty (no matches found). Verified: no `tool/seed/service-account`, `GOOGLE_APPLICATION_CREDENTIALS`, `FIREBASE_TOKEN`, `GCP_SA_KEY`, `APP_CHECK_DEBUG_TOKEN`, or `GEMINI_API_KEY` in the workflow file. PASS.

### All Phase 2 Plan 02-10 elements preserved

- `dorny/paths-filter@v4` — PASS
- `node-version: '20'` — PASS
- `cache: 'npm'` — PASS
- `cache-dependency-path: functions/package-lock.json` — PASS
- `cd functions && npm ci` — PASS
- `cd functions && npm run lint && npm run build` — PASS

## Deviations from Plan

None — plan executed exactly as written.

## Forward Pointer

Phase 7 polish: wire the Firestore emulator into the CI functions: job, then remove the `--testPathIgnorePatterns=rules` argument so `rules.test.ts` (plan 03-09) also runs in CI. The change is a single-line removal of `--testPathIgnorePatterns=rules` from the `Run Jest tests` step.

## Self-Check: PASSED

- .github/workflows/ci.yml exists: FOUND
- Commit 18aad01 exists: FOUND
- Run Jest tests step present: PASS
- npm test -- --testPathIgnorePatterns=rules in workflow: PASS
- Job name updated to "Cloud Functions lint + build + test (CI-03)": PASS
- T-1-SECRET preserved: PASS
- Local test run: 38 passed, 0 failed, exit 0

## kluster.ai Compliance Note

⚠️ Your kluster.ai trial has ended. You can visit https://platform.kluster.ai/ to select a plan, subscribe, and re-enable protection.
