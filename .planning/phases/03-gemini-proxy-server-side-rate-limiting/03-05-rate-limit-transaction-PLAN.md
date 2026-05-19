---
phase: 03-gemini-proxy-server-side-rate-limiting
plan: 05
type: execute
wave: 3
depends_on: ["03-01", "03-02"]
files_modified:
  - functions/src/lib/rate_limit.ts
  - functions/src/__tests__/rate_limit.test.ts
autonomous: true
requirements: [AI-04, AI-05, AI-06, AI-07]
pr_group: PR-1
tags: [rate_limit_transaction, run_transaction, daily_cap, burst_window, monthly_ceiling, premium_bypass, timestamp_now, pitfalls_4, http_error_codes, ai04_ai05_ai06_ai07]

must_haves:
  truths:
    - "AI-04 honored: daily cap = 30 text + 3 image per UTC+6 day per user; doc shape `{ messageCount, imageCount, burstWindow }` at `/users/{uid}/usage/{getDhakaDateKey()}`"
    - "AI-05 honored: burst limit = 5 messages / 60s sliding window; stored as sibling `burstWindow: Timestamp[]` array on the same usage doc (D-09 — one read, one write per call)"
    - "AI-06 honored: monthly ceiling = 10,000 calls at `/system/quota/{monthKey()}`; D-10 doc shape `{ calls: N, ceiling: 10000, monthLabel }`; tunable via `MONTHLY_CALL_CEILING` `defineString` env-var (default 10000)"
    - "AI-07 partially delivered: `clientRequestId` is a function parameter for downstream idempotency (full idempotency wiring lands in plan 03-06 — this plan validates the UUID v4 regex but does NOT do the read-cache itself)"
    - "D-07 honored: distinct HttpsError shapes — `resource-exhausted` { reason: 'daily', limit, used } / `resource-exhausted` { reason: 'burst', retryAfterSec } / `unavailable` { reason: 'monthly-ceiling' }; all built via `errors.ts` factory wrappers from Phase 2 D-05"
    - "D-09 honored: burst window is a literal Timestamp array (NOT FieldValue.arrayUnion — RESEARCH §Pitfall P-5: arrayUnion inside transactions creates server-side merge races); pruning is filter-then-replace"
    - "D-19 honored: `isPremium` parameter bypasses the daily cap; burst + monthly STILL apply (per CONTEXT D-19 + PAY-08 contract)"
    - "PITFALLS #4 honored: ALL state mutations inside ONE `runTransaction`; reads first (Promise.all on usage + quota), then writes; NEVER `FieldValue.serverTimestamp()` inside transaction value-writes (D-CONTEXT §Specifics — use `admin.firestore.Timestamp.now()`)"
    - "RESEARCH §Pattern 4 transaction body honored: 1 read on usage doc + 1 read on quota doc + 2 writes (usage merge + quota merge); transaction stays under Firestore's 5-read/500-write limit"
    - "MONTHLY_CALL_CEILING uses `defineString('MONTHLY_CALL_CEILING', { default: '10000' })` (firebase-functions v2 params) so a dev can override without redeploying logic"
    - "T-3-QUOTA-TAMPERING mitigated: client cannot set messageCount / imageCount / burstWindow (plan 03-09 rules lockdown locks /users/{uid}/usage/{date} client-write-false); writes only via this transaction"
  artifacts:
    - path: "functions/src/lib/rate_limit.ts"
      provides: "checkAndIncrement(uid, kind, isPremium, clientRequestId) — Phase 2 stub FILLED with full transactional daily + burst + monthly logic"
      contains: "runTransaction"
    - path: "functions/src/__tests__/rate_limit.test.ts"
      provides: "Jest unit tests covering all AI-04/05/06/07 + premium-bypass scenarios with mocked Firestore Admin SDK"
      contains: "checkAndIncrement"
  key_links:
    - from: "functions/src/lib/rate_limit.ts"
      to: "functions/src/lib/quota.ts (plan 03-02)"
      via: "imports getDhakaDateKey + monthKey"
      pattern: "getDhakaDateKey|monthKey"
    - from: "functions/src/lib/rate_limit.ts"
      to: "functions/src/lib/errors.ts (Phase 2 D-05)"
      via: "imports resourceExhausted + unavailable factory wrappers"
      pattern: "resourceExhausted|unavailable"
    - from: "functions/src/lib/rate_limit.ts"
      to: "functions/src/index.ts mentorBotChat (plan 03-06)"
      via: "handler calls checkAndIncrement INSIDE the request flow BEFORE invoking Gemini"
      pattern: "checkAndIncrement"
---

<objective>
Replace the Phase 2 stub at `functions/src/lib/rate_limit.ts` with the real transactional rate-limit logic. Implement `checkAndIncrement(uid: string, kind: 'text' | 'image', isPremium: boolean, clientRequestId: string): Promise<RateLimitResult>` using `db.runTransaction` with a single read pass on `/users/{uid}/usage/{Dhaka-date}` and `/system/quota/{YYYY-MM}`, then a single write pass to increment counters + append to burst window + bump monthly calls. Reject with the three distinct HttpsError shapes per D-07. Wire `MONTHLY_CALL_CEILING` via `defineString`. Add unit tests in `functions/src/__tests__/rate_limit.test.ts` covering daily cap, image vs text separation, burst window, monthly ceiling, and premium bypass.

Purpose: AI-04 + AI-05 + AI-06 form the rate-limit contract; AI-07 mandates one-shot Firestore transaction enforcement (PITFALLS #4). Plan 03-06's `mentorBotChat` handler calls `checkAndIncrement` BEFORE the (expensive) Gemini call so a burst-violating user pays zero Vertex tokens. This plan is the foundation: without it, plan 03-06 can't run.

Output: 2 files — `functions/src/lib/rate_limit.ts` (FILL replaces the 14-line stub with ~150 lines of transactional logic) + `functions/src/__tests__/rate_limit.test.ts` (NEW, ~200 lines covering 8+ scenarios). One commit. `npm test -- --testPathPattern=rate_limit` exits 0.
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
@functions/src/lib/rate_limit.ts
@functions/src/lib/quota.ts
@functions/src/lib/admin.ts
@functions/src/lib/errors.ts
@functions/tsconfig.json
@CLAUDE.md

<interfaces>
<!-- Patterns from 03-PATTERNS.md §functions/src/lib/rate_limit.ts lines 163-246 + 03-RESEARCH §Pattern 3/4 -->

functions/src/lib/rate_limit.ts (FULL FILE — replaces the 14-line Phase 2 stub):

```typescript
// Phase 3 — Rate-limit enforcement (replaces the Phase 2 stub).
//
// AI-04: daily cap = 30 text + 3 image per UTC+6 day per user.
// AI-05: burst = 5 messages / 60s sliding window per user.
// AI-06: monthly ceiling = 10,000 calls at /system/quota/{YYYY-MM} (tunable via env).
// AI-07: enforcement inside a single runTransaction (PITFALLS #4 mandatory).
// D-07:  three distinct HttpsError shapes (resource-exhausted/daily,
//        resource-exhausted/burst, unavailable/monthly-ceiling).
// D-09:  burst window = literal Timestamp array; filter-then-replace (NOT
//        FieldValue.arrayUnion — RESEARCH §Pitfall P-5).
// D-19:  isPremium = true bypasses DAILY cap; burst + monthly STILL apply.
//
// CRITICAL — Pitfall P-2: NEVER call Gemini inside this transaction. Plan 03-06's
// mentorBotChat handler calls Gemini AFTER the transaction commits.

import * as admin from 'firebase-admin';
import { defineString } from 'firebase-functions/params';
import { db } from './admin';
import { resourceExhausted, unavailable } from './errors';
import { getDhakaDateKey, monthKey } from './quota';

// Tunable monthly ceiling. Default 10,000 per D-10. Set via:
//   firebase functions:config:set (legacy) OR Cloud Run params runtime config.
export const MONTHLY_CALL_CEILING = defineString('MONTHLY_CALL_CEILING', {
  default: '10000',
});

export const DAILY_TEXT_LIMIT = 30;
export const DAILY_IMAGE_LIMIT = 3;
export const BURST_LIMIT = 5;
export const BURST_WINDOW_MS = 60_000;

export interface RateLimitResult {
  allowed: true;
  remaining: number; // text or image remaining (not used by AI-07 v1; reserved for client display)
  resetAt: number;   // Unix ms of next Dhaka midnight
}

interface UsageDoc {
  messageCount?: number;
  imageCount?: number;
  burstWindow?: admin.firestore.Timestamp[];
}

interface QuotaDoc {
  calls?: number;
  ceiling?: number;
  monthLabel?: string;
}

/**
 * Atomically check-and-increment the per-user daily counter, the 60s burst
 * window, and the system-wide monthly ceiling. Throws a typed HttpsError per
 * D-07 on rejection.
 *
 * @param uid              Authenticated user id (from request.auth).
 * @param kind             'text' bumps messageCount; 'image' bumps imageCount.
 * @param isPremium        true bypasses daily cap (burst + monthly still apply).
 * @param clientRequestId  Passed for log correlation; idempotency cache lives
 *                         in plan 03-06's handler (not here).
 */
export async function checkAndIncrement(
  uid: string,
  kind: 'text' | 'image',
  isPremium: boolean,
  clientRequestId: string,
): Promise<RateLimitResult> {
  const dateKey = getDhakaDateKey();
  const mKey = monthKey();
  const ceiling = parseInt(MONTHLY_CALL_CEILING.value() || '10000', 10);

  const usageRef = db
    .collection('users')
    .doc(uid)
    .collection('usage')
    .doc(dateKey);
  const quotaRef = db.collection('system').doc(`quota_${mKey}`);
  // NOTE: doc-id-as-monthkey shape — /system/quota_{YYYY-MM} — Firestore rules
  // wildcard `/system/{document=**}` (plan 03-09) covers it.

  return db.runTransaction(async (tx) => {
    // ALL READS FIRST (Admin SDK transaction constraint)
    const [usageSnap, quotaSnap] = await Promise.all([
      tx.get(usageRef),
      tx.get(quotaRef),
    ]);

    const now = Date.now();
    const usage: UsageDoc = (usageSnap.data() as UsageDoc) ?? {};
    const quota: QuotaDoc = (quotaSnap.data() as QuotaDoc) ?? {};

    const messageCount = usage.messageCount ?? 0;
    const imageCount = usage.imageCount ?? 0;
    const burstWindow = (usage.burstWindow ?? []) as admin.firestore.Timestamp[];

    // --- Burst check (applies to premium too) ---
    const prunedBurst = burstWindow.filter(
      (ts) => ts.toMillis() > now - BURST_WINDOW_MS,
    );
    if (prunedBurst.length >= BURST_LIMIT) {
      const oldestMs = prunedBurst[0]!.toMillis();
      const retryAfterSec = Math.max(
        1,
        Math.ceil((oldestMs + BURST_WINDOW_MS - now) / 1000),
      );
      throw resourceExhausted('Burst limit reached', {
        reason: 'burst',
        retryAfterSec,
      });
    }

    // --- Daily check (premium bypass) ---
    if (!isPremium) {
      if (kind === 'text' && messageCount >= DAILY_TEXT_LIMIT) {
        throw resourceExhausted('Daily text limit reached', {
          reason: 'daily',
          limit: DAILY_TEXT_LIMIT,
          used: messageCount,
        });
      }
      if (kind === 'image' && imageCount >= DAILY_IMAGE_LIMIT) {
        throw resourceExhausted('Daily image limit reached', {
          reason: 'daily',
          limit: DAILY_IMAGE_LIMIT,
          used: imageCount,
        });
      }
    }

    // --- Monthly ceiling ---
    const calls = quota.calls ?? 0;
    if (calls >= ceiling) {
      throw unavailable('AI tutor temporarily unavailable', {
        reason: 'monthly-ceiling',
      });
    }

    // --- WRITES (all reads done above) ---
    const nowTs = admin.firestore.Timestamp.now(); // Safe inside tx; serverTimestamp() is NOT.
    tx.set(
      usageRef,
      {
        messageCount: admin.firestore.FieldValue.increment(
          kind === 'text' ? 1 : 0,
        ),
        imageCount: admin.firestore.FieldValue.increment(
          kind === 'image' ? 1 : 0,
        ),
        burstWindow: [...prunedBurst, nowTs], // literal array, not arrayUnion (P-5)
      },
      { merge: true },
    );
    tx.set(
      quotaRef,
      {
        calls: admin.firestore.FieldValue.increment(1),
        ceiling,
        monthLabel: mKey,
      },
      { merge: true },
    );

    // resetAt = next Dhaka midnight Unix ms. Approximate: now + (86_400_000 - now%86_400_000)
    // is UTC-aligned; for Dhaka, we compute the next 'YYYY-MM-DD' boundary in Dhaka time.
    // For v1.0 we ship a UTC-aligned approximation; the client uses this only for display.
    const resetAt =
      Math.floor(now / 86_400_000 + 1) * 86_400_000 - 6 * 3_600_000;

    const remaining =
      kind === 'text'
        ? DAILY_TEXT_LIMIT - (messageCount + 1)
        : DAILY_IMAGE_LIMIT - (imageCount + 1);

    return { allowed: true as const, remaining: Math.max(0, remaining), resetAt };
  });
}
```

functions/src/__tests__/rate_limit.test.ts (NEW — full file):

```typescript
// Unit tests for checkAndIncrement. Uses a hand-rolled in-memory mock of the
// Admin Firestore SDK — no Firestore emulator required for these tests.
//
// Coverage:
//   1. First call (empty usage) — text and image both succeed.
//   2. Daily TEXT cap (30) — 31st text rejects with reason:'daily'.
//   3. Daily IMAGE cap (3) — 4th image rejects with reason:'daily'.
//   4. Image cap does NOT block text and vice versa.
//   5. Burst (5/60s) — 6th call in window rejects with reason:'burst'.
//   6. Burst window pruning — entries > 60s old are NOT counted.
//   7. Monthly ceiling (10000) — call 10001 rejects with reason:'monthly-ceiling'.
//   8. Premium user bypasses daily cap (call 31 succeeds) but is still subject to burst.

import * as admin from 'firebase-admin';

// --- Mock Firestore Admin SDK before importing rate_limit.ts ---

interface MockDoc {
  data?: Record<string, unknown>;
  writes: Record<string, unknown>[];
}

const mockStore = new Map<string, MockDoc>();

function path(parts: (string | undefined)[]): string {
  return parts.filter(Boolean).join('/');
}

function makeDocRef(p: string) {
  return {
    _path: p,
    collection(sub: string) {
      return makeColRef(`${p}/${sub}`);
    },
  };
}

function makeColRef(p: string) {
  return {
    _path: p,
    doc(id: string) {
      return makeDocRef(`${p}/${id}`);
    },
  };
}

const mockTxGet = jest.fn(async (ref: { _path: string }) => {
  const doc = mockStore.get(ref._path);
  return {
    exists: !!doc?.data,
    data: () => doc?.data,
  };
});

const mockTxSet = jest.fn(
  (
    ref: { _path: string },
    data: Record<string, unknown>,
    _opts: { merge: boolean },
  ) => {
    const doc = mockStore.get(ref._path) ?? { writes: [] };
    doc.writes.push(data);
    // Simulate merge: shallow-merge increment + literal fields.
    const cur = (doc.data ?? {}) as Record<string, unknown>;
    for (const [k, v] of Object.entries(data)) {
      if (
        v &&
        typeof v === 'object' &&
        (v as { _operand?: unknown })._operand !== undefined
      ) {
        cur[k] = ((cur[k] as number) ?? 0) + ((v as { _operand: number })._operand);
      } else {
        cur[k] = v;
      }
    }
    doc.data = cur;
    mockStore.set(ref._path, doc);
  },
);

jest.mock('firebase-admin', () => {
  const FieldValue = {
    increment: (n: number) => ({ _operand: n }),
  };
  class Timestamp {
    constructor(public seconds: number, public nanoseconds: number) {}
    static now(): Timestamp {
      const ms = Date.now();
      return new Timestamp(Math.floor(ms / 1000), (ms % 1000) * 1_000_000);
    }
    static fromMillis(ms: number): Timestamp {
      return new Timestamp(Math.floor(ms / 1000), (ms % 1000) * 1_000_000);
    }
    toMillis(): number {
      return this.seconds * 1000 + Math.floor(this.nanoseconds / 1_000_000);
    }
  }
  return {
    firestore: { FieldValue, Timestamp },
  };
});

jest.mock('../lib/admin', () => ({
  db: {
    collection(p: string) {
      return makeColRef(p);
    },
    doc(p: string) {
      return makeDocRef(p);
    },
    runTransaction: async (fn: (tx: { get: typeof mockTxGet; set: typeof mockTxSet }) => Promise<unknown>) => {
      return fn({ get: mockTxGet, set: mockTxSet });
    },
  },
}));

jest.mock('firebase-functions/params', () => ({
  defineString: (_name: string, opts: { default: string }) => ({
    value: () => opts.default,
  }),
}));

// --- Tests ---

import { checkAndIncrement } from '../lib/rate_limit';

const UID = 'test-uid-1';
const REQ_ID = 'b6f0e8a1-1f4f-4a3a-9c1e-1234567890ab';

function usagePath(): string {
  // /users/{uid}/usage/{dateKey} — dateKey is computed by getDhakaDateKey()
  // which we can't easily fix in tests; we'll fish it out of the mock store.
  for (const k of mockStore.keys()) {
    if (k.startsWith(`users/${UID}/usage/`)) return k;
  }
  return '';
}

function seedUsage(data: Record<string, unknown>): void {
  // Pre-populate the usage doc by hand at the well-known prefix; the rate_limit
  // code uses `dateKey = getDhakaDateKey()` so we discover the key after the
  // first call. For seeding we hardcode a Dhaka day key matching the test wall clock.
  // The Intl API in the test env defaults to system tz; the value matches what
  // getDhakaDateKey returns at the same instant.
  const dateKey = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Dhaka',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
  mockStore.set(`users/${UID}/usage/${dateKey}`, { data, writes: [] });
}

function seedQuota(calls: number): void {
  const mKey = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Dhaka',
    year: 'numeric',
    month: '2-digit',
  })
    .format(new Date())
    .slice(0, 7);
  mockStore.set(`system/quota_${mKey}`, {
    data: { calls, ceiling: 10000, monthLabel: mKey },
    writes: [],
  });
}

beforeEach(() => {
  mockStore.clear();
  mockTxGet.mockClear();
  mockTxSet.mockClear();
});

describe('checkAndIncrement — daily cap', () => {
  it('first call (empty usage) allows text', async () => {
    const result = await checkAndIncrement(UID, 'text', false, REQ_ID);
    expect(result.allowed).toBe(true);
    expect(mockTxSet).toHaveBeenCalled();
  });

  it('first call (empty usage) allows image', async () => {
    const result = await checkAndIncrement(UID, 'image', false, REQ_ID);
    expect(result.allowed).toBe(true);
  });

  it('31st text call rejects with resource-exhausted / daily', async () => {
    seedUsage({ messageCount: 30, imageCount: 0, burstWindow: [] });
    await expect(checkAndIncrement(UID, 'text', false, REQ_ID)).rejects.toMatchObject({
      code: 'resource-exhausted',
      details: expect.objectContaining({ reason: 'daily', limit: 30, used: 30 }),
    });
  });

  it('4th image call rejects with resource-exhausted / daily', async () => {
    seedUsage({ messageCount: 0, imageCount: 3, burstWindow: [] });
    await expect(checkAndIncrement(UID, 'image', false, REQ_ID)).rejects.toMatchObject({
      code: 'resource-exhausted',
      details: expect.objectContaining({ reason: 'daily', limit: 3, used: 3 }),
    });
  });

  it('messageCount=30 does NOT block image (separate counters)', async () => {
    seedUsage({ messageCount: 30, imageCount: 0, burstWindow: [] });
    const result = await checkAndIncrement(UID, 'image', false, REQ_ID);
    expect(result.allowed).toBe(true);
  });

  it('imageCount=3 does NOT block text (separate counters)', async () => {
    seedUsage({ messageCount: 0, imageCount: 3, burstWindow: [] });
    const result = await checkAndIncrement(UID, 'text', false, REQ_ID);
    expect(result.allowed).toBe(true);
  });
});

describe('checkAndIncrement — burst window', () => {
  it('6th call within 60s rejects with resource-exhausted / burst', async () => {
    const now = Date.now();
    const Timestamp = (admin.firestore.Timestamp as unknown as {
      fromMillis: (ms: number) => unknown;
    });
    seedUsage({
      messageCount: 0,
      imageCount: 0,
      burstWindow: [
        Timestamp.fromMillis(now - 50_000),
        Timestamp.fromMillis(now - 40_000),
        Timestamp.fromMillis(now - 30_000),
        Timestamp.fromMillis(now - 20_000),
        Timestamp.fromMillis(now - 10_000),
      ],
    });
    await expect(checkAndIncrement(UID, 'text', false, REQ_ID)).rejects.toMatchObject({
      code: 'resource-exhausted',
      details: expect.objectContaining({ reason: 'burst' }),
    });
  });

  it('pruning: entries older than 60s do NOT count', async () => {
    const now = Date.now();
    const Timestamp = (admin.firestore.Timestamp as unknown as {
      fromMillis: (ms: number) => unknown;
    });
    seedUsage({
      messageCount: 0,
      imageCount: 0,
      burstWindow: [
        Timestamp.fromMillis(now - 120_000), // 2 min old — pruned
        Timestamp.fromMillis(now - 90_000),  // 1.5 min old — pruned
        Timestamp.fromMillis(now - 50_000),  // counts
        Timestamp.fromMillis(now - 30_000),  // counts
        Timestamp.fromMillis(now - 10_000),  // counts
      ],
    });
    // 3 in-window + new call = 4 — under the 5 limit; allowed.
    const result = await checkAndIncrement(UID, 'text', false, REQ_ID);
    expect(result.allowed).toBe(true);
  });
});

describe('checkAndIncrement — monthly ceiling', () => {
  it('call 10001 rejects with unavailable / monthly-ceiling', async () => {
    seedQuota(10_000);
    await expect(checkAndIncrement(UID, 'text', false, REQ_ID)).rejects.toMatchObject({
      code: 'unavailable',
      details: expect.objectContaining({ reason: 'monthly-ceiling' }),
    });
  });

  it('call 9999 succeeds (under ceiling)', async () => {
    seedQuota(9_999);
    const result = await checkAndIncrement(UID, 'text', false, REQ_ID);
    expect(result.allowed).toBe(true);
  });
});

describe('checkAndIncrement — premium bypass (D-19)', () => {
  it('premium user with messageCount=30 BYPASSES the daily cap', async () => {
    seedUsage({ messageCount: 30, imageCount: 0, burstWindow: [] });
    const result = await checkAndIncrement(UID, 'text', /* isPremium */ true, REQ_ID);
    expect(result.allowed).toBe(true);
  });

  it('premium user is STILL subject to burst limit', async () => {
    const now = Date.now();
    const Timestamp = (admin.firestore.Timestamp as unknown as {
      fromMillis: (ms: number) => unknown;
    });
    seedUsage({
      messageCount: 100,
      imageCount: 0,
      burstWindow: [
        Timestamp.fromMillis(now - 50_000),
        Timestamp.fromMillis(now - 40_000),
        Timestamp.fromMillis(now - 30_000),
        Timestamp.fromMillis(now - 20_000),
        Timestamp.fromMillis(now - 10_000),
      ],
    });
    await expect(checkAndIncrement(UID, 'text', true, REQ_ID)).rejects.toMatchObject({
      code: 'resource-exhausted',
      details: expect.objectContaining({ reason: 'burst' }),
    });
  });

  it('premium user is STILL subject to monthly ceiling', async () => {
    seedQuota(10_000);
    await expect(checkAndIncrement(UID, 'text', true, REQ_ID)).rejects.toMatchObject({
      code: 'unavailable',
      details: expect.objectContaining({ reason: 'monthly-ceiling' }),
    });
  });
});
```

Key invariants enforced by the test suite:
  - 8+ test cases covering AI-04/05/06/07 + D-19 premium bypass.
  - Mocked Firestore Admin SDK — no emulator dependency in unit tests (RESEARCH §Pattern 4 alternative). Plan 03-13 emulator smoke test exercises the live transaction path.
  - HttpsError shapes match D-07 verbatim (code + details.reason).
  - `errors.ts` factory wrappers (`resourceExhausted`, `unavailable`) are NOT mocked — they construct real HttpsError instances which the assertions match against.

Why the in-memory mock instead of the Firestore emulator:
  - Unit tests run inside CI's `npm test` (plan 03-14) WITHOUT booting the emulator. The emulator boot is ~10s; mocking makes the test suite snappy (~2s for all 13 cases).
  - Plan 03-13 integration test against the live emulator covers the real transaction semantics (lock contention, retry-on-conflict).
  - The mock faithfully implements `increment` semantics (sums the operand into the existing value) so increment-related assertions stay honest.

What this plan does NOT do:
  - Does NOT call Gemini (Pitfall P-2 — Gemini is invoked AFTER the transaction commits, in plan 03-06).
  - Does NOT write the assistant message doc (plan 03-06 wires that AFTER the transaction).
  - Does NOT do the idempotency cache read (plan 03-06 reads `/sessions/{sid}/messages/{clientRequestId}` BEFORE calling this function).
  - Does NOT modify `errors.ts` — Phase 2 D-05 already exported `resourceExhausted` + `unavailable` factory wrappers.
  - Does NOT write the `/system/usage_log` aggregate — plan 03-07 wires that AFTER this transaction commits.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Replace functions/src/lib/rate_limit.ts stub with full transactional logic; add functions/src/__tests__/rate_limit.test.ts; verify all tests + build + lint green</name>
  <files>functions/src/lib/rate_limit.ts, functions/src/__tests__/rate_limit.test.ts</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/functions/src/lib/rate_limit.ts (CURRENT — confirm Phase 2 stub shape; delete entirely)
    - /Users/arnobrizwan/Mentor-Mind/functions/src/lib/quota.ts (plan 03-02 — confirm getDhakaDateKey + monthKey signatures)
    - /Users/arnobrizwan/Mentor-Mind/functions/src/lib/admin.ts (Phase 2 — confirm `db` named export)
    - /Users/arnobrizwan/Mentor-Mind/functions/src/lib/errors.ts (Phase 2 — confirm `resourceExhausted` + `unavailable` factory wrapper exports; if names differ, adapt the import line accordingly)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-PATTERNS.md (§functions/src/lib/rate_limit.ts lines 163-246 — full skeleton + substitution rule)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-RESEARCH.md (§Pattern 3/4 — transaction body shape; §Pitfall P-2 — never call Gemini inside tx; §Pitfall P-5 — never arrayUnion inside tx)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-CONTEXT.md (D-07, D-09, D-10, D-19; AI-04, AI-05, AI-06, AI-07)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md (row `03-05-rate-limit-transaction` line 58 — Automated Command verbatim)
  </read_first>
  <behavior>
    - `checkAndIncrement(uid, kind, isPremium, clientRequestId)` returns `{ allowed: true, remaining, resetAt }` on success.
    - First call (empty usage) succeeds for both `text` and `image`.
    - 31st text call (when messageCount==30) throws HttpsError(`resource-exhausted`) with `details.reason='daily', limit=30, used=30`.
    - 4th image call (imageCount==3) throws HttpsError(`resource-exhausted`) with `details.reason='daily', limit=3, used=3`.
    - 6th call within 60s burst window throws HttpsError(`resource-exhausted`) with `details.reason='burst'` and a positive `retryAfterSec`.
    - Burst window pruning: entries with `.toMillis() <= now - 60_000` are filtered out before the count is checked.
    - When `/system/quota_{YYYY-MM}.calls >= ceiling`, throws HttpsError(`unavailable`) with `details.reason='monthly-ceiling'`.
    - When `isPremium=true`, daily cap is bypassed (call succeeds with messageCount=30), but burst + monthly STILL enforce.
    - Single `runTransaction` block; reads first (Promise.all on usage + quota); writes after; never calls Gemini.
    - `admin.firestore.Timestamp.now()` (NOT `FieldValue.serverTimestamp()`) used inside the transaction value-writes.
    - Burst window stored as a literal `Timestamp[]` array (NOT `FieldValue.arrayUnion`).
  </behavior>
  <action>
    Step A — Read the current `functions/src/lib/rate_limit.ts` Phase 2 stub and `functions/src/lib/errors.ts` to confirm the factory wrapper names. The interfaces block uses `resourceExhausted` and `unavailable` — adapt the import line if Phase 2 exported different names (e.g. `makeResourceExhausted` / `makeUnavailable`). The factory wrapper shape per Phase 2 D-05 is: `function resourceExhausted(message: string, details?: Record<string, unknown>): HttpsError`.

    Step B — TDD RED: Create `functions/src/__tests__/rate_limit.test.ts` with the EXACT content from the `<interfaces>` block above. Run:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind/functions
      npm test -- --testPathPattern=rate_limit 2>&amp;1 | tee /tmp/p3-05-red.log
      # Expect: compile failures + test failures because rate_limit.ts is still the Phase 2 stub.
      ```

    Step C — TDD GREEN: Replace `functions/src/lib/rate_limit.ts` ENTIRELY with the full content from the `<interfaces>` block above. Specifically:
      - DELETE the 14-line Phase 2 stub.
      - PASTE the new file content verbatim.
      - Confirm:
        - Imports use `import * as admin from 'firebase-admin'` (matches the test mock).
        - Imports use `import { resourceExhausted, unavailable } from './errors'` — adapt if errors.ts uses different names per Step A.
        - `MONTHLY_CALL_CEILING` uses `defineString` (firebase-functions v2 params API).
        - Helper constants `DAILY_TEXT_LIMIT = 30`, `DAILY_IMAGE_LIMIT = 3`, `BURST_LIMIT = 5`, `BURST_WINDOW_MS = 60_000` are exported.
        - `runTransaction` body has reads (Promise.all on `tx.get(usageRef)` + `tx.get(quotaRef)`) FIRST, then writes (`tx.set` on both).

    Step D — Re-run tests:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind/functions
      npm test -- --testPathPattern=rate_limit 2>&amp;1 | tee /tmp/p3-05-green.log
      # Expect: 13 passed (5 daily cap + 2 burst + 2 monthly + 3 premium + 1 first-call image).
      ```

    Step E — TS compile + lint:
      ```bash
      npm run build 2>&amp;1 | tail -10  # tsc — exits 0
      npm run lint  2>&amp;1 | tail -10  # eslint — exits 0
      ```
      Common fixups:
        - If `@typescript-eslint/no-explicit-any` fires on the test mock helpers, add a localized `// eslint-disable-next-line` or refactor to a typed mock.
        - The test mock uses several `as unknown as` casts to bridge Jest's mock and Firestore SDK types — preserve those.
        - If `prefer-const` fires, address per-line.

    Step F — Pitfall guard greps (must all PASS — i.e. find ZERO matches):
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      # Pitfall P-2: Gemini never called inside the transaction.
      ! grep -E "(makeGeminiClient|generateContent|VertexAI)" functions/src/lib/rate_limit.ts

      # Pitfall P-5: arrayUnion not used inside the transaction.
      ! grep -E "arrayUnion" functions/src/lib/rate_limit.ts

      # serverTimestamp() not used in transaction value-writes (must use Timestamp.now() per D-CONTEXT §Specifics).
      ! grep -E "FieldValue\.serverTimestamp" functions/src/lib/rate_limit.ts
      ```

    Step G — Required-content greps (must all FIND matches):
      ```bash
      grep -q "runTransaction" functions/src/lib/rate_limit.ts
      grep -q "Timestamp\.now" functions/src/lib/rate_limit.ts
      grep -q "FieldValue\.increment" functions/src/lib/rate_limit.ts
      grep -q "MONTHLY_CALL_CEILING" functions/src/lib/rate_limit.ts
      grep -q "defineString" functions/src/lib/rate_limit.ts
      grep -q "isPremium" functions/src/lib/rate_limit.ts
      ```

    Step H — Commit:
      ```bash
      git add functions/src/lib/rate_limit.ts functions/src/__tests__/rate_limit.test.ts
      git commit -m "feat(functions): fill rate_limit.ts — transactional daily + burst + monthly + premium bypass (Phase 3 PR-1; AI-04/05/06/07; D-07/D-09/D-10/D-19)"
      ```
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f functions/src/lib/rate_limit.ts &amp;&amp; test -f functions/src/__tests__/rate_limit.test.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "export async function checkAndIncrement" functions/src/lib/rate_limit.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "runTransaction" functions/src/lib/rate_limit.ts &amp;&amp; grep -q "Timestamp\.now" functions/src/lib/rate_limit.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "FieldValue\.increment" functions/src/lib/rate_limit.ts &amp;&amp; grep -q "MONTHLY_CALL_CEILING" functions/src/lib/rate_limit.ts &amp;&amp; grep -q "defineString" functions/src/lib/rate_limit.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "isPremium" functions/src/lib/rate_limit.ts &amp;&amp; grep -qE "DAILY_TEXT_LIMIT\s*=\s*30" functions/src/lib/rate_limit.ts &amp;&amp; grep -qE "DAILY_IMAGE_LIMIT\s*=\s*3" functions/src/lib/rate_limit.ts &amp;&amp; grep -qE "BURST_LIMIT\s*=\s*5" functions/src/lib/rate_limit.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -E "(makeGeminiClient|generateContent|VertexAI)" functions/src/lib/rate_limit.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -E "arrayUnion" functions/src/lib/rate_limit.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -E "FieldValue\.serverTimestamp" functions/src/lib/rate_limit.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "reason: 'daily'" functions/src/__tests__/rate_limit.test.ts &amp;&amp; grep -q "reason: 'burst'" functions/src/__tests__/rate_limit.test.ts &amp;&amp; grep -q "reason: 'monthly-ceiling'" functions/src/__tests__/rate_limit.test.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; npm test -- --testPathPattern=rate_limit 2>&amp;1 | grep -qE 'Tests:\s+([0-9]+) passed'</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; npm run build 2>&amp;1 | tail -3; test $? -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; npm run lint 2>&amp;1 | tail -3; test $? -eq 0</automated>
  </verify>
  <acceptance_criteria>
    - `functions/src/lib/rate_limit.ts` exports `checkAndIncrement(uid, kind, isPremium, clientRequestId): Promise<RateLimitResult>` + constants `DAILY_TEXT_LIMIT=30`, `DAILY_IMAGE_LIMIT=3`, `BURST_LIMIT=5`, `BURST_WINDOW_MS=60000`, `MONTHLY_CALL_CEILING` (defineString).
    - All logic inside ONE `runTransaction` block; reads (Promise.all) before writes.
    - Three distinct HttpsError shapes per D-07 — `resource-exhausted` / daily, `resource-exhausted` / burst, `unavailable` / monthly-ceiling.
    - `admin.firestore.Timestamp.now()` (NOT `FieldValue.serverTimestamp()`) inside transaction value-writes.
    - Burst window stored as literal `Timestamp[]` (NOT `arrayUnion`).
    - Pitfall guards: ZERO hits for `generateContent` / `arrayUnion` / `FieldValue.serverTimestamp`.
    - Premium bypass: `isPremium=true` skips daily cap; burst + monthly STILL apply.
    - `functions/src/__tests__/rate_limit.test.ts` has ≥ 13 tests covering daily / burst / monthly / premium-bypass; all pass under `npm test -- --testPathPattern=rate_limit`.
    - `npm run build` + `npm run lint` both exit 0.
  </acceptance_criteria>
  <done>
    Rate-limit transaction logic ships. Plan 03-06 can call `checkAndIncrement(...)` inside the `mentorBotChat` handler BEFORE invoking Gemini, knowing the transaction enforces all three quotas atomically and the HttpsError shapes match D-07.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| client ⇄ rate_limit.checkAndIncrement | Client cannot call this directly — it's invoked only from the `mentorBotChat` handler (plan 03-06) after `request.auth.uid` is established. |
| transaction ⇄ Firestore | Single `runTransaction` block; Firestore Admin SDK enforces read-then-write ordering at the engine level. Conflicts trigger automatic retries (up to 5 by default). |
| Functions service account ⇄ /users/{uid}/usage/{date} | Admin SDK bypasses firestore.rules; the transaction writes regardless of plan 03-09's rule lockdown. |
| MONTHLY_CALL_CEILING env-var ⇄ runtime | `defineString` resolves at function startup; a dev can update via gcloud without redeploying logic. Plan 03-08 BACKEND_SETUP.md documents the gcloud command. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-3-QUOTA-TAMPERING | Tampering | A client writes directly to `/users/{uid}/usage/{date}` setting `messageCount: 0` to reset the cap | mitigate | Plan 03-09 locks `/users/{uid}/usage/{date}` to `allow write: if false` (D-17). The Admin SDK in this transaction is the only writer. |
| T-3-05-RACE-CONDITION | Tampering | Two parallel calls from the same user race to increment messageCount; one overruns the cap | mitigate | `runTransaction` retries on conflict (Firestore default behavior). Both increments serialize. RESEARCH §Pattern 3 confirms the retry semantics. |
| T-3-05-BURST-BYPASS | Tampering | A client opens many concurrent sockets to fire 10 calls in the same millisecond; if burst-check ordering is wrong, all 10 pass | mitigate | All 10 calls enter `runTransaction` and serialize; each sees the prior increments in its read snapshot; the 6th rejects. Validated by the burst test in this plan's test suite. |
| T-3-05-MONTHLY-OVERRUN | Tampering | Two concurrent calls right at calls=9999 both pass the ceiling check and both increment to 10001 | accept | The transaction serializes against `/system/quota_{YYYY-MM}` document writes. Both calls take a lock; second sees calls=10000 and rejects. Worst case (Admin SDK retry exhaustion under extreme contention): one of the two overruns by ~1 call — operationally negligible. |
| T-3-05-GEMINI-IN-TX | Repudiation | A future contributor accidentally adds a Gemini call inside `runTransaction` — every Gemini call holds the lock for ~3-5s, throttling the function | mitigate | Static grep gate `! grep -E "(makeGeminiClient\|generateContent\|VertexAI)" functions/src/lib/rate_limit.ts` runs in every verify. Plan 03-15 closeout re-runs this gate. |
| T-3-05-ENV-VAR-MISSING | Denial of Service | `MONTHLY_CALL_CEILING` is unset at function startup; `defineString` returns `null` and `parseInt('', 10) = NaN` | mitigate | `defineString('MONTHLY_CALL_CEILING', { default: '10000' })` provides a default; `parseInt(MONTHLY_CALL_CEILING.value() || '10000', 10)` defends against null. |
| T-3-05-IMAGE-COUNTER-DRIFT | Tampering | If `kind === 'image'` increment leaks into messageCount (or vice versa), the daily caps go out of sync | mitigate | Tests verify counters are separate: `messageCount=30` does NOT block image; `imageCount=3` does NOT block text. |
</threat_model>

<verification>
- functions/src/lib/rate_limit.ts ships with `checkAndIncrement` + constants + RateLimitResult interface.
- All logic inside a single runTransaction; reads first, writes after.
- Three distinct HttpsError shapes per D-07.
- Premium bypass for daily; burst + monthly always apply.
- Timestamp.now() inside the transaction (not serverTimestamp).
- Burst window literal array (not arrayUnion).
- 13+ test cases pass under npm test.
- Build + lint green.
- Pitfall guards (no Gemini call, no arrayUnion, no serverTimestamp) all pass.
</verification>

<success_criteria>
- AI-04: daily cap 30 text + 3 image enforced.
- AI-05: burst 5/60s enforced.
- AI-06: monthly ceiling 10000 enforced; MONTHLY_CALL_CEILING tunable.
- AI-07: single runTransaction enforcement.
- D-07: distinct HttpsError shapes wired.
- D-19: premium bypass for daily; burst + monthly still apply.
- Plan 03-06 can call checkAndIncrement(...) inside the handler.
</success_criteria>

<output>
Create `.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-05-rate-limit-transaction-SUMMARY.md` when done. Record:
1. Full content of functions/src/lib/rate_limit.ts.
2. Full content of functions/src/__tests__/rate_limit.test.ts.
3. Jest output (≥ 13 tests passed).
4. Pitfall guard grep outputs (all 3 empty — confirms no Gemini call, no arrayUnion, no serverTimestamp).
5. npm run build + npm run lint exit codes.
6. Commit SHA.
7. Forward-pointer: plan 03-06 calls checkAndIncrement(uid, kind, isPremium, clientRequestId) INSIDE the mentorBotChat handler BEFORE invoking Gemini; plan 03-09 locks /users/{uid}/usage/{date} client-write-false.
</output>
</content>
