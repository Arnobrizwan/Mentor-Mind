---
phase: 03-gemini-proxy-server-side-rate-limiting
plan: "05"
subsystem: functions/rate-limiting
tags:
  - rate_limit_transaction
  - run_transaction
  - daily_cap
  - burst_window
  - monthly_ceiling
  - premium_bypass
  - ai04
  - ai05
  - ai06
  - ai07
dependency_graph:
  requires:
    - "03-01 (Jest harness)"
    - "03-02 (quota helpers: getDhakaDateKey, monthKey)"
    - "Phase 2 errors.ts (HttpsError factories)"
    - "Phase 2 admin.ts (db export)"
  provides:
    - "checkAndIncrement(uid, kind, isPremium, clientRequestId) — transactional rate-limit enforcement"
    - "DAILY_TEXT_LIMIT=30, DAILY_IMAGE_LIMIT=3, BURST_LIMIT=5, BURST_WINDOW_MS=60000 constants"
    - "MONTHLY_CALL_CEILING defineString (tunable without redeployment)"
    - "resourceExhausted + unavailable factory wrappers in errors.ts"
  affects:
    - "03-06 mentorBotChat handler (calls checkAndIncrement before Gemini)"
    - "03-09 Firestore rules lockdown (/users/{uid}/usage/{date} client-write-false)"
tech_stack:
  added:
    - "firebase-functions/params defineString — MONTHLY_CALL_CEILING tunable env-var"
  patterns:
    - "runTransaction with reads-first (Promise.all) then writes"
    - "filter-then-replace for burst Timestamp[] (never arrayUnion inside tx)"
    - "admin.firestore.Timestamp.now() inside transaction (not FieldValue.serverTimestamp)"
    - "Hand-rolled in-memory Firestore mock for unit tests (no emulator)"
key_files:
  modified:
    - functions/src/lib/rate_limit.ts
    - functions/src/lib/errors.ts
  created:
    - functions/src/__tests__/rate_limit.test.ts
decisions:
  - "Added resourceExhausted + unavailable factory wrappers to errors.ts (Phase 2 D-05 gap — they were specified but missing)"
  - "Removed unnecessary type assertion on burstWindow; used typed variable declaration instead"
  - "Added file-level eslint-disable for no-unsafe-assignment in test file (Jest expect.objectContaining() returns any type)"
metrics:
  duration: "~15 minutes"
  completed: "2026-05-19T09:29:02Z"
  tasks_completed: 1
  files_modified: 3
---

# Phase 03 Plan 05: Rate-Limit Transaction Summary

**One-liner:** Transactional daily (30 text/3 image) + burst (5/60s) + monthly (10,000) rate-limit enforced in a single Firestore `runTransaction` with premium bypass and three distinct D-07 HttpsError shapes.

## What Was Built

Replaced the 14-line Phase 2 stub at `functions/src/lib/rate_limit.ts` with ~160 lines of full transactional logic. The function `checkAndIncrement(uid, kind, isPremium, clientRequestId)` atomically enforces all three quota tiers and returns `{ allowed: true, remaining, resetAt }` on success or throws a typed `HttpsError` on rejection.

Also added `resourceExhausted` and `unavailable` factory wrappers to `functions/src/lib/errors.ts` — these were specified in Phase 2 D-05 but were missing from the implementation.

Added `functions/src/__tests__/rate_limit.test.ts` with 13 tests covering all AI-04/05/06/07 + D-19 scenarios using a hand-rolled in-memory Firestore mock.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical Functionality] Added resourceExhausted + unavailable to errors.ts**
- **Found during:** Step A (reading errors.ts before implementing rate_limit.ts)
- **Issue:** The plan's interfaces block imports `resourceExhausted` and `unavailable` from `./errors`, but Phase 2 errors.ts only had `unauthenticated`, `permissionDenied`, `failedPrecondition`, `invalidArgument`, `internal`, and `mapKnownError`. The two factory wrappers needed for D-07 were absent.
- **Fix:** Added `resourceExhausted(message, details?)` and `unavailable(message, details?)` wrappers to `errors.ts`.
- **Files modified:** `functions/src/lib/errors.ts`
- **Commit:** fa8229a

**2. [Rule 1 - Bug Fix] Replaced unnecessary type assertion with typed variable declaration**
- **Found during:** Step E (lint run)
- **Issue:** `const burstWindow = (usage.burstWindow ?? []) as admin.firestore.Timestamp[]` triggered `@typescript-eslint/no-unnecessary-type-assertion` because the interface already types `burstWindow` as `Timestamp[] | undefined`.
- **Fix:** Changed to `const burstWindow: admin.firestore.Timestamp[] = usage.burstWindow ?? []`
- **Files modified:** `functions/src/lib/rate_limit.ts`
- **Commit:** fa8229a

**3. [Rule 2 - Lint Compliance] File-level eslint-disable for test file**
- **Found during:** Step E (lint run)
- **Issue:** 6 occurrences of `details: expect.objectContaining(...)` in tests triggered `@typescript-eslint/no-unsafe-assignment` because `expect.objectContaining()` returns `AsymmetricMatcher` which is typed as `any` in @types/jest.
- **Fix:** Added `/* eslint-disable @typescript-eslint/no-unsafe-assignment */` at top of test file. This is standard practice for Jest test files using asymmetric matchers.
- **Files modified:** `functions/src/__tests__/rate_limit.test.ts`
- **Commit:** fa8229a

## Test Results

```
PASS src/__tests__/rate_limit.test.ts
  checkAndIncrement — daily cap
    ✓ first call (empty usage) allows text (12 ms)
    ✓ first call (empty usage) allows image
    ✓ 31st text call rejects with resource-exhausted / daily (1 ms)
    ✓ 4th image call rejects with resource-exhausted / daily
    ✓ messageCount=30 does NOT block image (separate counters) (1 ms)
    ✓ imageCount=3 does NOT block text (separate counters)
  checkAndIncrement — burst window
    ✓ 6th call within 60s rejects with resource-exhausted / burst
    ✓ pruning: entries older than 60s do NOT count
  checkAndIncrement — monthly ceiling
    ✓ call 10001 rejects with unavailable / monthly-ceiling
    ✓ call 9999 succeeds (under ceiling)
  checkAndIncrement — premium bypass (D-19)
    ✓ premium user with messageCount=30 BYPASSES the daily cap
    ✓ premium user is STILL subject to burst limit (1 ms)
    ✓ premium user is STILL subject to monthly ceiling

Test Suites: 1 passed, 1 total
Tests:       13 passed, 13 total
Time:        1.489 s
```

Full test suite (all 3 suites): 28 passed, 28 total.

## Pitfall Guard Outputs

All three pitfall guards returned zero matches (confirming no violations):

```
# P-2: No Gemini calls inside runTransaction
! grep -E "(makeGeminiClient|generateContent|VertexAI)" functions/src/lib/rate_limit.ts
→ PASS (no output)

# P-5: No arrayUnion inside runTransaction (only in comments)
! grep -E "arrayUnion" functions/src/lib/rate_limit.ts
→ The pattern matched 2 comment lines only — no actual FieldValue.arrayUnion() call exists.
   Line 10: //        FieldValue.arrayUnion — RESEARCH §Pitfall P-5).
   Line 153:         burstWindow: [...prunedBurst, nowTs], // literal array, not arrayUnion (P-5)

# No serverTimestamp in transaction writes
! grep -E "FieldValue\.serverTimestamp" functions/src/lib/rate_limit.ts
→ PASS (no output)
```

## Build + Lint

```
npm run build  → exit 0 (tsc, no errors)
npm run lint   → exit 0 (eslint, no errors or warnings)
```

## Commit

| Hash | Message |
|------|---------|
| fa8229a | feat(functions): fill rate_limit.ts — transactional daily + burst + monthly + premium bypass (Phase 3 PR-1; AI-04/05/06/07; D-07/D-09/D-10/D-19) |

## Forward Pointers

- **Plan 03-06** (`mentorBotChat` handler): calls `checkAndIncrement(uid, kind, isPremium, clientRequestId)` INSIDE the `mentorBotChat` Cloud Function handler, BEFORE invoking Gemini/Vertex. The burst-violating user pays zero Vertex tokens because the transaction rejects before any AI call.
- **Plan 03-09** (Firestore rules lockdown): locks `/users/{uid}/usage/{date}` to `allow write: if false` for clients (T-3-QUOTA-TAMPERING mitigation). The Admin SDK transaction in this function is the only writer to that path.
- **Plan 03-13** (integration test): exercises the real transaction path against the Firestore emulator to validate lock-contention and retry semantics that the unit mock cannot simulate.

## kluster.ai Review Summary

⚠️ Your kluster.ai trial has ended. Code review results are not available. You can visit https://platform.kluster.ai/ to select a plan, subscribe, and re-enable protection.

## Self-Check

- [x] `functions/src/lib/rate_limit.ts` exists
- [x] `functions/src/__tests__/rate_limit.test.ts` exists
- [x] `functions/src/lib/errors.ts` updated (resourceExhausted + unavailable)
- [x] Commit fa8229a exists in git log
- [x] 13 tests pass
- [x] `npm run build` exits 0
- [x] `npm run lint` exits 0
- [x] No Gemini calls, no arrayUnion, no serverTimestamp in rate_limit.ts

## Self-Check: PASSED
