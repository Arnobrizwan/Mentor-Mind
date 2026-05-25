// Unit test for the idempotency dedupe path of mentorBotChat.
//
// Strategy: extract the handler logic into a testable function OR mock the
// Firestore SDK and invoke the handler directly via the exported callable.
//
// Approach used here: invoke `mentorBotChat.run({ data, auth, app })` — the
// firebase-functions v2 onCall returns a runnable with `.run()`. We mock the
// Firestore SDK + GeminiClient at the module boundary.

// ---- Mock infra (mirror of plan 03-05 test mock; shared lib in PR future) ----

interface MockDoc {
  data?: Record<string, unknown>;
  exists: boolean;
}
const mockStore = new Map<string, MockDoc>();

const mockGet = jest.fn(async (path: string) => {
  const doc = mockStore.get(path) ?? { exists: false };
  return {
    exists: doc.exists,
    data: () => doc.data,
  };
});

const mockSet = jest.fn((path: string, data: Record<string, unknown>) => {
  mockStore.set(path, { exists: true, data });
});

const mockBatchOps: Array<{ path: string; data: Record<string, unknown> }> = [];

jest.mock('firebase-admin', () => {
  const FieldValue = {
    increment: (n: number) => ({ _operand: n }),
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
  return { firestore: { FieldValue, Timestamp } };
});

function docRef(path: string): {
  _path: string;
  get: () => Promise<{ exists: boolean; data: () => Record<string, unknown> | undefined }>;
  collection: (sub: string) => { doc: (id: string) => ReturnType<typeof docRef> };
} {
  return {
    _path: path,
    async get() {
      return mockGet(path);
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
        doc(id: string) {
          return docRef(`${name}/${id}`);
        },
      };
    },
    batch() {
      return {
        set(ref: { _path: string }, data: Record<string, unknown>) {
          mockBatchOps.push({ path: ref._path, data });
          mockSet(ref._path, data);
        },
        async commit() {
          /* no-op — writes already captured */
        },
      };
    },
  },
}));

jest.mock('../lib/rate_limit', () => ({
  checkAndIncrement: jest.fn(async () => ({
    allowed: true,
    remaining: 29,
    resetAt: Date.now() + 86_400_000,
  })),
}));

// Capture Gemini call count + return canned response.
const geminiCallCount = { value: 0 };
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
  makeGeminiClient: jest.fn(() => ({
    generate: async () => {
      geminiCallCount.value++;
      return { text: 'cached fake', promptTokens: 7, completionTokens: 13 };
    },
  })),
}));

// ---- Subject under test ----
import { mentorBotChat } from '../index';

const UID = 'u-1';
const SESSION_ID = 'b6f0e8a1-1f4f-4a3a-9c1e-1234567890ab';
const REQ_ID = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

function makeRequest(overrides?: Partial<Record<string, unknown>>) {
  return {
    auth: { uid: UID, token: { premium: false, ...(overrides?.['authToken'] as Record<string, unknown>) } },
    app: { appId: 'app-id', token: { iat: 0, exp: 0 } },
    data: {
      sessionId: SESSION_ID,
      clientRequestId: REQ_ID,
      message: 'Hello MentorBot',
      ...(overrides?.['data'] as Record<string, unknown>),
    },
    rawRequest: {} as never,
    acceptsStreaming: false,
  } as unknown as Parameters<typeof mentorBotChat.run>[0];
}

beforeEach(() => {
  mockStore.clear();
  mockGet.mockClear();
  mockSet.mockClear();
  mockBatchOps.length = 0;
  geminiCallCount.value = 0;
});

describe('mentorBotChat — idempotency', () => {
  it('first call returns Gemini text and writes user + assistant docs', async () => {
    const result = await mentorBotChat.run(makeRequest());
    expect(result.text).toBe('cached fake');
    expect(result.messageId).toBe(REQ_ID);
    expect(geminiCallCount.value).toBe(1);
    const writes = mockBatchOps.map((op) => op.path);
    expect(writes).toContain(`sessions/${SESSION_ID}/messages/${REQ_ID}`);
    expect(writes).toContain(`sessions/${SESSION_ID}/messages/${REQ_ID}-user`);
    expect(writes).toContain(`sessions/${SESSION_ID}`);
  });

  it('second call with same clientRequestId returns cached response (Gemini called ONCE total)', async () => {
    // First call — populates the idempotency doc.
    await mentorBotChat.run(makeRequest());
    expect(geminiCallCount.value).toBe(1);
    // Second call with the SAME clientRequestId — must short-circuit.
    const second = await mentorBotChat.run(makeRequest());
    expect(geminiCallCount.value).toBe(1); // unchanged
    expect(second.messageId).toBe(REQ_ID);
    expect(second.text).toBe('cached fake');
  });

  it('throws unauthenticated when request.auth.uid is missing', async () => {
    const req = makeRequest();
    (req as { auth?: unknown }).auth = undefined;
    await expect(mentorBotChat.run(req)).rejects.toMatchObject({ code: 'unauthenticated' });
  });

  it('throws internal when clientRequestId is not a UUID v4', async () => {
    await expect(
      mentorBotChat.run(makeRequest({ data: { clientRequestId: 'not-a-uuid' } })),
    ).rejects.toMatchObject({ code: 'internal' });
  });

  it('throws internal when sessionId is not a UUID v4', async () => {
    await expect(
      mentorBotChat.run(makeRequest({ data: { sessionId: 'not-a-uuid' } })),
    ).rejects.toMatchObject({ code: 'internal' });
  });

  it('throws internal when message is empty', async () => {
    await expect(
      mentorBotChat.run(makeRequest({ data: { message: '' } })),
    ).rejects.toMatchObject({ code: 'internal' });
  });
});
