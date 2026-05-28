// Unit tests for the /system/usage_log_{date} aggregate write block.
// Mocks the Firestore Admin SDK + TutorAIClient. Tests the deltas, the
// idempotency-hit path, and the failure-isolation behavior.

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
      return {
        doc(id: string) { return docRef(`${name}/${id}`); },
      };
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

jest.mock('../lib/tutor_ai', () => ({
  MODEL_CONFIG: {
    modelId: 'llama-3.3-70b-versatile',
    visionModelId: 'meta-llama/llama-4-scout-17b-16e-instruct',
    timeoutSeconds: 60,
    memory: '512MiB',
    maxOutputTokens: 1024,
    temperature: 0.7,
    topP: 0.95,
  },
  SYSTEM_PROMPT_VERSION: '3',
  makeTutorAIClient: () => ({
    generate: async () => ({ text: 'fake', promptTokens: 100, completionTokens: 200 }),
  }),
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
    // estimatedCostUsd = (100/1e6 * 0) + (200/1e6 * 0) = 0 on Groq free tier.
    // The estimated-cost field is still written for forward-compat dashboards
    // (rates flip non-zero if the project upgrades to Groq paid tier).
    expect(usageLogWrite!.data['estimatedCostUsd']).toMatchObject({
      _op: 'increment',
      _val: 0,
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
