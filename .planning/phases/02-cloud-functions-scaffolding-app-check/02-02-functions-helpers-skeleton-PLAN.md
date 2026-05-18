---
phase: 02-cloud-functions-scaffolding-app-check
plan: 02
type: execute
wave: 1
depends_on: []
files_modified:
  - functions/src/lib/admin.ts
  - functions/src/lib/errors.ts
  - functions/src/lib/gemini.ts
  - functions/src/lib/rate_limit.ts
  - functions/src/lib/claims.ts
autonomous: true
requirements: [FUNC-01]
pr_group: PR-1
tags: [functions_helpers, firebase_admin_singleton, https_error_factory, gemini_stub, rate_limit_stub, claims_stub, mapKnownError]

must_haves:
  truths:
    - "D-05 honored: 5 helper files ship — admin.ts and errors.ts FULLY implemented; gemini.ts / rate_limit.ts / claims.ts are TypeScript interface stubs throwing 'not implemented'"
    - "D-20 honored: NO Gemini SDK in functions/package.json; gemini.ts stub only (Phase 3 fills body)"
    - "D-21 honored: rate_limit.ts is interface stub only (Phase 3 fills transactional UTC+6 counter)"
    - "D-22 honored: claims.ts is interface stub only (Phase 5 fills setPremium + getRole)"
    - "admin.ts is a singleton — uses `if (!admin.apps.length) { admin.initializeApp(); }` guard (RESEARCH Pattern 3)"
    - "errors.ts exports 5 factory functions + mapKnownError per CONTEXT D-05; T-2-ERROR-LEAK mitigated"
    - "All stub bodies throw `new Error('not implemented — see Phase X')` so accidental call surfaces immediately"
    - "Parameters in stubs prefixed with underscore (`_uid`, `_kind`, `_opts`) to satisfy noUnusedLocals (RESEARCH Pitfall 8)"
  artifacts:
    - path: "functions/src/lib/admin.ts"
      provides: "firebase-admin singleton initialization + db/auth named exports"
      contains: "admin.initializeApp"
    - path: "functions/src/lib/errors.ts"
      provides: "HttpsError factory wrappers + mapKnownError translator"
      contains: "mapKnownError"
    - path: "functions/src/lib/gemini.ts"
      provides: "Phase 3 interface stub: callGemini(prompt, opts): Promise<GeminiResponse>"
      contains: "not implemented"
    - path: "functions/src/lib/rate_limit.ts"
      provides: "Phase 3 interface stub: checkAndIncrement(uid, kind): Promise<RateLimitResult>"
      contains: "not implemented"
    - path: "functions/src/lib/claims.ts"
      provides: "Phase 5 interface stub: setPremium(uid, isPremium) + getRole(uid)"
      contains: "not implemented"
  key_links:
    - from: "functions/src/lib/errors.ts"
      to: "firebase-functions/https HttpsError"
      via: "named import"
      pattern: "import.*HttpsError.*firebase-functions/https"
    - from: "functions/src/lib/admin.ts"
      to: "firebase-admin SDK"
      via: "default import + singleton guard"
      pattern: "admin\\.apps\\.length"
---

<objective>
Land all 5 helper files under `functions/src/lib/`. `admin.ts` and `errors.ts` are FULLY implemented per RESEARCH Patterns 2 + 3; `gemini.ts`, `rate_limit.ts`, `claims.ts` are TypeScript interface stubs that throw `new Error('not implemented — see Phase X')`. Stable import contracts so Phase 3 (gemini + rate_limit) and Phase 5 (claims) fill function bodies without touching callers.

Purpose: CONTEXT D-05 makes this an explicit Phase 2 deliverable — shipping the 5 import sites in PR-1 (alongside the monorepo scaffold) prevents downstream phases from inventing helper paths. errors.ts's mapKnownError factory is the T-2-ERROR-LEAK mitigation (the ping callable in Plan 02-03 does not call mapKnownError because there is no try/catch path; later callables in Phase 3+ will).

Output: 5 files under `functions/src/lib/`. After commit, `cd functions && npm run lint && npm run build` exits 0 — the stubs compile, the strict-mode flags accept the underscore-prefixed unused params, and lib/index.js does NOT yet exist (ping callable lands in Plan 02-03 which replaces the placeholder src/index.ts).
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
@CLAUDE.md

<interfaces>
<!-- All 5 skeletons below come verbatim from 02-PATTERNS.md (Group 8) and 02-RESEARCH.md (Patterns 2 + 3). -->

functions/src/lib/admin.ts (RESEARCH Pattern 3 + 02-PATTERNS.md Group 8 lines 562-578):
  ```typescript
  import * as admin from "firebase-admin";

  // Singleton: initializeApp() uses FIREBASE_CONFIG env var set by the runtime.
  // Guard prevents re-initialization when the module is hot-reloaded in emulator.
  if (!admin.apps.length) {
    admin.initializeApp();
  }

  export const db = admin.firestore();
  export const auth = admin.auth();
  export default admin;
  ```

functions/src/lib/errors.ts (RESEARCH Pattern 2 + 02-PATTERNS.md Group 8 lines 587-617):
  ```typescript
  import { HttpsError } from "firebase-functions/https";

  export function unauthenticated(message: string): HttpsError {
    return new HttpsError("unauthenticated", message);
  }

  export function permissionDenied(message: string): HttpsError {
    return new HttpsError("permission-denied", message);
  }

  export function failedPrecondition(message: string): HttpsError {
    return new HttpsError("failed-precondition", message);
  }

  export function invalidArgument(message: string): HttpsError {
    return new HttpsError("invalid-argument", message);
  }

  export function internal(message: string): HttpsError {
    return new HttpsError("internal", message);
  }

  export function mapKnownError(error: unknown): HttpsError {
    if (error instanceof HttpsError) return error;
    const msg = error instanceof Error ? error.message : "Unknown error";
    return new HttpsError("internal", msg);
  }
  ```

functions/src/lib/gemini.ts (02-PATTERNS.md Group 8 lines 627-644):
  ```typescript
  // Phase 3 interface — stub only. Do NOT implement in Phase 2.

  export interface GeminiCallOptions {
    maxOutputTokens?: number;
    temperature?: number;
  }

  export interface GeminiResponse {
    text: string;
    finishReason?: string;
  }

  export async function callGemini(
    _prompt: string,
    _opts?: GeminiCallOptions
  ): Promise<GeminiResponse> {
    throw new Error("not implemented — see Phase 3");
  }
  ```
  NOTE: PATTERNS.md shows `prompt` not `_prompt`; under noUnusedLocals + an empty body, the param triggers an error. Prefix with underscore as the other stubs do.

functions/src/lib/rate_limit.ts (02-PATTERNS.md Group 8 lines 655-669):
  ```typescript
  // Phase 3 interface — stub only. Do NOT implement in Phase 2.

  export interface RateLimitResult {
    allowed: boolean;
    remaining: number;
    resetAt: number; // Unix ms timestamp when the counter resets (midnight UTC+6)
  }

  export async function checkAndIncrement(
    _uid: string,
    _kind: "text" | "image"
  ): Promise<RateLimitResult> {
    throw new Error("not implemented — see Phase 3");
  }
  ```

functions/src/lib/claims.ts (02-PATTERNS.md Group 8 lines 680-693):
  ```typescript
  // Phase 5 interface — stub only. Do NOT implement in Phase 2.

  export type UserRole = "student" | "teacher" | "admin";

  export async function setPremium(
    _uid: string,
    _isPremium: boolean
  ): Promise<void> {
    throw new Error("not implemented — see Phase 5");
  }

  export async function getRole(_uid: string): Promise<UserRole> {
    throw new Error("not implemented — see Phase 5");
  }
  ```

Build behavior note:
  - Plan 02-01 left functions/src/index.ts as `export {};` placeholder. This plan adds 5 files under src/lib/ but does NOT touch src/index.ts (Plan 02-03 replaces it with the real ping callable).
  - After this plan: `tsc` compiles 6 files (index.ts + 5 lib/*.ts) into 6 .js files under lib/. Verify: `ls functions/lib/lib/*.js | wc -l` → 5.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Write all 5 helper files (admin.ts, errors.ts fully implemented + gemini/rate_limit/claims stubs)</name>
  <files>functions/src/lib/admin.ts, functions/src/lib/errors.ts, functions/src/lib/gemini.ts, functions/src/lib/rate_limit.ts, functions/src/lib/claims.ts</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-PATTERNS.md (§Group 8 — lines 559-697: ALL 5 helper skeletons VERBATIM)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-RESEARCH.md (§Pattern 2 errors.ts lines 313-339; §Pattern 3 admin.ts lines 345-356; §Pitfall 8 noUncheckedIndexedAccess implications lines 705-713)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-CONTEXT.md (D-05 — 5 helper files; D-20 NO Gemini code; D-21 NO rate limit; D-22 NO claims)
    - /Users/arnobrizwan/Mentor-Mind/functions/tsconfig.json (Plan 02-01 — confirm strict + noUnusedLocals enabled before deciding underscore-prefix on stub params)
  </read_first>
  <action>
    Write all 5 files under `functions/src/lib/` using the exact skeletons in `<interfaces>` above. Specific requirements:

    File 1 — functions/src/lib/admin.ts (FULL implementation):
      Use the 10-line skeleton from `<interfaces>` verbatim. The `if (!admin.apps.length)` guard is mandatory — without it, hot-reload in emulator (or duplicate imports across helpers) throws "App named '[DEFAULT]' already exists". Export named `db` and `auth` for callers that want subset access; export `admin` as default for full-SDK callers.

    File 2 — functions/src/lib/errors.ts (FULL implementation):
      Use the 24-line skeleton from `<interfaces>` verbatim. Five named factories (`unauthenticated`, `permissionDenied`, `failedPrecondition`, `invalidArgument`, `internal`) plus `mapKnownError(error: unknown)` translator. Import from `"firebase-functions/https"` (the v6 re-export path; NOT `"firebase-functions/v2/https"`).

    File 3 — functions/src/lib/gemini.ts (STUB):
      Use the 17-line skeleton from `<interfaces>` verbatim. Two interfaces (`GeminiCallOptions`, `GeminiResponse`) + one async function (`callGemini`) that throws `new Error("not implemented — see Phase 3")`. Parameters MUST be prefixed `_prompt` and `_opts` (the PATTERNS.md skeleton has `prompt` without underscore — UPDATE to `_prompt` because tsconfig's noUnusedLocals would otherwise fail compilation).

    File 4 — functions/src/lib/rate_limit.ts (STUB):
      Use the 14-line skeleton from `<interfaces>` verbatim. One interface (`RateLimitResult`) + one async function (`checkAndIncrement(_uid: string, _kind: "text" | "image")`) throwing `new Error("not implemented — see Phase 3")`. The resetAt JSDoc comment `// Unix ms timestamp when the counter resets (midnight UTC+6)` is intentional — Phase 3 reads this constraint when implementing.

    File 5 — functions/src/lib/claims.ts (STUB):
      Use the 13-line skeleton from `<interfaces>` verbatim. One type alias (`UserRole = "student" | "teacher" | "admin"`) + two async functions (`setPremium(_uid, _isPremium): Promise<void>`, `getRole(_uid): Promise<UserRole>`) both throwing `new Error("not implemented — see Phase 5")`.

    Build verification:
      `cd functions && npm run build` — exits 0. Confirm `functions/lib/lib/admin.js`, `errors.js`, `gemini.js`, `rate_limit.js`, `claims.js` materialize (note: tsc preserves the src/lib/ directory structure under outDir, so they end up at lib/lib/*.js — this is correct given rootDir:src + the files being at src/lib/*.ts; the resulting lib/lib/ nesting is intentional and Plan 02-03's index.ts at src/index.ts will compile to lib/index.js as the single entrypoint that `main` in package.json points to).

      Alternative interpretation: if the team prefers `lib/admin.js` (flat) over `lib/lib/admin.js`, that would require either moving src/lib → src/_lib or changing rootDir. CONTEXT.md D-05 specifies the path `functions/src/lib/admin.ts` so accept the nested output. The ping callable in Plan 02-03 imports as `from "./lib/admin"` which works regardless of the compiled output path because tsc maps imports correctly.

    Lint verification:
      `cd functions && npm run lint` — exits 0. Underscore-prefixed unused parameters do NOT trigger `@typescript-eslint/no-unused-vars` because the default rule allows `^_`. Verify no lint errors.

    Commit:
      `git add functions/src/lib/admin.ts functions/src/lib/errors.ts functions/src/lib/gemini.ts functions/src/lib/rate_limit.ts functions/src/lib/claims.ts`
      Commit message: `feat(functions): scaffold src/lib helpers — admin singleton + errors factory + 3 stubs (Phase 2 PR-1 / FUNC-01; CONTEXT D-05)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f functions/src/lib/admin.ts &amp;&amp; test -f functions/src/lib/errors.ts &amp;&amp; test -f functions/src/lib/gemini.ts &amp;&amp; test -f functions/src/lib/rate_limit.ts &amp;&amp; test -f functions/src/lib/claims.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'admin.initializeApp' functions/src/lib/admin.ts &amp;&amp; grep -q 'admin\.apps\.length' functions/src/lib/admin.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'mapKnownError' functions/src/lib/errors.ts &amp;&amp; grep -q 'HttpsError' functions/src/lib/errors.ts &amp;&amp; grep -cE '^export function' functions/src/lib/errors.ts | grep -qE '^[6-9]|[1-9][0-9]+$' || grep -c 'export function' functions/src/lib/errors.ts | xargs -I{} test {} -ge 6</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'not implemented' functions/src/lib/gemini.ts &amp;&amp; grep -q 'not implemented' functions/src/lib/rate_limit.ts &amp;&amp; grep -q 'not implemented' functions/src/lib/claims.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -E "@google/generative-ai|google-generative-ai" functions/src/lib/gemini.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; npm run build 2>&amp;1 | tee /tmp/p2-02-build.log; test $? -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; npm run lint 2>&amp;1 | tee /tmp/p2-02-lint.log; test $? -eq 0</automated>
  </verify>
  <acceptance_criteria>
    - All 5 .ts files exist under functions/src/lib/.
    - admin.ts contains the singleton guard `if (!admin.apps.length)` and `admin.initializeApp()` call.
    - errors.ts exports 6 functions (5 factories + mapKnownError) and imports HttpsError from `"firebase-functions/https"`.
    - All 3 stub files contain the literal string `not implemented`.
    - gemini.ts does NOT import @google/generative-ai (D-20).
    - `cd functions && npm run build` exits 0 — strict-mode flags accept underscore-prefixed unused params.
    - `cd functions && npm run lint` exits 0 — no @typescript-eslint violations.
  </acceptance_criteria>
  <done>
    All 5 helper sites are stable import targets. Plan 02-03 can import `from "./lib/errors"` and `from "./lib/admin"` if needed (the ping callable does NOT need either — ping is a no-op without auth or Firestore). Phase 3 / Phase 5 will fill the stub bodies without changing import signatures.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| functions runtime ⇄ external caller | Helpers are not directly called from outside — they are imported by callables (ping in 02-03; future mentorBotChat in P3; future setPremium in P5). The trust boundary is the callable surface, not the helpers. |
| errors.ts ⇄ internal SDK errors | mapKnownError wraps any thrown value into HttpsError("internal", ...) — the human-readable message MAY leak internal state (Firestore error codes, stack frames). The wrapper truncates to `error.message`, which firebase-admin sanitizes. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-2-ERROR-LEAK | Information Disclosure | functions/src/lib/errors.ts — mapKnownError wraps unknown errors but the error.message field is preserved | mitigate | mapKnownError casts to `error.message` only (never `error.stack`, never `JSON.stringify(error)`); HttpsError("internal", msg) is the only path; callers in Phase 3+ wrap try/catch with this factory. Phase 2 itself (ping callable in 02-03) has no try/catch path because ping has no I/O. Verify: grep functions/src/lib/errors.ts for the literal `error.message` (not `error.stack`). |
| T-2-02-STUB-ACCIDENTAL-CALL | Repudiation | A future caller in Phase 3+ imports `callGemini` before Phase 3 ships its body and ships with the stub | mitigate | Stub throws `new Error("not implemented — see Phase X")` — production-fast-fail. CI in Plan 02-10 builds but does not execute the stubs. Phase 3 / 5 plans MUST include an integration test that exercises the new body before shipping. |
| T-2-02-ADMIN-DOUBLE-INIT | Denial of Service | admin.initializeApp() called twice (e.g. import cycle or hot-reload) crashes the function instance | mitigate | `if (!admin.apps.length)` guard in admin.ts (RESEARCH Pattern 3). Verified by inspection. |
| T-2-02-NO-SECRETS-IN-CODE | Information Disclosure | A developer commits API keys / OAuth secrets into one of the 5 helper files | accept | Phase 2 helpers have no secrets (D-20 / D-21 / D-22 block Gemini key + premium webhook secret); Phase 3 will use Secret Manager (AI-01) — not env vars in source. Out of scope for THIS plan; checked by Phase 3 plans. |
</threat_model>

<verification>
- All 5 .ts files exist and match the skeletons in 02-PATTERNS.md Group 8.
- npm run build exits 0 (TypeScript compiles all 5 + the placeholder index.ts).
- npm run lint exits 0.
- gemini.ts has zero references to the Gemini SDK (D-20 honored).
- errors.ts exports 6 functions (5 named factories + mapKnownError).
</verification>

<success_criteria>
- D-05 honored: 5 helper files ship with admin + errors fully implemented and the other 3 as stubs.
- D-20 / D-21 / D-22 honored: zero implementation code for Gemini / rate-limit / claims.
- T-2-ERROR-LEAK mitigated via mapKnownError's error.message-only path.
- FUNC-01 part 2/3 met (monorepo skeleton from 02-01 + helpers here + ping callable in 02-03 = full FUNC-01).
- Plan 02-03 can import `from "./lib/errors"` if the ping handler grows error paths (it does not in v1 — but the import target exists).
- Phase 3 (gemini + rate_limit) and Phase 5 (claims) have stable file paths to fill in without changing call sites.
</success_criteria>

<output>
Create `.planning/phases/02-cloud-functions-scaffolding-app-check/02-02-functions-helpers-skeleton-SUMMARY.md` when done. Record: the full content of each of the 5 .ts files as written, the npm run build output (last 5 lines), the npm run lint output (last 5 lines), the `ls functions/lib/lib/` listing showing the 5 compiled .js files, and the `grep -c 'not implemented' functions/src/lib/*.ts` count (must be ≥ 3).
</output>
