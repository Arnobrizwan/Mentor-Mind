---
phase: 03-gemini-proxy-server-side-rate-limiting
plan: 06
type: execute
wave: 3
depends_on: ["03-03", "03-04", "03-05"]
files_modified:
  - functions/src/index.ts
  - functions/src/__tests__/idempotency.test.ts
autonomous: true
requirements: [AI-01, AI-07, AI-10]
pr_group: PR-1
tags: [mentorbot_callable, oncall_v2, asia_south1, enforce_app_check, idempotency, uuid_v4_validation, session_message_subcollection, prompt_version_stamp, ai10_non_streaming]

must_haves:
  truths:
    - "AI-01 honored: `mentorBotChat` is the server-side proxy for every Gemini call — no API key, ADC-only via Vertex AI"
    - "AI-07 honored: handler validates auth + clientRequestId UUID v4 + does idempotency cache read BEFORE calling rate_limit.checkAndIncrement; idempotent retries with same clientRequestId return the SAME messageId without re-invoking Gemini"
    - "AI-10 honored: handler calls `client.generate(...)` ONLY (non-streaming v1.0); response shape `{ text, promptTokens, completionTokens, messageId, createdAt }` — no streaming endpoint"
    - "D-06 honored: callable is `onCall({region:'asia-south1', enforceAppCheck:true, timeoutSeconds:60, memory:'512MiB'}, handler)` — matches Phase 2 ping shape (D-06/D-07)"
    - "D-07 error semantics inherited: handler throws `unauthenticated`, `internal`, `resource-exhausted/daily`, `resource-exhausted/burst`, `unavailable/monthly-ceiling`, `deadline-exceeded` via errors.ts factory wrappers"
    - "D-08 honored: handler returns assistant text immediately AND writes user + assistant message docs to `/sessions/{sid}/messages/{mid}` — Phase 4's onSessionWrite trigger fires on each new doc"
    - "D-11 honored: session metadata `/sessions/{sid}` is upserted (`uid, subject, level, startedAt, lastMessageAt, messageCount, lastClientRequestId`); message subcollection persists `role, text, imageUrl?, clientRequestId, createdAt, promptVersion: '1'`"
    - "D-04 honored: every assistant message doc is stamped with `promptVersion: SYSTEM_PROMPT_VERSION` from gemini.ts"
    - "D-19 honored: handler reads `request.auth?.token?.premium === true` and forwards `isPremium` into checkAndIncrement; pre-Phase-5 every token has premium=false (REWD-02 default) so it's a no-op"
    - "D-21 honored: handler picks the GeminiClient via `process.env.GEMINI_CLIENT_MODE === 'fake' ? 'fake' : 'prod'` — emulator + unit tests use fake; production uses Vertex"
    - "D-05 honored: image flow accepts `imageUrl` parameter (gs:// path OR download URL); server fetches bytes via Admin Storage SDK; passes to Gemini as `inline_data` (Pitfall P-4)"
    - "Idempotency cache: read `/sessions/{sid}/messages/{clientRequestId}` BEFORE the rate_limit transaction; if exists, return the cached `{ text, promptTokens, completionTokens, messageId, createdAt }` shape; this is the AI-07 dedupe path"
    - "PITFALLS #2 closed: idempotency check happens BEFORE quota increment — a retried 'completed' request does NOT double-charge quota"
    - "T-3-APPCHECK-BYPASS mitigated: `enforceAppCheck: true` enforced at the v2 onCall option level (Phase 2 D-01 baseline inherited)"
    - "T-3-AUTH-MISSING mitigated: handler throws `unauthenticated` if `request.auth?.uid` is falsy; UUID v4 regex on clientRequestId rejects garbage input with `internal`"
    - "T-3-IDEMPOTENCY-BYPASS mitigated: idempotency doc id IS the clientRequestId at `/sessions/{sid}/messages/{clientRequestId}`; collision space ~2^122; replay-with-same-id is the only re-entry path"
    - "Gemini is called AFTER the rate_limit transaction commits (Pitfall P-2 from plan 03-05) — text generation never holds the transaction lock"
  artifacts:
    - path: "functions/src/index.ts"
      provides: "mentorBotChat export alongside existing ping export; handler with auth + idempotency + rate-limit + Gemini + persist sequence"
      contains: "mentorBotChat"
    - path: "functions/src/__tests__/idempotency.test.ts"
      provides: "Unit tests verifying same clientRequestId returns same messageId AND Gemini.generate called exactly once across two invocations"
      contains: "clientRequestId"
  key_links:
    - from: "functions/src/index.ts mentorBotChat handler"
      to: "functions/src/lib/gemini.ts (plan 03-03)"
      via: "imports makeGeminiClient + MODEL_CONFIG + SYSTEM_PROMPT_VERSION"
      pattern: "makeGeminiClient|MODEL_CONFIG"
    - from: "functions/src/index.ts mentorBotChat handler"
      to: "functions/src/lib/rate_limit.ts (plan 03-05)"
      via: "calls checkAndIncrement(uid, kind, isPremium, clientRequestId) inside the request flow"
      pattern: "checkAndIncrement"
    - from: "functions/src/index.ts mentorBotChat handler"
      to: "/sessions/{sid}/messages/{clientRequestId} (Firestore)"
      via: "idempotency cache read + user/assistant message doc writes"
      pattern: "sessions/.*messages"
---

<objective>
Add `mentorBotChat` as a second export in `functions/src/index.ts` (existing `ping` stays untouched). The handler — invoked on `asia-south1` with `enforceAppCheck: true`, `timeoutSeconds: MODEL_CONFIG.timeoutSeconds`, `memory: MODEL_CONFIG.memory` — orchestrates: (1) auth check (`request.auth.uid`); (2) input validation (clientRequestId UUID v4 regex; required fields); (3) idempotency read at `/sessions/{sid}/messages/{clientRequestId}`; (4) `checkAndIncrement(uid, kind, isPremium, clientRequestId)` transaction (plan 03-05); (5) (if image) Admin Storage SDK fetch of `imageUrl` bytes; (6) `makeGeminiClient(mode).generate(...)` call AFTER the transaction commits; (7) write user + assistant message docs to `/sessions/{sid}/messages/`; (8) upsert `/sessions/{sid}` metadata; (9) return `{ text, promptTokens, completionTokens, messageId, createdAt }`. Add `functions/src/__tests__/idempotency.test.ts` verifying the dedupe path: two calls with the same `clientRequestId` return the same `messageId` AND Gemini.generate is invoked exactly once.

Purpose: This is the proxy. Without it, AI-01 / AI-07 / AI-10 cannot ship. Plan 03-05 wired the rate-limit transaction; plan 03-03 wired the Gemini client + interface; this plan stitches them into the v2 callable that the Flutter client (plan 03-11 repository, plan 03-12 viewmodel) invokes via `httpsCallable('mentorBotChat')`.

Output: 2 files — `functions/src/index.ts` (MODIFY — add `mentorBotChat` export, ~150 lines added) + `functions/src/__tests__/idempotency.test.ts` (NEW, ~120 lines). One commit. `npm test -- --testPathPattern=idempotency` exits 0; `npm run build` exports `mentorBotChat` from the compiled `lib/index.js`.
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
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-03-vertex-gemini-client-PLAN.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-04-model-availability-checkpoint-PLAN.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-05-rate-limit-transaction-PLAN.md
@functions/src/index.ts
@functions/src/lib/gemini.ts
@functions/src/lib/rate_limit.ts
@functions/src/lib/admin.ts
@functions/src/lib/errors.ts
@CLAUDE.md

<interfaces>
<!-- Patterns from 03-PATTERNS.md §functions/src/index.ts lines 252-304 + 03-RESEARCH §Pattern 3 -->

functions/src/index.ts — DESIRED state (the existing `ping` export STAYS; `mentorBotChat` is APPENDED):

```typescript
// (Existing Phase 2 imports + ping export stay above this block.)
//
// Phase 3 — mentorBotChat callable (replaces the Phase 2 d-CONTEXT stub).

import { onCall } from 'firebase-functions/https';
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { db } from './lib/admin';
import { makeGeminiClient, MODEL_CONFIG, SYSTEM_PROMPT_VERSION } from './lib/gemini';
import { checkAndIncrement } from './lib/rate_limit';
import {
  unauthenticated,
  internal,
  mapKnownError,
} from './lib/errors';

const UUID_V4_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const MAX_MESSAGE_BYTES = 8_000; // ~2k tokens of UTF-8

export const mentorBotChat = onCall(
  {
    region: 'asia-south1',
    enforceAppCheck: true,
    timeoutSeconds: MODEL_CONFIG.timeoutSeconds,
    memory: MODEL_CONFIG.memory,
  },
  async (request) => {
    const startMs = Date.now();

    // ---------------------- AUTH ----------------------
    const uid = request.auth?.uid;
    if (!uid) {
      throw unauthenticated('Authentication required');
    }
    const isPremium = request.auth?.token?.premium === true;

    // ---------------------- INPUT VALIDATION ----------------------
    const data = (request.data ?? {}) as Record<string, unknown>;
    const sessionId = typeof data['sessionId'] === 'string' ? data['sessionId'] : '';
    const clientRequestId =
      typeof data['clientRequestId'] === 'string' ? data['clientRequestId'] : '';
    const message = typeof data['message'] === 'string' ? data['message'] : '';
    const imageUrl = typeof data['imageUrl'] === 'string' ? data['imageUrl'] : undefined;
    const subject = typeof data['subject'] === 'string' ? data['subject'] : undefined;
    const level = typeof data['level'] === 'string' ? data['level'] : undefined;

    if (!UUID_V4_REGEX.test(clientRequestId)) {
      throw internal('Invalid clientRequestId (must be UUID v4)');
    }
    if (!UUID_V4_REGEX.test(sessionId)) {
      throw internal('Invalid sessionId (must be UUID v4)');
    }
    if (!message || message.length === 0) {
      throw internal('message is required');
    }
    if (Buffer.byteLength(message, 'utf8') > MAX_MESSAGE_BYTES) {
      throw internal('message too long');
    }

    const kind: 'text' | 'image' = imageUrl ? 'image' : 'text';

    try {
      // ---------------------- IDEMPOTENCY CACHE ----------------------
      // doc id == clientRequestId so a retry with the same id hits the SAME doc.
      const idempotencyRef = db
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .doc(clientRequestId);
      const idempotencySnap = await idempotencyRef.get();
      if (idempotencySnap.exists) {
        const cached = idempotencySnap.data() ?? {};
        functions.logger.info('mentorBotChat: idempotent hit', {
          uid,
          sessionId,
          clientRequestId,
        });
        const cachedCreatedAt = cached['createdAt'];
        const createdAtMs =
          cachedCreatedAt instanceof admin.firestore.Timestamp
            ? cachedCreatedAt.toMillis()
            : Date.now();
        return {
          text: (cached['text'] as string) ?? '',
          promptTokens: (cached['promptTokens'] as number) ?? 0,
          completionTokens: (cached['completionTokens'] as number) ?? 0,
          messageId: clientRequestId,
          createdAt: createdAtMs,
        };
      }

      // ---------------------- RATE LIMIT (TRANSACTION) ----------------------
      await checkAndIncrement(uid, kind, isPremium, clientRequestId);

      // ---------------------- (OPTIONAL) IMAGE FETCH ----------------------
      let imageInline: { buffer: Buffer; mimeType: string } | undefined;
      if (imageUrl) {
        // Accept gs:// path OR download URL; Admin Storage handles both via .bucket().file()
        // We expect path within OUR project; bail on cross-project URLs.
        const gsMatch = imageUrl.match(/^gs:\/\/([^/]+)\/(.+)$/);
        const httpsMatch = imageUrl.match(
          /^https?:\/\/firebasestorage\.googleapis\.com\/v0\/b\/([^/]+)\/o\/([^?]+)/,
        );
        const match = gsMatch ?? httpsMatch;
        if (!match) {
          throw internal('Invalid imageUrl (must be gs:// or firebasestorage URL)');
        }
        const bucket = match[1]!;
        const objectPath = decodeURIComponent(match[2]!);
        const file = admin.storage().bucket(bucket).file(objectPath);
        const [bytes] = await file.download();
        const [metadata] = await file.getMetadata();
        const mimeType = (metadata.contentType as string | undefined) ?? 'image/jpeg';
        imageInline = { buffer: bytes, mimeType };
      }

      // ---------------------- GEMINI CALL (AFTER tx commits) ----------------------
      const mode: 'prod' | 'fake' =
        process.env['GEMINI_CLIENT_MODE'] === 'fake' ? 'fake' : 'prod';
      const client = makeGeminiClient(mode);
      // Prompt prefix encodes subject + level so the system prompt can calibrate.
      const promptPrefix =
        subject && level
          ? `[Subject: ${subject}, Level: ${level}]\n`
          : '';
      const { text, promptTokens, completionTokens } = await client.generate({
        prompt: promptPrefix + message,
        ...(imageInline ? { image: imageInline } : {}),
        modelConfig: MODEL_CONFIG,
      });

      // ---------------------- PERSIST USER + ASSISTANT MESSAGE DOCS ----------------------
      const nowTs = admin.firestore.Timestamp.now();
      const userMessageRef = db
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .doc(`${clientRequestId}-user`);
      const assistantMessageRef = idempotencyRef; // doc id == clientRequestId — IDEMPOTENCY KEY

      const batch = db.batch();
      batch.set(userMessageRef, {
        role: 'user',
        text: message,
        ...(imageUrl ? { imageUrl } : {}),
        clientRequestId,
        createdAt: nowTs,
        promptVersion: SYSTEM_PROMPT_VERSION,
      });
      batch.set(assistantMessageRef, {
        role: 'assistant',
        text,
        clientRequestId,
        createdAt: nowTs,
        promptVersion: SYSTEM_PROMPT_VERSION,
        promptTokens,
        completionTokens,
      });
      // Upsert /sessions/{sid} metadata (D-11)
      batch.set(
        db.collection('sessions').doc(sessionId),
        {
          uid,
          ...(subject ? { subject } : {}),
          ...(level ? { level } : {}),
          startedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastMessageAt: nowTs,
          messageCount: admin.firestore.FieldValue.increment(2),
          lastClientRequestId: clientRequestId,
        },
        { merge: true },
      );
      await batch.commit();

      const durationMs = Date.now() - startMs;
      functions.logger.info('mentorBotChat: success', {
        uid,
        sessionId,
        clientRequestId,
        promptTokens,
        completionTokens,
        durationMs,
        mode,
      });

      return {
        text,
        promptTokens,
        completionTokens,
        messageId: clientRequestId,
        createdAt: nowTs.toMillis(),
      };
    } catch (err) {
      // resourceExhausted / unavailable / unauthenticated / internal propagate as-is;
      // unknown errors get mapped via mapKnownError (Phase 2 D-05).
      throw mapKnownError(err);
    }
  },
);
```

functions/src/__tests__/idempotency.test.ts (NEW — full file):

```typescript
// Unit test for the idempotency dedupe path of mentorBotChat.
//
// Strategy: extract the handler logic into a testable function OR mock the
// Firestore SDK and invoke the handler directly via the exported callable.
//
// Approach used here: invoke `mentorBotChat.run({ data, auth, app })` — the
// firebase-functions v2 onCall returns a runnable with `.run()`. We mock the
// Firestore SDK + GeminiClient at the module boundary.

import * as admin from 'firebase-admin';

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

jest.mock('firebase-functions/params', () => ({
  defineString: () => ({ value: () => '10000' }),
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
```

Required `errors.ts` symbols (Phase 2 D-05 — confirm before this plan ships):
  - `unauthenticated(msg, details?)` → HttpsError
  - `internal(msg, details?)` → HttpsError
  - `mapKnownError(err)` → HttpsError (passes through HttpsError, wraps unknown)
  - (used by plan 03-05; already imported there): `resourceExhausted(...)`, `unavailable(...)`

If the actual Phase 2 names differ (e.g. `makeUnauthenticated`), adapt the import line; do not refactor errors.ts in this plan.

Why the v2 onCall `.run()` API is used in tests:
  - `firebase-functions/https.onCall` returns a callable object with a `.run(request)` method that exercises the handler logic in-process (no HTTP server boot).
  - This bypasses App Check + auth header validation — the test injects `request.auth` directly.
  - RESEARCH §Pattern 3 cites this as the canonical unit-test entry point.

What this plan does NOT do:
  - Does NOT call the real Vertex API in tests (the Gemini mock returns canned text).
  - Does NOT exercise the rate_limit transaction body — plan 03-05 covers that with its own test suite.
  - Does NOT exercise the rules — plan 03-09 covers AI-08 rules unit tests.
  - Does NOT write the `/system/usage_log/{YYYY-MM-DD}` aggregate — plan 03-07 wires that.
  - Does NOT delete the Phase 2 ping export — `ping` stays for the boot-canary contract.
  - Does NOT define the streaming endpoint — AI-10 (non-streaming v1.0).
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add mentorBotChat export to functions/src/index.ts (alongside existing ping); write functions/src/__tests__/idempotency.test.ts; verify all tests + build + lint green; confirm compiled lib/index.js exports mentorBotChat</name>
  <files>functions/src/index.ts, functions/src/__tests__/idempotency.test.ts</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/functions/src/index.ts (CURRENT — Phase 2 ping shape; confirm the file structure to add to)
    - /Users/arnobrizwan/Mentor-Mind/functions/src/lib/errors.ts (CONFIRM exported names — `unauthenticated`, `internal`, `mapKnownError`)
    - /Users/arnobrizwan/Mentor-Mind/functions/src/lib/gemini.ts (plan 03-03 — confirm `makeGeminiClient`, `MODEL_CONFIG`, `SYSTEM_PROMPT_VERSION` exports)
    - /Users/arnobrizwan/Mentor-Mind/functions/src/lib/rate_limit.ts (plan 03-05 — confirm `checkAndIncrement` export + signature)
    - /Users/arnobrizwan/Mentor-Mind/functions/src/lib/admin.ts (Phase 2 — confirm `db` named export)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-PATTERNS.md (§functions/src/index.ts lines 252-304 — substitution rule preserving the existing ping export)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-CONTEXT.md (D-04, D-06, D-07, D-08, D-11, D-19, D-21)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md (row `03-06-mentorbot-callable` line 59)
  </read_first>
  <behavior>
    - First call to `mentorBotChat` with new `clientRequestId` returns `{ text: 'cached fake', promptTokens: 7, completionTokens: 13, messageId: <clientRequestId>, createdAt: <ms> }`; Gemini.generate called exactly 1 time.
    - Second call with the SAME `clientRequestId` returns the same `messageId` and same `text`; Gemini.generate called still exactly 1 time total (idempotency dedupe).
    - Missing `request.auth.uid` → HttpsError `unauthenticated`.
    - `clientRequestId` not matching UUID v4 regex → HttpsError `internal`.
    - `sessionId` not matching UUID v4 regex → HttpsError `internal`.
    - Empty `message` → HttpsError `internal`.
    - `request.auth.token.premium === true` is forwarded to `checkAndIncrement(uid, kind, isPremium=true, clientRequestId)`.
    - Three writes per first call: `/sessions/{sid}` (metadata upsert), `/sessions/{sid}/messages/{clientRequestId}-user`, `/sessions/{sid}/messages/{clientRequestId}` (assistant; idempotency key).
    - `promptVersion: '1'` stamped on both user and assistant docs.
    - Gemini is invoked AFTER `checkAndIncrement` returns successfully (Pitfall P-2 — never inside the rate_limit transaction).
  </behavior>
  <action>
    Step A — Read `functions/src/index.ts` to capture the existing `ping` shape + import block. Confirm:
      - `ping` uses `onCall({region:'asia-south1', enforceAppCheck:true}, ...)`.
      - The file has a single `import { onCall } from 'firebase-functions/https'` (or similar).
      - The file does NOT already import `db`, `makeGeminiClient`, `checkAndIncrement`, etc.

    Step B — Read `functions/src/lib/errors.ts` to confirm exported factory wrapper names. The interfaces block uses `unauthenticated`, `internal`, `mapKnownError`. If Phase 2 used different names (e.g. `makeUnauthenticated`), adapt the import line — do NOT modify errors.ts.

    Step C — TDD RED: Create `functions/src/__tests__/idempotency.test.ts` with the EXACT content from the `<interfaces>` block above. Run:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind/functions
      npm test -- --testPathPattern=idempotency 2>&amp;1 | tee /tmp/p3-06-red.log
      # Expect: compile failure — mentorBotChat not exported from ../index yet.
      ```

    Step D — TDD GREEN: APPEND the `mentorBotChat` block from the `<interfaces>` section to `functions/src/index.ts`. CRITICAL preservation:
      - Existing `ping` export stays unchanged.
      - Existing top-level imports merge with the new ones (deduplicate any shared imports — likely `onCall` is already imported for `ping`).
      - The new imports add: `* as functions from 'firebase-functions'`, `* as admin from 'firebase-admin'`, `db` from './lib/admin', `makeGeminiClient`, `MODEL_CONFIG`, `SYSTEM_PROMPT_VERSION` from './lib/gemini', `checkAndIncrement` from './lib/rate_limit', and the error factory wrappers from './lib/errors'.

    Step E — Re-run tests:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind/functions
      npm test -- --testPathPattern=idempotency 2>&amp;1 | tee /tmp/p3-06-green.log
      # Expect: 6 passed (1 first call + 1 idempotent + 4 input validation).
      ```

    Step F — TS compile + lint:
      ```bash
      npm run build 2>&amp;1 | tail -10
      npm run lint  2>&amp;1 | tail -10
      ```
      Common fixups:
        - `Buffer.byteLength` requires `@types/node` — should already be present from Phase 2.
        - The image-fetch block's `admin.storage().bucket(...)` may need `@types/firebase-admin` types — Phase 2 dep.
        - If `strict: true` complains about `request.auth?.token?.premium`, cast via `(request.auth?.token as { premium?: boolean } | undefined)?.premium`.

    Step G — Confirm the compiled lib/index.js exports mentorBotChat:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind/functions
      npm run build
      node -e "const m=require('./lib/index.js'); if(!m.ping) throw new Error('ping missing'); if(!m.mentorBotChat) throw new Error('mentorBotChat missing'); console.log('ok: ping + mentorBotChat both exported')"
      ```

    Step H — Required-content greps:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      grep -q "export const mentorBotChat = onCall" functions/src/index.ts
      grep -q "enforceAppCheck: true" functions/src/index.ts
      grep -q "region: 'asia-south1'" functions/src/index.ts
      grep -q "checkAndIncrement" functions/src/index.ts
      grep -q "makeGeminiClient" functions/src/index.ts
      grep -q "SYSTEM_PROMPT_VERSION" functions/src/index.ts
      grep -q "UUID_V4_REGEX" functions/src/index.ts
      grep -q "idempotencyRef" functions/src/index.ts
      # Pitfall P-2 — no Gemini inside transaction (rate_limit module has its own gate).
      ! grep -E "runTransaction" functions/src/index.ts
      # AI-10 — no streaming.
      ! grep -E "generateContentStream|async\*|await for" functions/src/index.ts
      # Existing ping export preserved.
      grep -q "export const ping = onCall" functions/src/index.ts
      ```

    Step I — Commit:
      ```bash
      git add functions/src/index.ts functions/src/__tests__/idempotency.test.ts
      git commit -m "feat(functions): add mentorBotChat callable + idempotency dedupe (Phase 3 PR-1; AI-01/AI-07/AI-10; D-04/D-06/D-07/D-08/D-11/D-19/D-21)"
      ```
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f functions/src/index.ts &amp;&amp; test -f functions/src/__tests__/idempotency.test.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "export const mentorBotChat" functions/src/index.ts &amp;&amp; grep -q "export const ping" functions/src/index.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "enforceAppCheck: true" functions/src/index.ts &amp;&amp; grep -q "region: 'asia-south1'" functions/src/index.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "checkAndIncrement" functions/src/index.ts &amp;&amp; grep -q "makeGeminiClient" functions/src/index.ts &amp;&amp; grep -q "SYSTEM_PROMPT_VERSION" functions/src/index.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "UUID_V4_REGEX|/\^\[0-9a-f\]\{8\}-\[0-9a-f\]\{4\}-4" functions/src/index.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "idempotencyRef|sessions.*messages.*clientRequestId" functions/src/index.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -E "generateContentStream|async\*" functions/src/index.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; npm test -- --testPathPattern=idempotency 2>&amp;1 | grep -qE 'Tests:\s+[0-9]+ passed'</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; npm run build 2>&amp;1 | tail -3; test $? -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; npm run lint 2>&amp;1 | tail -3; test $? -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; node -e "const m=require('./lib/index.js'); if(!m.ping) throw new Error('ping'); if(!m.mentorBotChat) throw new Error('mentorBotChat'); console.log('ok')" | grep -q '^ok$'</automated>
  </verify>
  <acceptance_criteria>
    - `functions/src/index.ts` exports both `ping` (Phase 2, untouched) AND `mentorBotChat` (new).
    - `mentorBotChat` uses `onCall({region:'asia-south1', enforceAppCheck:true, timeoutSeconds:60, memory:'512MiB'}, handler)`.
    - Handler validates: `request.auth.uid` (throws `unauthenticated`), UUID v4 on `clientRequestId` + `sessionId` (throws `internal`), non-empty `message` (throws `internal`).
    - Idempotency cache: read `/sessions/{sid}/messages/{clientRequestId}` BEFORE `checkAndIncrement`; on hit, return cached shape without calling Gemini.
    - Sequence: idempotency read → checkAndIncrement → (optional image fetch) → makeGeminiClient(mode).generate(...) → batch.set user + assistant + session metadata → return.
    - Gemini.generate is invoked AFTER `checkAndIncrement` returns (Pitfall P-2).
    - No `runTransaction` block in index.ts (rate_limit.ts owns transactions).
    - No `generateContentStream` reference (AI-10).
    - Both user + assistant message docs carry `promptVersion: '1'` (D-04).
    - Premium claim (`request.auth.token.premium === true`) forwarded to checkAndIncrement.
    - `functions/src/__tests__/idempotency.test.ts` has ≥ 6 tests; all pass under `npm test -- --testPathPattern=idempotency`.
    - `npm run build` + `npm run lint` both exit 0.
    - Compiled `functions/lib/index.js` exports BOTH `ping` AND `mentorBotChat`.
  </acceptance_criteria>
  <done>
    The mentorBotChat callable is wired end-to-end on the server. Plan 03-07 adds the usage_log observability AFTER the batch commits. Plan 03-11 (MentorBotRepository) is the Dart-side caller. Plan 03-13 emulator smoke test exercises the full path with the fake Gemini client.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| client device ⇄ mentorBotChat | App Check (`enforceAppCheck: true`) gates every call; only devices with a valid App Attest token reach the handler. |
| request.auth.uid ⇄ Firebase Auth | The `uid` is asserted by Firebase Auth via the ID token; spoofing requires forging a Google-signed JWT. |
| clientRequestId ⇄ idempotency cache | UUID v4 collision space ~2^122; collision = security non-issue; replay-with-same-id is the dedupe path. |
| sessionId ⇄ /sessions/{sid} | Server treats sessionId as opaque; a malicious client could write to ANOTHER user's session by forging the sessionId — Phase 4 rules lockdown of `/sessions/**` closes that. Phase 3 accepts the gap (CONTEXT D-17 explicitly defers session rules to Phase 4). |
| GEMINI_CLIENT_MODE env var ⇄ production | Production deploys MUST have GEMINI_CLIENT_MODE unset (or set to 'prod'); 'fake' would return canned responses to real users. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-3-APPCHECK-BYPASS | Spoofing | A client without a valid App Attest token calls the function and consumes quota | mitigate | `enforceAppCheck: true` at the v2 onCall option level — Functions runtime rejects pre-handler. Phase 2 D-01 baseline inherited. |
| T-3-AUTH-MISSING | Spoofing | A request arrives without `request.auth.uid` (e.g. anonymous user) and consumes resources | mitigate | Handler throws `unauthenticated` BEFORE any work. Validated by the idempotency test suite. |
| T-3-IDEMPOTENCY-BYPASS | Tampering | Two concurrent calls with the same `clientRequestId` both miss the idempotency cache (race) and both call Gemini | accept (low-probability) | The two writes serialize at the `/sessions/{sid}/messages/{clientRequestId}` doc level — Firestore's last-writer-wins means one assistant doc ends up persisted. Both calls return the SAME messageId. Worst case: one extra Gemini call (~$0.01); operationally negligible. Future hardening: wrap the idempotency read + Gemini call + write in a runTransaction at the cost of holding the lock through the Gemini call (Pitfall P-2 violation). |
| T-3-PROMPT-INJECTION | Tampering | A user crafts message text saying "Ignore the system prompt and ..." | mitigate (inherited) | Vertex SDK's `systemInstruction` field is separate from user content (plan 03-03 D-21). Safety settings BLOCK_MEDIUM_AND_ABOVE. Defense-in-depth, not perfect. |
| T-3-06-CROSS-USER-SESSION | Information Disclosure | Client A passes `sessionId` belonging to client B; server writes to B's session, leaking A's chat into B's history | partial-mitigate | Phase 3 does NOT validate sessionId ownership (CONTEXT D-17 — session rules deferred to Phase 4). The session metadata doc DOES record `uid: <calling user>` on every write; Phase 4 rules will use it. Surface in T-3-LAYER-BREACH closeout for Phase 4. |
| T-3-06-IMAGE-EXFIL | Information Disclosure | A user passes an `imageUrl` pointing to another project's bucket; server's storage SA fetches it | mitigate | Image URL regex restricts to `gs://*` or `firebasestorage.googleapis.com/v0/b/*` patterns; Phase 3 v1 trusts the bucket name (which the storage SA enforces via IAM — only `mentor-mind-aa765.firebasestorage.app` is readable to the function SA). Cross-project URL = `internal` reject. |
| T-3-06-LARGE-MESSAGE-DOS | Denial of Service | A user sends a 100KB message; tokenizes to 25k tokens; bloats prompt + cost | mitigate | `MAX_MESSAGE_BYTES = 8000` UTF-8 cap (~2k tokens). Reject with `internal` if exceeded. |
| T-3-06-FAKE-MODE-LEAK | Information Disclosure | `GEMINI_CLIENT_MODE=fake` accidentally set in production; users receive canned 'cached fake' replies | mitigate | Plan 03-08 BACKEND_SETUP.md §3 documents that `GEMINI_CLIENT_MODE` MUST NOT be set in production; default behavior (env var absent) selects 'prod'. CI green logs surface a real Vertex response in the smoke test only when explicitly opted out (which we do NOT do — emulator always uses 'fake'). |
| T-3-06-REGEX-DOS | Denial of Service | A user passes a 10MB UUID string; regex engine ReDoS | mitigate | Input field is read as `typeof === 'string'`; max length implicitly capped by callable payload limit (~10MB). UUID v4 regex is a finite anchored pattern (no nested quantifiers) — ReDoS-safe. |
</threat_model>

<verification>
- functions/src/index.ts exports both `ping` (preserved) and `mentorBotChat` (new).
- Callable shape matches D-06/D-07: region asia-south1, enforceAppCheck true, timeoutSeconds, memory from MODEL_CONFIG.
- Auth check, UUID v4 validation, idempotency cache read, rate_limit transaction, Gemini call, batch write — all wired in that exact sequence.
- promptVersion stamped on both user and assistant docs.
- AI-10 anti-streaming grep gate green.
- Compiled lib/index.js exports both functions.
- 6+ idempotency tests pass.
- Build + lint green.
</verification>

<success_criteria>
- AI-01: server-side proxy operational (no API key, ADC via Vertex).
- AI-07: idempotency via clientRequestId verified by test suite.
- AI-10: non-streaming response shape returned; no streaming code path.
- D-04/D-06/D-07/D-08/D-11/D-19/D-21: all honored.
- Plan 03-07 can wire usage_log after this plan's batch commit.
- Plan 03-11 (MentorBotRepository) calls httpsCallable('mentorBotChat').
</success_criteria>

<output>
Create `.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-06-mentorbot-callable-SUMMARY.md` when done. Record:
1. Full content of the appended `mentorBotChat` block in functions/src/index.ts.
2. Full content of functions/src/__tests__/idempotency.test.ts.
3. Jest output (≥ 6 tests passed).
4. The `node -e "const m=require('./lib/index.js'); ..."` output confirming both exports.
5. AI-10 grep output (empty — no generateContentStream / async* / await for).
6. npm run build + npm run lint exit codes.
7. Commit SHA.
8. Forward-pointer: plan 03-07 adds usage_log; plan 03-11 wraps with MentorBotRepository.
</output>
</content>
