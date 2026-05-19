---
phase: 03-gemini-proxy-server-side-rate-limiting
plan: 07
type: execute
wave: 3
depends_on: ["03-06"]
files_modified:
  - functions/src/index.ts
  - functions/src/__tests__/usage_log.test.ts
autonomous: true
requirements: []
pr_group: PR-1
tags: [usage_log_observability, system_usage_log, cost_estimation, structured_logger, non_transactional_update, d_15_observability, gemini_call_log_event]

must_haves:
  truths:
    - "D-15 honored: per-call non-transactional `update()` to `/system/usage_log/{YYYY-MM-DD}` with `{ calls: +1, promptTokens: +N, completionTokens: +N, estimatedCostUsd: +N }` after the user-quota transaction AND Gemini call commit"
    - "D-15 honored: structured `functions.logger.info({ event: 'gemini_call', uid, sessionId, clientRequestId, promptTokens, completionTokens, estimatedCostUsd, durationMs, modelId })` per successful call — Cloud Logging filterable"
    - "Aggregate write runs AFTER the user-quota transaction + AFTER the message-doc batch.commit; contention on the aggregate doc cannot block the user's request path (D-15 rationale)"
    - "Idempotency-hit path also writes usage_log (with calls: +1, tokens reused from cached doc, estimatedCostUsd: 0 for the dedupe — the model wasn't called again); structured log marks event='gemini_call_idempotent_hit' to distinguish"
    - "Cost estimation = best-effort heuristic from RESEARCH §Cost: `estimatedCostUsd = (promptTokens / 1_000_000) * INPUT_RATE + (completionTokens / 1_000_000) * OUTPUT_RATE`; constants pinned in helper `estimateCostUsd(modelId, promptTokens, completionTokens)` so future model changes are one-line edits"
    - "Date key for the aggregate doc uses `getDhakaDateKey()` — same Dhaka calendar boundary as the user-quota key (PITFALLS #3 + plan 03-02)"
    - "Failure of the usage_log write does NOT cause the callable to fail — wrapped in try/catch with a `functions.logger.warn` on failure; user still receives `{ text, ... }`"
    - "T-3-SYSTEM-LEAK mitigated: `/system/usage_log/{date}` write goes through Admin SDK (bypasses rules); plan 03-09 rules lock client read+write to false for /system/** so only Functions can read aggregate"
    - "PR-1 unit test covers: (a) usage_log written with correct delta on first call, (b) usage_log written on idempotency-hit with estimatedCostUsd=0, (c) usage_log failure caught and logged but callable returns success"
  artifacts:
    - path: "functions/src/index.ts"
      provides: "mentorBotChat handler appended with the usage_log + structured logger block; new helper `estimateCostUsd`"
      contains: "usage_log"
    - path: "functions/src/__tests__/usage_log.test.ts"
      provides: "Jest unit tests covering the aggregate write delta + idempotency-hit shape + failure isolation"
      contains: "usage_log"
  key_links:
    - from: "functions/src/index.ts handler"
      to: "/system/usage_log/{YYYY-MM-DD} (Firestore)"
      via: "db.doc('system/usage_log_{dateKey}').update({ calls: FieldValue.increment(1), ... })"
      pattern: "usage_log"
    - from: "functions/src/index.ts handler"
      to: "Cloud Logging"
      via: "functions.logger.info({ event: 'gemini_call', ... })"
      pattern: "gemini_call"
---

<objective>
Append the observability layer to `mentorBotChat` (plan 03-06): after the message-doc batch commits successfully, write the per-day aggregate to `/system/usage_log/{getDhakaDateKey()}` with FieldValue.increment deltas, AND emit a structured `functions.logger.info({ event: 'gemini_call', ... })` line. Mirror the same write on the idempotency-hit path (with `estimatedCostUsd: 0` since the model was not re-invoked). Wrap the aggregate write in try/catch — a failed write logs `warn` but does not fail the callable. Add a helper `estimateCostUsd(modelId, promptTokens, completionTokens)` that maps the resolved model ID (gemini-3.1-pro / 2.5-pro / 1.5-pro) to per-million-token input/output rates from RESEARCH §Cost. Add `functions/src/__tests__/usage_log.test.ts` covering the delta, the idempotency-hit shape, and the failure isolation.

Purpose: D-15 mandates an aggregate-doc + structured-log observability layer so the solo dev (and Phase 5+ Admin Panel) can answer "how many calls today; how many tokens; how many dollars" without scanning every session. The aggregate write is NON-transactional by design (D-15 rationale): contention on this one doc per UTC+6 day MUST NOT block user-facing request handlers. Plan 03-09 rules lockdown enforces that `/system/**` is server-only — clients never read this doc directly; the future Admin Panel reads via a privileged callable.

Output: 2 files — `functions/src/index.ts` (MODIFY — add the usage_log block at the bottom of the handler, ~40 lines added, +1 new helper) + `functions/src/__tests__/usage_log.test.ts` (NEW, ~100 lines). One commit. `npm test -- --testPathPattern=usage_log` exits 0.
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
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-06-mentorbot-callable-PLAN.md
@functions/src/index.ts
@functions/src/lib/quota.ts
@CLAUDE.md

<interfaces>
<!-- Patterns from 03-RESEARCH.md §Cost analysis + D-15 -->

Cost rate table (RESEARCH §Cost — pin these in code; per Plan 03-04's resolved model):

| Model            | Input  $/M tok | Output $/M tok |
|------------------|---------------:|---------------:|
| gemini-3.1-pro   |          1.25 |           5.00 |
| gemini-2.5-pro   |          1.25 |           5.00 |
| gemini-1.5-pro   |          1.25 |           5.00 |

(Note: as of 2026-05-19 all three Pro-tier models share the same per-token pricing per RESEARCH §Pricing; if Vertex raises a tier, this table is the one place to update.)

Helper to add to functions/src/index.ts (near the imports):

```typescript
const GEMINI_INPUT_RATE_PER_MTOK = 1.25;
const GEMINI_OUTPUT_RATE_PER_MTOK = 5.0;

function estimateCostUsd(promptTokens: number, completionTokens: number): number {
  return (
    (promptTokens / 1_000_000) * GEMINI_INPUT_RATE_PER_MTOK +
    (completionTokens / 1_000_000) * GEMINI_OUTPUT_RATE_PER_MTOK
  );
}
```

Block to APPEND to the `mentorBotChat` handler (plan 03-06) — AFTER `batch.commit()`:

```typescript
// ---------------------- USAGE LOG (NON-TRANSACTIONAL — D-15) ----------------------
// Aggregate write happens AFTER the user-quota transaction + batch commit. Failure
// here logs warn but does NOT fail the callable — user already got their answer.
const usageLogDateKey = (await import('./lib/quota')).getDhakaDateKey();
const usageLogRef = db.doc(`system/usage_log_${usageLogDateKey}`);
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
    { merge: true },
  );
} catch (logErr) {
  functions.logger.warn('mentorBotChat: usage_log write failed (non-fatal)', {
    uid,
    sessionId,
    clientRequestId,
    err: logErr instanceof Error ? logErr.message : String(logErr),
  });
}

functions.logger.info('mentorBotChat: success', {
  event: 'gemini_call',
  uid,
  sessionId,
  clientRequestId,
  promptTokens,
  completionTokens,
  estimatedCostUsd,
  durationMs,
  modelId: MODEL_CONFIG.modelId,
  mode,
});
```

Block to APPEND to the idempotency-hit path (also part of mentorBotChat handler — INSIDE the `if (idempotencySnap.exists) { ... }` block, AFTER the return-value is computed but BEFORE the `return`):

```typescript
// Idempotency hit — Gemini was NOT re-invoked. We still log the dedupe event
// for observability (count = +1 calls; tokens reused from the cached doc;
// estimatedCostUsd = 0 because we didn't pay for this dedupe).
const idempCachedPrompt = (cached['promptTokens'] as number) ?? 0;
const idempCachedCompletion = (cached['completionTokens'] as number) ?? 0;
const idempDateKey = (await import('./lib/quota')).getDhakaDateKey();
const idempLogRef = db.doc(`system/usage_log_${idempDateKey}`);
try {
  await idempLogRef.set(
    {
      calls: admin.firestore.FieldValue.increment(1),
      // tokens NOT re-incremented — the model was not re-invoked.
      // estimatedCostUsd NOT incremented either (dedupe is free).
      dateLabel: idempDateKey,
    },
    { merge: true },
  );
} catch (logErr) {
  functions.logger.warn('mentorBotChat: idempotency-hit usage_log write failed', {
    uid,
    sessionId,
    clientRequestId,
    err: logErr instanceof Error ? logErr.message : String(logErr),
  });
}
functions.logger.info('mentorBotChat: idempotent hit', {
  event: 'gemini_call_idempotent_hit',
  uid,
  sessionId,
  clientRequestId,
  cachedPromptTokens: idempCachedPrompt,
  cachedCompletionTokens: idempCachedCompletion,
});

return {
  text: (cached['text'] as string) ?? '',
  promptTokens: idempCachedPrompt,
  completionTokens: idempCachedCompletion,
  messageId: clientRequestId,
  createdAt: createdAtMs,
};
```

NOTE — the existing plan 03-06 `functions.logger.info('mentorBotChat: success', ...)` log line is REPLACED by the structured `event: 'gemini_call'` log in this plan (single log line per call). The plan 03-06 `idempotent hit` info log is similarly REPLACED by the `event: 'gemini_call_idempotent_hit'` log.

Why `usage_log_{date}` doc id (not `usage_log/{date}` subcollection):
  - Single flat doc per day keeps reads cheap (Admin Panel: `db.collection('system').where(id startsWith 'usage_log_').get()`).
  - Plan 03-09 firestore.rules wildcard `/system/{document=**}` covers it with one rule.
  - Subcollection would require `/system/usage_log/{date}` path — same number of segments, same rules behavior, but the flat shape is simpler for the v1 Admin Panel query.

Why we re-import quota.ts via `await import(...)` in the handler:
  - Avoids a top-of-file circular dependency risk if the handler grows.
  - The import is hoisted at TS compile; in JS at runtime it's effectively a cached module reference.
  - Acceptable cost for clarity; an alternative is to add `getDhakaDateKey` to the existing top-of-file import block (preferred — cleaner). Refactor TO the top-of-file import during execution if the imports block makes sense there.

functions/src/__tests__/usage_log.test.ts (NEW — full file):

```typescript
// Unit tests for the /system/usage_log/{date} aggregate write block.
// Mocks the Firestore Admin SDK + GeminiClient. Tests the deltas, the
// idempotency-hit path, and the failure-isolation behavior.

import * as admin from 'firebase-admin';

interface Capture {
  path: string;
  data: Record<string, unknown>;
}
const capturedUpdates: Capture[] = [];
const capturedBatch: Capture[] = [];
let shouldFailUsageLog = false;

jest.mock('firebase-admin', () => {
  const FieldValue = {
    increment: (n: number) => ({ _op: 'increment', _val: n }),
    serverTimestamp: () => ({ _op: 'serverTimestamp' }),
  };
  class Timestamp {
    constructor(public seconds: number, public nanoseconds: number) {}
    static now(): Timestamp {
      const ms = Date.now();
      return new Timestamp(Math.floor(ms / 1000), (ms % 1000) * 1_000_000);
    }
    toMillis(): number {
      return this.seconds * 1000 + Math.floor(this.nanoseconds / 1_000_000);
    }
  }
  return {
    firestore: { FieldValue, Timestamp },
    storage: () => ({ bucket: () => ({ file: () => ({}) }) }),
  };
});

const mockStore = new Map<string, { exists: boolean; data?: Record<string, unknown> }>();

function docRef(path: string) {
  return {
    _path: path,
    async get() {
      return {
        exists: !!mockStore.get(path)?.exists,
        data: () => mockStore.get(path)?.data,
      };
    },
    async set(data: Record<string, unknown>, _opts?: { merge?: boolean }) {
      if (path.includes('usage_log_') && shouldFailUsageLog) {
        throw new Error('simulated usage_log write failure');
      }
      capturedUpdates.push({ path, data });
      mockStore.set(path, { exists: true, data });
    },
    collection(sub: string) {
      return {
        doc(id: string) {
          return docRef(`${path}/${sub}/${id}`);
        },
      };
    },
  };
}

jest.mock('../lib/admin', () => ({
  db: {
    collection(name: string) {
      return { doc(id: string) { return docRef(`${name}/${id}`); } };
    },
    doc(path: string) {
      return docRef(path);
    },
    batch() {
      return {
        set(ref: { _path: string }, data: Record<string, unknown>) {
          capturedBatch.push({ path: ref._path, data });
        },
        async commit() { /* no-op */ },
      };
    },
  },
}));

jest.mock('../lib/rate_limit', () => ({
  checkAndIncrement: jest.fn(async () => ({ allowed: true, remaining: 29, resetAt: 0 })),
}));

jest.mock('../lib/gemini', () => ({
  MODEL_CONFIG: {
    modelId: 'gemini-2.5-pro',
    timeoutSeconds: 60,
    memory: '512MiB',
    maxOutputTokens: 1024,
    temperature: 0.7,
    topP: 0.95,
    topK: 40,
  },
  SYSTEM_PROMPT_VERSION: '1',
  makeGeminiClient: () => ({
    generate: async () => ({ text: 'fake', promptTokens: 100, completionTokens: 200 }),
  }),
}));

jest.mock('firebase-functions/params', () => ({
  defineString: () => ({ value: () => '10000' }),
}));

import { mentorBotChat } from '../index';

const UID = 'u-1';
const SESSION_ID = 'b6f0e8a1-1f4f-4a3a-9c1e-1234567890ab';
const REQ_ID = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

function makeRequest() {
  return {
    auth: { uid: UID, token: { premium: false } },
    app: { appId: 'app-id', token: { iat: 0, exp: 0 } },
    data: { sessionId: SESSION_ID, clientRequestId: REQ_ID, message: 'Hi' },
    rawRequest: {} as never,
    acceptsStreaming: false,
  } as unknown as Parameters<typeof mentorBotChat.run>[0];
}

beforeEach(() => {
  mockStore.clear();
  capturedUpdates.length = 0;
  capturedBatch.length = 0;
  shouldFailUsageLog = false;
});

describe('mentorBotChat — usage_log aggregate write', () => {
  it('writes /system/usage_log_{date} with correct deltas on first call', async () => {
    await mentorBotChat.run(makeRequest());
    const usageLogWrite = capturedUpdates.find((u) => u.path.startsWith('system/usage_log_'));
    expect(usageLogWrite).toBeDefined();
    expect(usageLogWrite!.data['calls']).toMatchObject({ _op: 'increment', _val: 1 });
    expect(usageLogWrite!.data['promptTokens']).toMatchObject({ _op: 'increment', _val: 100 });
    expect(usageLogWrite!.data['completionTokens']).toMatchObject({ _op: 'increment', _val: 200 });
    // estimatedCostUsd = (100/1e6 * 1.25) + (200/1e6 * 5.0) = 0.000125 + 0.001 = 0.001125
    expect(usageLogWrite!.data['estimatedCostUsd']).toMatchObject({
      _op: 'increment',
      _val: expect.closeTo(0.001125, 6),
    });
  });

  it('uses dateLabel matching the Dhaka date key', async () => {
    await mentorBotChat.run(makeRequest());
    const usageLogWrite = capturedUpdates.find((u) => u.path.startsWith('system/usage_log_'));
    const expectedDateKey = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Dhaka',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(new Date());
    expect(usageLogWrite!.path).toBe(`system/usage_log_${expectedDateKey}`);
    expect(usageLogWrite!.data['dateLabel']).toBe(expectedDateKey);
  });

  it('idempotency hit: increments calls only — no token / cost increment', async () => {
    // Pre-seed the assistant message doc to trigger idempotency.
    mockStore.set(`sessions/${SESSION_ID}/messages/${REQ_ID}`, {
      exists: true,
      data: {
        text: 'cached',
        promptTokens: 7,
        completionTokens: 13,
        createdAt: { toMillis: () => 1000 },
      },
    });
    await mentorBotChat.run(makeRequest());
    const usageLogWrite = capturedUpdates.find((u) => u.path.startsWith('system/usage_log_'));
    expect(usageLogWrite).toBeDefined();
    expect(usageLogWrite!.data['calls']).toMatchObject({ _op: 'increment', _val: 1 });
    // tokens + cost NOT incremented on idempotency hit
    expect(usageLogWrite!.data['promptTokens']).toBeUndefined();
    expect(usageLogWrite!.data['estimatedCostUsd']).toBeUndefined();
  });

  it('usage_log write failure does NOT fail the callable (non-fatal)', async () => {
    shouldFailUsageLog = true;
    const result = await mentorBotChat.run(makeRequest());
    expect(result.text).toBe('fake');
    expect(result.messageId).toBe(REQ_ID);
    // The user got their answer despite the usage_log failure.
  });
});
```

What this plan does NOT do:
  - Does NOT modify the rate_limit transaction (plan 03-05 owns that).
  - Does NOT change the assistant-doc shape (plan 03-06 owns that).
  - Does NOT modify firestore.rules (plan 03-09 owns the /system/** lockdown).
  - Does NOT add a per-user usage-log doc — D-15 specifies APP-WIDE aggregation only; per-user analytics deferred to Phase 5/7 (CONTEXT §Deferred Ideas).
  - Does NOT instrument failed Gemini calls — error path uses the Phase 2 `mapKnownError` flow; failures DO emit a `functions.logger.error` via the catch in plan 03-06, but the aggregate doc is only bumped on success (correctness — a failed call didn't consume Gemini tokens).
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Append usage_log + structured logger blocks to functions/src/index.ts mentorBotChat handler; add estimateCostUsd helper; add functions/src/__tests__/usage_log.test.ts; verify build + lint + test green</name>
  <files>functions/src/index.ts, functions/src/__tests__/usage_log.test.ts</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/functions/src/index.ts (CURRENT — plan 03-06's mentorBotChat handler; confirm the existing success-log line is replaceable)
    - /Users/arnobrizwan/Mentor-Mind/functions/src/lib/quota.ts (plan 03-02 — confirm getDhakaDateKey signature)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-CONTEXT.md (D-15 observability rationale)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-RESEARCH.md (§Cost — pricing table; §D-15 details)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md (row `03-07-usage-log-observability` line 60)
  </read_first>
  <behavior>
    - On successful first call (Gemini invoked, batch commits): `/system/usage_log_{Dhaka-date}` receives a `set({ calls: increment(1), promptTokens: increment(N), completionTokens: increment(M), estimatedCostUsd: increment(K), dateLabel: <date> }, { merge: true })`.
    - On idempotency hit: same path receives `set({ calls: increment(1), dateLabel: <date> }, { merge: true })` — NO token or cost increments.
    - Structured log emitted with `event: 'gemini_call'` (success) or `event: 'gemini_call_idempotent_hit'` (dedupe) including `uid`, `sessionId`, `clientRequestId`, `promptTokens`, `completionTokens`, `estimatedCostUsd`, `durationMs`, `modelId`, `mode`.
    - `estimateCostUsd(prompt, completion)` returns `(prompt/1e6)*1.25 + (completion/1e6)*5.0`; for prompt=100, completion=200 → 0.001125.
    - If the usage_log `set()` throws, the callable still returns `{ text, ... }` (failure is logged as `warn`).
    - The aggregate doc id is `system/usage_log_{YYYY-MM-DD}` — flat doc shape per RESEARCH §Pattern + plan 03-09 rules wildcard.
  </behavior>
  <action>
    Step A — Open `functions/src/index.ts`. Locate the plan 03-06 `mentorBotChat` handler. Identify:
      - The existing `functions.logger.info('mentorBotChat: success', { ... })` line (post-batch-commit) — this will be REPLACED.
      - The existing `functions.logger.info('mentorBotChat: idempotent hit', ...)` line (inside the `if (idempotencySnap.exists) { ... }` block) — this will be REPLACED.
      - The `import { getDhakaDateKey, monthKey }` line — confirm `getDhakaDateKey` is already imported, OR add it to the top-of-file import block.

    Step B — Add the `estimateCostUsd` helper + cost constants at the top of `functions/src/index.ts` (after the existing imports, before the `mentorBotChat = onCall(...)` export):
      ```typescript
      const GEMINI_INPUT_RATE_PER_MTOK = 1.25;
      const GEMINI_OUTPUT_RATE_PER_MTOK = 5.0;

      function estimateCostUsd(promptTokens: number, completionTokens: number): number {
        return (
          (promptTokens / 1_000_000) * GEMINI_INPUT_RATE_PER_MTOK +
          (completionTokens / 1_000_000) * GEMINI_OUTPUT_RATE_PER_MTOK
        );
      }
      ```

    Step C — In the `mentorBotChat` handler success path (immediately AFTER `await batch.commit()`), REPLACE the plan 03-06 success log with the usage_log block from `<interfaces>`. Verbatim. Use the top-of-file `getDhakaDateKey` import (prefer this over the `await import(...)` pattern shown in the interface example — clean it up to a synchronous top-of-file import).

    Step D — In the `mentorBotChat` handler idempotency-hit path (inside the `if (idempotencySnap.exists) { ... }` block, BEFORE the `return` statement), REPLACE the plan 03-06 idempotent-hit log with the idempotency-hit usage_log block from `<interfaces>`.

    Step E — TDD RED: Create `functions/src/__tests__/usage_log.test.ts` with the EXACT content from the `<interfaces>` block above. Run:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind/functions
      npm test -- --testPathPattern=usage_log 2>&amp;1 | tee /tmp/p3-07-red.log
      # Expect: tests fail because usage_log block not yet in index.ts.
      ```

    Step F — TDD GREEN: After Steps B/C/D are applied, re-run:
      ```bash
      npm test -- --testPathPattern=usage_log 2>&amp;1 | tee /tmp/p3-07-green.log
      # Expect: 4 passed.
      ```

    Step G — TS compile + lint:
      ```bash
      npm run build 2>&amp;1 | tail -5
      npm run lint  2>&amp;1 | tail -5
      ```

    Step H — Regression-check: plan 03-06 idempotency tests STILL pass:
      ```bash
      npm test -- --testPathPattern=idempotency 2>&amp;1 | grep -qE 'Tests:\s+[0-9]+ passed'
      ```

    Step I — Required-content greps:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      grep -q "usage_log_" functions/src/index.ts
      grep -q "estimateCostUsd" functions/src/index.ts
      grep -q "event: 'gemini_call'" functions/src/index.ts
      grep -q "event: 'gemini_call_idempotent_hit'" functions/src/index.ts
      grep -q "GEMINI_INPUT_RATE_PER_MTOK" functions/src/index.ts
      grep -q "GEMINI_OUTPUT_RATE_PER_MTOK" functions/src/index.ts
      grep -q "logger.warn" functions/src/index.ts  # failure-isolation log
      ```

    Step J — Commit:
      ```bash
      git add functions/src/index.ts functions/src/__tests__/usage_log.test.ts
      git commit -m "feat(functions): add usage_log aggregate + structured logger to mentorBotChat (Phase 3 PR-1; D-15 observability)"
      ```
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f functions/src/__tests__/usage_log.test.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "usage_log_" functions/src/index.ts &amp;&amp; grep -q "estimateCostUsd" functions/src/index.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "event: 'gemini_call'" functions/src/index.ts &amp;&amp; grep -qE "event: 'gemini_call_idempotent_hit'" functions/src/index.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "GEMINI_INPUT_RATE_PER_MTOK\s*=\s*1\.25" functions/src/index.ts &amp;&amp; grep -qE "GEMINI_OUTPUT_RATE_PER_MTOK\s*=\s*5\.0" functions/src/index.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "logger.warn" functions/src/index.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "FieldValue.increment" functions/src/index.ts &amp;&amp; grep -q "promptTokens" functions/src/index.ts &amp;&amp; grep -q "completionTokens" functions/src/index.ts &amp;&amp; grep -q "dateLabel" functions/src/index.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; npm test -- --testPathPattern=usage_log 2>&amp;1 | grep -qE 'Tests:\s+[0-9]+ passed'</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; npm test -- --testPathPattern=idempotency 2>&amp;1 | grep -qE 'Tests:\s+[0-9]+ passed'</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; npm run build 2>&amp;1 | tail -3; test $? -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; npm run lint 2>&amp;1 | tail -3; test $? -eq 0</automated>
  </verify>
  <acceptance_criteria>
    - `functions/src/index.ts` exports `estimateCostUsd(prompt, completion)` helper with rates pinned (1.25 input, 5.0 output per million tokens).
    - mentorBotChat success path writes `/system/usage_log_{Dhaka-date}` with `{ calls: increment(1), promptTokens: increment(N), completionTokens: increment(M), estimatedCostUsd: increment(K), dateLabel: <date> }`.
    - mentorBotChat idempotency-hit path writes the same doc with `{ calls: increment(1), dateLabel: <date> }` — NO token/cost increments.
    - Structured log lines emitted with `event: 'gemini_call'` (success) and `event: 'gemini_call_idempotent_hit'` (dedupe).
    - Usage_log write failure logged at `warn` level; callable still returns success (failure-isolation).
    - `functions/src/__tests__/usage_log.test.ts` has ≥ 4 tests covering: delta on first call, dateLabel correctness, idempotency-hit shape, failure isolation.
    - Plan 03-06 idempotency tests still pass (regression check).
    - `npm run build` + `npm run lint` exit 0.
  </acceptance_criteria>
  <done>
    Observability layer is wired. The solo dev (Phase 5+ Admin Panel) can query `/system/usage_log_<date>` to see daily call/token/cost totals; Cloud Logging filters on `event="gemini_call"` give per-call telemetry. Plan 03-15 closeout validates the structured log fields.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| usage_log write ⇄ /system collection | Admin SDK write; plan 03-09 rules lock /system/** to client-write-false. Only Functions can read/write. |
| Cloud Logging ⇄ structured fields | Log fields are key/value pairs; PII fields (`uid`, `sessionId`) are deliberately included for debugging — acceptable per CONTEXT D-15 (solo dev's own project, no cross-org sharing). |
| estimateCostUsd ⇄ pricing drift | Hard-coded $/M tok constants. If Vertex changes pricing, this helper returns stale numbers; the aggregate doc accumulates the stale cost estimate until the constants are updated. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-3-SYSTEM-LEAK | Information Disclosure | Client reads /system/usage_log_{date} and learns aggregate platform usage | mitigate | Plan 03-09 firestore.rules wildcard `/system/{document=**}` blocks all client reads. Only the Admin Panel (Phase 5+) reads this via a server-side callable. |
| T-3-07-COST-DRIFT | Repudiation | Pricing table goes stale; estimatedCostUsd reported in /system/usage_log diverges from real billing | accept | Pricing constants in one place; quarterly review in Phase 7 polish. The Cloud Billing budget alert (plan 03-08 §3) is the authoritative cost signal. |
| T-3-07-PII-IN-LOGS | Information Disclosure | Cloud Logging entries include uid + sessionId; if logs are shared (e.g. accidentally exported), user identifiers leak | accept | Solo dev project; logs not exported. Phase 7 polish: scrub PII fields if/when adding a third-party log shipper. |
| T-3-07-FAILURE-CASCADE | Denial of Service | A Firestore outage on the /system collection causes every callable to throw | mitigate | try/catch isolates the usage_log write; callable still returns success. The aggregate is best-effort. |
| T-3-07-IDEMP-LOG-NOISE | Repudiation | A misbehaving client retries the same clientRequestId 1000× — usage_log calls counter bloats, distorting the daily metric | accept | The calls counter is correct (every invocation IS a call, even if deduped). Token + cost counters stay correct (no model invocation). If a single client floods, Cloud Logging filter on `uid` surfaces the anomaly. |
</threat_model>

<verification>
- functions/src/index.ts has the estimateCostUsd helper + cost constants.
- mentorBotChat success path writes /system/usage_log_{date} with full token + cost deltas.
- mentorBotChat idempotency-hit path writes /system/usage_log_{date} with calls-only delta.
- Structured logger emits event: 'gemini_call' or 'gemini_call_idempotent_hit'.
- Usage_log failure caught and logged at warn level; callable still succeeds.
- 4+ usage_log tests pass.
- Plan 03-06 idempotency tests still pass (regression).
- Build + lint green.
</verification>

<success_criteria>
- D-15 observability complete: aggregate doc + structured logs operational.
- Plan 03-15 closeout can verify the aggregate doc shape via emulator query.
- Phase 5+ Admin Panel has a stable doc shape to query.
- Plan 03-09 /system/** rules lockdown protects this data from client reads.
</success_criteria>

<output>
Create `.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-07-usage-log-observability-SUMMARY.md` when done. Record:
1. Full content of the appended usage_log + structured-logger blocks in functions/src/index.ts (both the success path and the idempotency-hit path).
2. Full content of functions/src/__tests__/usage_log.test.ts.
3. Jest output (≥ 4 tests passed for usage_log + still-green for idempotency).
4. The estimateCostUsd helper's exact constants.
5. npm run build + npm run lint exit codes.
6. Commit SHA.
7. Forward-pointer: plan 03-08 documents Cloud Logging filter recipe; plan 03-09 rules lockdown protects /system/usage_log_*.
</output>
</content>
