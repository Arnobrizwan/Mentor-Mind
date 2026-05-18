---
phase: 02-cloud-functions-scaffolding-app-check
plan: 03
type: execute
wave: 2
depends_on: ["02-01", "02-02"]
files_modified:
  - functions/src/index.ts
autonomous: true
requirements: [FUNC-02]
pr_group: PR-1
tags: [ping_callable, firebase_functions_v2, onCall, enforceAppCheck, asia_south1, app_check_canary]

must_haves:
  truths:
    - "D-01 honored: ping ships with `enforceAppCheck: true` from PR-merge — day-1 hard enforcement, no soft-launch"
    - "D-06 honored: ping is the SINGLE deployable function in Phase 2; region asia-south1; returns `{ ok: true, timestamp: <ms>, region: 'asia-south1' }`"
    - "D-07 honored: ping is `onCall` (NOT `onRequest`); no cors / cookies / HTTP-style routing"
    - "D-19 honored: this plan is part of PR-1; the `enforceAppCheck: true` keyword IS in this file from PR-1 merge (server-side enforcement always on); client-side App Check activation lives in PR-3 (Plan 02-06)"
    - "D-23 honored: NO production deploy in Phase 2 — this function ships to the Functions emulator only; production deploy deferred to Phase 3"
    - "Discretion item honored: ping response includes `region: 'asia-south1'` for client-side sanity-check observability"
    - "RESEARCH Pattern 1 honored: v2 onCall({region, enforceAppCheck}, handler) — NOT v1 chaining `functions.region(...).https.onCall(...)`"
    - "Plan 02-01's placeholder src/index.ts (`export {};`) is REPLACED with the real ping callable"
  artifacts:
    - path: "functions/src/index.ts"
      provides: "Named export `ping` — onCall callable, region asia-south1, enforceAppCheck: true"
      contains: "enforceAppCheck: true"
    - path: "functions/lib/index.js"
      provides: "Compiled output (gitignored — created by `npm run build`)"
  key_links:
    - from: "functions/src/index.ts"
      to: "firebase-functions/https onCall"
      via: "named import"
      pattern: "import.*onCall.*firebase-functions/https"
    - from: "functions/src/index.ts ping handler"
      to: "asia-south1 region pin (matches Flutter client FirebaseFunctions.instanceFor(region: 'asia-south1'))"
      via: "region: 'asia-south1' option literal"
      pattern: "region:.*asia-south1"
---

<objective>
Replace the placeholder `functions/src/index.ts` (`export {};` from Plan 02-01) with the real `ping` callable: `onCall({ region: 'asia-south1', enforceAppCheck: true }, handler)` returning `{ ok: true, timestamp: Date.now(), region: 'asia-south1' }`. Single named export. 5–10 LOC implementation per CONTEXT D-06.

Purpose: The ping callable is the deliberate canary per CONTEXT D-01 + ROADMAP rationale (PITFALLS #1). It proves the Phase 2 plumbing — TypeScript compile, emulator host, client SDK round-trip — works BEFORE Phase 3 layers Gemini logic on top. If App Check misconfigures in Phase 3, the ping smoke test will surface it as a red gate (not a real-user outage). Server-side `enforceAppCheck: true` ships in PR-1 even though the Flutter client doesn't activate App Check until PR-3 (Plan 02-06) — this is intentional: the emulator bypasses enforcement per RESEARCH Pitfall 6, so PR-1 alone can ship the server-side enforcement keyword without breaking dev workflows. Production callers are blocked until PR-3 lands AND a debug token is registered AND `firebase deploy` happens (deferred to Phase 3 per D-23).

Output: One file rewritten — `functions/src/index.ts`. After commit, `cd functions && npm run build` produces `functions/lib/index.js` exporting `ping`. `npm run serve` (or `firebase emulators:start --only functions`) boots the emulator and registers `ping[asia-south1]` (verify in emulator stdout).
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
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-02-functions-helpers-skeleton-PLAN.md
@CLAUDE.md

<interfaces>
<!-- Canonical skeleton from 02-PATTERNS.md Group 8 (lines 533-553) and 02-RESEARCH.md Pattern 1 (lines 285-309) -->

functions/src/index.ts (FULL content — REPLACES the `export {};` placeholder Plan 02-01 wrote):
  ```typescript
  import { onCall } from "firebase-functions/https";

  export const ping = onCall(
    {
      region: "asia-south1",
      enforceAppCheck: true,
    },
    (_request) => {
      return {
        ok: true,
        timestamp: Date.now(),
        region: "asia-south1",
      };
    }
  );
  ```

Critical detail clauses:
  - Import path: `"firebase-functions/https"` (NOT `"firebase-functions/v2/https"` — v6 package re-exports from root https path).
  - The handler param is `_request` with underscore — `noUnusedLocals: true` in tsconfig (Plan 02-01) would fail compilation otherwise.
  - Response shape: `{ ok: true, timestamp: number, region: string }` — three keys, exact strings.
  - Region literal: `"asia-south1"` (lowercase, hyphenated; matches the Flutter client's `FirebaseFunctions.instanceFor(region: 'asia-south1')` in Plan 02-07's firebase_functions_provider.dart).
  - `enforceAppCheck: true` is a top-level option key — NOT nested under `appCheck:` or similar. v2 API only.
  - Date.now() returns ms since epoch as a `number` — Flutter client's PingResponse decodes via `(map['timestamp'] as num?)?.toInt() ?? 0` (Plan 02-07's ping_response.dart fromMap).

What this plan does NOT do:
  - Does NOT import `./lib/admin` — ping has no Firestore or Auth touch points.
  - Does NOT import `./lib/errors` — ping has no error paths.
  - Does NOT call `admin.initializeApp()` — admin.ts (Plan 02-02) already does this for any future import side, but ping does not import admin.
  - Does NOT add minInstances / memory options — defaults (256MB, 0 min instances) are correct for a no-op.
  - Does NOT deploy to production (D-23) — emulator-only via Plan 02-04's firebase.json edit.

Emulator boot validation (manual, post-commit; codified in verify below):
  - `cd functions && npm run build && (cd .. && firebase emulators:start --only functions)` — stdout includes a line like:
    `✔  functions[asia-south1-ping]: https function initialized (http://127.0.0.1:5001/mentor-mind-aa765/asia-south1/ping)`
  - Note: the emulator listens at port 5001 once Plan 02-04 adds the emulator port to firebase.json. Until then, the emulator falls back to its default port (5001) but logs a warning — that warning closes after Plan 02-04 ships.

Why this depends on 02-01 AND 02-02:
  - depends_on 02-01: needs functions/package.json + tsconfig.json + node_modules from `npm install` to compile.
  - depends_on 02-02: not a strict code dependency (ping does not import any helper) but a wave-2 sibling — both 02-01 + 02-02 are wave-1, this is wave-2 — and grouping them all in PR-1 means the helpers SHOULD compile cleanly alongside the index.ts so the PR is internally consistent.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Replace functions/src/index.ts placeholder with the ping callable; verify build + manual emulator boot</name>
  <files>functions/src/index.ts</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/functions/src/index.ts (CURRENT state — Plan 02-01 left it as `export {};` placeholder; confirm before replacing)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-PATTERNS.md (§Group 8 — `functions/src/index.ts` lines 533-553 verbatim skeleton)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-RESEARCH.md (§Pattern 1 — lines 281-309 v2 onCall code shape; §Pitfall 6 lines 685-692 — emulator bypasses App Check, documented intent)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-CONTEXT.md (D-01, D-06, D-07, D-19 — App Check on day 1; single ping callable; onCall only; PR-1 includes enforceAppCheck keyword)
    - /Users/arnobrizwan/Mentor-Mind/functions/tsconfig.json (Plan 02-01 — confirm noUnusedLocals is on so the `_request` underscore is justified)
  </read_first>
  <action>
    Step A — Replace functions/src/index.ts content:
      Overwrite the entire file with the 14-line skeleton from `<interfaces>`. The current content (`export {};` from Plan 02-01) is the placeholder; this plan replaces it with the real callable. Use the Write tool — do not append.

      Final file content (full):
      ```typescript
      import { onCall } from "firebase-functions/https";

      export const ping = onCall(
        {
          region: "asia-south1",
          enforceAppCheck: true,
        },
        (_request) => {
          return {
            ok: true,
            timestamp: Date.now(),
            region: "asia-south1",
          };
        }
      );
      ```

    Step B — Build:
      `cd functions && npm run build`
      Confirm: exits 0; `functions/lib/index.js` exists; `functions/lib/index.d.ts` exists (sourceMap: true also produces `index.js.map`).

      Sanity-check the compiled output exports ping:
      `node -e "const m = require('./functions/lib/index.js'); if (!m.ping) throw new Error('ping not exported'); console.log(typeof m.ping)"`
      Expected stdout: `function` (the onCall wrapper returns a function-like object).

    Step C — Lint:
      `cd functions && npm run lint` — exits 0. The `_request` underscore + the absence of unused imports keep the file clean against `@typescript-eslint/no-unused-vars` and the type-checked preset.

    Step D — Emulator boot smoke (MANUAL VERIFICATION — capture stdout):
      In one terminal:
        `cd /Users/arnobrizwan/Mentor-Mind && firebase emulators:start --only functions 2>&1 | tee /tmp/p2-03-emu-boot.log`
      Wait 10 seconds. Confirm stdout contains a line matching:
        `functions[asia-south1-ping]` OR `https function initialized.*ping`
      Then Ctrl-C the emulator.

      NOTE: Plan 02-04 adds `functions: { port: 5001 }` to firebase.json. Without it, the emulator MAY refuse to start ("functions emulator port not configured") OR fall back to default port 5001 with a warning. If the emulator refuses, defer the manual smoke verification to Plan 02-04 — the static gates (build + lint + grep) still pass.

      Verification of the boot smoke is BEST EFFORT in this plan; the authoritative end-to-end gate is Plan 02-09's `ping_smoke_test.dart` which calls the callable via the Flutter client.

    Step E — Commit:
      `git add functions/src/index.ts`
      Commit message: `feat(functions): add ping callable — onCall, asia-south1, enforceAppCheck: true (Phase 2 PR-1 / FUNC-02; CONTEXT D-01, D-06)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f functions/src/index.ts &amp;&amp; grep -q "enforceAppCheck: true" functions/src/index.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "region: \"asia-south1\"" functions/src/index.ts &amp;&amp; grep -q "export const ping" functions/src/index.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'from "firebase-functions/https"' functions/src/index.ts &amp;&amp; ! grep -q 'firebase-functions/v2/https' functions/src/index.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -E "onRequest|cors|cookies" functions/src/index.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; npm run build 2>&amp;1 | tee /tmp/p2-03-build.log; test $? -eq 0 &amp;&amp; test -f lib/index.js</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; node -e "const m=require('./lib/index.js'); if(!m.ping) throw new Error('ping not exported from lib/index.js'); console.log('ping exported:', typeof m.ping)"</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; npm run lint 2>&amp;1 | tee /tmp/p2-03-lint.log; test $? -eq 0</automated>
  </verify>
  <acceptance_criteria>
    - functions/src/index.ts exists and contains the literal strings `enforceAppCheck: true`, `region: "asia-south1"`, `export const ping`.
    - Imports from `"firebase-functions/https"` (NOT `"firebase-functions/v2/https"`).
    - No `onRequest`, `cors`, or `cookies` references (D-07 — onCall only).
    - `npm run build` exits 0 and produces functions/lib/index.js.
    - `node -e require('./lib/index.js').ping` confirms ping is exported (not undefined).
    - `npm run lint` exits 0.
  </acceptance_criteria>
  <done>
    The ping callable is on disk and compiles. Plan 02-04 adds the emulator port wiring; Plan 02-09's integration test then exercises the callable end-to-end via the Flutter client. Production deploy is deferred to Phase 3 per D-23.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| anonymous internet caller ⇄ ping callable (production deploy — Phase 3+) | Server-side `enforceAppCheck: true` rejects calls without a valid App Check token. Emulator bypasses this (RESEARCH Pitfall 6); production cannot. |
| Flutter client ⇄ ping (emulator, Phase 2) | Emulator returns the response shape without App Check validation. The integration test (02-09) asserts the shape, not the auth gate. Auth gate is verified by Phase 3 production manual test (Phase 2 success criterion 2 in CONTEXT.md). |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-2-APPCHECK-BYPASS | Spoofing | functions/src/index.ts — anonymous caller without a valid App Check token reaches the ping handler | mitigate | `enforceAppCheck: true` in the onCall options object (line 5 of the file). Firebase runtime rejects un-tokened calls with HTTP 401 / error code 'unauthenticated' before the handler runs (no in-handler code needed). Verify: grep functions/src/index.ts for the literal string `enforceAppCheck: true`. RESEARCH §Common Pitfalls 6 documents that the Functions emulator does NOT enforce this — intentional, so Phase 2 emulator tests pass; Phase 3 production deploy is when this actually gates real callers. |
| T-2-03-WRONG-REGION | Repudiation | Region drift between server (`region: "asia-south1"`) and Flutter client (`FirebaseFunctions.instanceFor(region: '...')` in Plan 02-07) — call routes to default us-central1 and 404s | mitigate | Both ends use the literal string `"asia-south1"` (Plan 02-07's verify greps the client for the same string). Phase 2 ROADMAP non-negotiable: asia-south1 only. |
| T-2-03-RESPONSE-LEAK | Information Disclosure | Ping response leaks server state (env vars, internal IDs) | accept | Ping returns 3 fields (ok, timestamp, region) — no PII, no internal IDs. Verified by inspection. Date.now() leaks server clock skew which is public information. |
| T-2-03-V1-API-DRIFT | Tampering | A future maintainer rewrites ping using v1 chaining (`functions.region().https.onCall`) which compiles but does not respect enforceAppCheck the same way | mitigate | RESEARCH §Anti-Patterns explicitly bans v1 chaining; tsconfig + lint will not catch this drift, but a docs/comment block in functions/src/index.ts (added in Plan 02-11 phase-closeout SUMMARY) records the contract. For Phase 2, the grep on `from "firebase-functions/https"` catches the v2 path. |
</threat_model>

<verification>
- functions/src/index.ts contains `enforceAppCheck: true` and `region: "asia-south1"`.
- Import path is `"firebase-functions/https"` (v6 re-export path).
- No `onRequest` / `cors` / `cookies` references (D-07).
- `npm run build` produces lib/index.js exporting `ping`.
- `npm run lint` exits 0.
</verification>

<success_criteria>
- D-01 met: enforceAppCheck:true ships in PR-1 from PR-merge — day-1 hard enforcement (server-side; client activation lands in PR-3).
- D-06 met: single ping callable; region asia-south1; response shape `{ok, timestamp, region}`.
- D-07 met: onCall only; no HTTP-style routing.
- D-23 honored: no production deploy in Phase 2.
- FUNC-02 partially met (callable exists; end-to-end exercise from Flutter client lands in Plan 02-09).
- T-2-APPCHECK-BYPASS mitigation in place on the server side (client side mitigation lands in Plan 02-06).
</success_criteria>

<output>
Create `.planning/phases/02-cloud-functions-scaffolding-app-check/02-03-ping-callable-SUMMARY.md` when done. Record: the full content of functions/src/index.ts as written, the `npm run build` exit + the path of the generated lib/index.js, the `node -e require(...).ping` typeof output, the `npm run lint` exit, and (if attempted) the emulator boot log line confirming `ping[asia-south1]` registered.
</output>
