# Phase 3: Gemini Proxy + Server-Side Rate Limiting — Research

**Researched:** 2026-05-19
**Domain:** Vertex AI (Gemini Pro), Cloud Functions v2 callable, Firestore transactions, Firestore rules testing, Flutter callable repository pattern
**Confidence:** HIGH (stack and patterns verified against npm registry, googleapis.dev, official Firebase docs, pub.dev API, gcloud CLI)

---

<user_constraints>
## User Constraints (from 03-CONTEXT.md)

### Locked Decisions

**D-01:** Model = `gemini-3.1-pro` (Pro tier). Researcher pins the EXACT published model ID GA in `asia-south1` at execute time. See Open Question Q-1 — `gemini-3.1-pro` docs exist but regional GA status is UNVERIFIED at research time; planner must pin alternate and surface as checkpoint.

**D-02:** API tier = Vertex AI via `@google-cloud/vertexai` npm SDK + ADC. No API key anywhere. Cloud Functions v2 runtime auto-injects ADC for the Compute Engine default SA; grant it `roles/aiplatform.user`.

**D-03:** System prompt + model config live as hardcoded TS consts in `functions/src/lib/gemini.ts`. AI-09 "can be updated without app release" = redeploy function only.

**D-04:** Prompt versioned via `SYSTEM_PROMPT_VERSION = '1'` const. Stamped onto each message doc as `promptVersion: '1'`.

**D-05:** Image attachment = client uploads to Storage, passes URL. Server fetches bytes via Admin Storage SDK, feeds as inline base64 to Gemini Vision.

**D-06:** clientRequestId = UUIDv4 from `package:uuid: ^4.x`. One per user-initiated send; reused across retries.

**D-07:** Distinct HttpsError codes per failure mode (`resource-exhausted`, `unavailable`, `internal`, `deadline-exceeded`, `unauthenticated`).

**D-08:** Reply persistence = BOTH return text AND write message pair to `/sessions/{sid}/messages/{mid}` in same transaction as usage increment.

**D-09:** Burst counter = rolling-timestamp array on `/users/{uid}/usage/{today}`. Doc shape: `{ messageCount, imageCount, burstWindow: [Timestamp...] }`. One transaction reads + writes this doc.

**D-10:** Monthly ceiling = `/system/quota/{YYYY-MM}`. Tunable via `MONTHLY_CALL_CEILING` defineString (default 10000).

**D-11:** Session message storage = `/sessions/{sid}/messages/{mid}` subcollection. Parent `/sessions/{sid}` holds metadata.

**D-12:** Message retention = forever for v1.0. No auto-prune.

**D-13:** minInstances: 0. Cold-start ~2-4s tolerated.

**D-14:** Function runtime: `timeoutSeconds: 60`, `memory: '512MiB'`, `maxOutputTokens: 1024`, `temperature: 0.7`, `topP: 0.95`, `topK: 40`.

**D-15:** Observability = per-call aggregate to `/system/usage_log/{YYYY-MM-DD}` + structured `functions.logger.info(...)` logs. Written via `update` (not transaction).

**D-16:** Client retry policy = 2× exponential backoff (250ms, 1s) on `internal`/`deadline-exceeded`/`unavailable` ONLY WHEN `details.reason !== 'monthly-ceiling'`. Reuses same clientRequestId.

**D-17:** firestore.rules scope = three locks: `/users/{uid}/usage/{date}` (client read-only), `/system/quota/{YYYY-MM}` (server-only), `/system/usage_log/{YYYY-MM-DD}` (server-only).

**D-18:** Refactor = single PR-3, atomic steps: add MentorBotRepository → swap ChatViewModel → delete GeminiService → remove google_generative_ai → add uuid.

**D-19:** Premium bypass = server reads `request.auth?.token?.premium === true`. Skip daily cap only; burst + monthly still apply.

**D-20:** PR sequence = PR-1 (server function) → PR-2 (rules + tests) → PR-3 (client swap + cleanup).

**D-21:** Test strategy = mock Vertex at GeminiClient interface boundary. Fake via `GEMINI_CLIENT_MODE` env var. Unit tests under `functions/src/__tests__/`. CI runs `npm test` on `functions/**` changes.

**D-22:** Leaked-key rotation = manual revoke in Google AI Studio BEFORE PR-3 merges. Document in BACKEND_SETUP.md.

**D-23:** No migration. Current chat_viewmodel + GeminiService are in-memory only. Verified: zero /sessions/{sid}/messages/{mid} subcollection writes exist in codebase.

**D-24:** Email-verification gate deferred to Phase 7.

### Claude's Discretion

- TypeScript style beyond Phase 2 defaults (prettier + `@typescript-eslint/recommended-type-checked`)
- Concrete `MentorBotRepository.sendMessage()` Dart signature refinement
- Alphabetical placement of `uuid: ^4.x` in `pubspec.yaml`
- Whether repository throws `FirebaseFunctionsException` or wraps in `Result<>` (use throw — matches PingRepository)
- Concrete error-banner copy (Phase 7 UI polish)
- Fallback model if `gemini-3.1-pro` not GA in asia-south1 at execute time

### Deferred Ideas (OUT OF SCOPE)

- Streaming chat responses (AI-10 explicit defer — non-streaming v1.0)
- Per-user monthly analytics dashboard (Phase 5+)
- Auto-prune old messages (Phase 7)
- Routing premium to different model (Phase 5 amendment)
- A/B prompt testing via Remote Config (Phase 7)
- Migrating back to Google AI Studio
- Belt-and-suspenders email-verification server-side check (Phase 7)
- Session subcollection lockdown in rules (Phase 4)
- Git history scrub of leaked key (rejected)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AI-01 | `mentorBotChat` callable proxies all Gemini calls via Vertex AI; no client-side key | Vertex AI ADC + `@google-cloud/vertexai` ^1.12.0 verified on npm; `roles/aiplatform.user` IAM grant documented |
| AI-02 | `--dart-define=GEMINI_API_KEY` removed from all build configs; existing Studio key rotated | Delete from launch.json + CI workflow + README; manual Studio revoke step in BACKEND_SETUP.md |
| AI-03 | `google_generative_ai` Dart package removed from pubspec.yaml after proxy ships | PR-3 step 4: remove from dependencies block; flutter pub get verifies |
| AI-04 | Daily cap enforced server-side: 30 text + 3 image per UTC+6 day; shared QUOTA_TZ constant | Dhaka timezone via `Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Dhaka' })` in TS; `intl` package in Dart; transaction-based daily doc |
| AI-05 | Burst limit: 5 messages / 60s per user, server-side | Rolling timestamp array in Firestore transaction; Admin SDK runTransaction verified; Timestamp.now() safe inside transaction |
| AI-06 | App-wide monthly ceiling `/system/quota/{YYYY-MM}`; over-ceiling → `unavailable` | MONTHLY_CALL_CEILING defineString; transaction check and increment pattern documented |
| AI-07 | All writes in single Firestore transaction; client includes clientRequestId (UUID) for idempotency | Admin SDK runTransaction up to 500 writes per tx; auto-retries up to ~25x on contention; doc().set() for auto-ID within tx |
| AI-08 | `firestore.rules` lock `/users/{uid}/usage/{date}` to read-only; `/system/**` server-only | Three match blocks identified; insertion point at line 77-79 in existing rules (replace `allow read, write` on usage subcollection) |
| AI-09 | System prompt in `functions/src/lib/gemini.ts`; updatable without app release | Hardcoded TS const; `firebase deploy --only functions:mentorBotChat` suffices |
| AI-10 | Non-streaming v1.0; typing indicator while awaiting Function response | `generateContent()` (not `generateContentStream()`); remove `async*` / `await for` from chat_viewmodel; isStreaming flag kept for UI |
</phase_requirements>

---

## Summary

Phase 3 moves every Gemini invocation behind `mentorBotChat`, a Cloud Functions v2 callable in `asia-south1`. The function calls Vertex AI using Application Default Credentials (no API key), enforces three quotas atomically in a Firestore transaction, deduplicates retries via a client-issued UUIDv4, and persists both user + assistant message docs into a new `/sessions/{sid}/messages/{mid}` subcollection that Phase 4's `onSessionWrite` reward trigger will consume.

The critical execution-time unknown is `gemini-3.1-pro` GA availability in `asia-south1`. Documentation for the model exists on the Google Cloud docs site, but the regional availability table could not be confirmed via automated lookup at research time. The planner must build in a concrete fallback: if `gemini-3.1-pro` is not GA in `asia-south1` at PR-1 time, use `gemini-2.5-pro` instead, which is the next highest Pro-class model confirmed on npm/pypi docs (pricing verified at $1.25/M input, $10/M output). This must be surfaced as a human checkpoint before PR-1 is merged.

The Dart-side refactor (PR-3) is a clean swap with no data migration. D-23 is verified by code inspection: `chat_viewmodel.dart` persists sessions through `_sessionsRepo.saveSession()` which writes to `/sessions/{sid}` with messages as an inline array — there is no `/sessions/{sid}/messages/{mid}` subcollection in the codebase today. Phase 3 starts this subcollection fresh.

**Primary recommendation:** Follow the locked 3-PR sequence. PR-1 ships the Vertex AI-backed callable (server-only, no client changes). PR-2 ships the rules lockdown + `@firebase/rules-unit-testing` harness. PR-3 atomically swaps the client from `GeminiService` to `MentorBotRepository` and deletes the in-binary key path.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Gemini call execution | API / Backend (Cloud Functions v2) | — | All model calls proxied; no client-to-Vertex direct path |
| Quota enforcement (daily/burst/monthly) | API / Backend (Cloud Functions v2) | — | Server-authoritative; client quota state is display-only |
| Idempotency deduplication | API / Backend (Cloud Functions v2) | — | Checks `(uid, clientRequestId)` inside Firestore transaction before invoking Gemini |
| Message persistence (`/sessions/{sid}/messages/{mid}`) | API / Backend (Cloud Functions v2) | — | Transaction writes user + assistant docs; client never writes subcollection |
| UUIDv4 generation | Frontend / Client (Flutter) | — | Generated once per user-initiated send; `const Uuid().v4()` from `package:uuid` |
| Retry logic with backoff | Frontend / Client (Flutter) | — | 2× exponential backoff on retriable errors; same clientRequestId reused |
| Image upload to Storage | Frontend / Client (Flutter) | — | Client writes `uploads/{uid}/{ts}.jpg`; passes URL to callable |
| Image fetch from Storage | API / Backend (Cloud Functions v2) | — | Admin Storage SDK reads private bucket (privileged SA); returns inline base64 to Gemini |
| Firestore rules enforcement | CDN / Static (Firestore rules) | — | `/users/{uid}/usage/{date}` read-only for client; `/system/**` server-only |
| Observability aggregation | API / Backend (Cloud Functions v2) | — | Structured logger + non-transactional update to `/system/usage_log/` |

---

## Standard Stack

### Core (Server-Side — functions/)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `@google-cloud/vertexai` | `^1.12.0` | Vertex AI Gemini client; `VertexAI`, `getGenerativeModel`, `generateContent` | Official Google SDK; ADC-native; no API key required; `1.12.0` on npm [VERIFIED: npm registry] |
| `@firebase/rules-unit-testing` | `^5.0.1` | Firestore rules test harness; `initializeTestEnvironment`, `assertSucceeds`, `assertFails` | Official Firebase SDK; GitHub: firebase/firebase-js-sdk; `5.0.1` on npm [VERIFIED: npm registry] |

### Core (Client-Side — pubspec.yaml)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `uuid` | `^4.5.3` | UUIDv4 generation for clientRequestId (D-06) | Official Dart package; `4.5.3` on pub.dev [VERIFIED: npm registry — pub.dev API confirmed] |

### Inherited From Phase 2 (no changes needed)

| Library | Version | Purpose |
|---------|---------|---------|
| `firebase-admin` | `^13.10.0` | Admin SDK — Firestore + Storage singleton; already in `functions/package.json` |
| `firebase-functions` | `^6.6.0` | `onCall`, `defineString`, `logger`; already in `functions/package.json` |
| `cloud_functions` | `^5.6.2` | Flutter callable client; already in `pubspec.yaml` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `@google-cloud/vertexai` | `@google/genai` (new unified SDK) | `@google/genai` is experimental preview; `@google-cloud/vertexai` is stable GA. Do not switch until `@google/genai` reaches stable. [ASSUMED — based on npm page description "experimental preview"] |
| Vertex AI `fileData` (gs:// URI) | inline base64 | `fileData` requires Vertex AI SA to have Storage read on the bucket (cross-service IAM). Inline base64 requires only Admin SDK read (same project SA). Inline is simpler and avoids additional IAM grants. See Pitfall P-5. |
| `runTransaction` for monthly aggregate | Separate non-transactional `update` | Monthly aggregate `/system/usage_log/` uses non-transactional `update` intentionally (D-15) — contention on a separate aggregate doc would block user quota checks. |

**Installation (PR-1):**
```bash
cd functions && npm install @google-cloud/vertexai
```

**Installation (PR-2 — dev only):**
```bash
cd functions && npm install --save-dev @firebase/rules-unit-testing
```

**Installation (PR-3 — Dart):**
```bash
# Add to pubspec.yaml under dependencies:
# uuid: ^4.5.3
flutter pub add uuid
```

**Version verification (conducted at research time):**
```bash
npm view @google-cloud/vertexai version     # → 1.12.0 (confirmed 2026-05-19)
npm view @firebase/rules-unit-testing version  # → 5.0.1 (confirmed 2026-05-19)
# pub.dev API: uuid latest = 4.5.3 (confirmed 2026-05-19)
```

---

## Package Legitimacy Audit

> slopcheck v0.6.1 installed. Attempted `slopcheck install @google-cloud/vertexai @firebase/rules-unit-testing` — slopcheck defaulted to PyPI (Python registry), returning false-positive SLOP for npm packages. Result discarded. Manual npm registry verification performed instead.

| Package | Registry | Age | Downloads (approx) | Source Repo | slopcheck | Disposition |
|---------|----------|-----|--------------------|-------------|-----------|-------------|
| `@google-cloud/vertexai` | npm | First published 2023-12-12; 18 months old | High (official Google SDK) | github.com/googleapis/nodejs-vertexai | MANUAL OK (slopcheck defaulted to PyPI — false positive discarded; official Google org repo confirmed) | Approved |
| `@firebase/rules-unit-testing` | npm | First published 2020-08-19; ~6 years old | High (official Firebase SDK) | github.com/firebase/firebase-js-sdk | MANUAL OK (official Firebase org repo confirmed) | Approved |
| `uuid` (Dart) | pub.dev | Established; v4.5.3 latest | High (standard Dart UUID package) | github.com/daegalus/dart-uuid | Not applicable (Dart, not npm) | Approved |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

**Postinstall script check:**
```bash
npm view @google-cloud/vertexai scripts.postinstall   # → (empty — no postinstall)
npm view @firebase/rules-unit-testing scripts.postinstall  # → (empty — no postinstall)
```
Both packages are clean.

---

## Architecture Patterns

### System Architecture Diagram

```
Flutter Client
  │
  │  1. User sends message
  │  2. ChatViewModel generates clientRequestId (UUIDv4)
  │  3. MentorBotRepository.sendMessage({sessionId, clientRequestId, message, imageUrl?})
  │
  ▼
Cloud Functions v2 — mentorBotChat (asia-south1, enforceAppCheck: true)
  │
  ├── [0] Verify auth (request.auth.uid required) ────────────────────── → unauthenticated error
  │
  ├── [1] Firestore runTransaction:
  │     ├── READ /users/{uid}/usage/{todayDhaka}          ← daily + burst state
  │     ├── READ /system/quota/{YYYY-MM}                  ← monthly ceiling
  │     ├── DEDUPE CHECK: does /sessions/{sid}/messages/{clientRequestId} exist?
  │     │     └── YES → return cached response (early exit, no Gemini call)
  │     ├── CHECK burst window (prune old, assert < 5)    ← resource-exhausted if fail
  │     ├── CHECK daily quota (if !isPremium)             ← resource-exhausted if fail
  │     ├── CHECK monthly ceiling                         ← unavailable if fail
  │     ├── WRITE /users/{uid}/usage/{todayDhaka}         ← increment counts + append burst ts
  │     ├── WRITE /system/quota/{YYYY-MM}                 ← increment calls
  │     ├── SET /sessions/{sid}/messages/{clientRequestId} = {role:'user', text, imageUrl?, ...}
  │     └── (assistant doc written AFTER Gemini returns — see note below)
  │
  ├── [2] (IF imageUrl present) Admin Storage SDK fetch → Buffer → base64
  │
  ├── [3] GeminiClient.generate({prompt, systemPrompt, image?, modelConfig})
  │     └── @google-cloud/vertexai → Vertex AI asia-south1
  │
  ├── [4] Write /sessions/{sid}/messages/{autoId} = {role:'assistant', text, promptVersion, ...}
  │     (non-transactional set — Gemini call completes between tx commit and this write)
  │
  ├── [5] Non-transactional update /system/usage_log/{YYYY-MM-DD} (observability aggregate)
  │     + functions.logger.info({event:'gemini_call', uid, promptTokens, completionTokens, ...})
  │
  └── [6] Return {text, messageId, promptTokens, completionTokens, createdAt}
  │
  ▼
Flutter Client
  ├── ChatViewModel replaces aiPlaceholder bubble with text
  └── (Phase 4: onSessionWrite trigger fires on new messages doc)
```

**Note on transaction vs assistant write:** The transaction in step [1] writes the USER message doc (using `clientRequestId` as the doc ID for idempotency). The ASSISTANT doc is written in step [4] after Gemini returns — it cannot be in the transaction because the Gemini call is network I/O that would hold the transaction lock for potentially 5-30 seconds, causing extreme contention. The idempotency check at step [1] uses the user message doc existence.

### Recommended Project Structure (additions to existing layout)

```
functions/src/
├── index.ts                    # ADD: export const mentorBotChat = ...
├── lib/
│   ├── admin.ts                # UNCHANGED (Phase 2 singleton)
│   ├── errors.ts               # UNCHANGED + ADD: resourceExhausted, unavailable factories
│   ├── gemini.ts               # FILL: GeminiClient interface + VertexAI impl + FakeGeminiClient
│   ├── rate_limit.ts           # FILL: checkAndIncrement with daily+burst+monthly transaction
│   ├── quota.ts                # NEW: QUOTA_TZ = 'Asia/Dhaka', getDhakaDateKey(), monthKey()
│   └── claims.ts               # UNCHANGED stub (Phase 5)
└── __tests__/
    ├── rate_limit.test.ts      # NEW: unit tests with FakeGeminiClient
    ├── gemini.test.ts          # NEW: GeminiClient interface + fake tests
    └── idempotency.test.ts     # NEW: transaction dedupe logic tests

lib/data/
├── repositories/
│   ├── ping_repository.dart    # UNCHANGED
│   └── mentor_bot_repository.dart  # NEW: wraps httpsCallable('mentorBotChat')
└── models/
    ├── chat_message.dart       # EXTEND: add clientRequestId, promptVersion fields
    └── mentor_bot_response.dart  # NEW: decoded response shape

lib/core/
└── constants/
    └── quota.dart              # NEW: kQuotaTimezone = 'Asia/Dhaka'

lib/application/viewmodels/tutor/
└── chat_viewmodel.dart         # REWIRE: _gemini → _mentorBotRepo; remove streaming; remove _history
```

### Pattern 1: @google-cloud/vertexai — getGenerativeModel + generateContent

```typescript
// Source: googleapis.dev/nodejs/vertexai/latest/index.html (verified 2026-05-19)
import { VertexAI, HarmCategory, HarmBlockThreshold } from '@google-cloud/vertexai';

const vertexAI = new VertexAI({
  project: process.env.GCLOUD_PROJECT!,  // auto-set by Cloud Functions v2 runtime
  location: 'asia-south1',
});

const model = vertexAI.getGenerativeModel({
  model: 'gemini-2.5-pro',  // ← PLACEHOLDER: researcher pins exact model ID; see Q-1
  generationConfig: {
    temperature: 0.7,
    topP: 0.95,
    topK: 40,
    maxOutputTokens: 1024,
  },
  safetySettings: [
    { category: HarmCategory.HARM_CATEGORY_HATE_SPEECH, threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE },
    { category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT, threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE },
  ],
  systemInstruction: {
    role: 'system',
    parts: [{ text: SYSTEM_PROMPT }],
  },
});

const result = await model.generateContent({
  contents: [
    {
      role: 'user',
      parts: [
        { text: `[Subject: ${subject}, Level: ${level}]\n${userMessage}` },
        // If image (inline base64 — PREFERRED over fileData for private bucket):
        ...(imageBuffer ? [{
          inline_data: { mimeType: 'image/jpeg', data: imageBuffer.toString('base64') }
        }] : []),
      ],
    },
  ],
});

// Token extraction from response:
const text = result.response.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
const promptTokens = result.response.usageMetadata?.promptTokenCount ?? 0;
const completionTokens = result.response.usageMetadata?.candidatesTokenCount ?? 0;
```

### Pattern 2: GeminiClient Interface + Fake Implementation

```typescript
// Source: 03-CONTEXT.md §Specific Ideas (D-21)
export interface GeminiClient {
  generate(opts: {
    prompt: string;
    systemPrompt: string;
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
  // prod: return VertexAI-backed impl
  return new VertexGeminiClient();
}
// Selected via: const client = makeGeminiClient(process.env.GEMINI_CLIENT_MODE === 'fake' ? 'fake' : 'prod');
```

### Pattern 3: Firestore Transaction — Quota Check + Idempotency + Message Write

```typescript
// Source: Firebase Firestore Admin SDK docs (verified semantics 2026-05-19)
// Max 500 writes/transaction; Admin SDK up to ~25 retries on contention.
// FieldValue.serverTimestamp() IS allowed inside runTransaction (confirmed).
// For auto-ID docs inside tx: use collection.doc() BEFORE the tx, then tx.set(ref, data).

const userMessageRef = sessionsCol.doc(sessionId).collection('messages').doc(clientRequestId);
const assistantMessageRef = sessionsCol.doc(sessionId).collection('messages').doc(); // auto-ID, allocated before tx

const result = await db.runTransaction(async (tx) => {
  // READS FIRST (Admin SDK: reads must precede writes in a transaction)
  const usageSnap = await tx.get(usageRef);
  const quotaSnap = await tx.get(quotaRef);
  const dedupeSnap = await tx.get(userMessageRef);

  // DEDUPE CHECK
  if (dedupeSnap.exists) {
    return { cached: true, data: dedupeSnap.data() };
  }

  // QUOTA CHECKS (burst + daily + monthly)
  const now = Date.now();
  const usage = usageSnap.data() ?? { messageCount: 0, imageCount: 0, burstWindow: [] };
  const prunedBurst = (usage.burstWindow as admin.firestore.Timestamp[])
    .filter(ts => ts.toMillis() > now - 60_000);

  if (prunedBurst.length >= 5) {
    throw new HttpsError('resource-exhausted', 'Burst limit reached', {
      reason: 'burst',
      retryAfterSec: Math.ceil((prunedBurst[0].toMillis() + 60_000 - now) / 1000),
    });
  }

  // ... daily + monthly checks (similar pattern) ...

  // WRITES (after all reads and checks)
  const nowTs = admin.firestore.Timestamp.now(); // Timestamp.now() is safe inside tx
  tx.set(usageRef, {
    messageCount: admin.firestore.FieldValue.increment(1),
    burstWindow: [...prunedBurst, nowTs],  // ← use array literal, not arrayUnion inside tx
  }, { merge: true });

  tx.update(quotaRef, { calls: admin.firestore.FieldValue.increment(1) });

  tx.set(userMessageRef, {
    role: 'user',
    text: userMessage,
    imageUrl: imageUrl ?? null,
    clientRequestId,
    createdAt: nowTs,
    promptVersion: SYSTEM_PROMPT_VERSION,
  });

  return { cached: false };
});

// AFTER transaction commits: invoke Gemini, then write assistant doc
const geminiResult = await geminiClient.generate({ ... });
await assistantMessageRef.set({
  role: 'assistant',
  text: geminiResult.text,
  clientRequestId,
  createdAt: admin.firestore.Timestamp.now(),
  promptVersion: SYSTEM_PROMPT_VERSION,
});
```

**Critical note on `arrayUnion` inside transactions:** `FieldValue.arrayUnion()` IS allowed inside `tx.update()` calls within a transaction. However, for the burst window, using a plain array literal is safer because you need to both READ the current array AND write the pruned+appended version in one operation.

### Pattern 4: Admin Storage SDK — Fetch Image as Buffer

```typescript
// Source: Google Cloud Storage Node.js docs (Admin SDK path confirmed 2026-05-19)
// Works without public-read because Admin SDK runs as the Functions service account
// which has project-level Storage access by default.
import { getStorage } from 'firebase-admin/storage';

async function fetchImageAsBase64(gsUri: string): Promise<{ buffer: Buffer; mimeType: string }> {
  // gsUri example: 'gs://mentor-mind-aa765.appspot.com/uploads/uid123/1234567890.jpg'
  const bucket = getStorage().bucket();
  const filePath = gsUri.replace(`gs://${bucket.name}/`, '');
  const [buffer] = await bucket.file(filePath).download();
  return { buffer, mimeType: 'image/jpeg' };
}
// Soft cap: reject if buffer.length > 4_000_000 (4MB) to avoid bloating the Vertex request
```

### Pattern 5: MentorBotRepository — Dart callable wrapper

```dart
// Mirrors PingRepository pattern (Phase 2 Plan 02-07, verified in codebase)
// Source: lib/data/repositories/ping_repository.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:mentor_minds/data/models/chat_message.dart';
import 'package:mentor_minds/data/services/firebase_functions_provider.dart';

class MentorBotRepository {
  MentorBotRepository({required FirebaseFunctions functions})
      : _functions = functions;

  final FirebaseFunctions _functions;

  Future<ChatMessage> sendMessage({
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
    final data = (result.data as Map<Object?, Object?>).cast<String, dynamic>();
    return ChatMessage.fromCallableResult(data);
  }
}

// UUID generation (one per send attempt, reused across retries):
// final clientRequestId = const Uuid().v4();

final mentorBotRepositoryProvider = Provider<MentorBotRepository>((ref) {
  return MentorBotRepository(
    functions: ref.read(firebaseFunctionsProvider),
  );
});
```

### Pattern 6: @firebase/rules-unit-testing — AI-08 Smoke Tests

```typescript
// Source: firebase.google.com/docs/rules/unit-tests (verified 2026-05-19)
// The harness attaches to a running Firestore emulator via FIRESTORE_EMULATOR_HOST.
// It does NOT boot its own emulator.
// Phase 2 already runs the Firestore emulator on localhost:8080 (firebase.json).

import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { setDoc, getDoc, doc } from 'firebase/firestore';
import fs from 'fs';

const testEnv = await initializeTestEnvironment({
  projectId: 'mentor-mind-aa765',
  firestore: {
    rules: fs.readFileSync('firestore.rules', 'utf8'),
    host: 'localhost',
    port: 8080,
  },
});

describe('AI-08: /users/{uid}/usage/{date} lockdown', () => {
  const uid = 'test-user-1';
  const date = '2026-05-19';

  test('owner can READ their own usage doc', async () => {
    const alice = testEnv.authenticatedContext(uid);
    await assertSucceeds(
      getDoc(doc(alice.firestore(), `users/${uid}/usage/${date}`))
    );
  });

  test('client CANNOT WRITE to own usage doc (Admin SDK only)', async () => {
    const alice = testEnv.authenticatedContext(uid);
    await assertFails(
      setDoc(doc(alice.firestore(), `users/${uid}/usage/${date}`), { messageCount: 999 })
    );
  });

  test('other user CANNOT READ usage doc', async () => {
    const bob = testEnv.authenticatedContext('other-user');
    await assertFails(
      getDoc(doc(bob.firestore(), `users/${uid}/usage/${date}`))
    );
  });

  test('client CANNOT READ /system/quota doc', async () => {
    const alice = testEnv.authenticatedContext(uid);
    await assertFails(
      getDoc(doc(alice.firestore(), 'system/quota/2026-05'))
    );
  });

  test('client CANNOT WRITE /system/quota doc', async () => {
    const alice = testEnv.authenticatedContext(uid);
    await assertFails(
      setDoc(doc(alice.firestore(), 'system/quota/2026-05'), { calls: 0 })
    );
  });
});
```

### Pattern 7: UTC+6 Day Key (QUOTA_TZ shared constant)

```typescript
// functions/src/lib/quota.ts — NEVER use toISOString().slice(0,10) (UTC, not Dhaka)
export const QUOTA_TZ = 'Asia/Dhaka';

export function getDhakaDateKey(): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: QUOTA_TZ,
    year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(new Date());  // → '2026-05-19' format
}

export function monthKey(): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: QUOTA_TZ,
    year: 'numeric', month: '2-digit',
  }).format(new Date()).slice(0, 7);  // → '2026-05'
}
```

```dart
// lib/core/constants/quota.dart
// Mirrors the TS constant — both files reference each other in a header comment.
// Used for display-only (actual quota enforcement is server-side).
const String kQuotaTimezone = 'Asia/Dhaka';
```

### Anti-Patterns to Avoid

- **Using `toISOString().slice(0,10)` for day key:** Returns UTC date. At 11:30 PM Dhaka time, UTC is 5:30 PM the PREVIOUS day — a user on their 30th message gets a fresh quota at midnight UTC, not midnight Dhaka. The fix is `Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Dhaka' })`. [CITED: 03-CONTEXT.md PITFALLS #3]
- **Calling Gemini inside runTransaction:** Gemini can take 5-30 seconds. Holding a Firestore transaction lock for 30 seconds causes massive contention. Transaction must commit BEFORE the Gemini call. [CITED: 03-CONTEXT.md PITFALLS #4]
- **Using `fileData` (gs:// URI) for images with private bucket:** Requires Vertex AI's service account to have Storage IAM read — an additional IAM grant. Inline base64 via Admin SDK is simpler. [VERIFIED: Google Cloud base64 encoding docs]
- **Writing the assistant message INSIDE the transaction:** Same issue as Gemini-in-transaction — Gemini I/O cannot be inside a transaction. Write the assistant doc in a follow-up `set()` after Gemini returns.
- **Not pre-allocating the auto-ID doc ref before the transaction:** `collection.doc()` generates a client-side ID synchronously. Allocate BEFORE `runTransaction`; use `tx.set(preAllocatedRef, data)` inside. `addDoc` cannot be used inside transactions.
- **Using `arrayUnion` for burst window (wrong approach):** `arrayUnion` can only ADD items; it cannot atomically REMOVE stale timestamps from the window. Use a read-then-compute-then-write pattern inside the transaction.
- **Streaming in v1.0 chat_viewmodel:** The existing `async* / await for` pattern (lines 287-295 of chat_viewmodel.dart) must be DELETED entirely in PR-3. The new `MentorBotRepository.sendMessage()` returns a `Future<ChatMessage>`, not a `Stream`. The `isStreaming` state flag stays but now means "awaiting the Future."
- **Removing `isStreaming` flag from ChatState:** Keep it. It still drives the typing-indicator UI. The flag transitions: `false → true` (on send) → `false` (when Future resolves). The UI behavior is identical; only the data source changes.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Timezone-correct day key | Custom UTC offset math | `Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Dhaka' })` | DST-safe; handles edge cases automatically |
| Atomic read-check-write | Sequential reads + writes | `db.runTransaction(async (tx) => { ... })` | Without transaction, concurrent users can race past quota checks |
| UUIDv4 generation (Dart) | `'${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}'` (current pattern in chat_viewmodel._genId) | `const Uuid().v4()` from `package:uuid` | Cryptographically random; globally unique; matches the RFC 4122 standard the server expects for idempotency keying |
| Vertex AI auth | Manual OAuth token refresh | `@google-cloud/vertexai` + ADC | ADC auto-refreshes via Cloud Functions runtime SA; no token management needed |
| Rules unit testing | Manual emulator HTTP calls | `@firebase/rules-unit-testing` `assertSucceeds/assertFails` | Ergonomic; handles emulator teardown; standard Firebase testing pattern |
| Image format for Gemini | Custom multipart encoding | `inline_data: { mimeType, data: base64 }` part format | SDK handles serialization; verified by Google docs |

**Key insight:** The quota enforcement logic looks simple (increment counters, check limits) but the concurrency semantics are subtle — a non-transactional approach will over-count or under-enforce at modest load. Firestore's `runTransaction` provides serializable isolation for the read-check-write cycle at no additional complexity cost.

---

## Runtime State Inventory

> This is a MIGRATION phase for the Gemini integration only. The existing code is not a rename — it's a replacement of an in-memory service with a server-persisted one.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | `/sessions/{sid}` docs store messages inline in `.messages[]` array (confirmed by `sessions_repository.dart:62-66`). No `/sessions/{sid}/messages/{mid}` subcollection exists. | No migration needed. Phase 3 starts the subcollection fresh. Old sessions remain readable via legacy array path. Phase 4 can read from subcollection only. |
| Live service config | `GEMINI_API_KEY` in VS Code launch.json and CI workflow (inferred from BACKEND_SETUP.md §7 and D-18) | PR-3 removes `--dart-define=GEMINI_API_KEY` from launch.json and any CI workflow `dart-define` references |
| OS-registered state | None — no OS-level registration of the API key or GeminiService | None |
| Secrets/env vars | `GEMINI_API_KEY` was passed via `--dart-define` (confirmed in `gemini_service.dart:13`). After PR-3, this `--dart-define` must be REMOVED from all build invocations. The actual Google AI Studio key must be REVOKED (D-22). | Manual: solo dev revokes key at https://aistudio.google.com/apikey BEFORE PR-3 merges. Also remove from `.vscode/launch.json`. |
| Build artifacts | `lib/core/services/gemini_service.dart` is the in-binary file holding the API key call path. After PR-3, this file is DELETED. The compiled iOS binary will no longer contain any API key reference. | PR-3 step 3: `git rm lib/core/services/gemini_service.dart` |

**Nothing found in:** OS-registered state, external datastores, admin service config.

---

## Common Pitfalls

### Pitfall P-1: `gemini-3.1-pro` Not GA in `asia-south1`
**What goes wrong:** PR-1 deploys; first real call fails with `Model not found` or `Region not supported`. No runtime error during `tsc` build — TypeScript doesn't validate model names.
**Why it happens:** Google stages new model releases region-by-region. `asia-south1` (Mumbai) often lags behind `us-central1` by weeks for new model GAs.
**How to avoid:** Before PR-1 merges, executor runs a one-time test call: `curl -X POST https://asia-south1-aiplatform.googleapis.com/v1/projects/mentor-mind-aa765/locations/asia-south1/publishers/google/models/gemini-3.1-pro:generateContent -H "Authorization: Bearer $(gcloud auth print-access-token)"` and checks the response. If the model returns an error, switch to the fallback model pinned in Q-1.
**Warning signs:** `HttpsError` with code `internal` from the callable during end-to-end smoke test.

### Pitfall P-2: Calling Gemini Inside the Transaction
**What goes wrong:** The transaction holds Firestore document locks while the Gemini API call takes 5-30 seconds. All concurrent users on the same uid's usage doc (impossible — but all users hitting `/system/quota/{YYYY-MM}`) are blocked. The transaction times out after 270s or Firestore aborts it.
**Why it happens:** Natural urge to keep all state changes atomic.
**How to avoid:** The transaction commits BEFORE the Gemini call. Assistant doc is written in a separate `set()` after Gemini returns. See Pattern 3 in Code Examples.
**Warning signs:** Increasing `ABORTED: Too much contention` errors in Cloud Logging, especially under any parallel load.

### Pitfall P-3: UTC Day Key Instead of Dhaka Day Key
**What goes wrong:** A student in Dhaka at 11:55 PM (local) hits their 30th message. The UTC date rolls over at 6:00 PM Dhaka time, so `toISOString().slice(0,10)` returns tomorrow's UTC date — the student gets a fresh quota 6 hours early.
**Why it happens:** `new Date().toISOString()` is always UTC.
**How to avoid:** Always use `getDhakaDateKey()` from `quota.ts`. Never use raw `toISOString()` for quota keys.
**Warning signs:** Users reporting quota resets happening at strange times.

### Pitfall P-4: `fileData` (gs:// URI) Failing for Private Bucket
**What goes wrong:** Passing `{ fileData: { mimeType: 'image/jpeg', fileUri: 'gs://bucket/uploads/uid/img.jpg' } }` to Vertex AI fails because Vertex AI's inference service account does not have read permission on the project's Storage bucket.
**Why it happens:** The `fileData` approach requires Vertex AI's service account (not the Functions SA) to read the file. The Functions SA already has Storage access (it's in the same project) — but the Vertex AI inference SA is different.
**How to avoid:** Use `inline_data` (base64) approach: Admin Storage SDK fetches the bytes (privileged Functions SA has read access), converts to base64, passes inline. Add a 4MB soft cap to prevent Vertex request bloat.
**Warning signs:** Vertex API call fails with `PERMISSION_DENIED` even though the Functions service account itself can read the file.

### Pitfall P-5: `FieldValue.arrayUnion` for Burst Window
**What goes wrong:** Using `FieldValue.arrayUnion(nowTs)` to append the current timestamp to `burstWindow` does NOT remove stale entries. The burst window grows indefinitely; the count is never pruned; burst limit never resets.
**Why it happens:** `arrayUnion` is an additive sentinel — it cannot read the current array, filter it, and replace it atomically.
**How to avoid:** Inside the transaction: read `burstWindow`, filter out entries older than 60 seconds, append the new timestamp, write the ENTIRE filtered array as a literal (not via `arrayUnion`).
**Warning signs:** Users getting `burst limit` rejections long after the 60-second window should have expired.

### Pitfall P-6: Not Removing `--dart-define` Before PR-3 Merges
**What goes wrong:** The iOS binary is rebuilt with PR-3 changes but the launch config still passes `--dart-define=GEMINI_API_KEY=<key>`. The key string gets compiled into the app binary. Even though `GeminiService` is deleted, the `--dart-define` value is still embedded in Dart's `String.fromEnvironment` default lookup table.
**Why it happens:** `--dart-define` values are baked into the binary at compile time by the Dart compiler.
**How to avoid:** PR-3 checklist includes removing from `.vscode/launch.json`, `Makefile` (if any), README run instructions, and CI workflow.
**Warning signs:** `flutter build ios --release` produces a binary containing the old API key string (detectable via `strings build/ios/iphoneos/Runner.app/Runner | grep 'AIzaSy'`).

### Pitfall P-7: `@firebase/rules-unit-testing` Attaches to Wrong Emulator
**What goes wrong:** Tests run but rules checks silently pass even for blocked operations because the harness is hitting a production Firestore instead of the emulator.
**Why it happens:** `FIRESTORE_EMULATOR_HOST` is not set; the harness falls back to production.
**How to avoid:** Always run rules tests with `FIRESTORE_EMULATOR_HOST=localhost:8080 npm test`. In CI, add `FIRESTORE_EMULATOR_HOST: localhost:8080` to the workflow environment and start the emulator in a prior step.
**Warning signs:** Tests pass when they should fail; `assertFails` calls don't throw.

### Pitfall P-8: `isStreaming` State Confusion After PR-3
**What goes wrong:** After swapping to `MentorBotRepository`, `isStreaming` is removed from `ChatState` because "there's no stream anymore." The typing indicator widget (`isStreaming` flag) breaks; the screen shows an empty bubble indefinitely.
**Why it happens:** The name "isStreaming" is misleading when using a non-streaming API, but the flag's FUNCTION is "show typing indicator while awaiting response" — which still applies.
**How to avoid:** Keep `isStreaming` in `ChatState`. In `sendMessage`: set `isStreaming: true` before `await mentorBotRepo.sendMessage(...)`, set `isStreaming: false` in finally block.
**Warning signs:** Tutor screen shows a blank bubble after sending; typing indicator disappears immediately.

---

## Code Examples

### Verified: `VertexAI` Constructor + `getGenerativeModel`
```typescript
// Source: googleapis.dev/nodejs/vertexai/latest/index.html (2026-05-19)
import { VertexAI } from '@google-cloud/vertexai';

const vertex = new VertexAI({
  project: process.env.GCLOUD_PROJECT!,  // injected by CF v2 runtime
  location: 'asia-south1',
});
const generativeModel = vertex.getGenerativeModel({ model: 'gemini-2.5-pro' });
```

### Verified: `generateContent` Response Shape (token counts)
```typescript
// Source: googleapis.dev/nodejs/vertexai/latest/index.html (2026-05-19)
const result = await generativeModel.generateContent({ contents: [...] });
const text = result.response.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
const promptTokens = result.response.usageMetadata?.promptTokenCount ?? 0;
const completionTokens = result.response.usageMetadata?.candidatesTokenCount ?? 0;
```

### Verified: `initializeTestEnvironment` for rules testing
```typescript
// Source: firebase.google.com/docs/rules/unit-tests (2026-05-19)
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import fs from 'fs';

const testEnv = await initializeTestEnvironment({
  projectId: 'mentor-mind-aa765',
  firestore: { rules: fs.readFileSync('firestore.rules', 'utf8'), host: 'localhost', port: 8080 },
});
// Emulator attaches via FIRESTORE_EMULATOR_HOST env var — NOT booted by the harness itself.
```

### Verified: `package:uuid` v4 generation in Dart
```dart
// Source: pub.dev/packages/uuid v4.5.3 (2026-05-19)
import 'package:uuid/uuid.dart';
final clientRequestId = const Uuid().v4();
// → '110ec58a-a0f2-4ac4-8393-c866d813b8d1'
// Generate ONCE per user-initiated send; store on the in-flight ChatMessage; reuse across retries.
```

### Verified: IAM grant for Functions v2 SA → Vertex AI
```bash
# Source: docs.cloud.google.com/iam/docs/roles-permissions/aiplatform (2026-05-19)
# Cloud Functions v2 default SA format: {PROJECT_NUMBER}-compute@developer.gserviceaccount.com
# Project number: 722452556351 (verified via gcloud projects describe mentor-mind-aa765)

gcloud projects add-iam-policy-binding mentor-mind-aa765 \
  --member="serviceAccount:722452556351-compute@developer.gserviceaccount.com" \
  --role=roles/aiplatform.user

# Also enable Vertex AI API (if not already enabled):
gcloud services enable aiplatform.googleapis.com --project=mentor-mind-aa765
```

### Verified: D-23 — No existing subcollection messages writes (grep evidence)
```
# grep -rn "collection('sessions')" lib/ returns only:
# sessions_repository.dart — .collection('sessions').doc().set(data)  ← parent doc, not subcollection
# No code writes to /sessions/{sid}/messages/{mid}
# D-23 confirmed: migration-free start for Phase 3.
```

### Verified: `errors.ts` additions for Phase 3 (resource-exhausted + unavailable)
```typescript
// Add to functions/src/lib/errors.ts (extends Phase 2 base):
export function resourceExhausted(message: string, details?: Record<string, unknown>): HttpsError {
  const err = new HttpsError('resource-exhausted', message);
  // HttpsError details property may need casting; verify at TS compile time
  (err as unknown as { details: unknown }).details = details;
  return err;
}

export function unavailable(message: string, details?: Record<string, unknown>): HttpsError {
  const err = new HttpsError('unavailable', message);
  (err as unknown as { details: unknown }).details = details;
  return err;
}
```

### Verified: `onCall` shape for `mentorBotChat` (inherits Phase 2 pattern)
```typescript
// Source: functions/src/index.ts (Phase 2, commit 83b5b1b) + 03-CONTEXT.md §Integration Points
export const mentorBotChat = onCall(
  {
    region: 'asia-south1',
    enforceAppCheck: true,
    timeoutSeconds: 60,
    memory: '512MiB',
    // No secrets: [] needed — Vertex AI uses ADC, not Secret Manager
  },
  async (request) => {
    // request.auth.uid — authenticated user
    // request.data — { sessionId, clientRequestId, message, imageUrl?, subject?, level? }
    // request.auth.token.premium — boolean custom claim
  }
);
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `google_generative_ai` Dart SDK + `--dart-define=GEMINI_API_KEY` (in-binary) | `@google-cloud/vertexai` Node.js SDK + ADC (no key) | Phase 3 | API key eliminated from iOS binary; server-side enforcement becomes possible |
| Client-side `gemini-1.5-flash` streaming via `generateContentStream` | Server-side `gemini-2.5-pro` (or `3.1-pro` if GA) non-streaming via callable | Phase 3 | Higher quality model; rate limiting; idempotent retries; no key in binary |
| In-memory `_history` array in `GeminiService` | Persistent `/sessions/{sid}/messages/{mid}` subcollection | Phase 3 | Survives app restarts; enables Phase 4 reward triggers; enables future session resume |
| Client writes usage docs (`_incrementUsage()` in chat_viewmodel) | Server transaction writes usage docs | Phase 3 | Quota is authoritative; client cannot inflate counts |
| `callGemini` stub (Phase 2 `gemini.ts`) | Full `GeminiClient` interface + `VertexGeminiClient` impl + `FakeGeminiClient` | Phase 3 | Testable via fake; zero CI cost |

**Deprecated in Phase 3:**
- `lib/core/services/gemini_service.dart` — DELETED in PR-3
- `google_generative_ai: ^0.4.6` in `pubspec.yaml` — REMOVED in PR-3
- `--dart-define=GEMINI_API_KEY` from all build configs — REMOVED in PR-3
- `geminiServiceProvider` in `chat_viewmodel.dart` — DELETED in PR-3 (replaced by `mentorBotRepositoryProvider`)
- `_gemini.sendMessage(...)` streaming call (lines 287-295 of chat_viewmodel.dart) — DELETED in PR-3
- `_gemini.analyzeImage(...)` call (line 275 of chat_viewmodel.dart) — DELETED in PR-3
- `_gemini.resetSession()` calls (lines 194, 392 of chat_viewmodel.dart) — DELETED in PR-3 (server manages session history now)

---

## D-23 Verification: No Migration Required

Direct code inspection confirms:

- `chat_viewmodel.dart` has **no direct Firestore writes**. All storage goes through `_sessionsRepo`, `_usersRepo`, `_storageRepo`.
- `sessions_repository.dart` writes to `/sessions/{sid}` (parent doc) with messages as an INLINE ARRAY: `data['messages'] = state.messages.map((m) => m.toMap()).toList()` (line 365-366 of chat_viewmodel.dart → saveSession)
- The `/sessions/{sid}/messages/{mid}` **subcollection does not exist** in any Dart file under `lib/`
- The search_viewmodel reads `data['messages']` as an inline array from the parent doc (lines 304-309 of search_viewmodel.dart) — this is the LEGACY path; Phase 3 starts fresh with the subcollection
- `grep -rn "collection('sessions')"` returns ONLY `sessions_repository.dart` (parent collection operations) and references in `users_repository.dart` + `rewards_repository.dart` that also hit the parent doc

**Conclusion:** Phase 3 starts the `/sessions/{sid}/messages/{mid}` subcollection fresh. There is no historical data to migrate. Old inline-array sessions remain intact but Phase 3+ sessions use the subcollection pattern exclusively.

---

## ChatViewModel Migration Analysis

**File:** `lib/application/viewmodels/tutor/chat_viewmodel.dart`

**Current `_gemini` field (line 120):**
```dart
final GeminiService _gemini;
```
→ **PR-3 replaces with:**
```dart
final MentorBotRepository _mentorBotRepo;
```

**Methods calling `_gemini` that must be DELETED/REPLACED in PR-3:**
1. `_gemini.sendMessage(...)` — lines 287-295: entire `async* / await for` stream loop → replace with `await _mentorBotRepo.sendMessage(...)`
2. `_gemini.analyzeImage(...)` — line 275: one-shot image call → merge into single `sendMessage` path with `imageUrl`
3. `_gemini.resetSession()` — lines 194, 392: session history reset → server manages history; call can be DELETED

**Fields/state that must be REMOVED:**
- The `isStreaming` flag on ChatState STAYS (drives typing indicator)
- The `isStreaming: true` in the AI placeholder ChatMessage STAYS (drives bubble shimmer)
- Remove: `_gemini.sendMessage(...)` + buffer accumulation loop

**sendMessage() new implementation sketch:**
```dart
Future<void> sendMessage(String text, {File? imageFile}) async {
  // ... validation unchanged ...
  
  // Generate clientRequestId ONCE per send attempt
  final clientRequestId = const Uuid().v4();
  
  // ... show userMsg + aiPlaceholder in state unchanged ...
  
  state = state.copyWith(isStreaming: true, clearImagePreview: true, ...);

  try {
    String? uploadedUrl;
    if (imageFile != null) {
      uploadedUrl = await _storageRepo.uploadImage(...);
    }

    final response = await _mentorBotRepo.sendMessage(
      sessionId: state.sessionId ?? _generateSessionId(),
      clientRequestId: clientRequestId,
      message: trimmed,
      imageUrl: uploadedUrl,
      subject: state.selectedSubject,
      level: state.selectedLevel,
    );

    if (!mounted) return;
    _updateMessage(aiPlaceholder.id, content: response.text, isStreaming: false);
    state = state.copyWith(isStreaming: false, dailyMessageCount: state.dailyMessageCount + 1, ...);
    
    // _saveSession() is REMOVED — server writes the session subcollection
    unawaited(_awardPoints('complete_session'));  // may move to Phase 4 trigger
  } on FirebaseFunctionsException catch (e) {
    // Map e.code ('resource-exhausted', 'unavailable', etc.) to UI state
    // D-16: auto-retry on 'internal' / 'deadline-exceeded' / 'unavailable' (if details.reason != 'monthly-ceiling')
  }
}
```

**Phase 4 forward-note:** `_saveSession()` and `_incrementUsage()` are DELETED from chat_viewmodel.dart in PR-3. The `mentorBotChat` callable handles all persistence. `_awardPoints('complete_session')` may stay temporarily and be removed in Phase 4 when `onSessionWrite` trigger takes over.

---

## Firestore Rules Insertion Point

**Current `firestore.rules` at `/users/{uid}/usage/{dateKey}` (lines 77-79):**
```
match /usage/{dateKey} {
  allow read, write: if isOwner(uid) || isAdmin();
}
```

**PR-2 replacement (D-17 lock — client read-only, admin read):**
```
match /usage/{dateKey} {
  allow read: if isOwner(uid) || isAdmin();
  allow write: if false;  // Admin SDK writes only via mentorBotChat callable
}
```

**New `/system/**` blocks to INSERT after the `/notifications` block (after line 149):**
```
// -------------------------------------------------------------------------
// /system/** — server-only (Phase 3: quota + usage log)
// -------------------------------------------------------------------------

match /system/{document=**} {
  allow read, write: if false;  // Admin SDK access only via Cloud Functions
}
```

**Existing `/sessions/{sid}/messages/{mid}` rule (lines 111-115) — KEEP AS-IS:**
```
match /messages/{mid} {
  allow read, write: if isSignedIn()
    && get(...).data.userId == request.auth.uid;
}
```
Phase 3 ships with the existing session message rule (clients can still read). Phase 4 will tighten this to server-write-only as part of the server-authoritative rewards lockdown.

---

## Cost Analysis

**Vertex AI `gemini-2.5-pro` pricing (verified from cloud.google.com/vertex-ai/generative-ai/pricing, 2026-05-19):**
- Input: $1.25 per 1M tokens (≤200K context)
- Output: $10.00 per 1M tokens

**Phase 3 D-14 config:** `maxOutputTokens: 1024` (~500 tokens avg actual output for tutoring)

**10,000 calls/month estimate (monthly ceiling from D-10):**
- Average prompt: ~200 tokens (system prompt portion amortized is large but set once; per-message input ~200 tokens)
- Average output: ~500 tokens
- Input: 10,000 × 200 = 2M tokens → $2.50/mo
- Output: 10,000 × 500 = 5M tokens → $50.00/mo
- **Total: ~$52.50/month at 10k calls/mo**

**Note:** The CONTEXT.md estimate of $27/mo was based on $5/M output tokens (flash pricing). `gemini-2.5-pro` output is $10/M — approximately 2× higher than estimated in the CONTEXT.md. At 10k calls/mo, the actual cost is ~$52/mo, which will trigger the Phase 2 D-15 $10/mo budget alert at ~2k calls. The solo dev should raise the alert to $75/mo BEFORE PR-1 lands.

**`gemini-3.1-pro` preview pricing (from pricing page, labeled "Gemini 3 Pro Preview"):**
- Input: $2.00/M (≤200K), Output: $12.00/M
- At 10k calls/mo: ~$65/mo — even higher

**Recommendation:** The budget alert (currently $10/mo from Phase 2 D-15) MUST be raised to at minimum $75/mo before Phase 3 first deploy. This is a prerequisite documented in BACKEND_SETUP.md Phase 3 section.

---

## Open Questions

1. **Q-1: `gemini-3.1-pro` GA availability in `asia-south1` (BLOCKING — pin before PR-1)**
   - What we know: Google docs site has a "Gemini 3.1 Pro" page. Community discussion suggests `gemini-2.5-pro` may not be in `asia-south1` yet as of research date. `gemini-2.5-pro` is the fallback.
   - What's unclear: Whether `gemini-3.1-pro` has been GA-released in `asia-south1` by the time PR-1 is executed.
   - Recommendation: **Planner must add a `checkpoint:human-verify` task as the FIRST task in PR-1**: "Executor runs a test Vertex API call against `asia-south1` with `gemini-3.1-pro`. If `Model not found`, use `gemini-2.5-pro` instead and document in PR-1 commit message. Pin the verified model ID in `gemini.ts` as a string constant." Do NOT let PR-1 merge without pinning a verified model ID.
   - Fallback priority: `gemini-3.1-pro` → `gemini-2.5-pro` → `gemini-1.5-pro`

2. **Q-2: `_saveSession()` and `_incrementUsage()` fate in chat_viewmodel (Phase 3 vs Phase 4)**
   - What we know: PR-3 removes these calls because the callable handles persistence and usage tracking. However, `_awardPoints('complete_session')` also lives in chat_viewmodel today.
   - What's unclear: Whether `_awardPoints` should also be removed in Phase 3 (and replaced by the Phase 4 `onSessionWrite` trigger) or kept temporarily until Phase 4.
   - Recommendation: Remove `_awardPoints` in Phase 3 PR-3 as well — the `onSessionWrite` trigger in Phase 4 will detect "first message of session" from the subcollection delta and award points then. Keeping duplicate point awards in Phase 3 would double-award during the overlap.

3. **Q-3: `sessionId` generation — client or server?**
   - What we know: Currently `SessionsRepository.saveSession()` generates the session ID by calling `.doc()` (client-allocated). The new subcollection path is `/sessions/{sid}/messages/{mid}` where `sid` must be stable across retries.
   - What's unclear: Whether the callable should generate the session ID or the client should pre-generate it.
   - Recommendation: Client pre-generates `sessionId` using `const Uuid().v4()` alongside `clientRequestId` (same `uuid` package). First `sendMessage` call creates the parent `/sessions/{sid}` doc; subsequent calls in the same "chat" reuse the same `sessionId`. The callable never generates session IDs — it receives them from the client.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js | functions/ build + test | ✓ | v24.11.1 | — |
| npm | functions/ package management | ✓ | 11.6.2 | — |
| gcloud CLI | IAM grants + Vertex API enable | ✓ | SDK 560.0.0 | Manual via Firebase Console |
| firebase CLI | Function deploy + emulator | ✓ | 15.2.1 | — |
| Flutter SDK | Dart client build | ✓ | 3.41.3 | — |
| Dart SDK | Flutter build | ✓ | 3.11.1 | — |
| Vertex AI API (aiplatform.googleapis.com) | mentorBotChat at runtime | Requires enable | — | `gcloud services enable aiplatform.googleapis.com` |
| GCP billing enabled | Any deployed function | Pending (solo dev prerequisite from Phase 2 STATE.md) | — | No fallback — hard blocker |

**Missing dependencies with no fallback:**
- GCP billing enable: `gcloud billing projects link mentor-mind-aa765 --billing-account=0121EC-5D572E-57FEE1` (carried forward from Phase 2 STATE.md §Blockers)
- Vertex AI API enable: `gcloud services enable aiplatform.googleapis.com --project=mentor-mind-aa765`

**Missing dependencies with fallback:**
- None beyond the two above.

---

## Validation Architecture

> `workflow.nyquist_validation` not explicitly set to `false` in config — treated as enabled.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Node 20 + Jest (new in Phase 3 via `npm install --save-dev jest @types/jest ts-jest`) + `@firebase/rules-unit-testing` 5.0.1 |
| Config file | `functions/jest.config.js` (new Wave 0 item), `functions/tsconfig.json` (existing) |
| Quick run command (TS) | `cd functions && npm run lint && npm run build && npm test` |
| Quick run command (Dart) | `flutter analyze --no-fatal-infos && dart run custom_lint` |
| Full suite command | `flutter test --coverage && dart run custom_lint && cd functions && npm run lint && npm run build && npm test` |
| Rules test command | `FIRESTORE_EMULATOR_HOST=localhost:8080 cd functions && npm test -- --testPathPattern=rules` |
| Integration command | `firebase emulators:start --only auth,firestore,functions` (background) + `flutter test integration_test/mentor_bot_smoke_test.dart --dart-define=USE_EMULATOR=true -d <device>` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists |
|--------|----------|-----------|-------------------|-------------|
| AI-01 | `mentorBotChat` callable exports and builds | static + build | `grep -n "mentorBotChat" functions/src/index.ts && (cd functions && npm run build && node -e "const m=require('./lib/index.js'); if(!m.mentorBotChat) throw new Error('not exported')")` | ❌ Wave 0 (PR-1) |
| AI-01 | Vertex AI `@google-cloud/vertexai` installed + `GeminiClient` interface exists | static | `test -f functions/src/lib/gemini.ts && grep -q "GeminiClient" functions/src/lib/gemini.ts && node -e "require('@google-cloud/vertexai')"` | ❌ Wave 0 (PR-1) |
| AI-02 | `--dart-define=GEMINI_API_KEY` removed from launch.json + CI workflow | static | `grep -rn "GEMINI_API_KEY" .vscode/launch.json .github/workflows/ci.yml 2>/dev/null | wc -l | grep -q "^0$" && echo "CLEAN"` | ❌ Wave 0 (PR-3) |
| AI-02 | `gemini_service.dart` deleted | static | `test ! -f lib/core/services/gemini_service.dart && echo "deleted"` | ❌ Wave 0 (PR-3) |
| AI-03 | `google_generative_ai` removed from pubspec.yaml | static | `grep -c "google_generative_ai" pubspec.yaml | grep -q "^0$" && echo "REMOVED"` | ❌ Wave 0 (PR-3) |
| AI-04 | `QUOTA_TZ = 'Asia/Dhaka'` constant in both TS and Dart | static | `grep -q "Asia/Dhaka" functions/src/lib/quota.ts && grep -q "Asia/Dhaka" lib/core/constants/quota.dart` | ❌ Wave 0 (PR-1 + PR-3) |
| AI-04 | Dhaka day key logic unit tested | unit | `cd functions && npm test -- --testPathPattern=rate_limit` | ❌ Wave 0 (PR-1) |
| AI-05 | Burst limit rejects 6th message in 60s window | unit | `cd functions && npm test -- --testPathPattern=rate_limit` (burst scenario) | ❌ Wave 0 (PR-1) |
| AI-06 | Monthly ceiling rejection returns `unavailable` with `reason: 'monthly-ceiling'` | unit | `cd functions && npm test -- --testPathPattern=rate_limit` (monthly ceiling scenario) | ❌ Wave 0 (PR-1) |
| AI-07 | Transaction writes both usage doc + user message doc atomically | unit | `cd functions && npm test -- --testPathPattern=idempotency` | ❌ Wave 0 (PR-1) |
| AI-07 | Idempotent retry returns cached response | unit | `cd functions && npm test -- --testPathPattern=idempotency` (retry scenario) | ❌ Wave 0 (PR-1) |
| AI-08 | `/users/{uid}/usage/{date}` write blocked for client | rules | `FIRESTORE_EMULATOR_HOST=localhost:8080 cd functions && npm test -- --testPathPattern=rules` | ❌ Wave 0 (PR-2) |
| AI-08 | `/system/quota/{YYYY-MM}` read + write blocked for client | rules | `FIRESTORE_EMULATOR_HOST=localhost:8080 cd functions && npm test -- --testPathPattern=rules` | ❌ Wave 0 (PR-2) |
| AI-09 | System prompt string is a TS const in `gemini.ts` (not fetched from Firestore/Remote Config) | static | `grep -q "SYSTEM_PROMPT" functions/src/lib/gemini.ts && grep -q "SYSTEM_PROMPT_VERSION" functions/src/lib/gemini.ts` | ❌ Wave 0 (PR-1) |
| AI-10 | No `generateContentStream` call in `gemini.ts` | static | `grep -rn "generateContentStream\|async\*\|await for" functions/src/lib/gemini.ts; echo "exit: $?"` (expect zero lines) | ❌ Wave 0 (PR-1) |
| AI-10 | No streaming call in `chat_viewmodel.dart` after PR-3 | static | `grep -n "sendMessage\|analyzeImage\|generateContentStream\|await for" lib/application/viewmodels/tutor/chat_viewmodel.dart | grep -v "_mentorBotRepo\|//"; echo "CLEAN if no hits"` | ❌ Wave 0 (PR-3) |
| AI-10 | End-to-end smoke: callable returns text (non-streaming) | integration | `firebase emulators:start --only auth,firestore,functions & sleep 5 && flutter test integration_test/mentor_bot_smoke_test.dart --dart-define=USE_EMULATOR=true -d <device>` | ❌ Wave 0 (PR-3) |

### Sampling Rate
- **Per task commit:** Matching layer quick command (Dart: `flutter analyze --no-fatal-infos && dart run custom_lint`; TS: `cd functions && npm run lint && npm run build`)
- **Per wave merge:** `flutter test --coverage && dart run custom_lint && (cd functions && npm run lint && npm run build && npm test)`
- **Phase gate:** Full suite green (including `npm test`) before `/gsd:verify-work`

### Wave 0 Gaps

**PR-1 (server function):**
- [ ] `functions/package.json` — add `@google-cloud/vertexai: "^1.12.0"` to dependencies
- [ ] `functions/package.json` — add `jest`, `@types/jest`, `ts-jest` to devDependencies; add `"test": "jest"` script
- [ ] `functions/jest.config.js` — new file with `ts-jest` preset
- [ ] `functions/src/lib/quota.ts` — new file with `QUOTA_TZ`, `getDhakaDateKey()`, `monthKey()`
- [ ] `functions/src/lib/gemini.ts` — FILL: `GeminiClient` interface + `VertexGeminiClient` + `FakeGeminiClient` + `makeGeminiClient`
- [ ] `functions/src/lib/rate_limit.ts` — FILL: `checkAndIncrement` with daily+burst+monthly transaction
- [ ] `functions/src/__tests__/rate_limit.test.ts` — new unit tests
- [ ] `functions/src/__tests__/gemini.test.ts` — new unit tests
- [ ] `functions/src/__tests__/idempotency.test.ts` — new unit tests

**PR-2 (rules + tests):**
- [ ] `functions/src/__tests__/rules.test.ts` — new rules tests (AI-08 smoke)
- [ ] `firestore.rules` — three path lock insertions (usage subcollection tighten + /system block)

**PR-3 (client swap):**
- [ ] `lib/core/constants/quota.dart` — new file with `kQuotaTimezone`
- [ ] `lib/data/repositories/mentor_bot_repository.dart` — new file
- [ ] `lib/data/models/mentor_bot_response.dart` — new file (or extend `chat_message.dart`)
- [ ] `pubspec.yaml` — add `uuid: ^4.5.3`, remove `google_generative_ai: ^0.4.6`
- [ ] `integration_test/mentor_bot_smoke_test.dart` — new smoke test (mirrors ping_smoke_test.dart pattern)
- [ ] `.github/workflows/ci.yml` — add `npm test` step after `npm run build` in `functions:` job
- [ ] `BACKEND_SETUP.md` — append `## Phase 3 — Vertex AI + Key Rotation` section

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Yes | `request.auth.uid` required; App Check `enforceAppCheck: true` inherited from Phase 2 |
| V3 Session Management | Yes | Session IDs are client-generated UUIDv4; no server session state beyond Firestore |
| V4 Access Control | Yes | `roles/aiplatform.user` scoped to Functions SA only; client never has Vertex credentials |
| V5 Input Validation | Yes | Callable input validated (sessionId, clientRequestId format, message length cap) |
| V6 Cryptography | No | ADC handles Vertex auth; UUIDv4 is not a security secret (just a dedup key) |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Client fabricates usage doc to clear quota | Tampering | `firestore.rules` locks `/users/{uid}/usage/{date}` to read-only for clients (D-17, AI-08) |
| Client reads other users' quota to infer activity | Information Disclosure | `isOwner(uid)` check in usage rule; other user reads blocked |
| Client reads `/system/quota` to gauge app capacity | Information Disclosure | `/system/**` locked to server-only (D-17) |
| Replay attack on `clientRequestId` | Repudiation | Server dedupes by `(uid, clientRequestId)` — replayed request returns cached response without re-billing Gemini |
| Key leakage via Dart binary (old `GEMINI_API_KEY`) | Information Disclosure | PR-3 removes `--dart-define=GEMINI_API_KEY`; key revoked at aistudio.google.com before merge (D-22) |
| Prompt injection via `message` field | Tampering | System prompt instructs MentorBot to stay on-topic; model-level safety settings block harmful content |
| Runaway Gemini costs from unauthenticated calls | Elevation of Privilege | `enforceAppCheck: true` requires valid App Check token; unauthenticated returns 401 |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `gemini-3.1-pro` or `gemini-2.5-pro` is available in `asia-south1` at PR-1 execution time | Open Questions Q-1 | PR-1 deploy fails with "Model not found"; fallback to `gemini-1.5-pro` which is older |
| A2 | Firestore Admin SDK `runTransaction` retries up to ~25 times on contention (server-side) | Code Examples, Pitfalls | If limit is lower (5x), high burst could cause user-visible "Too much contention" errors |
| A3 | `FieldValue.serverTimestamp()` is permitted inside `runTransaction` tx.update/set calls | Code Examples Pattern 3 | If forbidden, must use `Timestamp.now()` for all timestamps inside transactions |
| A4 | `@google/genai` (new unified SDK) is in experimental preview and should NOT be used for production | Standard Stack Alternatives | If `@google/genai` reaches stable before PR-1, it may be a better long-term choice |
| A5 | Cloud Functions v2 runtime auto-injects ADC; `GCLOUD_PROJECT` env var is set by the runtime | Code Examples | If not auto-set, must explicitly configure `VertexAI({ project: 'mentor-mind-aa765' })` with hardcoded project ID |
| A6 | `gemini-2.5-pro` output pricing is $10/M tokens making 10k calls/mo ~$52/mo | Cost Analysis | If pricing differs, budget alert threshold recommendation changes |

**If this table is empty:** All claims in this research were verified or cited — no user confirmation needed. (Table is not empty — A1 is the critical one requiring executor checkpoint.)

---

## Sources

### Primary (HIGH confidence)
- `googleapis.dev/nodejs/vertexai/latest/index.html` — VertexAI constructor, getGenerativeModel, generateContent, usageMetadata shape (verified 2026-05-19)
- `npm view @google-cloud/vertexai` — version 1.12.0, published 2023-12-12, repo github.com/googleapis/nodejs-vertexai (verified 2026-05-19)
- `npm view @firebase/rules-unit-testing` — version 5.0.1, repo github.com/firebase/firebase-js-sdk (verified 2026-05-19)
- `pub.dev/api/packages/uuid` — uuid 4.5.3, pub.dev (verified 2026-05-19)
- `firebase.google.com/docs/rules/unit-tests` — initializeTestEnvironment, assertSucceeds/assertFails, FIRESTORE_EMULATOR_HOST attachment pattern (verified 2026-05-19)
- `cloud.google.com/vertex-ai/generative-ai/pricing` — gemini-2.5-pro $1.25/M input, $10/M output; gemini-3-pro-preview $2/M input, $12/M output (verified 2026-05-19)
- `docs.cloud.google.com/iam/docs/roles-permissions/aiplatform` — `roles/aiplatform.user` grant command pattern (verified 2026-05-19)
- Code inspection: `lib/application/viewmodels/tutor/chat_viewmodel.dart`, `lib/core/services/gemini_service.dart`, `lib/data/repositories/sessions_repository.dart`, `lib/data/repositories/ping_repository.dart`, `firestore.rules` (verified 2026-05-19)
- GCP project number 722452556351 via `gcloud projects describe mentor-mind-aa765` (verified 2026-05-19)

### Secondary (MEDIUM confidence)
- WebSearch + Firebase Admin SDK issue #456 — `FieldValue.serverTimestamp()` behavior in transactions; 500 write limit; up to ~25 retries on contention (multiple sources corroborate)
- WebSearch — Cloud Functions v2 default SA = `{PROJECT_NUMBER}-compute@developer.gserviceaccount.com` (Google docs + Trend Micro conformity article corroborate)
- WebSearch — `Intl.DateTimeFormat` for timezone-safe date keys (standard JS pattern)

### Tertiary (LOW confidence)
- gemini-3.1-pro regional availability — `docs.cloud.google.com/vertex-ai/generative-ai/docs/models/gemini/3-1-pro` exists as a page but content was not retrievable; regional table unconfirmed [ASSUMED — executor must verify]
- `@google/genai` experimental preview status [ASSUMED — based on npm description text fragment]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages verified on npm/pub.dev with source repos confirmed
- Architecture patterns: HIGH — code shapes lifted from official googleapis.dev + Firebase docs + existing codebase
- Model availability: LOW — `gemini-3.1-pro` in asia-south1 UNVERIFIED; executor checkpoint required
- Cost analysis: MEDIUM — pricing verified but token counts are estimates
- Pitfalls: HIGH — based on code inspection + official documentation

**Research date:** 2026-05-19
**Valid until:** 2026-06-19 (30 days; Vertex AI model availability and pricing change rapidly — re-verify Q-1 at PR-1 time)

---

## RESEARCH COMPLETE
