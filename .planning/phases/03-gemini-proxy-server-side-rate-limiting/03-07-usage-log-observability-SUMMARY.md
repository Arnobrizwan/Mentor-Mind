---
phase: 03-gemini-proxy-server-side-rate-limiting
plan: "07"
subsystem: functions
tags: [usage_log_observability, system_usage_log, cost_estimation, structured_logger, non_transactional_update, d_15_observability, gemini_call_log_event]
dependency_graph:
  requires: ["03-06"]
  provides: [usage_log_aggregate, gemini_call_structured_log, estimateCostUsd_helper]
  affects: ["/system/usage_log_{date}", "Cloud Logging"]
tech_stack:
  added: []
  patterns: [non_transactional_aggregate_write, failure_isolation_try_catch, structured_logger_event_fields]
key_files:
  created:
    - functions/src/__tests__/usage_log.test.ts
  modified:
    - functions/src/index.ts
decisions:
  - "Used db.collection('system').doc('usage_log_{date}') instead of db.doc('system/usage_log_{date}') to remain consistent with existing Firestore mock patterns (collection().doc() pattern) — prevents breaking idempotency test mocks"
  - "getDhakaDateKey imported at top of file (synchronous) rather than via dynamic await import() as shown in interface example — cleaner TS, avoids false circular dep concerns"
  - "estimateCostUsd uses the single-function pattern (no modelId param) since all current models share identical pricing — modelId param deferred until pricing diverges"
metrics:
  duration: "~12 minutes"
  completed: "2026-05-20"
  tasks_completed: 1
  tasks_total: 1
  files_changed: 2
  commit: "fc0e415"
---

# Phase 3 Plan 07: Usage Log Observability Summary

D-15 observability layer appended to `mentorBotChat`: per-day aggregate writes to `/system/usage_log_{Dhaka-date}` with FieldValue.increment deltas for calls/tokens/cost, plus structured `functions.logger.info({ event: 'gemini_call', ... })` per successful invocation; idempotency-hit path logs `event: 'gemini_call_idempotent_hit'` with calls-only increment (no cost — model not re-invoked); write failures are non-fatal (warn log, callable still succeeds).

## Appended Blocks in functions/src/index.ts

### New import + estimateCostUsd helper (lines 12–31)

```typescript
import { getDhakaDateKey } from "./lib/quota";

const GEMINI_INPUT_RATE_PER_MTOK = 1.25;
const GEMINI_OUTPUT_RATE_PER_MTOK = 5.0;

function estimateCostUsd(promptTokens: number, completionTokens: number): number {
  return (
    (promptTokens / 1_000_000) * GEMINI_INPUT_RATE_PER_MTOK +
    (completionTokens / 1_000_000) * GEMINI_OUTPUT_RATE_PER_MTOK
  );
}
```

### Idempotency-hit path usage_log block (lines 141–175, inside `if (idempotencySnap.exists)`)

```typescript
const idempDateKey = getDhakaDateKey();
const idempLogRef = db.collection("system").doc(`usage_log_${idempDateKey}`);
try {
  await idempLogRef.set(
    { calls: admin.firestore.FieldValue.increment(1), dateLabel: idempDateKey },
    { merge: true }
  );
} catch (logErr) {
  functions.logger.warn("mentorBotChat: idempotency-hit usage_log write failed", { uid, sessionId, clientRequestId, err: ... });
}
functions.logger.info("mentorBotChat: idempotent hit", {
  event: "gemini_call_idempotent_hit",
  uid, sessionId, clientRequestId,
  cachedPromptTokens: idempCachedPrompt,
  cachedCompletionTokens: idempCachedCompletion,
});
```

### Success path usage_log block (lines 270–316, after `batch.commit()`)

```typescript
const usageLogDateKey = getDhakaDateKey();
const usageLogRef = db.collection("system").doc(`usage_log_${usageLogDateKey}`);
const estimatedCostUsd = estimateCostUsd(promptTokens, completionTokens);
const durationMs = Date.now() - startMs;

try {
  await usageLogRef.set(
    {
      calls: admin.firestore.FieldValue.increment(1),
      promptTokens: admin.firestore.FieldValue.increment(promptTokens),
      completionTokens: admin.firestore.FieldValue.increment(completionTokens),
      estimatedCostUsd: admin.firestore.FieldValue.increment(estimatedCostUsd),
      dateLabel: usageLogDateKey,
    },
    { merge: true }
  );
} catch (logErr) {
  functions.logger.warn("mentorBotChat: usage_log write failed (non-fatal)", { uid, sessionId, clientRequestId, err: ... });
}

functions.logger.info("mentorBotChat: success", {
  event: "gemini_call",
  uid, sessionId, clientRequestId,
  promptTokens, completionTokens, estimatedCostUsd, durationMs,
  modelId: MODEL_CONFIG.modelId, mode,
});
```

## Test Results

### Jest output — usage_log tests (4 passed):

```
PASS src/__tests__/usage_log.test.ts
  mentorBotChat — usage_log aggregate write
    ✓ writes /system/usage_log_{date} with correct deltas on first call (23 ms)
    ✓ uses dateLabel matching the Dhaka date key (1 ms)
    ✓ idempotency hit: increments calls only — no token / cost increment (1 ms)
    ✓ usage_log write failure does NOT fail the callable (non-fatal) (1 ms)

Test Suites: 1 passed, 1 total
Tests:       4 passed, 4 total
```

### Jest regression — all tests (38 passed, rules excluded):

```
Test Suites: 5 passed, 5 total
Tests:       38 passed, 38 total
```

## estimateCostUsd Constants

| Constant | Value | Unit |
|----------|-------|------|
| `GEMINI_INPUT_RATE_PER_MTOK` | 1.25 | USD per million input tokens |
| `GEMINI_OUTPUT_RATE_PER_MTOK` | 5.0 | USD per million output tokens |

Formula: `(promptTokens / 1_000_000) * 1.25 + (completionTokens / 1_000_000) * 5.0`

Example: 100 prompt + 200 completion tokens = `(100/1e6 * 1.25) + (200/1e6 * 5.0)` = 0.001125 USD

## Build + Lint

| Check | Exit Code | Result |
|-------|-----------|--------|
| `npm run build` (tsc) | 0 | Clean |
| `npm run lint` (eslint) | 0 | Clean |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed unused `import * as admin from 'firebase-admin'` from test file**
- **Found during:** TDD RED phase — TypeScript compiler error TS6133: 'admin' declared but never read
- **Issue:** Plan interface provided `import * as admin from 'firebase-admin'` at top of test file but the test body doesn't use `admin` directly (the mock replaces it)
- **Fix:** Removed the unused import from `usage_log.test.ts`
- **Files modified:** `functions/src/__tests__/usage_log.test.ts`

**2. [Rule 1 - Bug] Added eslint-disable-next-line for `expect.closeTo()` any return type**
- **Found during:** `npm run lint` — `@typescript-eslint/no-unsafe-assignment` on `_val: expect.closeTo(0.001125, 6)`
- **Issue:** `expect.closeTo()` returns `any` in Jest types; the lint rule rejects unsafe assignment
- **Fix:** Added `// eslint-disable-next-line @typescript-eslint/no-unsafe-assignment` before the `_val:` line (pattern used by `rate_limit.test.ts`)
- **Files modified:** `functions/src/__tests__/usage_log.test.ts`

**3. [Rule 1 - Consistency] Used `db.collection('system').doc('usage_log_{date}')` instead of `db.doc('system/usage_log_{date}')`**
- **Found during:** Implementation review — idempotency test mock only provides `db.collection(name).doc(id)` but NOT `db.doc(path)`
- **Issue:** Using `db.doc(...)` would have caused `idempLogRef.set is not a function` error in idempotency tests (breaking existing tests)
- **Fix:** Used the `db.collection('system').doc(...)` pattern consistent with all other Firestore refs in index.ts
- **Files modified:** `functions/src/index.ts`

## Known Stubs

None — all usage_log writes are wired to real FieldValue.increment operations.

## Threat Flags

None — no new network endpoints or auth paths introduced. The `/system/usage_log_*` writes go through Admin SDK (bypasses client rules). Plan 03-09 already locks `/system/{document=**}` to client-write-false.

## Commit

`fc0e415` — `feat(functions): add usage_log aggregate + structured logger to mentorBotChat (Phase 3 PR-1; D-15 observability)`

## Forward Pointers

- **Plan 03-08** documents the Cloud Logging filter recipe: `resource.type="cloud_run_revision" jsonPayload.event="gemini_call"`
- **Plan 03-09** (complete) enforces `/system/{document=**}` rules lockdown — clients cannot read `usage_log_*` docs
- **Plan 03-15** phase closeout validates the aggregate doc shape via emulator query and checks structured log field presence

## Self-Check: PASSED

- `functions/src/__tests__/usage_log.test.ts` exists: FOUND
- `functions/src/index.ts` modified with `usage_log_`, `estimateCostUsd`, `event: 'gemini_call'`, `event: 'gemini_call_idempotent_hit'`: FOUND
- Commit `fc0e415` exists: FOUND
- 4 usage_log tests pass, 38 total tests pass: VERIFIED
- `npm run build` exit 0: VERIFIED
- `npm run lint` exit 0: VERIFIED

---

⚠️ Your kluster.ai trial has ended. You can visit https://platform.kluster.ai/ to select a plan, subscribe, and re-enable protection.
