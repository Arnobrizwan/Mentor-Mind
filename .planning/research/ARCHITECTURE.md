# Architecture Research — MentorMinds v1.0 (server-side hardening)

**Domain:** Flutter + Firebase mobile app adding Cloud Functions, App Check, server-authoritative rewards, and a presentation-layer refactor
**Researched:** 2026-05-17
**Confidence:** MEDIUM — external doc verification (Context7, WebFetch, WebSearch) was unavailable in this environment. All Firebase/Functions API claims are from training data (Firebase Functions v2 GA was Q3 2024; cutoff is January 2026). Treat version-specific numbers (Node runtime support, App Attest minimums) as worth a one-look verification before phase implementation.

---

## 1. System Overview — target state after v1.0

```
┌────────────────────────────────────────────────────────────────────┐
│                       Flutter Client (iOS)                         │
│                                                                    │
│  lib/presentation/screens/<name>/<name>_screen.dart   (Views)      │
│           │                                                        │
│           │ ref.watch / ref.read                                   │
│           ▼                                                        │
│  lib/application/viewmodels/<name>_viewmodel.dart    (ViewModels)  │
│           │                                                        │
│           ▼                                                        │
│  lib/data/repositories/*.dart  +  lib/data/services/*.dart         │
│  (UsersRepo, SessionsRepo, RewardsRepo, MentorBotClient,           │
│   AppCheckService)                                                 │
└──────────────┬───────────────────────────┬─────────────────────────┘
               │                           │
               │ direct SDK                │ httpsCallable + AppCheck token
               │ (Firestore reads,         │
               │  Storage uploads,         │
               │  Auth)                    │
               ▼                           ▼
┌──────────────────────────┐   ┌─────────────────────────────────────┐
│  Firebase managed APIs   │   │      Firebase Cloud Functions (v2)  │
│  ─ Firestore             │   │      Region: asia-south1 (Mumbai)   │
│  ─ Storage               │   │                                     │
│  ─ Auth (+ ID token w/   │   │  CALLABLES (App Check enforced):    │
│    custom claims)        │   │  ─ mentorBotChat       (Gemini      │
│  ─ FCM                   │   │      proxy + rate limit)            │
│  ─ App Check (App        │   │  ─ mentorBotAnalyzeImg (premium)    │
│    Attest provider)      │   │  ─ setPremium          (admin only) │
│                          │   │                                     │
│  Security rules enforce  │   │  TRIGGERS (event-driven):           │
│  doc-level access; new   │   │  ─ onSessionWrite      → award pts  │
│  rules forbid client     │   │  ─ onUsageWrite        → streak inc │
│  writes to points/badges │   │  ─ onUserCreate        → init       │
│                          │   │      /rewards/{uid} + custom claims │
└──────────────┬───────────┘   └────────────┬────────────────────────┘
               │                            │
               │   (Functions use           │   Google Secret Manager
               │    Admin SDK — bypass      │   (GEMINI_API_KEY)
               │    security rules)         │
               └────────────┬───────────────┘
                            ▼
                ┌────────────────────────────────┐
                │  Google Generative AI API      │
                │  (gemini-1.5-flash, image-in)  │
                └────────────────────────────────┘
```

**What changes from today's architecture** (per `.planning/codebase/ARCHITECTURE.md`):

| Aspect | Today | v1.0 target |
|---|---|---|
| Folder layout | `lib/features/<name>/` (screen + viewmodel co-located) | `lib/presentation/screens/`, `lib/application/viewmodels/`, `lib/data/` (repos + services) |
| Gemini API key | `--dart-define` baked into iOS binary | Secret Manager, read by Cloud Function only |
| Points/badges writes | Client `FieldValue.increment` allowed by rules | Client cannot write `points`/`badges`/`history`; Firestore trigger writes them |
| Premium check | Read `/users/{uid}.subscriptionType == 'premium'` | Same, PLUS `request.auth.token.premium == true` custom claim for Function gating |
| Rate limiting | Client checks `/users/{uid}/usage/{today}.messageCount < 10` | Function checks it server-side (Admin SDK) and rejects over-limit |
| App attestation | None | App Check (App Attest provider on iOS) enforced on Callables, Firestore, Storage |
| Direct Firebase singleton access from VMs | `FirebaseAuth.instance` everywhere | Repository providers (`usersRepoProvider`, etc.) wrap the SDKs |

---

## 2. Component Responsibilities

| Component | Responsibility | Implementation |
|---|---|---|
| `lib/presentation/screens/<name>/` | Render UI, dispatch user intents to viewmodel via `ref.read(...)`. Zero Firebase imports. | `ConsumerWidget` / `ConsumerStatefulWidget` (unchanged from today, only path moves) |
| `lib/application/viewmodels/<name>_viewmodel.dart` | Own UI state, orchestrate repos/services. Zero direct `FirebaseAuth.instance` / `FirebaseFirestore.instance` calls. | `StateNotifier<TState>` (unchanged style; only the SDK calls move to repos) |
| `lib/data/repositories/` | Thin Firestore/Storage wrappers per collection. One file per aggregate root (`users_repo.dart`, `sessions_repo.dart`, `rewards_repo.dart`, `materials_repo.dart`, `notifications_repo.dart`). | Plain Dart classes exposing `Stream<T>` / `Future<T>`, exposed via `Provider<TRepo>` |
| `lib/data/services/mentor_bot_client.dart` | Client side of the Gemini proxy. Wraps `FirebaseFunctions.instance.httpsCallable('mentorBotChat')`. Streams tokens (or polls) and surfaces rate-limit errors as a typed `MentorBotException`. | Provider-scoped service |
| `lib/data/services/app_check_service.dart` | Single `activate()` call from `main()` to bring App Check up before any Firebase call that needs an attested context. | Provider-scoped service |
| `lib/data/models/` | Lift inline models (`DashboardUser`, `ChatMessage`, `MaterialItem`, `BadgeItem`, `SessionItem`) out of viewmodels so two features can share one model. | Plain Dart classes with `fromDoc` / `toMap` |
| `functions/src/index.ts` | Re-export all functions (callable + triggers) with explicit App Check + auth requirements set per export. | Firebase Functions v2 (TypeScript) |
| `functions/src/callables/mentor_bot.ts` | Receive `{ message, sessionId, subject, level, imageUrl? }`, verify auth + App Check, rate-limit via `/users/{uid}/usage/{today}`, call Gemini, return text. | `onCall` with `enforceAppCheck: true` |
| `functions/src/triggers/on_session_write.ts` | When a `/sessions/{sid}` is created or its `messageCount` crosses thresholds (1st message of day, 5th, 10th), idempotently award points by writing to `/rewards/{uid}` and mirroring `points` to `/users/{uid}` using a transaction. | `onDocumentWritten` Firestore trigger |
| `functions/src/triggers/on_user_create.ts` | Initialize `/rewards/{uid}`, set default custom claims (`{ role: 'student', premium: false }`). | `auth.user().onCreate` (v1) or Eventarc-style Identity Platform trigger (v2). Pick what's GA. |
| `functions/src/callables/set_premium.ts` | Admin-only callable that updates `/users/{uid}.subscriptionType` AND sets `setCustomUserClaims(uid, { ...existing, premium: true })`. | `onCall` with manual admin check on `request.auth.token.role == 'admin'` |
| Security rules | New invariant: clients cannot write `points`, `badges`, `history`, `streak`. Only Admin SDK (i.e., Functions) can. | `firestore.rules` update |

---

## 3. The `lib/` refactor — concrete recommendation

### Recommendation: **layered three-tier** (`presentation/` + `application/` + `data/`), NOT just `presentation/screens/`.

**Why**: The Active list in `PROJECT.md` says "refactor `lib/features/<name>/` → `lib/presentation/screens/<name>/`", but if you move screens without moving viewmodels, you end up with `presentation/screens/tutor/tutor_screen.dart` importing `features/tutor/chat_viewmodel.dart` — which keeps the awkward `features/` directory alive with only viewmodels in it, and makes the import graph ugly.

The existing `ARCHITECTURE.md` already documents two anti-patterns that this refactor is the natural moment to fix:
- "Inline data models inside ViewModels" → move to `lib/data/models/`
- "Direct Firebase singleton access from ViewModels" → introduce `lib/data/repositories/`

Doing those at the same time as the path move costs one extra commit per feature but saves a second pass later.

### Target layout

```
lib/
├── main.dart
├── firebase_options.dart
├── core/                              # unchanged (constants, theme, routes, utils)
│   ├── constants/
│   ├── routes/
│   ├── theme/
│   └── utils/
├── data/                              # NEW — Firebase boundary lives here
│   ├── models/
│   │   ├── app_user.dart              # was DashboardUser + User projection
│   │   ├── chat_message.dart
│   │   ├── material_item.dart
│   │   ├── session_item.dart
│   │   ├── badge_item.dart
│   │   └── rewards_snapshot.dart
│   ├── repositories/
│   │   ├── users_repository.dart
│   │   ├── sessions_repository.dart
│   │   ├── rewards_repository.dart
│   │   ├── materials_repository.dart
│   │   └── notifications_repository.dart
│   └── services/
│       ├── gemini_service.dart        # MOVED from lib/core/services/, now talks to Functions
│       ├── mentor_bot_client.dart     # httpsCallable wrapper
│       ├── app_check_service.dart
│       └── messaging_service.dart     # NEW — wires firebase_messaging
├── application/                       # NEW — viewmodels live here
│   └── viewmodels/
│       ├── auth_viewmodel.dart
│       ├── splash_viewmodel.dart
│       ├── onboarding_viewmodel.dart
│       ├── dashboard_viewmodel.dart
│       ├── chat_viewmodel.dart
│       ├── materials_viewmodel.dart
│       ├── search_viewmodel.dart
│       ├── profile_viewmodel.dart
│       ├── rewards_viewmodel.dart
│       ├── gamification_viewmodel.dart
│       └── notifications_viewmodel.dart
├── presentation/                      # NEW — only widgets, no Firebase imports
│   └── screens/
│       ├── splash/splash_screen.dart
│       ├── auth/login_screen.dart
│       ├── auth/register_screen.dart
│       ├── onboarding/onboarding_screen.dart
│       ├── dashboard/dashboard_screen.dart
│       ├── tutor/tutor_screen.dart
│       ├── materials/materials_screen.dart
│       ├── search/search_screen.dart
│       ├── profile/profile_screen.dart
│       ├── rewards/rewards_screen.dart
│       ├── notifications/notifications_screen.dart
│       └── admin/admin_screen.dart
└── shared/widgets/                    # finally populated (PremiumModal, BadgeOverlay, OfflineBanner)
```

### Hard rule enforced by the layout

- `presentation/` may import `application/`, `core/`, `shared/`. Never `data/`.
- `application/` may import `data/`, `core/`. Never `presentation/`.
- `data/` may import `core/`. Nothing else from `lib/`.

This breaks the current pattern where `lib/features/tutor/chat_viewmodel.dart` defines both `ChatMessage` (model) and `geminiServiceProvider` (service) in the same file — those two concerns split cleanly across `data/models/chat_message.dart` and `data/services/mentor_bot_client.dart`.

### Migration order (one feature at a time)

For each feature, in this order — splash → onboarding → auth → profile → dashboard → tutor → materials → search → rewards → notifications → admin:

1. Extract inline models into `lib/data/models/<entity>.dart`.
2. Extract direct `FirebaseFirestore.instance` calls into `lib/data/repositories/<feature>_repository.dart`. Expose `Stream<T>` / `Future<T>`. Add a `Provider<TRepo>`.
3. Move the viewmodel file to `lib/application/viewmodels/<feature>_viewmodel.dart`. Replace inline SDK calls with `ref.read(<feature>RepoProvider).method(...)`.
4. Move the screen file to `lib/presentation/screens/<feature>/<feature>_screen.dart`.
5. Update the corresponding `GoRoute` in `lib/core/routes/app_router.dart` (only the import path changes; route name/path/builder stay).
6. Run `flutter analyze` + the (new) smoke widget test for that screen — green before moving to the next feature.

**Why splash first**: it's the simplest screen and exercises the auth + routing path, so getting it right validates the layered import discipline before harder features. **Tutor last among the chat-relevant ones** because it depends on the new `MentorBotClient` which depends on Cloud Functions being deployed.

**Don't** do a big-bang rename via `git mv` of all 30 files at once — you'll spend two days in import-hell rebasing the rest of the milestone on top. Per-feature commits are cheap.

---

## 4. Cloud Functions architecture

### Recommendation

| Decision | Recommendation | Rationale |
|---|---|---|
| Location | `functions/` subfolder at repo root (monorepo) | Standard `firebase init functions` layout. Avoids a second repo + deploy pipeline for a solo dev. `firebase deploy` already deploys rules/indexes from this repo; adding `--only functions` is one flag. |
| Language | TypeScript | Type safety on request/response shapes for callables avoids client/server drift. `firebase-functions` ships first-class TS types; the seed script in `tool/seed/` already proves Node tooling works in this repo. |
| Generation | v2 only (no v1 functions in this milestone) | v2 is GA, supports concurrency, longer timeouts, finer region control, and Eventarc-based triggers. Avoid mixing generations. |
| Node runtime | Node 20 LTS, with an eye on bumping to Node 22 when officially supported in Firebase Functions v2 GA. *[LOW confidence on whether Node 22 is fully supported as of mid-2026 — verify in Firebase release notes before pinning.]* | Node 20 is the safe choice for a solo dev who doesn't want runtime-deprecation pressure during launch. |
| Invocation pattern | **Callable** (`onCall`) for everything client-initiated. **Firestore triggers** (`onDocumentWritten`) for event-driven server logic. **No raw HTTP** unless required by an external webhook (no requirement today). | Callables auto-pass the Firebase Auth ID token and the App Check token, enforce them with a single flag (`enforceAppCheck: true`, `cors: ...`), and the Flutter `cloud_functions` SDK has a typed `httpsCallable` API. Raw HTTP endpoints would re-implement auth + App Check verification by hand. |
| Region | Single region — `asia-south1` (Mumbai) | Closest GCP region with full Functions v2 + Firestore presence to Bangladesh users. Cuts cold-start round-trip vs. `us-central1` substantially. Match Firestore region (verify what region the existing `mentor-mind-aa765` project Firestore is in — if it's `nam5` or `us-central`, you're stuck with that for Firestore but you can still put Functions in `asia-south1`; cross-region Admin-SDK calls add ~150 ms — acceptable). |
| Secrets | Google Secret Manager (`defineSecret('GEMINI_API_KEY')`) | Built into Functions v2 — secrets are injected at runtime, never in source/repo, rotatable without redeploy. Replaces `--dart-define` for Gemini. |
| Concurrency | `concurrency: 80` (default) on `mentorBotChat` | Free tier is 10 chats/day/user. With ~1k DAU realistic in year 1, you'll never see >10 concurrent invocations. Default settings are fine; cost ceiling matters more. |

### `functions/` layout

```
functions/
├── package.json              # type: module, scripts: build/serve/deploy
├── tsconfig.json
├── .eslintrc.json
├── src/
│   ├── index.ts              # re-exports all entry points
│   ├── lib/
│   │   ├── admin.ts          # admin SDK singleton init
│   │   ├── gemini.ts         # @google/generative-ai wrapper, system prompt
│   │   ├── rate_limit.ts     # free-tier 10/day check
│   │   ├── claims.ts         # setCustomUserClaims helpers
│   │   └── errors.ts         # typed HttpsError factories
│   ├── callables/
│   │   ├── mentor_bot_chat.ts
│   │   ├── mentor_bot_analyze_image.ts
│   │   └── set_premium.ts
│   └── triggers/
│       ├── on_session_write.ts
│       ├── on_user_create.ts
│       └── on_user_delete.ts          # cleanup
└── test/
    └── (firebase-functions-test setup)
```

### Why callables over HTTPS for this app

| Concern | `onCall` (callable) | `onRequest` (raw HTTPS) |
|---|---|---|
| Auth | Auto-verified, `request.auth.uid` is ready | Manual `Authorization: Bearer` parse + `verifyIdToken()` |
| App Check | One-flag (`enforceAppCheck: true`) | Manual `X-Firebase-AppCheck` parse + verify |
| Client SDK | `FirebaseFunctions.instance.httpsCallable(...)` — typed, returns `HttpsCallableResult` | Manual `http` package call, manual JSON ser/de |
| Error model | `HttpsError(code, message, details)` mapped to platform exceptions | Manual status codes |
| Streaming | Limited (v2 supports `onCallStream` *[LOW confidence — verify availability and Flutter SDK support]*) | Easy with SSE / chunked |

The one place callables hurt is **streaming Gemini responses**. Two options:

1. **Non-streaming MVP**: send the message, wait for the full Gemini response, return it. Lose token-by-token UX but get a 10-line server implementation. Latency for short tutor answers is ~2-4 s — acceptable for v1.0.
2. **Server-side streaming via `onCallStream`** *[LOW confidence on Flutter SDK support]*: preserves the token-by-token UI from `ChatViewModel._updateMessage`. **Verify** that `cloud_functions: ^5.x` Flutter SDK supports `httpsCallable(...).stream()` before committing. If not, fall back to option 1.

**Recommendation**: ship v1.0 with option 1 (non-streaming). The visible cost is a typing indicator instead of a token stream — already in the spec (Screen 06). Add streaming in v1.1.

---

## 5. Data flow — the two critical paths

### Flow A — Tutor chat via Cloud Function proxy

```
TutorScreen (presentation)
   │  user taps Send
   ▼
ChatViewModel.sendMessage(text)                       (application)
   │  appends user msg + placeholder assistant msg to state
   │  flips isStreaming = true
   ▼
MentorBotClient.chat({sessionId, subject, level, text})  (data/services)
   │  await FirebaseAppCheck.instance.getToken()       ← happens transparently inside Firebase SDK on every callable
   │  httpsCallable('mentorBotChat').call({...})
   │
   ▼
[network — HTTPS, App Check header attached automatically by SDK]
   │
   ▼
mentorBotChat onCall (functions/src/callables/mentor_bot_chat.ts)
   │  1. request.auth     → verified by SDK
   │  2. request.app      → verified by SDK (enforceAppCheck: true)
   │  3. read /users/{uid}.subscriptionType — or read request.auth.token.premium claim
   │  4. read /users/{uid}/usage/{today}.messageCount
   │     ├─ if free && >= 10 → throw HttpsError('resource-exhausted', 'Daily limit reached')
   │     └─ else continue
   │  5. read /users/{uid}/usage/{today}.lastMessageAt — burst limit (e.g. ≥ 5/min throw)
   │  6. read GEMINI_API_KEY from Secret Manager
   │  7. call Gemini API (gemini-1.5-flash, system prompt from functions/src/lib/gemini.ts)
   │  8. write /users/{uid}/usage/{today} { messageCount: increment(1), lastMessageAt: now } (Admin SDK txn)
   │  9. write /sessions/{sid} { messages: arrayUnion(...), messageCount: inc(1), updatedAt: now }
   │ 10. return { text, sessionId, usageRemaining }
   ▼
MentorBotClient resolves with { text, sessionId, usageRemaining }
   │
   ▼
ChatViewModel._updateMessage(assistantMsg, text)
   │  state = state.copyWith(messages: ..., isStreaming: false, usageRemaining: ...)
   ▼
TutorScreen rebuilds (rate-limit banner appears if usageRemaining == 0)
```

**Key invariants enforced server-side:**

- Free-tier daily cap (10 messages) — moved from client to Function.
- Burst limit (e.g., max 5 msg / 60 s) — Function-only, can't be expressed in security rules.
- Gemini API key never reaches the device.
- Image uploads (premium) still go via `Storage` from the client (because uploading a 5 MB file through a Function is expensive); the Function receives the `gs://` URL, reads it via Admin SDK, sends bytes to Gemini.

**Rule changes to make this work** (`firestore.rules`):

- `/users/{uid}/usage/{date}` — **remove client write**, allow only `read` for owner. Admin SDK bypasses rules so Functions still write it.
- `/sessions/{sid}` — keep client read; **change client write to allow only `messages` deletion or `title` rename**; new messages are appended by the Function.
- Alternative (simpler migration): keep `/sessions` client-writable but make the Function the source of truth for `messageCount` and `messages[].id` integrity.

### Flow B — Server-authoritative rewards via Firestore trigger

The orchestrator question #3 asks: Eventarc/triggers vs client RPC. **Recommendation: Firestore trigger**, with two reasons:

1. The reward event is "a session was just written" — the Function gets the data for free as the trigger payload. A client RPC would re-send the same data.
2. Triggers are naturally idempotent if you key on the document state (e.g., "this session reached `messageCount == 1` for the first time"). A client RPC requires you to guard against client retries.

```
mentorBotChat onCall finishes writing /sessions/{sid}
   │
   ▼
[Eventarc — Firestore document.written event]
   │
   ▼
onSessionWrite trigger (functions/src/triggers/on_session_write.ts)
   │  event.data.before, event.data.after  ← snapshots
   │
   │  Logic (idempotent):
   │  ─ If !before.exists && after.exists:
   │      → first-session-of-the-day check via /users/{uid}/usage/{today}.loginRewarded
   │      → if not yet rewarded today, award +10 points (daily login)
   │
   │  ─ If before.messageCount < 1 && after.messageCount >= 1:
   │      → award +5 points (complete_session, once per session)
   │
   │  ─ Cumulative thresholds (5 sessions today → badge, etc.):
   │      → read /rewards/{uid}.history and dedupe by {date, type}
   │
   ▼
Transaction (Admin SDK):
   │  txn.update(/users/{uid},   { points: increment(N) })
   │  txn.update(/rewards/{uid}, { points: increment(N),
   │                               history: arrayUnion({type, points, at}) })
   │  txn.update(/users/{uid}/usage/{today}, { loginRewarded: true, ... })  // only if applicable
   ▼
GamificationViewModel (client) is watching /rewards/{uid} via stream
   ▼
badgeEarnedEventProvider fires → BadgeCelebrationOverlay shown by app shell
```

**Why this is better than client RPC for rewards specifically:**

- The trigger fires regardless of how the session was created — useful if you ever add an admin tool that creates sessions.
- The client doesn't need to know reward arithmetic — Function owns the policy.
- The client only **reacts** to `/rewards/{uid}` stream — no extra round-trip after sending a chat.

**Why this is worse than client RPC in general:**

- ~1-3 s latency between session write and reward update — the badge celebration overlay may show 2 s after the message lands. Acceptable for daily-login award; for in-chat awards the user is on the chat screen anyway.
- Trigger code must be carefully idempotent. Eventarc delivers **at-least-once** — duplicate trigger invocations are possible. Use a transaction with a "have I already awarded for this state?" check on `/rewards/{uid}.history`.

---

## 6. Premium gating — Firestore field vs custom claim

**Recommendation: dual-stored, with claims as the authority for Functions and Firestore field as the source for UI.**

| Layer | Source of truth | Why |
|---|---|---|
| UI gating (premium upgrade modal, image attach button enabled) | `/users/{uid}.subscriptionType` (Firestore field, already exists) | Real-time stream; UI updates in seconds when admin flips the field |
| Server-side gating in Cloud Functions (e.g., `mentorBotAnalyzeImage` requires premium) | `request.auth.token.premium` (custom claim) | Available in the ID token without a Firestore read — saves 1 round-trip per call. Also tamper-proof: only the Admin SDK can set claims. |
| Security rules gating writes that should be premium-only | Custom claim via `request.auth.token.premium == true` | Same — no extra `get()` cost in rules, which would otherwise count against billable reads. |

**How they stay in sync**: the `setPremium` callable does both writes in one transaction-equivalent:

```
1. db.doc(`users/${uid}`).update({ subscriptionType: 'premium' });
2. admin.auth().setCustomUserClaims(uid, { ...existing, premium: true });
3. return { ok: true };
```

The client then calls `await FirebaseAuth.instance.currentUser.getIdToken(/* forceRefresh */ true)` to pick up the new claim within seconds. *[MEDIUM confidence: claim propagation to clients is typically <1 minute without force refresh, or immediate with force refresh — verify exact behavior.]*

**Don't use claims as the *only* source**: claims are capped at ~1 KB per user, and a stream of `/users/{uid}` is what drives the existing profile/dashboard UI. Switching the UI to use claims would require a token-refresh loop on every user-doc change, which is awkward.

---

## 7. Rate limiting Gemini at server — cost ceiling

**Two layers:**

1. **Per-user daily cap** (the existing 10/day for free tier): stored at `/users/{uid}/usage/{YYYY-MM-DD}.messageCount`, checked by `mentorBotChat` Function before calling Gemini. Reject with `HttpsError('resource-exhausted', 'Daily limit reached. Upgrade to premium.')`.

2. **App-wide monthly ceiling** (cost guardrail): a single doc at `/system/quota/{YYYY-MM}.geminiCalls` incremented in the same transaction as the per-user usage. If it crosses a threshold (e.g., `BUDGET_USD * 1000` calls, since gemini-1.5-flash is ~$0.0001/short call), the Function returns `'unavailable'` and falls back to a stock message. **Plus** a GCP Billing budget alert at $X/month wired to your email — the in-app ceiling is the soft brake, billing alerts are the hard brake.

**Premium users**: skip the per-user daily cap but still count against the app-wide monthly ceiling. The premium tier promises "unlimited" but the global cap prevents a runaway loop from a buggy client.

**Where the limits live (concrete values to ship with):**

| Limit | Value | Location | Action when hit |
|---|---|---|---|
| Free-tier daily | 10 msg/user/day | `/users/{uid}/usage/{today}.messageCount` | Reject with rate-limit banner copy + upgrade modal |
| Burst | 5 msg/user/60 s | Same doc — check `lastMessageAt` | Reject with "Slow down" toast |
| App-wide monthly | Configurable, e.g. 50,000 calls/month | `/system/quota/{YYYY-MM}.geminiCalls` | Reject all users with "AI tutor temporarily unavailable", page admin |
| Per-message token cap | `maxOutputTokens: 1024` | Function config (Gemini request) | N/A — clamp |

---

## 8. Build order — which phase enables which

Because some components depend on others being live, this ordering matters. **The refactor is a no-runtime-dependency change and can run in parallel with backend work, but landing it FIRST means every subsequent change touches the new layout (cheaper).**

```
Phase 1 — lib/ refactor + CI baseline                  [PURE CLIENT, RUNNABLE]
   │  ─ Move features → presentation + application + data
   │  ─ Extract models, repositories
   │  ─ GitHub Actions: flutter analyze + flutter test on PR
   │  ─ Smoke widget test per screen
   │  ─ Fix avatar upload path mismatch (one-liner in profile_viewmodel)
   │
   ▼  Why first: every other phase edits viewmodels — landing the new layout
   │  first means later phases write to the new tree directly.
   │
Phase 2 — Functions scaffolding + App Check            [BLOCKING for Phase 3+]
   │  ─ firebase init functions (TypeScript, Node 20)
   │  ─ functions/src/index.ts + lib/admin.ts + lib/errors.ts
   │  ─ Deploy a no-op "ping" callable (App Check enforced) to verify wiring
   │  ─ Add firebase_app_check Flutter SDK
   │  ─ Activate App Check in main() with DEBUG provider for dev, AppAttest for release
   │  ─ Register debug token in Firebase Console for the simulator
   │  ─ Verify ping callable succeeds from device, fails without App Check token
   │
   ▼  Why this order: App Check MUST be live before any callable that
   │  enforces it, or every dev call fails. Get the plumbing green on a
   │  no-op function first.
   │
Phase 3 — Gemini proxy + rate limit                    [REPLACES IN-BINARY KEY]
   │  ─ functions/src/callables/mentor_bot_chat.ts
   │  ─ functions/src/lib/gemini.ts (system prompt moved server-side)
   │  ─ functions/src/lib/rate_limit.ts (free-tier check + burst + monthly ceiling)
   │  ─ Secret Manager: GEMINI_API_KEY
   │  ─ Client: lib/data/services/mentor_bot_client.dart replaces GeminiService.sendMessage
   │  ─ Remove --dart-define=GEMINI_API_KEY from build configs
   │  ─ firestore.rules: lock /users/{uid}/usage to read-only for client
   │
   ▼  Cuts the leak. App is runnable end-to-end — chat works through the proxy.
   │
Phase 4 — Server-authoritative rewards                 [LOCKS LEADERBOARD]
   │  ─ functions/src/triggers/on_session_write.ts (idempotent award)
   │  ─ functions/src/triggers/on_user_create.ts (init /rewards/{uid} + default claims)
   │  ─ firestore.rules: forbid client writes to /users.points, /users.badges,
   │      /rewards.points, /rewards.badges, /rewards.history
   │  ─ Remove client-side _awardPoints / FieldValue.increment('points') calls
   │  ─ Client just listens to /rewards/{uid} stream and reacts (badge overlay)
   │  ─ Verify with two devices that you can't pump leaderboard via debugger
   │
   ▼  Leaderboard is now trustworthy.
   │
Phase 5 — Premium + custom claims + Admin Panel        [COMPLETES SECURITY]
   │  ─ functions/src/callables/set_premium.ts (admin-only, sets claim + field)
   │  ─ Admin Panel screen — wire to setPremium callable
   │  ─ Premium gating in mentorBotAnalyzeImage uses request.auth.token.premium
   │  ─ Premium gating in UI uses /users.subscriptionType stream
   │  ─ Force-refresh ID token after admin flips premium so callable sees it
   │
   ▼
Phase 6 — FCM + Notifications wiring                   [UNBLOCKS PUSH]
   │  ─ lib/data/services/messaging_service.dart
   │  ─ APNs key + topic subscriptions
   │  ─ Optional: functions/src/callables/sendBroadcast.ts for admin
   │
   ▼
Phase 7 — UI polish per spec (Screens 01-12)           [MARKETABLE]
   │  ─ Brand-accurate splash, dashboard rings, tutor empty state, etc.
   │  ─ Shared widgets (PremiumModal, BadgeOverlay, OfflineBanner)
   │  ─ Lint debt burn-down (167 warnings)
```

**Key dependency chains** (the "X must precede Y" graph):

- **App Check setup (P2) precedes Gemini proxy (P3)** — `enforceAppCheck: true` would reject every dev request without it.
- **Refactor (P1) precedes Gemini proxy (P3)** — the new `MentorBotClient` belongs in `lib/data/services/`, which doesn't exist until P1 lands.
- **Gemini proxy (P3) precedes lint debt cleanup (P7)** — fixing lint while refactoring TS-bound code creates merge conflicts.
- **Server-side rewards trigger (P4) precedes locking down rules** — the rule lockdown must happen in the same deploy as the Function, or you brick existing client awards.
- **Custom claims (P5) precedes Admin Panel** — Admin Panel's "Grant premium" button calls the `setPremium` callable.

**What this means for the milestone shape:**

- Phases 1-5 are **infrastructure / contracts**. Each one ships a runnable app.
- Phases 6-7 are **product polish**. Each shipping a runnable, more-polished app.
- Don't put UI polish before the security fixes — you'll polish a UI that's about to change because the underlying API surface (callable vs direct SDK) changed.

---

## 9. CI — monorepo workflow

**Recommendation: single GitHub Actions workflow, two jobs (flutter, functions), separate triggers per path.**

```
.github/workflows/ci.yml
   ├── job: flutter
   │     triggers on: lib/**, test/**, pubspec.*, ios/**
   │     steps:
   │       - subosito/flutter-action@v2 (3.41.x)
   │       - flutter pub get
   │       - flutter analyze
   │       - flutter test --coverage
   │
   └── job: functions
         triggers on: functions/**
         steps:
           - actions/setup-node@v4 (Node 20)
           - cd functions && npm ci
           - npm run lint
           - npm run build  (tsc)
           - npm test        (firebase-functions-test)
```

**Why one workflow, two jobs**: the alternative — two separate workflows — duplicates the secret config, the status-check setup, and the PR comment. Two jobs with `paths:` filters give you fast PR feedback (touching only Dart skips the Node job) without doubling the YAML.

**Don't deploy from CI on every push** — manual `firebase deploy` from a dev Mac is fine for a solo dev and avoids the operational burden of service-account-in-CI. Add deploy automation in v1.1 if it becomes painful.

---

## 10. Anti-patterns to avoid

### Anti-pattern: Function does both `generateContent` AND awards points

**What people do**: Inside `mentorBotChat`, after the Gemini call, write to `/rewards/{uid}` directly.
**Why it's wrong here**: Couples chat success to rewards success — if the rewards txn fails, the user's chat appears broken even though Gemini answered. Also makes the function fatter and slower.
**Do this instead**: Function writes only `/sessions/{sid}` and `/users/{uid}/usage`. A separate `onSessionWrite` trigger handles rewards. Failure isolation is the whole reason event-driven architecture exists.

### Anti-pattern: Streaming Gemini through a callable that buffers fully on the server

**What people do**: Server collects the entire streamed Gemini response, then returns it as a single callable result, claiming "we'll add streaming later."
**Why it's wrong here**: If the response takes 15 s, the client thinks it failed (default callable timeout was 60 s but UX expectation is faster). Worse, you've paid the bandwidth twice — once from Gemini to Function, once from Function to client — without any UX benefit.
**Do this instead**: Either non-streaming with a typing indicator (acceptable for v1.0) or `onCallStream` with chunked delivery. Don't half-ass it.

### Anti-pattern: Letting client retry mean duplicate point awards

**What people do**: Client gets a network error from `mentorBotChat`, retries. The first request actually succeeded server-side but the response didn't reach the client. Now `/sessions/{sid}` has two near-identical message entries and `onSessionWrite` awards points twice.
**Why it's wrong here**: Points appear "free" to determined users — same gameability problem as the original client-side increment.
**Do this instead**: Client includes a deterministic `clientRequestId` (UUID generated before send) in the callable payload. Function uses it as the message ID and uses `set(..., { merge: true })` — duplicate request is a no-op. Trigger's idempotency check (`history` array dedupe by `clientRequestId`) prevents double-award.

### Anti-pattern: Putting `firebase_messaging` SDK init in a viewmodel

**What people do**: Wire FCM token registration inside `dashboard_viewmodel.dart` because that's where the user first lands.
**Why it's wrong here**: FCM needs to be alive globally, before any specific screen. Token must register on app start regardless of which screen mounts first.
**Do this instead**: `lib/data/services/messaging_service.dart` exposed as `Provider`, initialized in `main()` after Firebase init, before `runApp`. Use `ref.listen(messagingServiceProvider, ...)` from a top-level shell widget to surface foreground messages.

### Anti-pattern: Keeping security rules permissive "until Functions are ready"

**What people do**: Deploy the new `mentorBotChat` Function but leave the old client-side `_awardPoints` paths working "as fallback".
**Why it's wrong here**: Both paths active = the leaderboard remains gameable. The whole point of the migration is to make client-side rewards impossible.
**Do this instead**: In Phase 4, deploy the trigger AND the rule lockdown in the same `firebase deploy --only firestore:rules,functions`. Test the trigger with the rules already locked in the emulator before pushing.

---

## 11. Integration points

### External services

| Service | Integration | Notes |
|---|---|---|
| Google Generative AI (Gemini) | Server-side from Functions, `@google/generative-ai` Node SDK | Key in Secret Manager. Region for inference may differ from Function region — accept extra ~50 ms. |
| Google Sign-In | Unchanged — direct from client via `google_sign_in` | Native iOS config (`GoogleService-Info.plist` `CLIENT_ID` + `Info.plist` `CFBundleURLTypes`) still needs to land — listed in `PROJECT.md` Active. |
| Firebase App Check (App Attest) | Init in client `main()`, enforce on callables + Firestore + Storage | iOS 14+ required for App Attest. *[MEDIUM confidence — verify min iOS version in current Firebase SDK.]* Debug provider for dev. |
| Firebase Cloud Messaging | Client SDK init in `main()`, server send via `firebase-admin` from Functions | Currently 0 imports of `firebase_messaging` — full wire-up is one of the Active items. |
| Google Cloud Secret Manager | Read by Functions via `defineSecret('GEMINI_API_KEY')` in v2 | One-time `firebase functions:secrets:set GEMINI_API_KEY` per env. |

### Internal boundaries

| Boundary | Communication | Notes |
|---|---|---|
| `presentation/` ↔ `application/` | `ref.watch / ref.read / ref.listen` | One-way: presentation reads viewmodel state, calls notifier methods. Viewmodel never imports a widget. |
| `application/` ↔ `data/` | Repository / service `Provider`s | One-way: viewmodel reads `ref.read(usersRepoProvider).getUser(uid)`. Repository never imports a viewmodel. |
| `data/` ↔ Firebase SDKs | Direct (for managed services) or `httpsCallable` (for Functions) | Repositories own the SDK; viewmodels don't see `FirebaseFirestore.instance`. |
| Client ↔ Functions | `cloud_functions` SDK, callable invocation | App Check token attached automatically; auth token attached automatically. |
| Functions ↔ Firestore | Admin SDK (bypasses rules) | Triggers receive event payload; callables read/write directly. |
| Functions ↔ Gemini | HTTPS to `generativelanguage.googleapis.com`, key from Secret Manager | Single shared Gemini client per function instance (warm reuse). |
| Firestore ↔ Functions | Eventarc-delivered `document.written` events | At-least-once delivery; design triggers to be idempotent. |

---

## 12. Scaling considerations (for context, not action)

| Scale | Adjustment |
|---|---|
| 0-1k users (year 1) | Default Function concurrency, single region, free-tier Firestore. No changes needed. |
| 1k-10k users | Watch Function cold-starts on `mentorBotChat` — set `minInstances: 1` if p99 latency matters. Monitor `/system/quota` monthly. |
| 10k+ users | Split `mentorBotChat` and `mentorBotAnalyzeImage` into separate functions with separate scaling. Consider Firestore aggregation queries for leaderboard instead of reading every `/rewards/*` doc. |

---

## 13. Open questions for phase-specific research

These are deliberately deferred — flag them when the corresponding phase planning runs:

1. **Streaming callables**: Does `cloud_functions: ^5.x` Flutter SDK support `onCallStream`? If no, ship non-streaming for v1.0. *[Verify in Phase 3 planning.]*
2. **Firestore region**: What region is `mentor-mind-aa765` Firestore in? Determines whether Functions cross-region cost matters. *[Verify in Phase 2 planning.]*
3. **Node 22 in Firebase Functions v2**: Pin Node 20 LTS for safety; revisit Node 22 if it's officially supported by milestone end. *[Verify in Phase 2 planning.]*
4. **App Attest debug tokens on physical device**: Debug provider works in simulator; for TestFlight you need a real App Attest assertion which requires production signing. *[Verify in Phase 2 planning.]*
5. **`auth.user().onCreate` (v1) vs Identity Platform Eventarc trigger (v2)**: Pick whichever is GA when Phase 4 lands. *[Verify in Phase 4 planning.]*
6. **Custom claim propagation latency**: Confirm whether `getIdToken(true)` forces a fresh claim read or whether the server cache delays it by up to an hour. *[Verify in Phase 5 planning.]*

---

## Confidence summary

| Area | Confidence | Why |
|---|---|---|
| Layered refactor recommendation | HIGH | Direct read of existing `ARCHITECTURE.md` anti-patterns + import-graph analysis. Independent of external sources. |
| Callable vs HTTPS choice | HIGH | Well-established Firebase guidance and what the `cloud_functions` Flutter SDK exposes. |
| Monorepo `functions/` location | HIGH | Standard `firebase init functions` layout. |
| Node 20 vs Node 22 runtime support | LOW | Could not verify current supported runtimes in Firebase Functions v2 release notes. |
| Streaming callable Flutter SDK support | LOW | Could not verify; recommendation is to ship non-streaming for v1.0 and revisit. |
| Custom claim propagation timing | MEDIUM | Documented behavior is "<1 hr without force-refresh, immediate with"; should verify exact SDK behavior. |
| App Check + App Attest min iOS | MEDIUM | Historically iOS 14+; verify current minimum. |
| Eventarc trigger idempotency | HIGH | At-least-once delivery is documented; idempotency strategy is standard. |
| Region recommendation (asia-south1) | MEDIUM | Sound choice for Bangladesh users; depends on the existing Firestore region. |

**Overall confidence: MEDIUM.** Recommendations are architecturally sound and consistent with the existing codebase; specific version numbers and SDK-feature availability need a 15-minute verification pass before Phase 2 starts.
