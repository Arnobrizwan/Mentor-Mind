# Phase 3: Gemini Proxy + Server-Side Rate Limiting - Context

**Gathered:** 2026-05-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Move every Gemini call behind a server-side `mentorBotChat` callable in `asia-south1`. The callable is the single chokepoint that:

- Calls **Vertex AI** (Gemini Pro tier; targeting `gemini-3.1-pro` GA in asia-south1, with researcher pinning the exact published model ID at execute time) using Application Default Credentials — no API key in client, no API key in Secret Manager (AI-01 is AMENDED — see D-02).
- Reads the system prompt + model config from a hardcoded versioned TS const in `functions/src/lib/gemini.ts` (fills the Phase 2 stub).
- Enforces three independent quotas in **one Firestore transaction** before invoking Gemini:
  1. **Daily** — 30 text + 3 image per UTC+6 day per user, keyed off the `Asia/Dhaka` calendar date (AI-04 + PITFALLS #3).
  2. **Burst** — 5 messages / 60s sliding window per user (AI-05).
  3. **Monthly app-wide ceiling** — 10,000 calls/month at `/system/quota/{YYYY-MM}` (AI-06).
- Premium users (`request.auth.token.premium === true`) bypass the daily cap; burst + monthly still apply.
- Dedupes retries via a client-issued `clientRequestId` (UUIDv4 from `package:uuid`).
- Returns the assistant text in the callable response AND writes both the user message and the assistant reply as docs in a new `/sessions/{sid}/messages/{mid}` subcollection in the same transaction as the usage increment — so Phase 4's `onSessionWrite` trigger can fire on a stable, deltable shape.
- Locks `firestore.rules` for AI-08: `/users/{uid}/usage/{date}` becomes read-only for the owning client; `/system/**` becomes server-only (no client reads or writes). Session and rewards lockdown deferred to Phase 4.
- Ships a `BACKEND_SETUP.md` `## Phase 3 — Key Rotation` section + the solo dev manually revokes the previously-leaked Google AI Studio key BEFORE PR-3 merges (the new Vertex AI path doesn't use a key at all; the rotation just kills the dead one).
- Rewires the client: new `lib/data/repositories/mentor_bot_repository.dart` wrapping the callable; `ChatViewModel` swapped from `GeminiService` to the repository in a single atomic PR; `lib/core/services/gemini_service.dart` deleted; `google_generative_ai` removed from `pubspec.yaml`; `--dart-define=GEMINI_API_KEY` removed from all build configs (AI-02 + AI-03).

**Requirements covered:** AI-01 (amended), AI-02, AI-03, AI-04, AI-05, AI-06, AI-07, AI-08, AI-09, AI-10.
**Depends on:** Phase 2 (functions/ monorepo, asia-south1 callable shape, App Check enforcement, errors.ts factory, gemini.ts/rate_limit.ts stubs, cloud_functions ^5.6.2 Flutter SDK + repository pattern).

</domain>

<decisions>
## Implementation Decisions

### Gemini SDK + API tier (AI-01, AI-09, AI-10)

- **D-01: Model = `gemini-3.1-pro` (Pro tier).** Researcher pins the EXACT published model ID GA in `asia-south1` at execute time. Acceptance: the model name in `gemini.ts` resolves at runtime without `Model not found` errors. **Cost note:** Pro is roughly an order of magnitude more expensive per token than `gemini-1.5-flash`; this drives the Phase 2 D-15 budget-alert tension surfaced in the Open Considerations section below.

- **D-02: API tier = Vertex AI via `@google-cloud/vertexai` npm SDK + ADC.** No API key anywhere. The Cloud Functions v2 runtime auto-injects Application Default Credentials for the Functions service account; we grant it `roles/aiplatform.user`. Regional endpoint `asia-south1` matches the function region — no cross-region hop. **AI-01 AMENDED:** the original wording `reads GEMINI_API_KEY from Google Secret Manager` is superseded — Phase 3 ships with no Gemini API key at all. AI-02 still applies (binary scrub + rotation of the dead Studio key).

- **D-03: System prompt + model config live as hardcoded TS consts in `functions/src/lib/gemini.ts`.** Fills the Phase 2 D-05 stub. AI-09 "can be updated without an app release" is satisfied by redeploying Functions only (`firebase deploy --only functions:mentorBotChat`); no iOS rebuild needed. Versioned via git history.

- **D-04: Prompt is VERSIONED via `SYSTEM_PROMPT_VERSION = '1'` const.** The version string is stamped onto each `/sessions/{sid}/messages/{mid}` doc (`promptVersion: '1'`) so future quality regressions can be traced to a specific prompt revision.

### mentorBotChat callable contract (AI-07, AI-10)

- **D-05: Image attachment flow = client uploads to Storage, passes URL.** Client uploads to `uploads/{uid}/{ts}.jpg` (Phase 1 pattern). Callable request includes `imageUrl` (the `gs://` path OR the Storage download URL). Server fetches bytes via the Admin Storage SDK (same project — no cross-service auth) and feeds them into the Gemini Vision API as an inline image part. Keeps callable payload < 2KB even with images.

- **D-06: `clientRequestId` = UUIDv4 from `package:uuid: ^4.x`.** Generated once per user-initiated send and reused across retries (including the auto-retry from D-16). Persisted onto the in-flight `ChatMessage` model immediately so a network flap doesn't drop it. Server dedupes by `(uid, clientRequestId)` inside the transaction.

- **D-07: Error code disambiguation = distinct HttpsError codes per failure mode.** Concrete map:
  - `resource-exhausted` + `details: { reason: 'daily', limit: 30, used: N }` — daily text/image quota hit.
  - `resource-exhausted` + `details: { reason: 'burst', retryAfterSec: N }` — 5/60s burst limit.
  - `unavailable` + `details: { reason: 'monthly-ceiling' }` — `/system/quota/{YYYY-MM}` over ceiling (AI-06 wording: "AI tutor temporarily unavailable" surfaces here).
  - `unauthenticated` — missing auth OR App Check rejection (Phase 2 D-01 inherit).
  - `permission-denied` — reserved for Phase 5 admin-only paths.
  - `internal` / `deadline-exceeded` — transient; eligible for auto-retry (D-16).
  Server constructs errors via the Phase 2 D-05 `errors.ts` factory wrappers.

- **D-08: Reply persistence = BOTH return text AND write the message pair to `/sessions/{sid}/messages/{mid}` in the same transaction as the usage increment.** Caller gets immediate text (drives the typing-indicator-to-bubble transition); the transaction also writes two docs (user message + assistant reply). Phase 4's `onSessionWrite` trigger fires on each new message doc in the subcollection.

### Rate-limit state model + session schema (AI-04, AI-05, AI-06, AI-07, AI-08)

- **D-09: Burst counter = sibling rolling-timestamp array on `/users/{uid}/usage/{today}`.** Same doc as the daily counter. Document shape: `{ messageCount: N, imageCount: N, burstWindow: [<server-ts1>, <server-ts2>, ...] }`. The transaction: (1) reads the doc once; (2) prunes `burstWindow` entries older than `now-60s`; (3) asserts `burstWindow.length < 5`; (4) appends `now`; (5) increments `messageCount` (or `imageCount` for images). One read + one write per call. PITFALLS #4 mandate (`runTransaction`) is honored from v1.

- **D-10: Monthly ceiling = 10,000 calls/month at `/system/quota/{YYYY-MM}`.** Doc shape: `{ calls: N, ceiling: 10000, monthLabel: '2026-05' }`. Function increments `calls` inside the transaction; rejects with `unavailable` when `calls >= ceiling`. **Tunable via env var `MONTHLY_CALL_CEILING` (Functions `defineString`)** so it can be dialed up/down without redeploying logic. Default 10,000.

- **D-11: Session message storage = subcollection `/sessions/{sid}/messages/{mid}`.** Parent `/sessions/{sid}` holds metadata: `{ uid, subject, level, startedAt, lastMessageAt, messageCount, lastClientRequestId }`. Subcollection messages: `{ role: 'user'|'assistant', text, imageUrl?, clientRequestId, createdAt: <server-ts>, promptVersion: '1' }`. Phase 4 reward trigger reads from the subcollection. Firestore composite index needed on `(sid, createdAt)` for ordered reads.

- **D-12: Message retention = forever for v1.0.** No auto-prune. Storage cost negligible at projected scale (~45MB at 100 users/month). PAY-08's "full chat history search" depends on this. Phase 7 may revisit if cost actually shows up.

### Runtime config + observability + retry (cross-cutting)

- **D-13: `minInstances: 0`** on `mentorBotChat`. Cold-start ~2-4s tolerated. First-of-day user pays; subsequent warm calls finish in ~3-5s total (within the 10s answer goal). `minInstances: 1` (~$25/mo) is out until Phase 5 Stripe revenue covers it.

- **D-14: Function runtime config (exported from `gemini.ts` as `MODEL_CONFIG`, versioned per D-04):** `timeoutSeconds: 60`, `memory: '512MiB'`, `maxOutputTokens: 1024`, `temperature: 0.7`, `topP: 0.95`, `topK: 40`.

- **D-15: Observability = per-call aggregate to `/system/usage_log/{YYYY-MM-DD}`** PLUS structured logs via `functions.logger.info({ event: 'gemini_call', uid, promptTokens, completionTokens, estimatedCostUsd, durationMs })`. Aggregate doc shape: `{ calls: N, promptTokens: N, completionTokens: N, estimatedCostUsd: N }`. Written via `update` (not transaction — separate from the user-quota transaction so contention doesn't block on aggregate-doc writes). Admin Panel (Phase 5+) reads this. firestore.rules locks `/system/**` to server-only (D-17).

- **D-16: Client retry policy = 2× exponential backoff (250ms, 1s) on `internal`/`deadline-exceeded`/`unavailable` ONLY WHEN `details.reason !== 'monthly-ceiling'`.** Reuses the same `clientRequestId` so server idempotency dedupes. Does NOT retry on `resource-exhausted`, `unauthenticated`, `permission-denied`. After 2 fails: surface "Couldn't reach the tutor — try again" with a manual retry button (still reuses the same id).

### Security + refactor + sequencing (AI-02, AI-03, AI-08, PAY-08 forward-pointer)

- **D-17: firestore.rules scope (this phase only) = minimum needed for AI-08.** Three path locks:
  - `/users/{uid}/usage/{date}` — `allow read: if request.auth.uid == uid; allow write: if false;` (Admin SDK writes via function only).
  - `/system/quota/{YYYY-MM}` — `allow read, write: if false;` (server-only).
  - `/system/usage_log/{YYYY-MM-DD}` — `allow read, write: if false;` (server-only).
  Sessions subcollection lockdown (`/sessions/{sid}/messages/{mid}` server-write-only) and rewards lockdown belong to Phase 4 (`Server-Authoritative Rewards + Rules Lockdown`). Phase 3 ships `@firebase/rules-unit-testing` harness + AI-08 smoke tests; Phase 4 expands the suite.

- **D-18: Refactor strategy = single PR (PR-3) with atomic commits in order.** Step 1: add `lib/data/repositories/mentor_bot_repository.dart` (returns `Future<ChatMessage>`). Step 2: swap `ChatViewModel._geminiService` → `_mentorBotRepository` (same atomic commit OR follow-up commit; tests stay green). Step 3: delete `lib/core/services/gemini_service.dart`. Step 4: remove `google_generative_ai` from `pubspec.yaml` + `--dart-define=GEMINI_API_KEY` from all build configs + the FlutterFire / build-config places that reference it. Step 5: add `uuid: ^4.x` to `pubspec.yaml` (D-06). Each step compiles and tests green. PR-3 description includes the manual-step pointer to the leaked-key rotation procedure (D-22).

- **D-19: Premium-claim bypass wired in Phase 3.** Server reads `request.auth?.token?.premium === true`. If true: skip the daily-cap check inside the transaction (burst + monthly STILL apply per PAY-08). Pre-Phase-5, all tokens have `premium: false` (default custom claim from REWD-02), so the check is a no-op. Phase 5 just has to set the claim via Stripe webhook; mentorBotChat stays untouched. Idempotency check inside the transaction happens FIRST (before any quota check), so a premium retry still dedupes.

- **D-20: PR sequencing = 3 PRs.**
  - **PR-1 — server-side function:** `functions/src/index.ts` exports `mentorBotChat`; `functions/src/lib/gemini.ts` filled with the Vertex AI client + `SYSTEM_PROMPT` + `SYSTEM_PROMPT_VERSION` + `MODEL_CONFIG`; `functions/src/lib/rate_limit.ts` filled with the transactional daily + burst + monthly enforcement; `functions/package.json` adds `@google-cloud/vertexai`; the Functions service account is granted `roles/aiplatform.user` (documented in BACKEND_SETUP.md). Includes a `GeminiClient` interface + fake impl for testing (D-21). Server-only PR.
  - **PR-2 — firestore.rules + tests:** Three path locks per D-17 + `@firebase/rules-unit-testing` harness + AI-08 smoke tests. Rules-only PR.
  - **PR-3 — client swap + cleanup:** New `MentorBotRepository` + `ChatViewModel` migration + delete `GeminiService` + remove `google_generative_ai` + remove `--dart-define=GEMINI_API_KEY` + add `uuid: ^4.x`. Triggers the iOS binary rebuild that scrubs the leaked key from the compiled artifact (AI-02). Manual leaked-key rotation (D-22) MUST land BEFORE PR-3 merges.

### Testing + operations (AI-01, AI-02, AI-10)

- **D-21: Test strategy = mock Vertex at the SDK boundary.** Extract a `GeminiClient` interface in `functions/src/lib/gemini.ts`. Production impl wraps `@google-cloud/vertexai`. Fake impl returns canned `{ text: 'fake response', tokensIn: 10, tokensOut: 20 }`. Injection via factory function selected by `GEMINI_CLIENT_MODE` env var (`prod` | `fake`). Unit tests under `functions/src/__tests__/` use the fake. Integration tests against the Functions emulator also use the fake (set via env). Real-Vertex tests live under `npm run test:live` gated by an explicit env var — NOT run in CI. Zero CI cost; high coverage of rate-limit + idempotency + transaction logic.

- **D-22: Leaked-key rotation procedure = manual revoke in Google AI Studio BEFORE PR-3 merges + document in `BACKEND_SETUP.md ## Phase 3 — Key Rotation`.** Solo dev runs the rotation manually (no automated step). Section documents: (1) URL to revoke (`https://aistudio.google.com/apikey`), (2) confirm no other system is using the key (it was only in the iOS `--dart-define` and possibly env files), (3) note that the new Vertex AI path doesn't use a key at all, (4) git-history-scrub explicitly NOT performed — revoked = dead, scrubbing would force-push to main. The PR-3 description includes a checkbox for "key rotated in Studio".

- **D-23: Existing chat history = no migration; nothing is persisted today.** Current `lib/features/tutor/chat_viewmodel.dart` + `lib/core/services/gemini_service.dart` keep an in-memory `_history` per ChatViewModel instance; nothing is written to Firestore. The research phase MUST verify (grep `chat_viewmodel.dart` for any `set(`/`add(`/`update(` against `/sessions` — expect zero hits). First new session after PR-3 lands in the new schema. Old in-memory transcripts vanish on app restart (current behavior anyway).

- **D-24: Email-verification gate (AUTH-02) DEFERRED to Phase 7.** AUTH-02 is "unverified users cannot use AI tutor" — a Phase 7 polish requirement (`/gsd:plan-phase 7` will wire the check in `ChatViewModel.sendMessage`). Phase 3 stays focused on rate-limit + proxy. A server-side belt-and-suspenders `request.auth.token.email_verified === true` check would be one line, but it crosses the phase boundary and is rightfully Phase 7's responsibility.

### Claude's Discretion

- TypeScript style choices beyond Phase 2 inheritance (semi-colons, trailing commas, etc.) — keep Phase 2's prettier defaults + `@typescript-eslint/recommended-type-checked`.
- Concrete shape of the `MentorBotRepository.sendMessage()` Dart signature beyond `Future<ChatMessage> sendMessage({required String sessionId, required String message, required String clientRequestId, String? imageUrl, String? subject, String? level})` — researcher / planner refine if needed.
- Where exactly `package:uuid: ^4.x` is added in `pubspec.yaml` (alphabetical in `dependencies:` block).
- Whether the `MentorBotRepository` exposes a thin `Result<ChatMessage, FunctionError>` wrapper or just throws `FirebaseFunctionsException` (probably the latter — matches `PingRepository` from Phase 2 D-CONTEXT D-CONTEXT).
- Concrete error-banner copy for TUTR-02 — that's Phase 7's UI polish; here we only define the error semantics.
- Whether to add a fallback Gemini model (e.g. `gemini-1.5-flash`) if `gemini-3.1-pro` isn't GA in asia-south1 at execute time — researcher decides based on Vertex AI model availability table; if a fallback IS needed, surface it as a CONTEXT amendment before PR-1.
- Test fixture: how to seed `/system/quota/{YYYY-MM}` at ceiling for the AI-06 "monthly ceiling rejection" integration test — likely a one-shot `tool/test-fixtures/seed-quota-at-ceiling.ts` script invoked from the integration test setup.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before planning or implementing.**

### Phase scope + traceability
- `.planning/ROADMAP.md` §"Phase 3: Gemini Proxy + Server-Side Rate Limiting" — phase goal, success criteria (5 items), non-negotiables (PITFALLS #2, #3, #4)
- `.planning/REQUIREMENTS.md` §"AI Tutor Backend (Gemini Proxy)" (AI-01 through AI-10)
- `.planning/PROJECT.md` §Constraints — locks: Firebase backend, Flutter 3.41 / Dart 3.11, iOS-only v1.0, Gemini provider

### Phase 1 baseline (downstream MUST honor)
- `.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-CONTEXT.md` — Phase 1 decisions D-01..D-16; especially:
  - D-01..D-04 (repository pattern + Riverpod providers — `MentorBotRepository` follows this)
  - D-05..D-07 (no codegen / no DI containers — Dart side stays vanilla; TS side has no equivalent constraint)
  - D-14 (`package:mentor_minds/...` imports for every new Dart file)
  - `custom_lint` `layered_imports` rule (Plan 01-02 + 05) — `MentorBotRepository` MAY import `cloud_functions`; `ChatViewModel` MUST NOT

### Phase 2 baseline (downstream MUST honor)
- `.planning/phases/02-cloud-functions-scaffolding-app-check/02-CONTEXT.md` — Phase 2 decisions D-01..D-24; especially:
  - D-01 (server-side `enforceAppCheck: true` baseline — `mentorBotChat` inherits this)
  - D-04 (CommonJS TypeScript output; `tsconfig.json` `strict: true`)
  - D-05 (the Phase 2 `gemini.ts` + `rate_limit.ts` STUBS that Phase 3 FILLS; `errors.ts` factory wrappers Phase 3 USES; `admin.ts` singleton Phase 3 USES)
  - D-06 (region `asia-south1` on every callable)
  - D-07 (callable shape: `onCall({region, enforceAppCheck}, handler)` v2 API; `onCall` NOT `onRequest`)
  - D-15 (`$10/mo` budget alert wired — surfaces tension with D-10 Pro-tier cost; see Open Considerations)
  - D-18 (Functions emulator on port 5001 — used by Phase 3 integration tests with the `GeminiClient` fake)
  - D-19 (PR sequencing template — Phase 3 follows the same 3-PR structure per D-20)
- `.planning/phases/02-cloud-functions-scaffolding-app-check/02-PATTERNS.md` — `firebase_functions_provider.dart`, `ping_repository.dart`, `ping_response.dart` analogs that `MentorBotRepository` mirrors
- `.planning/phases/02-cloud-functions-scaffolding-app-check/02-06-app-check-activation-SUMMARY.md` — `appAttestWithDeviceCheckFallback` provider lock (free Apple Developer account)
- `.planning/phases/02-cloud-functions-scaffolding-app-check/02-07-flutter-functions-sdk-SUMMARY.md` — `FirebaseFunctions.instanceFor(region: 'asia-south1')` + repository pattern + `(result.data as Map<Object?, Object?>).cast<String, dynamic>()` cast

### Vertex AI + firebase-functions v2 (researcher: fetch via WebFetch during research phase)
- https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/gemini — model versions + regional availability table (researcher pins exact `gemini-3.1-pro` or fallback model ID)
- https://cloud.google.com/vertex-ai/docs/reference/sdk-nodejs — `@google-cloud/vertexai` API surface
- https://firebase.google.com/docs/functions/callable?gen=2nd — v2 `onCall` shape + `enforceAppCheck` option
- https://firebase.google.com/docs/firestore/manage-data/transactions — `runTransaction` semantics (max 5 reads / 500 writes; retries on conflict)
- https://firebase.google.com/docs/rules/unit-tests — `@firebase/rules-unit-testing` setup for D-17 rules tests
- https://pub.dev/packages/uuid — v4 generation for D-06

### Architecture pitfalls (project-internal — researcher MUST consult)
- `.planning/ARCHITECTURE.md` (if exists) §"Anti-pattern #3 — Idempotency via clientRequestId" — Phase 3 honors via D-06 + transaction dedupe
- `.planning/PITFALLS.md` (if exists) §#3 (QUOTA_TZ shared), §#4 (runTransaction mandatory v1), §#2 (idempotency before Phase 4)
- If those docs don't exist as separate files, the pitfalls are inlined in `.planning/ROADMAP.md` §"Rationale & non-negotiables" under each phase

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets (from Phase 1 + Phase 2)
- `lib/data/services/firebase_functions_provider.dart` (Phase 2 Plan 02-07) — `Provider<FirebaseFunctions>` using `FirebaseFunctions.instanceFor(region: 'asia-south1')`. `MentorBotRepository` reads from this same provider.
- `lib/data/repositories/ping_repository.dart` (Phase 2 Plan 02-07) — repository pattern to mirror: constructor takes `FirebaseFunctions` from `ref.read`, method wraps `httpsCallable('NAME').call()`, returns decoded domain model.
- `lib/data/models/ping_response.dart` (Phase 2 Plan 02-07) — decoded-model factory pattern. `MentorBotMessage` (or `ChatMessage` — verify existing name with `lib/data/models/chat_message.dart` from Phase 1 D-02 model extraction) factory `fromCallableResult(Map<String, dynamic>)`.
- `functions/src/lib/admin.ts` (Phase 2 Plan 02-02) — `firebase-admin` singleton; `mentorBotChat` uses for the Storage Admin SDK read (D-05 image fetch).
- `functions/src/lib/errors.ts` (Phase 2 Plan 02-02) — `HttpsError` factory wrappers (`unauthenticated`, `permissionDenied`, `failedPrecondition`, `resourceExhausted`, `unavailable`, `internal`) + `mapKnownError`. Phase 3 errors built via these.
- `functions/src/lib/gemini.ts` (Phase 2 Plan 02-02 stub) — Phase 3 FILLS this. Stub currently throws `'not implemented — see Phase 3'`. Replace the throw with the real implementation (Vertex AI client + `SYSTEM_PROMPT` const + `MODEL_CONFIG` const).
- `functions/src/lib/rate_limit.ts` (Phase 2 Plan 02-02 stub) — Phase 3 FILLS this. Stub currently throws. Implement `checkAndIncrement(uid: string, kind: 'text' | 'image', isPremium: boolean): Promise<RateLimitResult>` with the transactional daily + burst + monthly logic.
- `functions/src/index.ts` (Phase 2 Plan 02-03) — currently exports the `ping` callable. Phase 3 ADDS a `mentorBotChat` export alongside `ping`. Both stay in the same `index.ts` (no submodules).
- `lib/main.dart` (Phase 2 Plan 02-06 + 02-08) — `FirebaseAppCheck.instance.activate(...)` already runs after `Firebase.initializeApp` and before any provider read. `useFunctionsEmulator('localhost', 5001)` already wired. No change needed.
- `lib/data/models/chat_message.dart` (Phase 1 D-02 model extraction) — existing `ChatMessage` model. Verify shape; reuse if compatible with the new `{role, text, imageUrl?, clientRequestId, createdAt, promptVersion}` schema.
- `lib/features/tutor/chat_viewmodel.dart` (Phase 1 + Phase 2 — but viewmodel itself untouched by Phase 2) — the swap site. Currently depends on `GeminiService` (in-memory history). PR-3 swaps to `MentorBotRepository`.
- `lib/core/services/gemini_service.dart` — DELETED in PR-3.
- `test/_helpers/emulator_setup.dart` (Phase 1 + Phase 2 D-18) — already calls `useFunctionsEmulator('localhost', 5001)`. Phase 3 integration test reuses this.
- `integration_test/login_smoke_test.dart` (Phase 1) and `integration_test/ping_smoke_test.dart` (Phase 2 Plan 02-09) — patterns for the new `integration_test/mentor_bot_smoke_test.dart` (Phase 3).
- `.github/workflows/ci.yml` (Phase 2 Plan 02-10) — `functions:` job runs `npm ci && npm run lint && npm run build` on `functions/**` changes; Phase 3 plans should also add a unit test step (`npm test` after the `GeminiClient` fake is wired).
- `BACKEND_SETUP.md` (Phase 2 Plan 02-05) — already has `## Phase 2 — Cloud Functions + App Check Setup`. Phase 3 appends `## Phase 3 — Vertex AI + Key Rotation` section.

### Established Patterns
- **Per-collection repositories with decoded domain models, never raw snapshots** (Phase 1 D-02) — `MentorBotRepository.sendMessage()` returns a decoded `ChatMessage` (or new `MentorBotResponse`), never the raw `HttpsCallableResult`.
- **SDK singletons exposed as Riverpod providers** (Phase 1 D-04) — `MentorBotRepository` reads `firebaseFunctionsProvider` via `ref.read`. New `mentorBotRepositoryProvider` exposed alongside `pingRepositoryProvider`.
- **Package-style imports for all cross-layer references** (Phase 1 D-14).
- **`-no-fatal-infos` analyze gate** (Phase 1) — Phase 3 inherits.
- **Layered_imports custom_lint rule** (Phase 1) — `MentorBotRepository` may import `cloud_functions`; `ChatViewModel` may NOT (it goes through the repository).
- **firebase-functions v2 `onCall({region, enforceAppCheck}, handler)`** (Phase 2 D-06, D-07) — `mentorBotChat` uses the same shape.
- **`(result.data as Map<Object?, Object?>).cast<String, dynamic>()` cast** (Phase 2 D-PATTERNS) — `MentorBotRepository` uses the same cast.
- **`HttpsError` factory wrappers from `errors.ts`** (Phase 2 D-05) — error construction always goes through the factory; never raw `new HttpsError(...)`.
- **Transaction-first state mutations** (PITFALLS #4) — every read-check-write goes through `runTransaction`; no out-of-band `update` for state that has concurrency implications.

### Integration Points
- **`functions/src/index.ts`** — ADD `export const mentorBotChat = onCall({region: 'asia-south1', enforceAppCheck: true, secrets: [], timeoutSeconds: 60, memory: '512MiB'}, handler)`. Existing `ping` export stays.
- **`functions/src/lib/gemini.ts`** — REPLACE stub with the real Vertex AI client + interface + fake.
- **`functions/src/lib/rate_limit.ts`** — REPLACE stub with the transactional daily + burst + monthly logic. New helpers: `getDhakaDateKey(): string` (the `QUOTA_TZ = 'Asia/Dhaka'` shared constant per PITFALLS #3), `monthKey(): string`.
- **`functions/package.json`** — ADD `@google-cloud/vertexai` (`^1.x` — researcher pins).
- **`functions/src/__tests__/`** — NEW unit tests for rate_limit + gemini fake + idempotency + transaction semantics.
- **`firestore.rules`** — ADD three path locks per D-17. Existing rules preserved.
- **`firestore.indexes.json`** — ADD composite index on `(sessionId, createdAt)` for the subcollection ordered reads OR rely on auto-indexing (Firestore auto-indexes single fields; composite needed only for compound queries — verify need).
- **`pubspec.yaml`** — ADD `uuid: ^4.x`; REMOVE `google_generative_ai`.
- **`lib/data/repositories/mentor_bot_repository.dart`** — NEW. Single method `Future<ChatMessage> sendMessage(...)`.
- **`lib/data/models/mentor_bot_request.dart`** OR reuse `chat_message.dart` — the wire-shape sent to the callable.
- **`lib/features/tutor/chat_viewmodel.dart`** — REWIRE from `GeminiService` to `MentorBotRepository`. Removes the in-memory `_history` (now persisted via D-08 server-side write). Removes the streaming code path (AI-10 — non-streaming v1.0).
- **`lib/core/services/gemini_service.dart`** — DELETE.
- **All build configs that pass `--dart-define=GEMINI_API_KEY`** — VS Code launch.json, CI workflow, README run instructions, BACKEND_SETUP.md.
- **`BACKEND_SETUP.md`** — APPEND `## Phase 3 — Vertex AI + Key Rotation` section.
- **`.github/workflows/ci.yml`** — Phase 2 already lifted the `functions:` job; Phase 3 plans MAY add `npm test` step alongside `lint`/`build`.

</code_context>

<specifics>
## Specific Ideas

- **`QUOTA_TZ = 'Asia/Dhaka'`** — shared constant per PITFALLS #3. Lives in BOTH `lib/core/constants/quota.dart` (Dart side, exported as `kQuotaTimezone`) AND `functions/src/lib/quota.ts` (TS side, exported as `QUOTA_TZ`). Both files reference each other in a header comment so future drift is loud. Day-key computed via the `intl` package (Dart) and `Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Dhaka' })` (TS) — NEVER raw `toISOString().slice(0,10)` (the entire bug class PITFALLS #3 calls out).

- **`MONTHLY_CALL_CEILING` env var** — defined via firebase-functions v2 `defineString('MONTHLY_CALL_CEILING', { default: 10000 })` so it can be raised/lowered without redeploying logic. Function reads at invocation. Set via `firebase functions:config:set monthly_call_ceiling=10000` (legacy) or the v2 params runtime config interface.

- **Mock `GeminiClient` interface shape:**
  ```typescript
  export interface GeminiClient {
    generate(opts: { prompt: string; systemPrompt: string; image?: { uri: string; mimeType: string }; modelConfig: ModelConfig }): Promise<{ text: string; promptTokens: number; completionTokens: number }>;
  }

  export function makeGeminiClient(mode: 'prod' | 'fake'): GeminiClient { ... }
  ```
  Production impl wraps `@google-cloud/vertexai`; fake returns canned `{ text: 'fake', promptTokens: 10, completionTokens: 20 }`. Selected via `GEMINI_CLIENT_MODE` env var (default `prod` in deploy; tests set `fake`).

- **`/system/quota/{YYYY-MM}` doc seeding for tests** — `tool/test-fixtures/seed-quota.ts` script: `firestore.doc('/system/quota/2026-05').set({ calls: 10000, ceiling: 10000, monthLabel: '2026-05' })`. Run from integration test `setUpAll` to pre-seed ceiling-reached state for the AI-06 test.

- **Burst window stored as Firestore Timestamps in an array** — `burstWindow: [<Timestamp>, <Timestamp>, ...]`. Server-side pruning: `arrayBefore = burstWindow.filter(ts => ts.toMillis() > nowMs - 60000)`. Append `now` server-time inside the transaction via `Timestamp.now()` (not `FieldValue.serverTimestamp()` — that's not allowed inside a read-then-write transaction value).

- **PR-3 manual checkpoint** — PR-3 description includes a checkbox: `- [ ] Leaked Google AI Studio key revoked in https://aistudio.google.com/apikey BEFORE merging`. Solo dev verifies before clicking merge.

</specifics>

<deferred>
## Deferred Ideas

- **Streaming chat responses (AI-10 explicit defer):** non-streaming v1.0 keeps the contract simple; streaming → v1.1. Server-sent-events via `onRequest` (not `onCall`) would require manual App Check header validation. Skipped.
- **Per-user monthly usage analytics dashboard:** observability data lives in `/system/usage_log/{YYYY-MM-DD}` (aggregate). A per-user-monthly query for the Profile screen / Admin Panel belongs in Phase 5 (Admin Panel) or Phase 7 (Profile polish).
- **Auto-prune old messages for free users (PAY-08 \"last 7 days search\"):** considered in D-12; deferred to Phase 7 — Firestore storage cost is negligible at v1.0 scale.
- **Routing premium users to a different model (e.g. `gemini-3.1-pro-large`):** considered as a Pro-tier cost mitigation; deferred to Phase 5 amendment if cost becomes painful.
- **A/B testing of system prompts via Remote Config:** considered for D-03; deferred to Phase 7 if prompt regressions become a real problem.
- **Migrating from Vertex AI back to Google AI Studio:** considered if Vertex AI cost is materially higher than Studio Pro tier; researcher MUST surface the cost comparison during Phase 3 research so this stays an open option, but the default is Vertex for the no-key + regional-endpoint benefits.
- **Belt-and-suspenders email-verification server-side check:** considered for D-24; deferred to Phase 7 (AUTH-02 owner).
- **Session subcollection lockdown in firestore.rules:** considered for D-17; deferred to Phase 4 (rules-lockdown phase).
- **Git history scrub of the leaked Google AI Studio key:** considered for D-22; rejected — revoked key is no more sensitive than `correct horse battery staple`. Force-push to main is destructive and pointless.

## Open Considerations (surface during planning / first phase review)

- **Phase 2 D-15 budget alert tension (D-10 + D-01):** Pro-tier × 10,000 calls/month will breach the existing `$10/mo` GCP budget alert from Phase 2 D-15. Three paths:
  - (a) **Raise the alert pre-emptively** before PR-1 lands — solo dev runs `gcloud billing budgets update ... --budget-amount=50USD`. Document in BACKEND_SETUP.md alongside D-22.
  - (b) **Let it fire as designed** — the alert is meant to warn at 50%/90%/100%; firing is the system working. React in Phase 5 when Stripe revenue is observable.
  - (c) **Drop monthly ceiling to ~2,000** so the alert stays a warning. UX gets restrictive.
  Surface to user at Phase 3 plan-review. Default: path (a) raise to $50/mo and note in BACKEND_SETUP.md alongside the Vertex AI section. NOT a Phase 3 plan task — solo dev manual gcloud invocation; CONTEXT just flags it.

- **`gemini-3.1-pro` GA availability in asia-south1:** researcher MUST verify at research time. If not yet GA, fallback to whichever current-generation Pro-class model IS GA in asia-south1 (likely `gemini-2.x-pro` or `gemini-1.5-pro`). Surface as a CONTEXT amendment.

</deferred>

---

*Phase: 03-gemini-proxy-server-side-rate-limiting*
*Context gathered: 2026-05-19*
