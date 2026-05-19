# Phase 3: Gemini Proxy + Server-Side Rate Limiting — Pattern Map

**Mapped:** 2026-05-19
**Files analyzed:** 25 (new/modified across PR-1, PR-2, PR-3)
**Analogs found:** 20 / 25 (5 have no in-repo analog; canonical skeletons from RESEARCH.md supplied)

---

## File Classification

| New / Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `functions/src/lib/quota.ts` | utility | transform | none (RESEARCH.md Pattern 7) | no-analog |
| `functions/src/lib/gemini.ts` | service | request-response | `functions/src/lib/gemini.ts` (current stub) | fill-stub |
| `functions/src/lib/rate_limit.ts` | service | CRUD + transaction | `functions/src/lib/rate_limit.ts` (current stub) | fill-stub |
| `functions/src/index.ts` | controller | request-response | `functions/src/index.ts` (`ping` export) | exact |
| `functions/jest.config.js` | config | — | none (RESEARCH.md §Test Infrastructure) | no-analog |
| `functions/package.json` | config | — | `functions/package.json` (Phase 2) | exact |
| `functions/src/__tests__/quota.test.ts` | test | — | none (RESEARCH.md §Pattern 7) | no-analog |
| `functions/src/__tests__/rate_limit.test.ts` | test | — | none (RESEARCH.md §Pattern 3 + 4) | no-analog |
| `functions/src/__tests__/gemini.test.ts` | test | — | none (RESEARCH.md §Pattern 1 + 2) | no-analog |
| `functions/src/__tests__/idempotency.test.ts` | test | — | none (RESEARCH.md §Pattern 3) | no-analog |
| `functions/src/__tests__/usage_log.test.ts` | test | — | none (D-15 observability) | no-analog |
| `functions/src/__tests__/rules.test.ts` | test (rules) | — | none (RESEARCH.md §Pattern 6) | no-analog |
| `functions/tool/verify-model-availability.js` | utility (script) | request-response | none (RESEARCH.md §Pitfall P-1) | no-analog |
| `firestore.rules` | config (security) | — | `firestore.rules` (existing) | exact |
| `lib/core/constants/quota.dart` | utility | transform | `lib/core/constants/app_colors.dart` | role-match |
| `lib/data/models/mentor_bot_response.dart` | model | transform | `lib/data/models/ping_response.dart` | exact |
| `lib/data/repositories/mentor_bot_repository.dart` | repository | request-response | `lib/data/repositories/ping_repository.dart` | exact |
| `lib/application/viewmodels/tutor/chat_viewmodel.dart` | viewmodel | request-response | itself (current state) | modify |
| `lib/core/services/gemini_service.dart` | service | — | itself (current state) | delete |
| `pubspec.yaml` | config | — | `pubspec.yaml` (Phase 2 state) | exact |
| `integration_test/mentor_bot_smoke_test.dart` | test | request-response | `integration_test/ping_smoke_test.dart` | exact |
| `.vscode/launch.json` | config | — | does not exist yet | n/a |
| `README.md` | doc | — | `BACKEND_SETUP.md` (run instructions) | role-match |
| `BACKEND_SETUP.md` | doc | — | `BACKEND_SETUP.md` §Phase 2 section | exact |
| `.github/workflows/ci.yml` | config (CI) | — | `.github/workflows/ci.yml` `functions:` job | exact |

---

## Pattern Assignments

---

### Layer: TypeScript Server (PR-1)

---

#### `functions/src/lib/quota.ts` — NEW utility, transform

**Analog:** None in-repo. Canonical shape from RESEARCH.md §Pattern 7.

**Core pattern** (full file skeleton — copy verbatim):
```typescript
// MIRROR: lib/core/constants/quota.dart exports kQuotaTimezone = 'Asia/Dhaka'.
// If this constant drifts from the Dart side, day-key mismatch causes
// a quota-reset at UTC midnight instead of Dhaka midnight (PITFALLS #3).
// NEVER use: new Date().toISOString().slice(0, 10)  ← UTC, NOT Dhaka.

export const QUOTA_TZ = 'Asia/Dhaka';

export function getDhakaDateKey(now: Date = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: QUOTA_TZ,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now); // → '2026-05-19'
}

export function monthKey(now: Date = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: QUOTA_TZ,
    year: 'numeric',
    month: '2-digit',
  }).format(now).slice(0, 7); // → '2026-05'
}
```

**Substitution rule:** Copy verbatim. The `now: Date` parameter makes both helpers testable with a fixed instant — always pass a `Date` in tests, rely on default `new Date()` in production code.

---

#### `functions/src/lib/gemini.ts` — FILL existing Phase 2 stub

**Analog:** `functions/src/lib/gemini.ts` (lines 1–18 — the stub being replaced)

**Imports pattern** (replace stub's imports):
```typescript
import { VertexAI, HarmCategory, HarmBlockThreshold } from '@google-cloud/vertexai';
import * as functions from 'firebase-functions';
```

**Interface + factory pattern** (from RESEARCH.md §Pattern 2 + CONTEXT D-21):
```typescript
export interface GeminiClient {
  generate(opts: {
    prompt: string;
    image?: { buffer: Buffer; mimeType: string };
    modelConfig: ModelConfig;
  }): Promise<{ text: string; promptTokens: number; completionTokens: number }>;
}

export function makeGeminiClient(mode: 'prod' | 'fake'): GeminiClient {
  if (mode === 'fake') {
    return {
      generate: async (_opts) => ({
        text: 'Fake MentorBot response for testing.',
        promptTokens: 10,
        completionTokens: 20,
      }),
    };
  }
  return new VertexGeminiClient();
}
// Usage: const client = makeGeminiClient(
//   process.env['GEMINI_CLIENT_MODE'] === 'fake' ? 'fake' : 'prod'
// );
```

**Vertex AI core pattern** (from RESEARCH.md §Pattern 1):
```typescript
// VertexGeminiClient.generate() body:
const vertexAI = new VertexAI({
  project: process.env['GCLOUD_PROJECT']!,
  location: 'asia-south1',
});
const model = vertexAI.getGenerativeModel({
  model: MODEL_CONFIG.modelId,  // pinned at execute time (D-01, Q-1)
  generationConfig: {
    temperature: MODEL_CONFIG.temperature,
    topP: MODEL_CONFIG.topP,
    topK: MODEL_CONFIG.topK,
    maxOutputTokens: MODEL_CONFIG.maxOutputTokens,
  },
  safetySettings: [...],
  systemInstruction: { role: 'system', parts: [{ text: SYSTEM_PROMPT }] },
});
const result = await model.generateContent({ contents: [...] });
// NEVER: generateContentStream  (AI-10 — non-streaming v1.0)
```

**Constants pattern:**
```typescript
export const SYSTEM_PROMPT_VERSION = '1';
export const SYSTEM_PROMPT = `You are MentorBot...`; // copy from gemini_service.dart _kSystemPrompt
export const MODEL_CONFIG = {
  modelId: 'gemini-2.5-pro',   // executor pins after running verify-model-availability.js
  timeoutSeconds: 60,
  memory: '512MiB' as const,
  maxOutputTokens: 1024,
  temperature: 0.7,
  topP: 0.95,
  topK: 40,
} as const;
export type ModelConfig = typeof MODEL_CONFIG;
```

**Substitution rule:** Delete the stub's 18 lines entirely. The new file exports: `GeminiClient` interface, `ModelConfig` type, `VertexGeminiClient` class, `FakeGeminiClient` inline object, `makeGeminiClient` factory, `SYSTEM_PROMPT`, `SYSTEM_PROMPT_VERSION`, `MODEL_CONFIG`. Copy `_kSystemPrompt` text from `lib/core/services/gemini_service.dart` lines 16–31 for the TS `SYSTEM_PROMPT` const.

---

#### `functions/src/lib/rate_limit.ts` — FILL existing Phase 2 stub

**Analog:** `functions/src/lib/rate_limit.ts` (lines 1–14 — stub being replaced) + `functions/src/lib/admin.ts` (for `db`) + `functions/src/lib/errors.ts` (for error factories)

**Imports pattern:**
```typescript
import * as admin from 'firebase-admin';
import { HttpsError } from 'firebase-functions/https';
import { db } from './admin';
import { getDhakaDateKey, monthKey } from './quota';
import { SYSTEM_PROMPT_VERSION } from './gemini';
```

**New signature** (replace stub's `checkAndIncrement`):
```typescript
export interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  resetAt: number;     // Unix ms — midnight of next Dhaka day
}

export async function checkAndIncrement(
  uid: string,
  kind: 'text' | 'image',
  isPremium: boolean,
  clientRequestId: string,
): Promise<RateLimitResult> { ... }
```

**Transaction body** (from RESEARCH.md §Pattern 3 — critical shape):
```typescript
// Reads FIRST, then writes — Admin SDK transaction constraint.
// Pre-allocate assistant doc ref BEFORE the transaction (auto-ID is sync).
const usageRef = db.collection('users').doc(uid).collection('usage').doc(getDhakaDateKey());
const quotaRef = db.collection('system').doc('quota').collection('monthly').doc(monthKey());

return db.runTransaction(async (tx) => {
  const [usageSnap, quotaSnap] = await Promise.all([
    tx.get(usageRef), tx.get(quotaRef),
  ]);
  const now = Date.now();
  const usage = usageSnap.data() ?? { messageCount: 0, imageCount: 0, burstWindow: [] };

  // Burst check (applies to premium too)
  const prunedBurst = (usage.burstWindow as admin.firestore.Timestamp[])
    .filter(ts => ts.toMillis() > now - 60_000);
  if (prunedBurst.length >= 5) {
    throw new HttpsError('resource-exhausted', 'Burst limit reached', {
      reason: 'burst',
      retryAfterSec: Math.ceil((prunedBurst[0]!.toMillis() + 60_000 - now) / 1000),
    });
  }

  // Daily check (premium bypass)
  if (!isPremium) {
    const count = kind === 'image' ? usage.imageCount : usage.messageCount;
    const limit = kind === 'image' ? 3 : 30;
    if (count >= limit) throw new HttpsError('resource-exhausted', 'Daily limit reached', {
      reason: 'daily', limit, used: count,
    });
  }

  // Monthly ceiling
  const quota = quotaSnap.data() ?? { calls: 0, ceiling: 10_000 };
  if (quota.calls >= quota.ceiling) {
    throw new HttpsError('unavailable', 'Service temporarily unavailable', {
      reason: 'monthly-ceiling',
    });
  }

  // WRITES after all reads
  const nowTs = admin.firestore.Timestamp.now(); // Timestamp.now() safe inside tx
  tx.set(usageRef, {
    messageCount: admin.firestore.FieldValue.increment(kind === 'text' ? 1 : 0),
    imageCount: admin.firestore.FieldValue.increment(kind === 'image' ? 1 : 0),
    burstWindow: [...prunedBurst, nowTs],  // literal array — NOT arrayUnion (Pitfall P-5)
  }, { merge: true });
  tx.set(quotaRef, { calls: admin.firestore.FieldValue.increment(1) }, { merge: true });

  return { allowed: true, remaining: 0, resetAt: 0 };
});
```

**Substitution rule:** Delete the stub's 14 lines. Export the new `RateLimitResult` interface and `checkAndIncrement(uid, kind, isPremium, clientRequestId)` function. The `clientRequestId` param is passed through for potential idempotency use inside the handler (the transaction checks the idempotency doc before incrementing). DO NOT call Gemini inside `runTransaction` (Pitfall P-2).

---

#### `functions/src/index.ts` — MODIFY: ADD `mentorBotChat` alongside `ping`

**Analog:** `functions/src/index.ts` lines 1–15 (the `ping` export — exact shape to mirror)

**Imports pattern** (lines 1–N of the modified file):
```typescript
import { onCall } from 'firebase-functions/https';
import * as functions from 'firebase-functions';
import { defineString } from 'firebase-functions/params';
import * as admin from 'firebase-admin';
import { db } from './lib/admin';
import { makeGeminiClient, MODEL_CONFIG, SYSTEM_PROMPT_VERSION } from './lib/gemini';
import { checkAndIncrement } from './lib/rate_limit';
import { unauthenticated, internal, mapKnownError } from './lib/errors';
import { getDhakaDateKey } from './lib/quota';
```

**Core callable pattern** (mirror `ping` shape, then add handler body):
```typescript
// Existing ping stays untouched:
export const ping = onCall({ region: 'asia-south1', enforceAppCheck: true }, (_request) => {
  return { ok: true, timestamp: Date.now(), region: 'asia-south1' };
});

// NEW alongside ping:
export const mentorBotChat = onCall(
  {
    region: 'asia-south1',
    enforceAppCheck: true,       // Phase 2 D-01 baseline inherited
    timeoutSeconds: MODEL_CONFIG.timeoutSeconds,
    memory: MODEL_CONFIG.memory,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw unauthenticated('Authentication required');

    const { sessionId, clientRequestId, message, imageUrl, subject, level } =
      request.data as Record<string, string | undefined>;

    // Validate clientRequestId is a UUID v4 (basic regex)
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
      clientRequestId ?? ''
    )) throw internal('Invalid clientRequestId');

    // Idempotency check (read BEFORE transaction — if cached, return early)
    // ... rate_limit.checkAndIncrement transaction ...
    // ... Gemini call AFTER transaction commits ...
    // ... write assistant message doc ...
    // ... update usage_log aggregate (non-transactional) ...
    // Return: { text, promptTokens, completionTokens, messageId, createdAt }
  },
);
```

**Substitution rule:** Keep the existing `ping` export unchanged. Add `mentorBotChat` as a second named export in the same file. The handler body follows the exact sequencing in D-08 and RESEARCH.md Pattern 3: idempotency read → transaction (quota checks + user message write) → Gemini call → assistant message write → usage_log update → return payload.

---

#### `functions/jest.config.js` — NEW config

**Analog:** None in-repo. Canonical ts-jest shape (RESEARCH.md §Test Infrastructure):

```javascript
/** @type {import('jest').Config} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/__tests__/**/*.test.ts'],
  moduleFileExtensions: ['ts', 'js'],
  transform: {
    '^.+\\.ts$': ['ts-jest', { tsconfig: './tsconfig.json' }],
  },
};
```

**Substitution rule:** Copy verbatim. The `tsconfig.json` path is relative to `functions/`. No coverage config here — add `--coverage` flag in `npm test` script if needed, but keep jest.config.js minimal.

---

#### `functions/package.json` — MODIFY

**Analog:** `functions/package.json` (lines 1–27 — the Phase 2 state, read above)

**Changed sections only:**
```json
{
  "scripts": {
    "build": "tsc",
    "build:watch": "tsc --watch",
    "lint": "eslint --ext .ts src/",
    "serve": "npm run build && firebase emulators:start --only functions",
    "test": "jest"
  },
  "dependencies": {
    "firebase-admin": "^13.10.0",
    "firebase-functions": "^6.6.0",
    "@google-cloud/vertexai": "^1.12.0"
  },
  "devDependencies": {
    "@typescript-eslint/eslint-plugin": "^8.59.3",
    "@typescript-eslint/parser": "^8.59.3",
    "eslint": "^10.4.0",
    "prettier": "^3.8.3",
    "typescript": "^5.8.3",
    "jest": "^29.0.0",
    "@types/jest": "^29.0.0",
    "ts-jest": "^29.0.0",
    "@firebase/rules-unit-testing": "^5.0.1"
  }
}
```

**Substitution rule:** Preserve all existing fields (`name`, `description`, `version`, `private`, `engines`, `main`). Add `"test": "jest"` to scripts. Add `@google-cloud/vertexai: ^1.12.0` to dependencies (alphabetical after `firebase-functions`). Add the four devDeps. Run `npm install` after to update `package-lock.json`.

---

### Layer: TypeScript Tests (PR-1 and PR-2)

---

#### `functions/src/__tests__/quota.test.ts` — NEW

**Analog:** None in-repo. Canonical Jest + ts-jest shape; mirrors `getDhakaDateKey` / `monthKey` from `quota.ts`.

**Core test pattern:**
```typescript
import { getDhakaDateKey, monthKey, QUOTA_TZ } from '../lib/quota';

describe('quota helpers', () => {
  it('QUOTA_TZ is Asia/Dhaka', () => {
    expect(QUOTA_TZ).toBe('Asia/Dhaka');
  });

  it('getDhakaDateKey returns Dhaka calendar date for a known UTC instant', () => {
    // 2026-05-18 18:00 UTC = 2026-05-19 00:00 Dhaka (UTC+6)
    const utcInstant = new Date('2026-05-18T18:00:00.000Z');
    expect(getDhakaDateKey(utcInstant)).toBe('2026-05-19');
  });

  it('getDhakaDateKey does NOT use UTC date at UTC midnight edge', () => {
    // 2026-05-19 00:00 UTC = 2026-05-19 06:00 Dhaka — same Dhaka day
    const atUtcMidnight = new Date('2026-05-19T00:00:00.000Z');
    expect(getDhakaDateKey(atUtcMidnight)).toBe('2026-05-19');
  });

  it('monthKey returns YYYY-MM', () => {
    const utcInstant = new Date('2026-05-18T18:00:00.000Z');
    expect(monthKey(utcInstant)).toBe('2026-05');
  });
});
```

**Substitution rule:** Copy the describe/it/expect shape. All tests use the `now: Date` parameter so no real-time dependency exists. Add one more test: that `getDhakaDateKey(new Date('2026-05-19T17:59:00.000Z'))` returns `'2026-05-19'` (23:59 Dhaka, still that day).

---

#### `functions/src/__tests__/gemini.test.ts` — NEW

**Analog:** None in-repo. Tests the `GeminiClient` interface and `makeGeminiClient` factory.

**Core test pattern:**
```typescript
import { makeGeminiClient, MODEL_CONFIG } from '../lib/gemini';

describe('FakeGeminiClient', () => {
  const client = makeGeminiClient('fake');

  it('generate returns canned response', async () => {
    const result = await client.generate({
      prompt: 'Hello',
      modelConfig: MODEL_CONFIG,
    });
    expect(result.text).toBe('Fake MentorBot response for testing.');
    expect(result.promptTokens).toBe(10);
    expect(result.completionTokens).toBe(20);
  });
});

describe('makeGeminiClient factory', () => {
  it("mode='fake' returns FakeGeminiClient (no VertexAI instantiation)", () => {
    const client = makeGeminiClient('fake');
    expect(client).toBeDefined();
    // Confirm no network call: fake resolves immediately
    return expect(client.generate({ prompt: 'test', modelConfig: MODEL_CONFIG }))
      .resolves.toHaveProperty('text');
  });
});
// Note: VertexGeminiClient unit test mocks @google-cloud/vertexai at the module boundary.
// Use jest.mock('@google-cloud/vertexai') and verify generateContent is called with correct params.
```

**Substitution rule:** The `VertexGeminiClient` test uses `jest.mock('@google-cloud/vertexai')` so no real Vertex API call fires in CI. The fake client tests need no mocking. Both `makeGeminiClient('fake')` and `makeGeminiClient('prod')` must be covered.

---

#### `functions/src/__tests__/rate_limit.test.ts` — NEW

**Analog:** None in-repo. Uses `@firebase/rules-unit-testing` or the Firestore emulator for transaction semantics. See RESEARCH.md §Pattern 6 for emulator setup shape.

**Core test structure:**
```typescript
// Must run with FIRESTORE_EMULATOR_HOST=localhost:8080
import { checkAndIncrement } from '../lib/rate_limit';

describe('rate_limit.checkAndIncrement', () => {
  it('allows first text message (daily + burst + monthly all clear)', async () => { ... });
  it('rejects 31st text message (daily limit 30 exhausted)', async () => {
    // Pre-seed usage doc with messageCount: 30
    // Expect HttpsError resource-exhausted, reason: 'daily'
  });
  it('counts imageCount separately from messageCount', async () => { ... });
  it('rejects 6th message in 60s window (burst limit 5)', async () => {
    // Pre-seed burstWindow with 5 Timestamps all within last 60s
    // Expect HttpsError resource-exhausted, reason: 'burst'
  });
  it('rejects when monthly ceiling reached', async () => {
    // Pre-seed /system/quota/{YYYY-MM} with calls: 10000, ceiling: 10000
    // Expect HttpsError unavailable, reason: 'monthly-ceiling'
  });
  it('premium user bypasses daily cap but is subject to burst', async () => { ... });
});
```

**Substitution rule:** Each test seeds Firestore emulator data in `beforeEach`, calls `checkAndIncrement`, and asserts the `HttpsError` code + `details.reason`. Use `afterEach` to clean up the seeded doc. Emulator must be running (`FIRESTORE_EMULATOR_HOST=localhost:8080`).

---

#### `functions/src/__tests__/idempotency.test.ts` — NEW

**Analog:** None in-repo. Verifies that a second call with the same `clientRequestId` returns the cached response without calling Gemini a second time.

**Core test pattern:**
```typescript
// Inject FakeGeminiClient; spy on generate() call count.
it('second call with same clientRequestId returns cached response (Gemini called once)', async () => {
  let callCount = 0;
  const fakeClient = {
    generate: async () => {
      callCount++;
      return { text: 'response', promptTokens: 5, completionTokens: 10 };
    },
  };
  // First call
  const first = await invokeMentorBotChat(fakeClient, { clientRequestId: 'uuid-1', ... });
  // Second call with same id
  const second = await invokeMentorBotChat(fakeClient, { clientRequestId: 'uuid-1', ... });
  expect(callCount).toBe(1);   // Gemini called exactly once
  expect(second.messageId).toBe(first.messageId);
});
```

**Substitution rule:** The test requires a helper `invokeMentorBotChat` that calls the handler logic directly (not via the Firebase SDK, to avoid App Check). Extract the handler body into a testable function that accepts a `GeminiClient` parameter.

---

#### `functions/src/__tests__/usage_log.test.ts` — NEW

**Analog:** None in-repo. Verifies `/system/usage_log/{YYYY-MM-DD}` aggregate increments correctly.

**Core test pattern:**
```typescript
// Mock db.doc().update() to capture the called arguments.
it('writes usage_log aggregate after successful Gemini call', async () => {
  const updates: Record<string, unknown>[] = [];
  // Inject spy on db.doc('system/usage_log/2026-05-19').update(...)
  // Invoke the callable handler with FakeGeminiClient
  // Assert update was called with:
  //   { calls: FieldValue.increment(1), promptTokens: FieldValue.increment(10), ... }
  expect(updates).toHaveLength(1);
  expect(updates[0]).toMatchObject({ calls: expect.anything() });
});
```

**Substitution rule:** Use `jest.spyOn` on the admin Firestore SDK's `update` method or inject a mock `db` via dependency parameter. The usage_log write is non-transactional (D-15) so it is a simple `update()` call — confirm it fires AFTER the transaction and Gemini call complete.

---

#### `functions/src/__tests__/rules.test.ts` — NEW (PR-2)

**Analog:** None in-repo. Uses `@firebase/rules-unit-testing` v5. Exact shape from RESEARCH.md §Pattern 6.

**Core test pattern** (copy from RESEARCH.md Pattern 6 lines 516–575 verbatim as the scaffold):
```typescript
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { setDoc, getDoc, doc } from 'firebase/firestore';
import fs from 'fs';

const testEnv = await initializeTestEnvironment({
  projectId: 'mentor-mind-aa765',
  firestore: {
    rules: fs.readFileSync('../../firestore.rules', 'utf8'),
    host: 'localhost',
    port: 8080,
  },
});
// Covers 5 AI-08 scenarios:
// 1. Owner can READ /users/{uid}/usage/{date}
// 2. Client CANNOT WRITE /users/{uid}/usage/{date}
// 3. Other user CANNOT READ /users/{uid}/usage/{date}
// 4. Client CANNOT READ /system/quota/{YYYY-MM}
// 5. Client CANNOT WRITE /system/quota/{YYYY-MM}
```

**Substitution rule:** Copy the full Pattern 6 test from RESEARCH.md as the starting scaffold. Add two more assertions for `/system/usage_log/{YYYY-MM-DD}` (read blocked, write blocked) to cover all three D-17 path locks. Run only with `FIRESTORE_EMULATOR_HOST=localhost:8080`.

---

#### `functions/tool/verify-model-availability.js` — NEW utility script

**Analog:** None in-repo. One-shot Node.js script; executor runs manually before PR-1 merges.

**Core script pattern** (from RESEARCH.md §Pitfall P-1):
```javascript
#!/usr/bin/env node
// Verify the pinned Gemini model is GA in asia-south1.
// Usage: node functions/tool/verify-model-availability.js
// Exit 0 = model resolves; exit 1 = "Model not found" or auth error.

const { VertexAI } = require('@google-cloud/vertexai');

async function main() {
  const model = 'gemini-2.5-pro'; // update to pinned model ID before running
  const vertexAI = new VertexAI({
    project: process.env.GCLOUD_PROJECT ?? 'mentor-mind-aa765',
    location: 'asia-south1',
  });
  const genModel = vertexAI.getGenerativeModel({ model });
  try {
    const result = await genModel.generateContent({
      contents: [{ role: 'user', parts: [{ text: 'Say "ok".' }] }],
    });
    console.log('Model resolved:', result.response.candidates?.[0]?.content?.parts?.[0]?.text);
    process.exit(0);
  } catch (err) {
    console.error('Model not found or error:', err.message);
    process.exit(1);
  }
}
main();
```

**Substitution rule:** Copy verbatim. The `model` const is the ONLY line to change — executor updates it to the target model ID, runs the script with ADC credentials (`gcloud auth application-default login`), and records the result in PR-1 description.

---

### Layer: Rules (PR-2)

---

#### `firestore.rules` — MODIFY: ADD three D-17 path locks

**Analog:** `firestore.rules` lines 77–79 (current `/users/{uid}/usage/{dateKey}` match block — the insertion/modification site)

**Current state** (lines 76–79 — REPLACE):
```
match /usage/{dateKey} {
  allow read, write: if isOwner(uid) || isAdmin();
}
```

**New state** (D-17 lock — tighter write rule):
```
match /usage/{dateKey} {
  // AI-08: client can READ own usage (to show quota remaining); Admin SDK owns writes.
  allow read: if isOwner(uid);
  allow write: if false;  // Admin SDK (Functions service account) writes via server
}
```

**New blocks to ADD** (insert before the closing `}` of `service cloud.firestore { match /databases/{database}/documents {`):
```
// -------------------------------------------------------------------------
// /system/**  — server-only quota and usage aggregates (AI-08 / D-17)
// -------------------------------------------------------------------------
match /system/{document=**} {
  allow read, write: if false;  // Admin SDK only; no client access
}
```

**Substitution rule:** Preserve all existing rules unchanged. Replace only the `match /usage/{dateKey}` block (2 lines become 3). Add the `match /system/{document=**}` block near the bottom before the closing braces. The single wildcard `{document=**}` covers `/system/quota/{YYYY-MM}` and `/system/usage_log/{YYYY-MM-DD}` with one rule.

---

### Layer: Dart Core (PR-3)

---

#### `lib/core/constants/quota.dart` — NEW utility

**Analog:** `lib/core/constants/app_colors.dart` (lines 1–15 — `abstract final class` with static consts, no imports beyond flutter)

**Imports pattern** (from app_colors.dart shape + intl package):
```dart
import 'package:intl/intl.dart';
```

**Core pattern** (mirror `abstract final class AppColors` shape):
```dart
// MIRROR: functions/src/lib/quota.ts exports QUOTA_TZ = 'Asia/Dhaka'.
// These two constants MUST stay in sync. If they diverge, quota day-keys
// differ between client and server — a student's display quota count drifts.
// Used by ChatViewModel to display remaining messages (display-only;
// actual enforcement is server-side in functions/src/lib/rate_limit.ts).

const String kQuotaTimezone = 'Asia/Dhaka';

// Returns the Dhaka calendar date key for [now], e.g. '2026-05-19'.
// Uses intl package DateFormat so timezone handling is DST-safe.
// NEVER use: DateTime.now().toIso8601String().substring(0, 10)  ← UTC only.
String dhakaDateKey(DateTime now) {
  // intl DateFormat.yMd() with explicit locale gives 'en_CA' ISO format.
  return DateFormat('yyyy-MM-dd', 'en').format(
    now.toUtc().add(const Duration(hours: 6)),  // UTC+6 fixed offset (Dhaka has no DST)
  );
}
```

**Substitution rule:** Do NOT use `abstract final class` — these are module-level constants and functions, not a namespace class (unlike `AppColors` which uses `static const`). Use top-level `const` and top-level functions per Dart convention for utility files. Note: `intl` is already a dependency (`pubspec.yaml` line 44). No new dep needed.

---

### Layer: Dart Data (PR-3)

---

#### `lib/data/models/mentor_bot_response.dart` — NEW model

**Analog:** `lib/data/models/ping_response.dart` (lines 1–26 — exact shape)

**Core pattern** (copy `PingResponse.fromMap` shape, change fields):
```dart
// ---------------------------------------------------------------------------
// MentorBotResponse — decoded response from the `mentorBotChat` callable.
// Server returns: { text, promptTokens, completionTokens, messageId, createdAt }
// All fields use safe-cast `as T? ?? default` (Phase 1 model convention).
// ---------------------------------------------------------------------------

class MentorBotResponse {
  const MentorBotResponse({
    required this.text,
    required this.promptTokens,
    required this.completionTokens,
    required this.messageId,
    required this.createdAt,
  });

  final String text;
  final int promptTokens;
  final int completionTokens;
  final String messageId;
  final DateTime createdAt;

  factory MentorBotResponse.fromMap(Map<String, dynamic> map) {
    return MentorBotResponse(
      text: (map['text'] as String?) ?? '',
      promptTokens: (map['promptTokens'] as num?)?.toInt() ?? 0,
      completionTokens: (map['completionTokens'] as num?)?.toInt() ?? 0,
      messageId: (map['messageId'] as String?) ?? '',
      createdAt: map['createdAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
    );
  }
}
```

**Substitution rule:** Mirror `PingResponse.fromMap` exactly — `as T? ?? default` on every field, never bare `as`. The `createdAt` field is an epoch-ms int from the callable (Firestore `Timestamp` is serialised to millis by the Functions SDK for callable responses). No `toMap()` needed — this is a read-only response model.

---

#### `lib/data/repositories/mentor_bot_repository.dart` — NEW repository

**Analog:** `lib/data/repositories/ping_repository.dart` (lines 1–39 — exact shape)

**Imports pattern** (lines 1–7, mirror ping_repository.dart):
```dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/data/models/mentor_bot_response.dart';
import 'package:mentor_minds/data/services/firebase_functions_provider.dart';
```

**Core CRUD pattern** (from RESEARCH.md §Pattern 5 — adapted):
```dart
class MentorBotRepository {
  MentorBotRepository({required FirebaseFunctions functions})
      : _functions = functions;

  final FirebaseFunctions _functions;

  Future<MentorBotResponse> sendMessage({
    required String sessionId,
    required String clientRequestId,
    required String message,
    String? imageUrl,
    String? subject,
    String? level,
  }) async {
    final result = await _functions
        .httpsCallable('mentorBotChat')
        .call<dynamic>({
          'sessionId': sessionId,
          'clientRequestId': clientRequestId,
          'message': message,
          if (imageUrl != null) 'imageUrl': imageUrl,
          if (subject != null) 'subject': subject,
          if (level != null) 'level': level,
        });
    // REQUIRED cast: callable returns Map<Object?, Object?> at runtime
    // (Phase 2 D-PATTERNS / ping_repository.dart line 26)
    final data = (result.data as Map<Object?, Object?>).cast<String, dynamic>();
    return MentorBotResponse.fromMap(data);
  }
}

final mentorBotRepositoryProvider = Provider<MentorBotRepository>((ref) {
  return MentorBotRepository(functions: ref.read(firebaseFunctionsProvider));
});
```

**Substitution rule:** Copy `PingRepository` structure verbatim — same constructor pattern, same `httpsCallable().call()` call, same `(result.data as Map<Object?, Object?>).cast<String, dynamic>()` cast, same provider at bottom. Change: callable name `'ping'` → `'mentorBotChat'`, return type `PingResponse` → `MentorBotResponse`, add the 6 named parameters to `.call()`. The `cloud_functions` import is confined to `lib/data/` per `custom_lint` `layered_imports` rule.

---

### Layer: Dart Presentation (PR-3)

---

#### `lib/application/viewmodels/tutor/chat_viewmodel.dart` — MODIFY

**Analog:** itself at `/Users/arnobrizwan/Mentor-Mind/lib/application/viewmodels/tutor/chat_viewmodel.dart` (full file, 493 lines — read above)

**Current `_gemini` field** (line 120 — the swap target):
```dart
final GeminiService _gemini;
```

**Replace with:**
```dart
final MentorBotRepository _mentorBotRepository;
```

**Current streaming block** (lines 286–296 — DELETE entirely):
```dart
// DELETE this entire async* block from the else branch:
final buffer = StringBuffer();
await for (final chunk in _gemini.sendMessage(
  text: trimmed,
  subject: state.selectedSubject,
  level: state.selectedLevel,
)) {
  buffer.write(chunk);
  _updateMessage(aiPlaceholder.id, content: buffer.toString());
}
finalText = buffer.toString();
_updateMessage(aiPlaceholder.id, isStreaming: false);
```

**Replace with (Future-based, from RESEARCH.md Anti-Patterns §isStreaming note):**
```dart
// isStreaming flag STAYS in ChatState — drives typing indicator.
// Now means "awaiting the Future" rather than "consuming a Stream".
final response = await _mentorBotRepository.sendMessage(
  sessionId: state.sessionId ?? const Uuid().v4(),
  clientRequestId: clientRequestId,  // pre-generated before appending userMsg
  message: trimmed,
  subject: state.selectedSubject,
  level: state.selectedLevel,
);
finalText = response.text;
_updateMessage(aiPlaceholder.id, content: finalText, isStreaming: false);
```

**Provider block** (lines 477–493 — replace `geminiServiceProvider` + update `chatViewModelProvider`):
```dart
// DELETE: geminiServiceProvider (lines 477–481)
// MODIFY chatViewModelProvider to inject MentorBotRepository instead of GeminiService:
final chatViewModelProvider =
    StateNotifierProvider.autoDispose<ChatViewModel, ChatState>((ref) {
  return ChatViewModel(
    ref.read(mentorBotRepositoryProvider),   // ← swapped
    ref.read(authRepositoryProvider),
    ref.read(usersRepositoryProvider),
    ref.read(sessionsRepositoryProvider),
    ref.read(storageRepositoryProvider),
  );
});
```

**Items to REMOVE from chat_viewmodel.dart:**
- Import `package:mentor_minds/core/services/gemini_service.dart` (line 7)
- `final GeminiService _gemini` field (line 120)
- `_gemini.resetSession()` call in `newChat()` (line 194)
- `_gemini.resetSession()` call in `loadSession()` (line 392)
- `_gemini.analyzeImage(...)` call and its `await` block (lines 275–283)
- The `async* / await for` streaming block in `sendMessage` else-branch (lines 286–296)
- `geminiServiceProvider` provider declaration (lines 477–481)
- `_todayKey()` static helper (lines 461–465) — replaced by `dhakaDateKey()` from `quota.dart`
- `_genId()` helper (lines 467–470) — replaced by `const Uuid().v4()`

**Items to ADD to chat_viewmodel.dart:**
- Import `package:mentor_minds/data/repositories/mentor_bot_repository.dart`
- Import `package:mentor_minds/core/constants/quota.dart`
- Import `package:uuid/uuid.dart`
- Field `final MentorBotRepository _mentorBotRepository`
- `clientRequestId` generation: `final clientRequestId = const Uuid().v4();` before appending `userMsg`
- `sessionId` generation for first message: `state.sessionId ?? const Uuid().v4()`

**Substitution rule:** This is an atomic swap — the `sendMessage` method signature, `ChatState`, `copyWith`, all other helpers (`selectSubject`, `toggleLevel`, `setFeedback`, `_saveSession`, `loadSession`, `_incrementUsage`, `_awardPoints`, `_updateMessage`) stay unchanged. Only the Gemini-touching lines change. The `isStreaming` flag in `ChatState` is preserved (drives typing indicator — see RESEARCH.md Anti-Patterns §isStreaming).

---

#### `lib/core/services/gemini_service.dart` — DELETE in PR-3

**Current content:** 139 lines (read above lines 1–139). Contains `GeminiService` class + `_kSystemPrompt` const.

**Extract before deleting:**
- Copy `_kSystemPrompt` text (lines 16–31) → becomes `SYSTEM_PROMPT` const in `functions/src/lib/gemini.ts`.

**Deletion command:** `git rm lib/core/services/gemini_service.dart`

**Substitution rule:** No replacement file. The `geminiServiceProvider` in `chat_viewmodel.dart` is also deleted. After deletion, run `flutter analyze --no-fatal-infos` to confirm zero dangling references before committing.

---

### Layer: Configs and Docs

---

#### `pubspec.yaml` — MODIFY

**Analog:** `pubspec.yaml` lines 1–60 (Phase 2 state, read above)

**Remove** (line 47):
```yaml
  google_generative_ai: ^0.4.6
```

**Add** (alphabetical in dependencies block, between `image_picker` and `intl`):
```yaml
  uuid: ^4.5.3
```

**Substitution rule:** The dependencies block after modification should have `uuid: ^4.5.3` inserted alphabetically (u comes after s for `shared_preferences`, before nothing). `google_generative_ai` line is deleted. Run `flutter pub get` after the edit. The `riverpod_annotation` and `injectable` entries are not touched.

---

#### `integration_test/mentor_bot_smoke_test.dart` — NEW

**Analog:** `integration_test/ping_smoke_test.dart` (lines 1–85 — exact structural match)

**Imports pattern** (mirror ping_smoke_test.dart lines 30–39):
```dart
@Tags(<String>['emulator', 'integration'])
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mentor_minds/data/repositories/mentor_bot_repository.dart';
import 'package:mentor_minds/firebase_options.dart';
import 'package:uuid/uuid.dart';

import '../test/_helpers/emulator_setup.dart';
```

**Core test pattern** (mirror ping_smoke_test.dart `testWidgets` shape):
```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MentorBotRepository repo;
  final sessionId = const Uuid().v4();
  final clientRequestId = const Uuid().v4();

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await configureEmulators();
    // Functions emulator uses GEMINI_CLIENT_MODE=fake — no real Vertex calls.
    final container = ProviderContainer();
    repo = container.read(mentorBotRepositoryProvider);
  });

  testWidgets('mentor_bot smoke — 5-field response shape', (tester) async {
    final stopwatch = Stopwatch()..start();
    final response = await repo.sendMessage(
      sessionId: sessionId, clientRequestId: clientRequestId, message: 'Hello',
    );
    stopwatch.stop();
    expect(response.text, isNotEmpty);
    expect(response.messageId, isNotEmpty);
    expect(response.promptTokens, greaterThanOrEqualTo(0));
    expect(response.completionTokens, greaterThanOrEqualTo(0));
    expect(stopwatch.elapsedMilliseconds, lessThan(5000));
  }, tags: ['emulator', 'integration']);

  testWidgets('mentor_bot idempotency — same clientRequestId returns same messageId', (tester) async {
    final first = await repo.sendMessage(
      sessionId: sessionId, clientRequestId: clientRequestId, message: 'Retry',
    );
    final second = await repo.sendMessage(
      sessionId: sessionId, clientRequestId: clientRequestId, message: 'Retry',
    );
    expect(second.messageId, equals(first.messageId));
  }, tags: ['emulator', 'integration']);
}
```

**Substitution rule:** Mirror `ping_smoke_test.dart` completely — same `@Tags`, same `setUpAll`, same `testWidgets` structure, same `configureEmulators()` call. Replace `FirebaseFunctions.instance.httpsCallable('ping').call()` with `repo.sendMessage(...)`. Add the second idempotency test (no analog in ping test — it is Phase 3-specific).

---

#### `.vscode/launch.json` — MODIFY if file exists (currently absent)

**Analog:** File does not exist at `/Users/arnobrizwan/Mentor-Mind/.vscode/`. If it exists at execute time (created during Phase 3 setup), the executor must remove any line containing `--dart-define=GEMINI_API_KEY`.

**Grep command to confirm scope:**
```bash
grep -rE 'GEMINI_API_KEY' .vscode/ .github/workflows/ci.yml README.md BACKEND_SETUP.md 2>/dev/null
```

**Substitution rule:** If the file exists, delete only the `--dart-define=GEMINI_API_KEY=...` argument from any `args` array. If the file does not exist, no action needed. Same removal applies to any `Makefile` or shell scripts found by the grep above.

---

#### `README.md` — MODIFY

**Analog:** `BACKEND_SETUP.md` §Phase 2 run instructions for `--dart-define` usage pattern.

**Find and remove** any block matching:
```
--dart-define=GEMINI_API_KEY=<your-key>
```

**Replace with:**
```
# No API key needed — Gemini calls are proxied via Cloud Functions + Vertex AI (ADC).
# See BACKEND_SETUP.md §Phase 3 for setup.
flutter run
```

**Substitution rule:** Grep README.md for `GEMINI_API_KEY` and delete the entire line (or the `--dart-define` argument if it is part of a multi-argument `flutter run` invocation). Add one-line note pointing to BACKEND_SETUP.md Phase 3 section.

---

#### `BACKEND_SETUP.md` — MODIFY: APPEND Phase 3 section

**Analog:** `BACKEND_SETUP.md` lines 190–259 — `## Phase 2 — Cloud Functions + App Check Setup` section. Mirror its heading level, subsection structure (`### N. Step name`), and gcloud command formatting.

**New section structure to append:**
```markdown
## Phase 3 — Vertex AI + Key Rotation

> Solo dev runs these commands ONCE manually. Each step is idempotent where noted.

### 1. Enable Vertex AI API

```bash
gcloud services enable aiplatform.googleapis.com --project=mentor-mind-aa765
```

### 2. Grant Functions service account `roles/aiplatform.user`

```bash
# Discover your Functions service account (created on first deploy):
gcloud iam service-accounts list --project=mentor-mind-aa765

# Grant the role (replace SA_EMAIL with the actual SA from above):
gcloud projects add-iam-policy-binding mentor-mind-aa765 \
  --member="serviceAccount:SA_EMAIL" \
  --role="roles/aiplatform.user"
```

### 3. Raise billing budget alert to $75/mo

Vertex AI Pro × 10,000 calls/month ≈ $52/mo. Raise the Phase 2 $10 alert.

```bash
# Update existing budget (NOT idempotent — update, don't create):
gcloud billing budgets update BUDGET_ID \
  --billing-account=0121EC-5D572E-57FEE1 \
  --budget-amount=75USD
```

### 4. Revoke the leaked Google AI Studio key (BEFORE PR-3 merges)

1. Open https://aistudio.google.com/apikey
2. Find the key previously used as `GEMINI_API_KEY`
3. Click **Revoke** — the key is now dead (no git scrub needed; revoked = harmless)
4. Confirm no other system uses this key

### 5. `MONTHLY_CALL_CEILING` env-var tunable

Default: 10,000 calls/month. To adjust without redeploying logic:

```bash
firebase functions:config:set monthly_call_ceiling=5000
firebase deploy --only functions:mentorBotChat
```

Or via Firebase Console → Functions → mentorBotChat → Edit → Environment variables.
```

**Substitution rule:** Append after the last line of the existing `## Phase 2` section. Do not modify any existing content. Mirror the exact heading depth (`##` for phase, `###` for steps) from the Phase 2 section.

---

#### `.github/workflows/ci.yml` — MODIFY: ADD `npm test` step in `functions:` job

**Analog:** `.github/workflows/ci.yml` lines 116–118 — existing `Lint + build TypeScript` step (the step immediately before which `npm test` is added after)

**Current last step in `functions:` job** (lines 116–118):
```yaml
      - name: Lint + build TypeScript
        if: steps.filter.outputs.functions == 'true'
        run: cd functions && npm run lint && npm run build
```

**ADD after** (new step):
```yaml
      - name: Run TypeScript unit tests (Jest)
        if: steps.filter.outputs.functions == 'true'
        run: cd functions && npm test
```

**Substitution rule:** Insert the new step AFTER the `Lint + build TypeScript` step (not before — tests run on the compiled output). Keep the same `if:` guard so the step only fires on `functions/**` changes. No environment variable override needed — unit tests use `makeGeminiClient('fake')` automatically when `GEMINI_CLIENT_MODE=fake` is absent (the default in CI). Rules tests that require `FIRESTORE_EMULATOR_HOST` are NOT added to CI in Phase 3 (emulator startup adds complexity; deferred to Phase 5 CI hardening).

---

## Shared Patterns

### `(result.data as Map<Object?, Object?>).cast<String, dynamic>()` cast
**Source:** `lib/data/repositories/ping_repository.dart` lines 26–27
**Apply to:** `lib/data/repositories/mentor_bot_repository.dart`
```dart
final data = (result.data as Map<Object?, Object?>).cast<String, dynamic>();
```
This cast is mandatory — the Firebase Functions SDK returns `Map<Object?, Object?>` at runtime even though the type parameter is `dynamic`.

---

### `HttpsError` factory wrappers
**Source:** `functions/src/lib/errors.ts` lines 1–27
**Apply to:** `functions/src/index.ts`, `functions/src/lib/rate_limit.ts`
```typescript
import { unauthenticated, internal, mapKnownError } from './lib/errors';
// Usage: throw unauthenticated('Authentication required');
//        throw internal('Gemini call failed');
```
Never use `new HttpsError(...)` directly — always go through the factory.

---

### `if (!mounted) return;` post-await guard
**Source:** `lib/application/viewmodels/tutor/chat_viewmodel.dart` `_updateMessage` line 448
**Apply to:** `chat_viewmodel.dart` sendMessage method — every state mutation after `await repo.sendMessage(...)` must check `if (!mounted) return;`

---

### `firebaseFunctionsProvider` seam
**Source:** `lib/data/services/firebase_functions_provider.dart` lines 16–18
**Apply to:** `lib/data/repositories/mentor_bot_repository.dart`
```dart
final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  return FirebaseFunctions.instanceFor(region: 'asia-south1');
});
```
`MentorBotRepository` receives `FirebaseFunctions` via constructor injection from this provider — same as `PingRepository`.

---

### `onCall` callable shape
**Source:** `functions/src/index.ts` lines 2–15 (`ping` export)
**Apply to:** `functions/src/index.ts` `mentorBotChat` export
```typescript
export const ping = onCall(
  { region: 'asia-south1', enforceAppCheck: true },
  (_request) => { ... }
);
```
`mentorBotChat` adds `timeoutSeconds` and `memory` to the options object but otherwise mirrors this exact shape.

---

### Transaction-first state mutations
**Source:** RESEARCH.md §Pattern 3; PITFALLS #4
**Apply to:** `functions/src/lib/rate_limit.ts`, `functions/src/index.ts` handler
```typescript
// ALL reads must come before ALL writes inside runTransaction.
// Gemini call happens AFTER db.runTransaction(...) resolves.
const result = await db.runTransaction(async (tx) => { ... });
const geminiResult = await geminiClient.generate({ ... }); // AFTER tx commits
```

---

## No Analog Found (Canonical Skeletons from RESEARCH.md)

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `functions/src/lib/quota.ts` | utility | transform | No utility helpers exist in TS codebase yet |
| `functions/jest.config.js` | config | — | No Jest config exists in repo |
| `functions/src/__tests__/quota.test.ts` | test | — | No test files exist in `functions/src/__tests__/` yet |
| `functions/src/__tests__/rate_limit.test.ts` | test | — | Same — first test file in functions |
| `functions/src/__tests__/gemini.test.ts` | test | — | Same |
| `functions/src/__tests__/idempotency.test.ts` | test | — | Same |
| `functions/src/__tests__/usage_log.test.ts` | test | — | Same |
| `functions/src/__tests__/rules.test.ts` | test (rules) | — | Same |
| `functions/tool/verify-model-availability.js` | utility script | — | No tooling scripts exist under `functions/tool/` |

For all of the above, the planner should use the canonical skeletons from `03-RESEARCH.md` §Code Examples (Patterns 1–7) as the reference rather than any in-repo file.

---

## Metadata

**Analog search scope:** `functions/src/`, `lib/data/`, `lib/core/`, `lib/application/`, `integration_test/`, `.github/workflows/`, root config files
**Files scanned:** 18 source files read directly
**Key paths verified:**
- `chat_viewmodel.dart` confirmed at `lib/application/viewmodels/tutor/chat_viewmodel.dart` (Phase 1 D-02 refactor path)
- `.vscode/launch.json` does NOT exist in repo at mapping time — executor verifies before PR-3
- `functions/src/__tests__/` directory does NOT exist yet — Wave 0 creates it

---

## PATTERN MAPPING COMPLETE

**Phase:** 03 — Gemini Proxy + Server-Side Rate Limiting
**Files classified:** 25
**Analogs found:** 16 exact/role-match / 25 total (9 use RESEARCH.md canonical skeletons)

### Coverage
- Files with exact or fill-stub analog: 9
- Files with role-match analog: 7
- Files with no analog (RESEARCH.md skeleton used): 9

### Key Patterns Identified
- All TS callables use `onCall({region: 'asia-south1', enforceAppCheck: true}, handler)` — `ping` is the exact template
- All Dart repositories use `httpsCallable('NAME').call()` + `(result.data as Map<Object?, Object?>).cast<String, dynamic>()` + `fromMap` decoded model — `PingRepository` is the exact template
- All TS error construction goes through `functions/src/lib/errors.ts` factory wrappers — never `new HttpsError(...)` directly
- TypeScript transaction pattern: reads-first → Gemini-outside-tx → assistant-write-after; never Gemini inside `runTransaction`
- `quota.ts` / `quota.dart` are a mirrored pair — both must export the same `'Asia/Dhaka'` timezone string to prevent PITFALL #3

### File Created
`/Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-PATTERNS.md`

### Ready for Planning
Pattern mapping complete. Planner can now reference analog patterns in PLAN.md files.
