---
phase: 3
slug: gemini-proxy-server-side-rate-limiting
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-19
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `03-RESEARCH.md` § Validation Architecture (lines 1015–1083).
> Status: **draft** — `gsd-planner` will translate each row below into one or more `<task>` entries inside the matching PLAN.md and copy the `Automated Command` into the task's `<verify>` / `<acceptance_criteria>` block. Mark `nyquist_compliant: true` once every row has a green automated gate (or an explicit manual-evidence escape hatch documented in BACKEND_SETUP.md).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (SDK) + `integration_test` (SDK) for Dart. Node 20 + Jest (NEW in Phase 3 via `npm install --save-dev jest @types/jest ts-jest`) + `@firebase/rules-unit-testing ^5.0.1` for TypeScript unit + rules tests. |
| **Config file** | Existing: `dart_test.yaml`, `functions/tsconfig.json`, `functions/.eslintrc.js`. NEW in Phase 3: `functions/jest.config.js` (ts-jest preset). |
| **Quick run command (Dart)** | `flutter analyze --no-fatal-infos && dart run custom_lint` |
| **Quick run command (TS)** | `(cd functions && npm run lint && npm run build && npm test)` |
| **Full suite command** | `flutter test --coverage && dart run custom_lint && (cd functions && npm run lint && npm run build && npm test)` |
| **Rules test command** | `FIRESTORE_EMULATOR_HOST=localhost:8080 (cd functions && npm test -- --testPathPattern=rules)` |
| **Integration command** | `firebase emulators:start --only auth,firestore,storage,functions` (separate terminal) **then** `flutter test integration_test/mentor_bot_smoke_test.dart --dart-define=USE_EMULATOR=true -d <device>` |
| **Estimated runtime** | ~25 s Dart quick · ~30 s TS quick (incl. Jest cold) · ~140 s full suite (~110s P2 baseline + ~30s `npm test`) |

---

## Sampling Rate

- **After every task commit:** Run the matching quick command for the layer touched:
  - Dart task → `flutter analyze --no-fatal-infos && dart run custom_lint`
  - TypeScript task → `(cd functions && npm run lint && npm run build && npm test)` (Jest is now CI-relevant — added by PR-1 Wave 0)
  - Rules-only edit → `FIRESTORE_EMULATOR_HOST=localhost:8080 (cd functions && npm test -- --testPathPattern=rules)`
  - Config-only task (e.g. `firebase.json`, `.github/workflows/ci.yml`) → boot smoke OR `act` local run
- **After every plan wave:** Full quick suite (Dart + TS combined).
- **Before `/gsd:verify-work`:** Full suite + `mentor_bot_smoke_test.dart` against emulator must be green.
- **Max feedback latency:** 140 s (full suite).

> **Why `--no-fatal-infos` not `--fatal-infos`** (inherited from Phase 1): ~104 `withOpacity` info-level warnings remain pending the Phase 7 burndown. Phase 3 does not alter that gate.

---

## Per-Plan Verification Map

> Plan slugs below are the **requirement-to-test map** the planner must turn into concrete task rows. PR boundaries (PR-1 server / PR-2 rules / PR-3 client+cleanup) follow D-20 from `03-CONTEXT.md`. Each row already has an automated command except where marked **Manual**.

| Plan slug (planned) | PR | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---|---|---|---|---|---|---|---|---|---|
| 03-01-jest-harness-bootstrap | PR-1 | 1 | (infra) | — | Jest configured, ts-jest preset, `npm test` script wires into CI from Phase 2 D-20 | static + build | `test -f functions/jest.config.js && grep -q '"test"' functions/package.json && (cd functions && npm test -- --listTests 2>&1 \| grep -q 'test')` | ❌ Wave 0 (PR-1) | ⬜ pending |
| 03-02-quota-shared-constant | PR-1 + PR-3 | 1 | AI-04 | — | `QUOTA_TZ = 'Asia/Dhaka'` lives in BOTH `functions/src/lib/quota.ts` AND `lib/core/constants/quota.dart`; Dhaka day-key computed via `Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Dhaka' })` (TS) and `intl` package (Dart); NEVER raw `toISOString().slice(0,10)` (PITFALLS #3) | static + unit | `grep -q "'Asia/Dhaka'" functions/src/lib/quota.ts && grep -q "Asia/Dhaka" lib/core/constants/quota.dart && (! grep -rE 'toISOString\(\)\.slice' functions/src lib) && (cd functions && npm test -- --testPathPattern=quota)` | ❌ Wave 0 (PR-1 + PR-3) | ⬜ pending |
| 03-03-vertex-gemini-client | PR-1 | 2 | AI-01, AI-09, AI-10 | T-3-PROMPT-INJECTION | `@google-cloud/vertexai ^1.12.0` installed; `GeminiClient` interface in `functions/src/lib/gemini.ts`; `VertexGeminiClient` impl uses `getGenerativeModel({ model: <pinned-id>, generationConfig, safetySettings })` with `SYSTEM_PROMPT` const + `SYSTEM_PROMPT_VERSION = '1'`; NO `generateContentStream` calls (AI-10 non-streaming); `FakeGeminiClient` returns canned response for unit tests; `makeGeminiClient` factory selects on `GEMINI_CLIENT_MODE` env var | static + unit | `grep -q 'GeminiClient' functions/src/lib/gemini.ts && grep -q 'SYSTEM_PROMPT' functions/src/lib/gemini.ts && grep -q 'SYSTEM_PROMPT_VERSION' functions/src/lib/gemini.ts && (! grep -E 'generateContentStream\|async\*' functions/src/lib/gemini.ts) && node -e "require('@google-cloud/vertexai')" && (cd functions && npm test -- --testPathPattern=gemini)` | ❌ Wave 0 (PR-1) | ⬜ pending |
| 03-04-model-availability-checkpoint | PR-1 | 2 | AI-01 | — | Executor verifies `gemini-3.1-pro` is GA in `asia-south1` via a direct Vertex API call BEFORE PR-1 merges; if not GA, falls back to `gemini-2.5-pro` then `gemini-1.5-pro`; pinned model ID committed to `gemini.ts` matches what the Vertex API actually accepts | manual + smoke | `node functions/tool/verify-model-availability.js` (one-shot script that calls Vertex with the pinned model ID; exits 0 if model resolves, 1 if "Model not found") | ❌ Wave 0 (PR-1) | ⬜ pending |
| 03-05-rate-limit-transaction | PR-1 | 2 | AI-04, AI-05, AI-06, AI-07 | T-3-QUOTA-TAMPERING | `functions/src/lib/rate_limit.ts` implements `checkAndIncrement(uid, kind, isPremium, clientRequestId)` using `runTransaction`: 1 read on `/users/{uid}/usage/{Dhaka-date}` + 1 read on `/system/quota/{YYYY-MM}` + writes daily counter + monthly counter + idempotency check; rejects with distinct HttpsError codes per D-07; premium bypasses daily but burst+monthly apply; uses `Timestamp.now()` (not `FieldValue.serverTimestamp()`) inside transaction value-writes per Pitfall #4 | unit | `(cd functions && npm test -- --testPathPattern=rate_limit)` covers: daily quota exhaustion, image vs text count separation, burst limit 5/60s, monthly ceiling 10,000, premium bypass, transaction atomicity | ❌ Wave 0 (PR-1) | ⬜ pending |
| 03-06-mentorbot-callable | PR-1 | 3 | AI-01, AI-07, AI-10 | T-3-APPCHECK-BYPASS, T-3-AUTH-MISSING | `functions/src/index.ts` exports `mentorBotChat` as `onCall({region: 'asia-south1', enforceAppCheck: true, timeoutSeconds: 60, memory: '512MiB'}, handler)`; handler validates `request.auth.uid` (throws `unauthenticated` if missing); validates `clientRequestId` format (UUIDv4 regex); checks idempotency cache (read `/sessions/{sid}/messages/{clientRequestId}`) BEFORE calling rate_limit; pattern: rate_limit transaction → Gemini call (AFTER transaction commits) → write assistant message doc in follow-up `set()`; returns `{ text, promptTokens, completionTokens, messageId, createdAt }` | static + unit + integration | `grep -q "export const mentorBotChat" functions/src/index.ts && grep -q "enforceAppCheck: true" functions/src/index.ts && grep -q "region: 'asia-south1'" functions/src/index.ts && (cd functions && npm test -- --testPathPattern=idempotency) && (cd functions && npm run build && node -e "const m=require('./lib/index.js'); if(!m.mentorBotChat) throw new Error('not exported')")` | ❌ Wave 0 (PR-1) | ⬜ pending |
| 03-07-usage-log-observability | PR-1 | 3 | (D-15 observability) | — | Per-call non-transactional `update` to `/system/usage_log/{YYYY-MM-DD}` with `{ calls: +1, promptTokens: +N, completionTokens: +N, estimatedCostUsd: +N }`; structured `functions.logger.info({ event: 'gemini_call', uid, promptTokens, completionTokens, estimatedCostUsd, durationMs })` per call; aggregate write happens AFTER the user-quota transaction commits so contention doesn't block | static + unit | `grep -q "usage_log" functions/src/index.ts && grep -q "logger.info" functions/src/index.ts && (cd functions && npm test -- --testPathPattern=usage_log)` | ❌ Wave 0 (PR-1) | ⬜ pending |
| 03-08-backend-setup-vertex-keyrotation | PR-2 | 4 | AI-02 | T-3-KEY-LEAK | BACKEND_SETUP.md gets `## Phase 3 — Vertex AI + Key Rotation` section documenting: (1) enable Vertex AI API + grant `roles/aiplatform.user` to Functions SA, (2) MANUAL leaked Google AI Studio key rotation at https://aistudio.google.com/apikey BEFORE PR-3 merges, (3) raise Phase 2 D-15 budget alert to $75/mo, (4) `MONTHLY_CALL_CEILING` env-var tunable | static | `grep -q 'Phase 3 — Vertex AI + Key Rotation' BACKEND_SETUP.md && grep -q 'aiplatform.user' BACKEND_SETUP.md && grep -q 'aistudio.google.com/apikey' BACKEND_SETUP.md && grep -q '75' BACKEND_SETUP.md && grep -q 'MONTHLY_CALL_CEILING' BACKEND_SETUP.md` (manual gcloud execution by solo dev verified post-merge) | ❌ Wave 0 (PR-2) | ⬜ pending |
| 03-09-firestore-rules-lockdown | PR-2 | 4 | AI-08 | T-3-QUOTA-TAMPERING, T-3-SYSTEM-LEAK | `firestore.rules` adds three path locks per D-17: `/users/{uid}/usage/{date}` read-only-for-owner client write blocked, `/system/quota/{YYYY-MM}` server-only no client access, `/system/usage_log/{YYYY-MM-DD}` server-only no client access; existing rules preserved | static + rules-unit | `grep -q '/users/{uid}/usage/' firestore.rules && grep -q '/system/' firestore.rules && FIRESTORE_EMULATOR_HOST=localhost:8080 (cd functions && npm test -- --testPathPattern=rules)` | ❌ Wave 0 (PR-2) | ⬜ pending |
| 03-10-uuid-and-quota-dart | PR-3 | 5 | AI-04, AI-07 | — | `pubspec.yaml` adds `uuid: ^4.5.3`; `lib/core/constants/quota.dart` exports `kQuotaTimezone = 'Asia/Dhaka'` and `String dhakaDateKey(DateTime now)` helper using `intl`; Dart-side day-key matches TS-side day-key for the same instant (cross-language behavioral test); `Uuid().v4()` used to generate `clientRequestId` on every user send | static + unit | `grep -q 'uuid:' pubspec.yaml && test -f lib/core/constants/quota.dart && grep -q 'Asia/Dhaka' lib/core/constants/quota.dart && flutter test test/core/constants/quota_test.dart && (! grep -rE "toIso8601String\(\)\.substring" lib)` | ❌ Wave 0 (PR-3) | ⬜ pending |
| 03-11-mentor-bot-repository | PR-3 | 5 | AI-01, AI-07 | T-3-LAYER-BREACH | `lib/data/repositories/mentor_bot_repository.dart` exposes `Future<MentorBotResponse> sendMessage({sessionId, clientRequestId, message, imageUrl?, subject?, level?})` wrapping `httpsCallable('mentorBotChat').call(...)`; `mentor_bot_response.dart` model with safe-cast `fromMap`; `mentorBotRepositoryProvider` mirrors `pingRepositoryProvider`; `cloud_functions` import confined to `lib/data/` per `custom_lint` `layered_imports` rule; viewmodel DOES NOT import `cloud_functions` directly | static + lint + unit | `test -f lib/data/repositories/mentor_bot_repository.dart && test -f lib/data/models/mentor_bot_response.dart && grep -q 'firebaseFunctionsProvider' lib/data/repositories/mentor_bot_repository.dart && dart run custom_lint && flutter test test/data/repositories/mentor_bot_repository_test.dart` | ❌ Wave 0 (PR-3) | ⬜ pending |
| 03-12-chat-viewmodel-swap | PR-3 | 5 | AI-02, AI-03, AI-10 | T-3-LAYER-BREACH | `chat_viewmodel.dart` swapped from `_geminiService` → `_mentorBotRepository`; `_history` removed; streaming code paths removed (AI-10); `lib/core/services/gemini_service.dart` DELETED; `google_generative_ai` REMOVED from `pubspec.yaml`; `--dart-define=GEMINI_API_KEY` REMOVED from .vscode/launch.json, .github/workflows/ci.yml, README run instructions, BACKEND_SETUP.md; iOS binary rebuilt scrubs the leaked key | static + analyze + build | `test ! -f lib/core/services/gemini_service.dart && (! grep -q 'google_generative_ai' pubspec.yaml) && (! grep -rE 'GEMINI_API_KEY' .vscode/launch.json .github/workflows/ci.yml 2>/dev/null) && grep -q '_mentorBotRepository\|MentorBotRepository' lib/application/viewmodels/tutor/chat_viewmodel.dart && (! grep -E 'generateContentStream\|await for' lib/application/viewmodels/tutor/chat_viewmodel.dart) && flutter analyze --no-fatal-infos && dart run custom_lint && flutter build ios --no-codesign` | ❌ Wave 0 (PR-3) | ⬜ pending |
| 03-13-mentor-bot-smoke-test | PR-3 | 6 | AI-01, AI-07, AI-10 | — | `integration_test/mentor_bot_smoke_test.dart` mirrors `ping_smoke_test.dart` pattern: `@Tags(['emulator', 'integration'])` + `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` + `configureEmulators()` + invokes `MentorBotRepository.sendMessage(...)` against the Functions emulator (which is configured with `GEMINI_CLIENT_MODE=fake` so no real Vertex calls); asserts response shape `{text, promptTokens, completionTokens, messageId, createdAt}`; asserts retry with same `clientRequestId` returns SAME `messageId` (idempotency live test) | integration | `firebase emulators:start --only auth,firestore,storage,functions &` (background) **then** `GEMINI_CLIENT_MODE=fake flutter test integration_test/mentor_bot_smoke_test.dart --dart-define=USE_EMULATOR=true -d <device>` | ❌ Wave 0 (PR-3) | ⬜ pending |
| 03-14-ci-npm-test-step | PR-3 | 6 | (infra) | — | `.github/workflows/ci.yml` `functions:` job adds `npm test` step AFTER `npm run build`; path-filter on `functions/**` from Phase 2 D-20 preserved; existing `flutter:` job untouched | static + CI | `grep -q 'npm test' .github/workflows/ci.yml && grep -q 'functions:' .github/workflows/ci.yml && (! grep -E 'if:\s*false' .github/workflows/ci.yml)` (and green CI run on PR-3 commit) | ❌ Wave 0 (PR-3) | ⬜ pending |
| 03-15-phase-closeout | — | 7 | (all AI-*) | — | Phase 3 SUMMARY notarizes which AI-* IDs green vs deferred; updates 03-VALIDATION.md to `status: closed` + `nyquist_compliant: true`; ROADMAP.md Phase 3 marked complete; REQUIREMENTS.md AI-01..AI-10 marked Complete; STATE.md advances to Phase 4 | manual + static | `gsd-sdk query check.coverage 3 --include-decisions` (must return 100% covered) and `grep -q 'nyquist_compliant: true' .planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md` | — | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky · ⏸ blocked (model GA, billing raise)*

> Planner MUST translate each row into one or more `<task>` entries inside the matching PLAN.md and copy the `Automated Command` into the task's `<verify>` / `<acceptance_criteria>` block.

---

## Wave 0 Requirements

> Items the planner MUST schedule before any verifiable acceptance criterion fires.

**PR-1 (server function + tests):**
- [ ] `functions/jest.config.js` — NEW (ts-jest preset)
- [ ] `functions/package.json` — add `@google-cloud/vertexai: ^1.12.0`, devDeps `jest`, `@types/jest`, `ts-jest`, `@firebase/rules-unit-testing: ^5.0.1`; script `"test": "jest"`
- [ ] `functions/src/lib/quota.ts` — NEW (`QUOTA_TZ`, `getDhakaDateKey`, `monthKey`)
- [ ] `functions/src/lib/gemini.ts` — FILL (replaces Phase 2 stub)
- [ ] `functions/src/lib/rate_limit.ts` — FILL (replaces Phase 2 stub)
- [ ] `functions/src/index.ts` — ADD `mentorBotChat` export alongside existing `ping`
- [ ] `functions/src/__tests__/quota.test.ts`, `rate_limit.test.ts`, `gemini.test.ts`, `idempotency.test.ts`, `usage_log.test.ts` — NEW unit tests
- [ ] `functions/tool/verify-model-availability.js` — NEW one-shot Vertex model-resolve smoke (executor runs before pinning the model ID in gemini.ts)

**PR-2 (rules + tests + docs):**
- [ ] `firestore.rules` — three path lock insertions per D-17
- [ ] `functions/src/__tests__/rules.test.ts` — NEW rules tests for AI-08
- [ ] `BACKEND_SETUP.md` — append `## Phase 3 — Vertex AI + Key Rotation` section (gcloud IAM + key rotation + budget raise + MONTHLY_CALL_CEILING)

**PR-3 (client swap + cleanup):**
- [ ] `pubspec.yaml` — add `uuid: ^4.5.3`; remove `google_generative_ai: ^0.4.6`
- [ ] `lib/core/constants/quota.dart` — NEW
- [ ] `lib/data/repositories/mentor_bot_repository.dart` — NEW
- [ ] `lib/data/models/mentor_bot_response.dart` — NEW
- [ ] `lib/features/tutor/chat_viewmodel.dart` (or wherever the viewmodel lives post-Phase-1 D-02 refactor; verify path) — SWAP to repository
- [ ] `lib/core/services/gemini_service.dart` — DELETE
- [ ] `.vscode/launch.json`, `.github/workflows/ci.yml`, README, BACKEND_SETUP.md — remove `--dart-define=GEMINI_API_KEY` everywhere
- [ ] `integration_test/mentor_bot_smoke_test.dart` — NEW
- [ ] `.github/workflows/ci.yml` `functions:` job — ADD `npm test` step

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `gemini-3.1-pro` GA in `asia-south1` | AI-01 | No CLI verb queries regional GA at research time; requires live API call | Executor runs `node functions/tool/verify-model-availability.js` against the live Vertex API in the user's project. If `gemini-3.1-pro` returns "Model not found", fall back to `gemini-2.5-pro` (next-most-recent Pro). Document the resolved model ID in PR-1 description. |
| Leaked Google AI Studio key revoked | AI-02 | Solo dev opens https://aistudio.google.com/apikey and clicks revoke | Manual step BEFORE PR-3 merges. PR-3 description has checkbox `- [ ] Leaked key revoked in Studio`. Documented in BACKEND_SETUP.md §Phase 3. |
| Vertex AI API enabled + Functions SA granted `roles/aiplatform.user` | AI-01 | One-shot `gcloud services enable` + `gcloud projects add-iam-policy-binding` from solo dev's machine | Manual step BEFORE PR-1 deploys to production. Documented in BACKEND_SETUP.md §Phase 3. |
| Phase 2 D-15 budget alert raised to $75/mo | (D-15 cost tension carried from Phase 2) | One-shot `gcloud billing budgets update` from solo dev's machine; or update via Console | Manual step BEFORE PR-1 merges. Documented in BACKEND_SETUP.md §Phase 3. Required because Pro × 10k calls ~= $52/mo per RESEARCH cost analysis. |
| End-to-end on real device (Vertex prod path) | AI-10 | Functions emulator uses `GEMINI_CLIENT_MODE=fake` so the integration test exercises the wiring, not the real Vertex call | Deferred to Phase 7 or to a manual post-PR-3 smoke (`flutter run -d <device>` → log in → send a real chat message → confirm response in <10s; verify no `GEMINI_API_KEY` in the binary via `strings build/ios/Release-iphoneos/Runner.app/Runner \| grep -i AIza`). |

---

## Open Questions (blocking nyquist_compliant: true)

**Q-1 (BLOCKING for AI-01, surfaced in Plan 03-04 as checkpoint:human-verify).** `gemini-3.1-pro` GA in `asia-south1` is UNVERIFIED at research time. Researcher recommends executor run a one-shot Vertex API call BEFORE PR-1 merges to confirm the model ID resolves. Fallback chain: `gemini-3.1-pro` → `gemini-2.5-pro` → `gemini-1.5-pro`. Whichever resolves becomes the pinned model ID in `gemini.ts`. PR-1 description records the resolved ID + the fallback decision (if any).

**Q-2 (deferred to Phase 4).** Whether to remove the existing client-side `_awardPoints('complete_session')` call from `chat_viewmodel.dart` in PR-3 or defer to Phase 4 (rewards lockdown). Recommendation: defer to Phase 4 — REWD-04 explicitly owns client-side increment removal.

**Q-3 (Claude's discretion).** Client vs server `sessionId` generation. Research recommends client pre-generates via `Uuid().v4()` when starting a new chat session; client passes `sessionId` to `mentorBotChat`. Server treats it as opaque. Locked in CONTEXT D-CONTEXT discretion list.

---

## Validation Sign-Off

- [ ] All planner-generated tasks have `<verify>` automated commands OR a Wave 0 dependency
- [ ] Sampling continuity: no 3 consecutive tasks without an automated verify command
- [ ] Wave 0 covers all `❌ W0` references above
- [ ] No watch-mode flags in any verify command (CI must be one-shot)
- [ ] Feedback latency < 140 s for full suite
- [ ] `uuid ^4.5.3` + (gemini-3.1-pro OR gemini-2.5-pro fallback) resolved cleanly under existing version constraints
- [ ] `functions/package-lock.json` updated to include `@google-cloud/vertexai` + Jest deps; `npm ci` exits 0 in CI
- [ ] Manual gates documented in BACKEND_SETUP.md §Phase 3 (model verification + key rotation + Vertex IAM + budget raise)
- [ ] `nyquist_compliant: true` set in this frontmatter once every row turns ✅ (or is explicitly ⏸ with a Phase 5+ follow-up entry in STATE.md)

**Approval:** pending (draft)

> **nyquist_compliant note (forward-looking):** Phase 3 has 4 categories that may legitimately remain ⏸ at close: (i) model-availability checkpoint (resolved during PR-1 execution); (ii) leaked-key rotation (manual Studio click); (iii) Vertex IAM grant (manual gcloud); (iv) budget alert raise (manual gcloud). All four have static automated gates (grep on BACKEND_SETUP.md + Function deploy success) so nyquist condition can still be met — live device + live Vertex verification is additional assurance carried forward to Phase 5+ follow-ups.
