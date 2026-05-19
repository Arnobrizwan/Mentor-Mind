---
phase: 02-cloud-functions-scaffolding-app-check
plan: 10
subsystem: infra
tags: [github_actions_ci, functions_job_lift, paths_filter, npm_ci, dorny_paths_filter_v4, node20, ci_03]

# Dependency graph
requires:
  - phase: 02-cloud-functions-scaffolding-app-check
    provides: "functions/package-lock.json (Plan 02-01), compiled TypeScript (Plans 02-02/02-03)"
  - phase: 01-foundation-refactor-ci-test-harness-ios-identity
    provides: "Phase 1 ci.yml stub with if: false guard and concurrency/triggers already wired"
provides:
  - "functions: CI job runs npm ci + npm run lint + npm run build on every PR touching functions/**"
  - "dorny/paths-filter@v4 gate skips heavy install/build for PRs not touching functions/"
  - "CI-03 fully closed; FUNC-01 (CI half) and FUNC-06 (CI half) satisfied"
affects:
  - 02-11-phase-closeout
  - phase-03 (inherits a live TypeScript lint + build gate for any callable additions)

# Tech tracking
tech-stack:
  added:
    - "dorny/paths-filter@v4 — path-based step gating in GitHub Actions"
  patterns:
    - "Per-step if: steps.filter.outputs.X == 'true' guard rather than job-level if: — job always runs (filter is cheap), heavy steps skip on unrelated PRs"
    - "cache-dependency-path: functions/package-lock.json — scopes npm cache key to the monorepo subdirectory lockfile"

key-files:
  created: []
  modified:
    - ".github/workflows/ci.yml"

key-decisions:
  - "Use per-step if: guards (not job-level if:) so the paths-filter step itself always runs and PRs get a fast green check even when functions/ is untouched"
  - "Pin dorny/paths-filter@v4 (major-version) consistent with Phase 1 action-pinning convention; SHA-pinning deferred to Phase 7"
  - "APP_CHECK_DEBUG_TOKEN NOT consumed in Phase 2 CI (D-13 preserved); Phase 3 will wire it only when production callables exist"
  - "Phase 2's emulator integration test (ping_smoke_test.dart) is NOT run in CI — Linux runners cannot host iOS simulators; local-dev only"

patterns-established:
  - "Paths-filter gate pattern: checkout → dorny/paths-filter@v4 (id: filter) → conditional steps with if: steps.filter.outputs.X == 'true'"
  - "functions/ npm CI cache: cache: npm + cache-dependency-path: functions/package-lock.json"

requirements-completed: [FUNC-01, FUNC-06]

# Metrics
duration: 8min
completed: 2026-05-19
---

# Phase 02 Plan 10: CI Functions Job Lift Summary

**dorny/paths-filter@v4 gate + npm ci/lint/build steps replace the Phase 1 if:false stub, making functions/** PRs run TypeScript lint and tsc in CI (CI-03 closed)**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-05-19T00:00:00Z
- **Completed:** 2026-05-19T00:08:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Replaced the Phase 1 `if: false` no-op stub in the `functions:` job with five real steps
- Added `dorny/paths-filter@v4` path gate so PRs not touching `functions/**` skip install/build entirely
- Added `actions/setup-node@v4` with `node-version: '20'`, `cache: 'npm'`, `cache-dependency-path: functions/package-lock.json`
- Added conditional `cd functions && npm ci` and `cd functions && npm run lint && npm run build` steps
- Verified `flutter:` job (CI-01/CI-02) is untouched; T-1-SECRET and T-2-CI-TOKEN-LEAK invariants preserved
- Local dry-runs of all three commands exited 0 — CI will pass on first PR touching `functions/**`

## Task Commits

1. **Task 1: Lift functions: job stub to real npm ci + lint + build** — `ebb2969` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `.github/workflows/ci.yml` — `functions:` job replaced: removed `if: false`, renamed to `Cloud Functions lint + build (CI-03)`, added 5 steps (checkout, paths-filter, setup-node, npm ci, lint+build)

## Before / After

**BEFORE (Phase 1 lines 83-115):**
```yaml
  # Job 2 — Cloud Functions: lint + build stub  (CI-03)
  # Phase 2 replacement plan: ...
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
```

**AFTER (Phase 2 lines 83-118):**
```yaml
  # Job 2 — Cloud Functions: lint + build (CI-03)
  # Gated on changes under functions/** via dorny/paths-filter@v4.
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

## Verification Results

| Check | Result |
|-------|--------|
| YAML valid (ruby yaml.safe_load) | ok |
| No `if: false` in ci.yml | PASS |
| `dorny/paths-filter@v4` present | PASS |
| `node-version: '20'`, `cache: 'npm'`, `cache-dependency-path` | PASS |
| `cd functions && npm ci` step | PASS |
| `cd functions && npm run lint && npm run build` step | PASS |
| `functions/**` filter pattern | PASS |
| `steps.filter.outputs.functions == 'true'` guards | PASS |
| T-1-SECRET (no credential refs) | PASS |
| T-2-CI-TOKEN-LEAK (no APP_CHECK_DEBUG_TOKEN) | PASS |
| `flutter:` job unchanged (Flutter 3.41.3, flutter test --coverage, dart run custom_lint) | PASS |
| Local `npm ci` exit code | 0 |
| Local `npm run lint` exit code | 0 |
| Local `npm run build` exit code | 0 |

## Decisions Made

- Per-step `if:` guards chosen over job-level `if:` so the paths-filter step always runs and PRs not touching `functions/` still get a fast green job completion rather than a skipped job
- `dorny/paths-filter@v4` major-version pin (consistent with Phase 1 action-pinning convention; SHA-pinning is Phase 7)
- No `APP_CHECK_DEBUG_TOKEN` consumption in Phase 2 CI (D-13 / T-2-CI-TOKEN-LEAK — Phase 3 will add it only once production callables exist)

## Deviations from Plan

None — plan executed exactly as written. YAML validation used Ruby's built-in yaml module as fallback (js-yaml and pyyaml not available in the local environment); equivalent outcome confirmed.

## Issues Encountered

Minor: `python3 -c "import yaml; ..."` failed (pyyaml not installed) and `node -e "require('js-yaml')"` failed (js-yaml not in local node_modules). Used Ruby's built-in YAML parser as fallback — same structural validation, exit 0 confirms valid YAML.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The plan only modifies `.github/workflows/ci.yml`. Threat register items verified:

- **T-1-SECRET (Phase 1):** Zero references to `GOOGLE_APPLICATION_CREDENTIALS`, `FIREBASE_TOKEN`, `GCP_SA_KEY`, `service-account.json` — PRESERVED
- **T-2-CI-TOKEN-LEAK (Phase 2):** Zero references to `APP_CHECK_DEBUG_TOKEN` — PRESERVED
- **T-2-10-ACTION-PIN:** `dorny/paths-filter@v4` and `actions/setup-node@v4` pinned to major version v4 (Phase 1 standard; SHA-pinning deferred to Phase 7) — ACCEPTED

## Next Phase Readiness

- CI-03 is closed: every PR that touches `functions/**` will now run `npm ci && npm run lint && npm run build`
- Phase 3 TypeScript callables can be developed with confidence the CI gate catches lint/tsc regressions on every PR
- Plan 02-11 (phase closeout) should re-grep the workflow for `npm run lint` to verify the gate survives any future edits

---
*Phase: 02-cloud-functions-scaffolding-app-check*
*Completed: 2026-05-19*

## Self-Check: PASSED

- `.github/workflows/ci.yml` exists and contains all required content
- Commit `ebb2969` verified in git log
- No missing artifacts
