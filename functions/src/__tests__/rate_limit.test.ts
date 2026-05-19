/* eslint-disable @typescript-eslint/no-unsafe-assignment */
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
    const cur: Record<string, unknown> = doc.data ?? {};
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
