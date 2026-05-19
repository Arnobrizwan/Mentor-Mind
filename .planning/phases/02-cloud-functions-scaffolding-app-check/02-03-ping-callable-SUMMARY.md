---
phase: 02-cloud-functions-scaffolding-app-check
plan: 03
subsystem: infra
tags: [firebase_functions_v2, onCall, enforceAppCheck, asia_south1, ping_callable, app_check_canary, typescript]

requires:
  - phase: 02-cloud-functions-scaffolding-app-check
    plan: "02-01"
    provides: "functions/package.json + tsconfig.json + node_modules; export {} placeholder in functions/src/index.ts"
  - phase: 02-cloud-functions-scaffolding-app-check
    plan: "02-02"
    provides: "functions/src/lib/errors.ts + admin.ts + stubs for gemini/rate_limit/claims — compile-clean helpers alongside index.ts"

provides:
  - "functions/src/index.ts: named export `ping` — onCall callable, region asia-south1, enforceAppCheck: true"
  - "functions/lib/index.js: compiled CJS output exporting `ping` as a function"
  - "T-2-APPCHECK-BYPASS server-side mitigation in place (enforceAppCheck: true)"

affects:
  - "02-04-firebase-json-emulator-port: wires functions port to firebase.json so emulator boot smoke can run"
  - "02-06-app-check-flutter-client: adds client-side App Check activation (PR-3 partner)"
  - "02-07-flutter-functions-sdk: FirebaseFunctions.instanceFor(region: 'asia-south1') must match this region pin"
  - "02-09-ping-smoke-test: exercises this callable end-to-end from Flutter client"

tech-stack:
  added: []
  patterns:
    - "firebase-functions/https onCall v2 API: import { onCall } from 'firebase-functions/https' (not v2/https re-export path)"
    - "enforceAppCheck in onCall options object (top-level key, not nested)"
    - "_request underscore prefix for unused handler param — required by noUnusedLocals: true in tsconfig"
    - "Response includes region field for client-side sanity-check observability (D-06 discretion)"

key-files:
  created: []
  modified:
    - "functions/src/index.ts — replaced export {} placeholder with real ping onCall callable (15 LOC)"
    - "functions/lib/index.js — compiled output (gitignored; rebuilt by npm run build)"

key-decisions:
  - "D-01 honored: enforceAppCheck: true ships in PR-1 (server-side); client-side App Check activation deferred to PR-3 (Plan 02-06)"
  - "D-06 honored: single ping callable; region asia-south1; response shape {ok, timestamp, region}"
  - "D-07 honored: onCall only — no onRequest, cors, or cookies"
  - "D-23 honored: no production deploy in Phase 2; emulator boot blocked until Plan 02-04 adds functions port to firebase.json"
  - "Import from firebase-functions/https (v6 re-export root path), NOT firebase-functions/v2/https"

patterns-established:
  - "Pattern: firebase-functions v2 onCall with enforceAppCheck is a top-level option, not chained v1 style"
  - "Pattern: unused handler params prefixed with underscore to satisfy noUnusedLocals: true"

requirements-completed: [FUNC-02]

duration: 2min
completed: 2026-05-19
---

# Phase 2 Plan 03: Ping Callable Summary

**`ping` onCall callable shipping with `enforceAppCheck: true` in asia-south1, returning `{ok, timestamp, region}` — the App Check canary that proves Functions plumbing before Phase 3 layers Gemini logic**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-05-19T01:21:51Z
- **Completed:** 2026-05-19T01:23:05Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Replaced `export {};` placeholder (Plan 02-01) with the real `ping` onCall callable using firebase-functions v2 `https` path
- `npm run build` exits 0; `functions/lib/index.js` produced; `node -e require('./lib/index.js').ping` confirms `typeof ping === 'function'`
- `npm run lint` exits 0; `_request` underscore satisfies `noUnusedLocals: true`; no `onRequest`/`cors`/`cookies` in file
- T-2-APPCHECK-BYPASS mitigation in place: `enforceAppCheck: true` in onCall options object (server-side enforcement from PR-merge)
- Emulator boot smoke deferred to Plan 02-04 (expected: `firebase.json` lacks `functions` emulator port until that plan runs)

## Task Commits

1. **Task 1: Replace placeholder with ping callable** - `83b5b1b` (feat)

**Plan metadata:** (combined with task commit — single-task plan)

## Files Created/Modified

- `functions/src/index.ts` — Replaced 1-line `export {};` placeholder with 15-LOC ping onCall callable (onCall v2, asia-south1, enforceAppCheck: true, returns `{ok, timestamp, region}`)
- `functions/lib/index.js` — Compiled output regenerated (gitignored)

## Key implementation (functions/src/index.ts as written)

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

## Build + Lint Evidence

- `npm run build` exit: **0** — `functions/lib/index.js` + `functions/lib/index.js.map` + `functions/lib/index.d.ts` produced
- `node -e require('./lib/index.js').ping` output: **`ping exported: function`**
- `npm run lint` exit: **0** — ESLint clean, no unused vars, no type errors
- Emulator boot attempt: **deferred** — `firebase.json` has no `functions` emulator port yet (Plan 02-04 adds it); emulator correctly rejected `--only functions` with "No emulators to start" — expected behavior per plan note

## Decisions Made

- Import from `"firebase-functions/https"` not `"firebase-functions/v2/https"` — firebase-functions v6 re-exports from the root `https` path; using v2 path would be wrong
- `_request` underscore — required by `noUnusedLocals: true` in tsconfig (Plan 02-01); the handler receives no data from ping callers
- Response includes `region: "asia-south1"` field — discretion from D-06; confirms asia-south1 pin from client perspective (Plan 02-07 client greps for the same string)
- No `admin.initializeApp()` import — ping has no Firestore/Auth touch points; admin.ts handles init for future callables that do import it

## Deviations from Plan

None — plan executed exactly as written. Emulator boot smoke was documented as best-effort and correctly deferred to Plan 02-04.

## Issues Encountered

None. The `macOS` environment lacks GNU `timeout`/`gtimeout`, so the emulator smoke was run via background process + sleep + kill — it exited immediately with "No emulators to start" as expected (functions port not in firebase.json). This is the documented expected behavior.

## Threat Surface Scan

No new threat surface introduced beyond what is in the plan's threat model. `enforceAppCheck: true` is present (T-2-APPCHECK-BYPASS mitigated server-side). Response shape leaks only `ok`, `timestamp` (server clock), `region` — no PII, no internal IDs (T-2-03-RESPONSE-LEAK accepted per plan).

## Known Stubs

None — `functions/src/index.ts` is fully implemented with no placeholder logic.

## Next Phase Readiness

- Plan 02-04 (firebase.json emulator port) can now run and will enable the full emulator boot smoke: `firebase emulators:start --only functions` will print `functions[asia-south1-ping]: https function initialized`
- Plan 02-07 (Flutter Functions SDK) should match `FirebaseFunctions.instanceFor(region: 'asia-south1')` — region pin locked here
- Plan 02-09 (ping smoke test) can exercise the callable end-to-end once Plans 02-04 + 02-07 land
- FUNC-02 partially met: callable exists and compiles; end-to-end exercise from Flutter client lands in Plan 02-09

---
*Phase: 02-cloud-functions-scaffolding-app-check*
*Completed: 2026-05-19*

## Self-Check: PASSED

- `functions/src/index.ts`: FOUND
- `functions/lib/index.js`: FOUND (post-build)
- Commit `83b5b1b`: FOUND
- `enforceAppCheck: true` in index.ts: FOUND
- `export const ping` in index.ts: FOUND
- `from "firebase-functions/https"` in index.ts: FOUND
- No `onRequest`/`cors`/`cookies` in index.ts: CONFIRMED
