---
phase: 02-cloud-functions-scaffolding-app-check
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - functions/package.json
  - functions/package-lock.json
  - functions/tsconfig.json
  - functions/.eslintrc.js
  - functions/.prettierrc
  - functions/.gitignore
autonomous: true
requirements: [FUNC-01]
pr_group: PR-1
tags: [functions_monorepo, typescript, node20, firebase_functions_v6, eslint_typescript, prettier, npm_ci]

must_haves:
  truths:
    - "D-03 honored: functions/ pins firebase-functions ^6.6.0, firebase-admin ^13.10.0, typescript ^5.8.3; eslint + @typescript-eslint preset; prettier defaults"
    - "D-04 honored: tsconfig produces CommonJS output targeting ES2022, with strict + noUncheckedIndexedAccess + noImplicitOverride"
    - "D-19 honored: this plan ships in PR-1 (NO App Check wiring; NO enforceAppCheck — added in PR-3 by Plan 02-03 only on the ping export, but the scaffold here is plumbing-only)"
    - "Discretion item honored: prettier defaults stored in .prettierrc; tsconfig strict-mode flags set"
    - "Node 20 LTS pinned via package.json engines field"
    - "functions/lib/ + functions/node_modules/ in .gitignore but NOT in any .gcloudignore (Firebase deploy reads lib/ from disk — RESEARCH Pitfall 4)"
    - "functions/package-lock.json committed (CI uses npm ci — Plan 02-10)"
  artifacts:
    - path: "functions/package.json"
      provides: "TypeScript Node 20 monorepo manifest with firebase-functions ^6.6.0 / firebase-admin ^13.10.0 deps + lint/build/serve scripts"
      contains: "firebase-functions"
    - path: "functions/tsconfig.json"
      provides: "Strict TypeScript compiler config emitting CommonJS to lib/"
      contains: "noUncheckedIndexedAccess"
    - path: "functions/.eslintrc.js"
      provides: "Type-aware ESLint config (recommended + recommended-type-checked)"
      contains: "recommended-type-checked"
    - path: "functions/.prettierrc"
      provides: "Prettier defaults marker (empty object)"
    - path: "functions/.gitignore"
      provides: "Excludes compiled lib/ and node_modules/ from git"
      contains: "lib/"
    - path: "functions/package-lock.json"
      provides: "Reproducible install for CI npm ci"
  key_links:
    - from: "functions/package.json scripts.build"
      to: "functions/tsconfig.json outDir = lib"
      via: "tsc invocation"
      pattern: "tsc"
    - from: "functions/.eslintrc.js parserOptions.project"
      to: "functions/tsconfig.json"
      via: "type-aware lint requires project ref"
      pattern: "project:\\s*true"
---

<objective>
Stand up the empty TypeScript monorepo at `functions/` — package.json with Node 20 + firebase-functions ^6.6.0, tsconfig.json with strict-mode flags, .eslintrc.js with type-aware preset, .prettierrc defaults, .gitignore — and run `npm install` once locally so a `package-lock.json` is committed. NO callable code, NO helper files, NO App Check — those land in Plans 02-02 / 02-03 / 02-06 respectively. This is the empty plumbing PR-1 prerequisite.

Purpose: Every subsequent Phase 2 plan depends on `cd functions && npm ci && npm run lint && npm run build` exiting 0. This plan is the precondition. Splitting it from helpers (02-02) and the ping callable (02-03) keeps each plan ≤ 30% context and lets Plans 02-02 + 02-03 + 02-04 run as wave-2/2 children of a clean wave-1.

Output: Six files under `functions/` (none yet exist; the directory itself is new). `npm install` produces `node_modules/` (gitignored) and `package-lock.json` (committed). `npm run build` writes `functions/lib/index.js` — but `src/` is empty in this plan, so `tsc` against an empty include compiles successfully with no output (verify `lib/` exists as an empty directory after running). Plan 02-02 fills `src/lib/*.ts`; Plan 02-03 fills `src/index.ts`. After both, `lib/index.js` materializes.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-CONTEXT.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-RESEARCH.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-PATTERNS.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-VALIDATION.md
@CLAUDE.md

<interfaces>
<!-- All skeletons below come verbatim from 02-PATTERNS.md (Group 8 — TypeScript Monorepo, no in-repo analog). Use them EXACTLY. -->

functions/package.json — RESEARCH §Standard Stack + 02-PATTERNS.md Group 8:
  - "name": "mentor-minds-functions"
  - "private": true
  - "engines.node": "20"
  - "main": "lib/index.js"
  - scripts: build (`tsc`), build:watch (`tsc --watch`), lint (`eslint --ext .ts src/`), serve (`npm run build && firebase emulators:start --only functions`)
  - dependencies: firebase-admin@^13.10.0, firebase-functions@^6.6.0
  - devDependencies: @typescript-eslint/eslint-plugin@^8.59.3, @typescript-eslint/parser@^8.59.3, eslint@^10.4.0, prettier@^3.8.3, typescript@^5.8.3

functions/tsconfig.json — RESEARCH Pattern 4 + 02-PATTERNS.md Group 8:
  - module: commonjs, target: ES2022, outDir: lib, rootDir: src
  - strict: true, noUncheckedIndexedAccess: true, noImplicitOverride: true
  - noImplicitReturns: true, noUnusedLocals: true, sourceMap: true, esModuleInterop: true
  - include: ["src"]
  - compileOnSave: true

functions/.eslintrc.js — RESEARCH Pattern 5 + 02-PATTERNS.md Group 8:
  - root: true, env: { es2022: true, node: true }
  - extends: ["eslint:recommended", "plugin:@typescript-eslint/recommended", "plugin:@typescript-eslint/recommended-type-checked"]
  - parser: "@typescript-eslint/parser"
  - parserOptions: { project: true, tsconfigRootDir: __dirname }
  - ignorePatterns: ["/lib/**/*", "/generated/**/*"]
  - plugins: ["@typescript-eslint"]
  - rules: {}

functions/.prettierrc:
  - Content: `{}` (empty JSON object — uses prettier built-in defaults: double quotes, semicolons, trailing comma "all")

functions/.gitignore:
  - Content (two lines):
    lib/
    node_modules/

Empty-src tsc note:
  - `tsc` on an empty include set warns "no inputs were found" but exits 0. Verify by running `cd functions && npm run build` after creating files but BEFORE Plan 02-02 lands its src/lib/*.ts files. Acceptable behavior: warning but exit 0.

Node 20 prerequisite:
  - `nvm use 20` before running `npm install` (active Node may be v24 per RESEARCH §Environment Availability — firebase-functions ^6.x requires Node 14+ to install, but the engines field locks deploys + emulator to v20).

npm install caveat:
  - Run `npm install` (NOT `npm ci`) the FIRST time — no lockfile exists yet. After install, commit BOTH package.json + package-lock.json. CI in Plan 02-10 uses `npm ci` which requires the lockfile.

Slopcheck note (RESEARCH §Package Legitimacy Audit):
  - All 7 npm packages above were verified directly via `npm view` on registry. slopcheck PyPI false-positives on eslint/@typescript-eslint/* are explicitly resolved — no per-install human checkpoint needed for THIS plan; the audit table in 02-RESEARCH.md is the legitimacy gate.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create functions/ directory with 6 scaffold files (package.json, tsconfig.json, .eslintrc.js, .prettierrc, .gitignore + empty src/)</name>
  <files>functions/package.json, functions/tsconfig.json, functions/.eslintrc.js, functions/.prettierrc, functions/.gitignore</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-PATTERNS.md (§Group 8 — lines 405-525: ALL 5 file skeletons verbatim)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-RESEARCH.md (§Standard Stack lines 105-148 — version pins; §Pattern 4 — tsconfig; §Pattern 5 — eslintrc)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-CONTEXT.md (D-03, D-04 — TypeScript Node 20, CommonJS, strict flags)
    - /Users/arnobrizwan/Mentor-Mind/CLAUDE.md (project constraints — Node 18+ for tool/seed already established; functions/ adds Node 20)
  </read_first>
  <action>
    Step A — Create directory layout:
      `mkdir -p functions/src/lib functions/src/__tests__`
      (src/lib/ and src/__tests__/ are placeholder dirs; Plan 02-02 fills src/lib/, Plan 02-03 fills src/index.ts. __tests__/ may stay empty in Phase 2 per CONTEXT discretion item — Plan 02-02 decides whether to add the trivial errors.test.ts.)

    Step B — Write functions/package.json verbatim from 02-PATTERNS.md Group 8 (lines 411-440):
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
          "serve": "npm run build && firebase emulators:start --only functions"
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
          "typescript": "^5.8.3"
        }
      }
      ```
      NOTE: `"node": "20"` is a STRING (not 20). NOT `>=20` — exact major. Per D-03.

    Step C — Write functions/tsconfig.json verbatim from 02-PATTERNS.md Group 8 (lines 451-469):
      ```json
      {
        "compilerOptions": {
          "module": "commonjs",
          "noImplicitReturns": true,
          "noUnusedLocals": true,
          "outDir": "lib",
          "rootDir": "src",
          "sourceMap": true,
          "strict": true,
          "noUncheckedIndexedAccess": true,
          "noImplicitOverride": true,
          "target": "ES2022",
          "esModuleInterop": true
        },
        "compileOnSave": true,
        "include": ["src"]
      }
      ```

    Step D — Write functions/.eslintrc.js verbatim from 02-PATTERNS.md Group 8 (lines 481-501):
      ```javascript
      module.exports = {
        root: true,
        env: {
          es2022: true,
          node: true,
        },
        extends: [
          "eslint:recommended",
          "plugin:@typescript-eslint/recommended",
          "plugin:@typescript-eslint/recommended-type-checked",
        ],
        parser: "@typescript-eslint/parser",
        parserOptions: {
          project: true,
          tsconfigRootDir: __dirname,
        },
        ignorePatterns: ["/lib/**/*", "/generated/**/*"],
        plugins: ["@typescript-eslint"],
        rules: {},
      };
      ```

    Step E — Write functions/.prettierrc with literal content `{}` (empty JSON object; 2 chars + newline).

    Step F — Write functions/.gitignore with two lines:
      ```
      lib/
      node_modules/
      ```

    Step G — Switch to Node 20 BEFORE install (per RESEARCH §Environment Availability):
      `command -v nvm >/dev/null && (. ~/.nvm/nvm.sh && nvm use 20 || nvm install 20 && nvm use 20)`
      Verify: `node -v` reports v20.x.

    Step H — Install + lock:
      `cd functions && npm install`
      This creates `node_modules/` (gitignored) AND `package-lock.json` (commit it).
      Expect ~270 packages installed (firebase-functions transitive deps).

    Step I — Build smoke (empty src):
      `cd functions && npm run build`
      With src/ empty, `tsc` warns "error TS18003: No inputs were found in config file" — this is acceptable in THIS plan because the actual src files land in 02-02 / 02-03. To suppress this so the plan's gate is green, create a temporary `src/.gitkeep` and an empty `src/index.ts` containing just `export {};` so tsc has at least one input. Plan 02-03 will replace `src/index.ts` with the real ping callable.

      Final src/ contents after this plan:
        - functions/src/index.ts (single line: `export {};` — placeholder)
        - functions/src/lib/ (empty dir; `.gitkeep` optional)

    Step J — Lint smoke:
      `cd functions && npm run lint`
      eslint exits 0 on a near-empty src/ (with placeholder index.ts: zero rule violations).

    Step K — Commit:
      `git add functions/package.json functions/package-lock.json functions/tsconfig.json functions/.eslintrc.js functions/.prettierrc functions/.gitignore functions/src/index.ts`
      Commit message: `feat(functions): scaffold TypeScript monorepo — package.json + tsconfig + eslint + prettier + .gitignore (Phase 2 PR-1 / FUNC-01)`.

      CRITICAL: do NOT `git add functions/node_modules/` (.gitignore should already prevent this — sanity-check with `git status` showing `functions/` clean except the 7 listed files).
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f functions/package.json &amp;&amp; test -f functions/tsconfig.json &amp;&amp; test -f functions/.eslintrc.js &amp;&amp; test -f functions/.prettierrc &amp;&amp; test -f functions/.gitignore</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q '"node": "20"' functions/package.json &amp;&amp; grep -q '"firebase-functions": "\^6' functions/package.json &amp;&amp; grep -q '"firebase-admin": "\^13' functions/package.json &amp;&amp; grep -q '"typescript": "\^5' functions/package.json</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'noUncheckedIndexedAccess' functions/tsconfig.json &amp;&amp; grep -q '"module": "commonjs"' functions/tsconfig.json &amp;&amp; grep -q '"target": "ES2022"' functions/tsconfig.json &amp;&amp; grep -q '"outDir": "lib"' functions/tsconfig.json</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'recommended-type-checked' functions/.eslintrc.js &amp;&amp; grep -q '@typescript-eslint/parser' functions/.eslintrc.js</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q '^lib/' functions/.gitignore &amp;&amp; grep -q '^node_modules/' functions/.gitignore</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f functions/package-lock.json &amp;&amp; node -e "const p=require('./functions/package-lock.json'); if(!p.packages) throw new Error('no packages field'); console.log('ok')"</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; npm run build 2>&amp;1 | tee /tmp/p2-01-build.log; test $? -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; npm run lint 2>&amp;1 | tee /tmp/p2-01-lint.log; test $? -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! git status --porcelain functions/node_modules 2>&amp;1 | grep -q functions/node_modules</automated>
  </verify>
  <acceptance_criteria>
    - All 6 files exist at the correct paths.
    - package.json pins Node 20 (literal "20", not ">=20"), firebase-functions ^6.x, firebase-admin ^13.x, typescript ^5.x.
    - tsconfig.json has noUncheckedIndexedAccess, module:commonjs, target:ES2022, outDir:lib.
    - .eslintrc.js extends recommended-type-checked (type-aware preset).
    - .gitignore excludes lib/ AND node_modules/.
    - package-lock.json is committed (`npm install` completed; no lockfile = CI npm ci fails).
    - `cd functions && npm run build` exits 0 (placeholder src/index.ts compiles).
    - `cd functions && npm run lint` exits 0.
    - functions/node_modules/ is NOT tracked by git (gitignore effective).
  </acceptance_criteria>
  <done>
    The empty monorepo plumbing is on disk. Plan 02-02 can add src/lib/*.ts files; Plan 02-03 can replace the placeholder src/index.ts with the ping callable; Plan 02-10 can run `cd functions && npm ci && npm run lint && npm run build` in CI against the committed package-lock.json.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| npm registry ⇄ developer machine | `npm install` fetches ~270 packages from registry.npmjs.org. Package Legitimacy Audit in 02-RESEARCH.md cleared all 7 direct deps. Transitive deps trusted by npm SAT-solver against package-lock integrity hashes. |
| committed package-lock.json ⇄ CI runner | Plan 02-10 CI uses `npm ci` which validates integrity hashes against the committed lock. Tampering with the lock would surface as a failed integrity check on the next CI run. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-2-01-DEP-SUPPLY-CHAIN | Tampering | npm direct + transitive deps (firebase-functions, firebase-admin, typescript, eslint, @typescript-eslint/*, prettier) | mitigate | RESEARCH §Package Legitimacy Audit explicitly verified 7 direct deps via `npm view` (registry-of-record); slopcheck PyPI false-positives documented. Lockfile commits integrity hashes; future `npm ci` re-validates. No human checkpoint needed (audit complete). |
| T-2-01-NODE-MODULES-LEAK | Information Disclosure | functions/node_modules/ accidentally committed | mitigate | functions/.gitignore line `node_modules/`; verify step checks `git status` does not list it. |
| T-2-01-LIB-COMMITTED | Tampering | functions/lib/ (TypeScript build output) committed to git | mitigate | functions/.gitignore line `lib/`. RESEARCH Pitfall 4 (lib/ in .gitignore but NOT .gcloudignore) is honored by absence of any functions/.gcloudignore file in this plan. |
| T-2-01-WRONG-NODE | Repudiation | Developer installs with Node v22+ producing a package-lock.json incompatible with CI's Node 20 | accept | Action Step G runs `nvm use 20` before install. CI in Plan 02-10 explicitly pins setup-node@v4 to node-version:20. Drift is recoverable (delete node_modules + relock). |
</threat_model>

<verification>
- All 6 scaffold files exist with correct content per 02-PATTERNS.md Group 8.
- npm install succeeded; package-lock.json committed.
- npm run build exits 0 with placeholder src/index.ts.
- npm run lint exits 0.
- functions/node_modules/ is gitignored.
- functions/lib/ is gitignored (not yet on disk; will be created by Plan 02-03's build).
</verification>

<success_criteria>
- D-03 + D-04 honored: TypeScript Node 20, CommonJS, strict-mode flags.
- FUNC-01 partially met (monorepo skeleton; helpers + ping land in 02-02 / 02-03).
- 02-VALIDATION.md row 02-01-functions-monorepo-scaffold turns ✅ on first 6 grep + 2 build/lint commands.
- Plan 02-02 can `cd functions && npm run build` and pick up new src/lib/*.ts files without re-running install.
- Plan 02-10's `npm ci` will succeed because package-lock.json is committed.
</success_criteria>

<output>
Create `.planning/phases/02-cloud-functions-scaffolding-app-check/02-01-functions-monorepo-scaffold-SUMMARY.md` when done. Record: the full package.json (with resolved version numbers from npm), tsconfig.json content, .eslintrc.js content, .gitignore content, the exit codes from `npm run build` + `npm run lint` against the placeholder src/, and confirmation that functions/node_modules/ is excluded by git.
</output>
