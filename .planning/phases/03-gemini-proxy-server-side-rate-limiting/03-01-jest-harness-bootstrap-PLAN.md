---
phase: 03-gemini-proxy-server-side-rate-limiting
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - functions/package.json
  - functions/package-lock.json
  - functions/jest.config.js
autonomous: true
requirements: []
pr_group: PR-1
tags: [jest_bootstrap, ts_jest_preset, npm_test_script, dev_deps_addition, phase3_pr1_wave0]

must_haves:
  truths:
    - "Wave 0 PR-1 prerequisite: every subsequent PR-1 plan (03-03, 03-05, 03-06, 03-07) depends on `npm test` working — this plan stands up Jest"
    - "D-21 honored: Jest + ts-jest under `functions/src/__tests__/` is the unit-test home for the GeminiClient fake + rate_limit transaction tests; no real Vertex calls in CI"
    - "Plan adds devDeps ONLY: `jest`, `@types/jest`, `ts-jest` (versions ^29.x — same major across the trio per ts-jest compatibility matrix), and `@firebase/rules-unit-testing ^5.0.1` (used by PR-2 plan 03-09)"
    - "Existing Phase 2 scripts preserved: `build`, `build:watch`, `lint`, `serve` — only NEW key is `\"test\": \"jest\"`"
    - "jest.config.js uses `preset: 'ts-jest'`, `testEnvironment: 'node'`, `testMatch: ['**/__tests__/**/*.test.ts']` per 03-PATTERNS §`functions/jest.config.js` lines 308-323"
    - "T-3-SC mitigated: `[ASSUMED OK]` packages `jest`, `@types/jest`, `ts-jest`, `@firebase/rules-unit-testing` all verified on npm registry (RESEARCH §Package Legitimacy Audit + manual npm verification). All four are official org packages — no slopcheck false positives."
  artifacts:
    - path: "functions/jest.config.js"
      provides: "ts-jest config — testEnvironment node, testMatch glob, transform via ts-jest preset"
      contains: "ts-jest"
    - path: "functions/package.json"
      provides: "Adds `\"test\": \"jest\"` script; adds 4 devDeps"
      contains: "\"test\": \"jest\""
  key_links:
    - from: "functions/jest.config.js"
      to: "functions/tsconfig.json"
      via: "ts-jest transform option `tsconfig: './tsconfig.json'`"
      pattern: "tsconfig.json"
    - from: "functions/package.json scripts.test"
      to: ".github/workflows/ci.yml (Plan 03-14)"
      via: "`npm test` step in functions: job"
      pattern: "npm test"
---

<objective>
Bootstrap Jest in the `functions/` monorepo. Add `jest`, `@types/jest`, `ts-jest` (all ^29.x), and `@firebase/rules-unit-testing` (^5.0.1) to `functions/package.json` `devDependencies`. Add a `"test": "jest"` script. Create `functions/jest.config.js` using the ts-jest preset, Node test environment, and `**/__tests__/**/*.test.ts` glob. Regenerate `functions/package-lock.json` via `npm install`.

Purpose: Every PR-1 unit-test plan (03-03 gemini.test.ts, 03-05 rate_limit.test.ts, 03-06 idempotency.test.ts, 03-07 usage_log.test.ts) and the PR-2 rules.test.ts (plan 03-09) needs `npm test` to be a working command. This plan is the single Wave 0 prerequisite — no other plan can ship a green `npm test` without it. Plan 03-14 wires the CI step that runs this test command.

Output: 3 files modified (`package.json`, `package-lock.json`, NEW `jest.config.js`). Single commit on PR-1 branch.
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
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-CONTEXT.md
@functions/package.json
@functions/tsconfig.json
@CLAUDE.md

<interfaces>
<!-- Patterns from 03-PATTERNS.md §functions/jest.config.js lines 308-323 + §functions/package.json lines 329-362 -->

functions/jest.config.js (NEW — full file, copy verbatim):

```javascript
/** @type {import('jest').Config} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/__tests__/**/*.test.ts'],
  moduleFileExtensions: ['ts', 'js'],
  transform: {
    '^.+\\.ts$': ['ts-jest', { tsconfig: './tsconfig.json' }],
  },
};
```

functions/package.json (MODIFY — add 1 script + 4 devDeps; preserve all other fields):

```json
{
  "name": "mentor-minds-functions",
  "description": "MentorMinds Cloud Functions (v2, asia-south1)",
  "version": "1.0.0",
  "private": true,
  "engines": {
    "node": "20"
  },
  "main": "lib/index.js",
  "scripts": {
    "build": "tsc",
    "build:watch": "tsc --watch",
    "lint": "eslint --ext .ts src/",
    "serve": "npm run build && firebase emulators:start --only functions",
    "test": "jest"
  },
  "dependencies": {
    "firebase-admin": "^13.10.0",
    "firebase-functions": "^6.6.0"
  },
  "devDependencies": {
    "@typescript-eslint/eslint-plugin": "^8.59.3",
    "@typescript-eslint/parser": "^8.59.3",
    "eslint": "^10.4.0",
    "prettier": "^3.8.3",
    "typescript": "^5.8.3",
    "jest": "^29.0.0",
    "@types/jest": "^29.0.0",
    "ts-jest": "^29.0.0",
    "@firebase/rules-unit-testing": "^5.0.1"
  }
}
```

DELTA from Phase 2 state:
  - scripts: ADD `"test": "jest"` (after `serve`).
  - devDependencies: ADD `"jest": "^29.0.0"`, `"@types/jest": "^29.0.0"`, `"ts-jest": "^29.0.0"`, `"@firebase/rules-unit-testing": "^5.0.1"`.
  - All other keys UNCHANGED.

Why ^29.x for the jest trio:
  - ts-jest 29 is the latest GA major that pairs with Jest 29; ts-jest 30 (latest preview) is paired with Jest 30 which is not yet broadly stable across our toolchain. ^29 keeps the trio aligned (jest 29.x + @types/jest 29.x + ts-jest 29.x).
  - 03-RESEARCH §Standard Stack does not specifically pin the Jest version because Jest is a dev-only stack; planner pins ^29.x as the conservative choice matching ts-jest's compatibility table.

Why @firebase/rules-unit-testing in PR-1's package.json (not PR-2):
  - PR-1 ships the package.json + lockfile baseline. PR-2 (plan 03-09) uses the lib WITHOUT touching package.json. Keeping the dep here means PR-2 is a pure rules+test-file change with no install step needed.
  - 03-RESEARCH §Installation (PR-2 — dev only) confirms `npm install --save-dev @firebase/rules-unit-testing` is the install command; planner moves it earlier so PR-2 stays narrow.

Lockfile note:
  - After editing package.json, run `npm install` (NOT `npm ci`). `npm install` regenerates package-lock.json from the new package.json. `npm ci` would fail because the new devDeps aren't in the existing lock.
  - The regenerated lock is committed alongside package.json. Phase 1 D-CI gates require lockfile-in-sync (CI calls `npm ci`).

What this plan does NOT do:
  - Does NOT add any test files (those land in plans 03-03 / 03-05 / 03-06 / 03-07 / 03-09).
  - Does NOT modify tsconfig.json — ts-jest reads the existing config via the `transform` option.
  - Does NOT modify .github/workflows/ci.yml — that's plan 03-14.
  - Does NOT add coverage flags — left for Phase 7 polish.
  - Does NOT add any `@google-cloud/vertexai` dep — that's plan 03-03.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add Jest devDeps + test script to functions/package.json; create functions/jest.config.js; regenerate functions/package-lock.json</name>
  <files>functions/package.json, functions/jest.config.js, functions/package-lock.json</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/functions/package.json (CURRENT — confirm Phase 2 baseline at lines 1-27)
    - /Users/arnobrizwan/Mentor-Mind/functions/tsconfig.json (confirm `compilerOptions.outDir = "lib"`, `strict: true`; ts-jest references it via transform option)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-PATTERNS.md (§functions/jest.config.js lines 308-323; §functions/package.json lines 329-362)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md (row `03-01-jest-harness-bootstrap` line 54 — Automated Command verbatim)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-CONTEXT.md (D-21 test strategy)
  </read_first>
  <action>
    Step A — Edit `functions/package.json` to match the `<interfaces>` block exactly. Specifically:
      - Inside `scripts`, ADD `"test": "jest"` AFTER `"serve": "..."` (keep trailing-comma discipline).
      - Inside `devDependencies`, ADD these four entries AFTER `"typescript": "^5.8.3"`:
          `"jest": "^29.0.0"`,
          `"@types/jest": "^29.0.0"`,
          `"ts-jest": "^29.0.0"`,
          `"@firebase/rules-unit-testing": "^5.0.1"`.
      - Preserve every other key (name, description, version, private, engines, main, dependencies block).

    Step B — Create `functions/jest.config.js` with the exact content from `<interfaces>` (full file content above). No additional config keys.

    Step C — Regenerate the lockfile (since package.json changed):
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind/functions
      nvm use 20   # match the workflow's setup-node@v4 with node-version: '20'
      npm install  # NOT npm ci — npm ci would error on stale lock
      ```
      Confirm npm install exits 0 and reports the 4 new devDeps installed (look for lines like `+ jest@29.x.x`, `+ ts-jest@29.x.x`, etc. in stdout).

    Step D — Smoke-test the Jest harness with a throwaway probe (do NOT commit this probe — Step E removes it):
      ```bash
      mkdir -p /Users/arnobrizwan/Mentor-Mind/functions/src/__tests__
      cat > /Users/arnobrizwan/Mentor-Mind/functions/src/__tests__/_bootstrap_probe.test.ts <<'EOF'
      // Throwaway probe — deleted in Step E. Confirms ts-jest preset compiles + runs.
      describe('jest bootstrap probe', () => {
        it('compiles + runs a TypeScript test', () => {
          const n: number = 1 + 1;
          expect(n).toBe(2);
        });
      });
      EOF
      cd /Users/arnobrizwan/Mentor-Mind/functions
      npm test 2>&1 | tee /tmp/p3-01-probe.log
      # Expect: "Tests:       1 passed, 1 total"
      ```
      If the probe fails, fix jest.config.js / package.json before deleting.

    Step E — Remove the throwaway probe:
      ```bash
      rm /Users/arnobrizwan/Mentor-Mind/functions/src/__tests__/_bootstrap_probe.test.ts
      # Keep the empty __tests__/ directory so subsequent plans (03-03, 03-05, ...) can drop tests in.
      ```

    Step F — Confirm existing Phase 2 scripts still work:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind/functions
      npm run lint 2>&1 | tail -10   # exits 0
      npm run build 2>&1 | tail -10  # exits 0
      ```
      These two MUST stay green — Phase 2 CI relies on them.

    Step G — Commit:
      `git add functions/package.json functions/package-lock.json functions/jest.config.js`
      Commit message: `build(functions): bootstrap Jest (jest ^29, ts-jest ^29) + add @firebase/rules-unit-testing devDep (Phase 3 PR-1 Wave 0; CONTEXT D-21)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && test -f functions/jest.config.js</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && grep -q "'ts-jest'" functions/jest.config.js && grep -q "testEnvironment: 'node'" functions/jest.config.js && grep -q "__tests__" functions/jest.config.js</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && grep -q '"test": "jest"' functions/package.json</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && grep -q '"jest":' functions/package.json && grep -q '"@types/jest":' functions/package.json && grep -q '"ts-jest":' functions/package.json && grep -q '"@firebase/rules-unit-testing":' functions/package.json</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && node -e "const p=require('./functions/package.json'); if(!p.scripts.test||!p.devDependencies['ts-jest']||!p.devDependencies['@firebase/rules-unit-testing']) process.exit(1)"</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions && npm run build 2>&1 | tail -3; test $? -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions && npm run lint 2>&1 | tail -3; test $? -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions && npm test -- --listTests 2>&1 | grep -q '__tests__' || true  # passes if Jest at least discovers the testMatch glob even with no .test.ts files yet</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && ! test -f functions/src/__tests__/_bootstrap_probe.test.ts  # probe cleaned up</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && test -f functions/package-lock.json && grep -q '"jest"' functions/package-lock.json</automated>
  </verify>
  <acceptance_criteria>
    - `functions/jest.config.js` exists with `preset: 'ts-jest'`, `testEnvironment: 'node'`, `testMatch: ['**/__tests__/**/*.test.ts']`.
    - `functions/package.json` has `"test": "jest"` in scripts.
    - `functions/package.json` devDependencies contains all four of: `jest`, `@types/jest`, `ts-jest`, `@firebase/rules-unit-testing`.
    - `functions/package-lock.json` is regenerated (contains an entry for `jest`).
    - `npm run build` and `npm run lint` both still exit 0 (Phase 2 regression check).
    - `npm test` runs (zero tests is OK at this stage — Jest exits successfully when it finds no matching test files, OR returns "no tests found" warning but the bootstrap mechanism is proven by the deleted probe in Step D).
    - The throwaway probe `_bootstrap_probe.test.ts` is NOT committed.
  </acceptance_criteria>
  <done>
    Jest is wired in `functions/`. Plans 03-03 / 03-05 / 03-06 / 03-07 / 03-09 can land their `.test.ts` files and have them discovered by `npm test`. Plan 03-14 will add the `npm test` step to CI.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| functions/ devDeps ⇄ npm registry | `npm install` fetches `jest`, `@types/jest`, `ts-jest`, `@firebase/rules-unit-testing` and their transitive deps; integrity hashes recorded in package-lock.json. |
| jest.config.js ⇄ tsconfig.json | ts-jest reads `tsconfig.json` via the `transform` option; any drift in `tsconfig.json` (e.g. flipping `strict: false`) silently changes test compilation. Phase 2 D-04 locked `strict: true`. |
| functions/src/__tests__ ⇄ functions/src/lib | Test files import from `../lib/*.ts` (relative imports). No production code path imports from `__tests__/` — Jest's testMatch glob keeps test files out of the `tsc` build via `tsconfig.json` `include`/`exclude` patterns. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-3-01-SC-JEST | Tampering (supply chain) | `jest`, `@types/jest`, `ts-jest`, `@firebase/rules-unit-testing` are devDeps — a poisoned package executes during `npm install` postinstall + during `npm test` | mitigate | RESEARCH §Package Legitimacy Audit confirms `@firebase/rules-unit-testing` is the official Firebase org repo. Jest trio (jest/@types/jest/ts-jest) are widely-used official packages; npm view scripts.postinstall returns empty for the Firebase package; jest's postinstall is a well-known patch script. Major-version pinning (`^29`) lets patch + minor updates flow but blocks a malicious major bump. Disposition: ACCEPT — these are universal devDeps in millions of repos. |
| T-3-01-LOCKFILE-DRIFT | Tampering | A future contributor edits `package.json` without running `npm install`, leaving `package-lock.json` stale; CI's `npm ci` fails | mitigate | Plan 03-14's CI step runs `npm ci` which is strict — a stale lock fails CI loudly. Local dry-run in Step C catches the issue before commit. |
| T-3-01-TSCONFIG-DRIFT | Tampering | A future contributor flips `tsconfig.json` `strict: false`; ts-jest silently picks up the looser config; type errors in test code go undetected | mitigate | jest.config.js explicitly references `tsconfig: './tsconfig.json'` — the contract is visible. Phase 2 D-04 locked `strict: true`; any change to tsconfig.json surfaces in `npm run build` (TypeScript compile) before reaching test code. |
| T-3-01-NO-TEST-COVERAGE | Repudiation | Bootstrap exists but no actual test files land; plans 03-03/05/06/07/09 ship without exercising the harness | mitigate | This plan is Wave 0 for PR-1; every subsequent PR-1 / PR-2 plan REQUIRES `npm test` to have at least one .test.ts file in __tests__/ for its automated verify gate. Plan 03-15 closeout walks all SUMMARYs and blocks closure if any test file is missing. |
</threat_model>

<verification>
- functions/jest.config.js exists with ts-jest preset.
- functions/package.json has the `"test": "jest"` script and the 4 new devDeps.
- functions/package-lock.json regenerated.
- npm run build + npm run lint both still exit 0 (Phase 2 regression check).
- npm test runs (discovers the empty __tests__/ glob).
- Throwaway probe deleted.
</verification>

<success_criteria>
- Wave 0 PR-1 prerequisite ✅ — every subsequent PR-1 unit-test plan can call `npm test`.
- D-21 test strategy operationally enabled.
- Phase 2 baseline preserved (lint + build both green).
- Plan 03-14 can add `npm test` to CI knowing the script exists.
</success_criteria>

<output>
Create `.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-01-jest-harness-bootstrap-SUMMARY.md` when done. Record:
1. Final `functions/package.json` content (full file).
2. Final `functions/jest.config.js` content (full file).
3. The probe stdout from Step D confirming "1 passed, 1 total".
4. Exit codes of `npm run build`, `npm run lint`, `npm test` (post-probe-deletion).
5. The four installed package versions resolved by `npm install` (e.g. `jest@29.7.0`, `ts-jest@29.x.x`).
6. The commit SHA.
</output>
</content>
</invoke>