# Phase 3: Gemini Proxy + Server-Side Rate Limiting - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-19
**Phase:** 03-gemini-proxy-server-side-rate-limiting
**Areas discussed:** Gemini SDK & API tier, mentorBotChat contract, Rate-limit state + session schema, Runtime + observability + retry, Rules + refactor + premium + PR sequencing, Testing + key rotation + migration

---

## Gemini SDK & API tier

### Model selection

| Option | Description | Selected |
|--------|-------------|----------|
| gemini-1.5-flash | Status quo — cheapest + fastest tier; multimodal; sufficient quality for O/A Level | |
| gemini-1.5-pro | Better reasoning; ~10× cost; ~2-3× latency | |
| gemini-2.x | Whichever current-generation flash-class model is GA in asia-south1 at execute time | |
| gemini-3.1-pro (user free-text) | Latest-generation Pro tier; researcher pins exact published model ID | ✓ |

**User's choice:** "gemini 3.1 pro" — interrupted the AskUserQuestion with the direct preference.
**Notes:** User explicitly chose Pro tier. Surfaced the cost implication (Pro ~10× flash) against Phase 2 D-15 $10/mo budget alert. User accepted; tension carried into Open Considerations.

### API tier

| Option | Description | Selected |
|--------|-------------|----------|
| Vertex AI | `@google-cloud/vertexai` + ADC; regional asia-south1; no API key; billing via GCP project | ✓ |
| Google AI Studio | `@google/generative-ai` + GEMINI_API_KEY in Secret Manager; global endpoint; ~200-500ms cross-region | |
| Direct REST | Hand-rolled fetch(); smallest dep but most boilerplate | |

**User's choice:** Vertex AI (Recommended for Pro).
**Notes:** Amends AI-01 — no Secret Manager dependency. AI-02 still applies (binary scrub + Studio key rotation).

### Prompt location

| Option | Description | Selected |
|--------|-------------|----------|
| Hardcoded TS const in gemini.ts | Versioned via git; redeploy to update; simplest | ✓ |
| Firestore doc /system/prompts/tutor-v1 | Hot-fix without redeploy; one Firestore read per call; more moving parts | |
| Firebase Remote Config | Push without redeploy; fetch-frequency limits; overkill for v1.0 | |

**User's choice:** Hardcoded TS const (Recommended).
**Notes:** AI-09 "can be updated without an app release" satisfied by Functions-only deploy.

### Prompt versioning

| Option | Description | Selected |
|--------|-------------|----------|
| Single versioned const + audit-logged changes | SYSTEM_PROMPT_VERSION = '1'; stamped on each session message | ✓ |
| No versioning — just edit and redeploy | Simpler; loses audit trail | |

**User's choice:** Single versioned const + audit (Recommended).

---

## mentorBotChat contract

### Image attachment flow

| Option | Description | Selected |
|--------|-------------|----------|
| Client uploads to Storage, passes URL | Server fetches bytes via Admin SDK; small callable payload | ✓ |
| Client base64-encodes inline | One round-trip; inflates payload by 33%; up to 10MB cap | |
| Hybrid (threshold) | Two code paths; marginal benefit | |

**User's choice:** Storage URL flow (Recommended).
**Notes:** Reuses Phase 1's `uploads/{uid}/{ts}.jpg` pattern.

### clientRequestId generation

| Option | Description | Selected |
|--------|-------------|----------|
| uuid v4 via `package:uuid` ^4.x | Standard UUID; new pubspec dep | ✓ |
| Built-in Random + timestamp | No new dep; non-standard format | |
| Server generates (client just sends text) | Breaks idempotency on network drop | |

**User's choice:** uuid v4 (Recommended).
**Notes:** UUID generated once per user send, reused on retry — critical for D-16 auto-retry idempotency.

### Error code disambiguation

| Option | Description | Selected |
|--------|-------------|----------|
| Distinct HttpsError codes per failure mode | resource-exhausted (daily + burst with details.reason), unavailable (monthly), unauthenticated (App Check), etc. | ✓ |
| Single resource-exhausted + structured details | Simpler code surface; richer details | |
| Numeric status codes in custom field | Throws away gRPC semantics | |

**User's choice:** Distinct codes (Recommended).
**Notes:** Burst overloaded onto `resource-exhausted` with `details.reason` to keep the daily-vs-burst client logic simple.

### Reply persistence

| Option | Description | Selected |
|--------|-------------|----------|
| Both: return text AND write message pair to /sessions/{sid}/messages/{mid} | Immediate UX + Phase 4 trigger fires on subcollection writes | ✓ |
| Write-only — client subscribes for assistant message | More reactive; adds Firestore read latency on top of Gemini | |
| Return-only — client writes message pair itself | Contradicts Phase 4 rules lockdown | |

**User's choice:** Both (Recommended).

---

## Rate-limit state + session schema

### Burst counter location

| Option | Description | Selected |
|--------|-------------|----------|
| Sibling field on /users/{uid}/usage/{today} | One doc; one transaction; one read+write | ✓ |
| Separate doc /users/{uid}/burst/current | Two reads per transaction; no real benefit | |
| In-memory in Function | Doesn't work — stateless instances | |

**User's choice:** Sibling field on daily doc (Recommended).
**Notes:** Rolling-timestamp array; transaction prunes + appends.

### Monthly ceiling number

| Option | Description | Selected |
|--------|-------------|----------|
| 5,000 calls/month — small launch buffer | ~$25-50/mo at Pro; breaches alert | |
| 10,000 calls/month — launch target | ~$50-100/mo at Pro; breaches alert | ✓ |
| 2,000 calls/month — stay under $10 budget | Very restrictive UX | |
| Tunable env var | MONTHLY_CALL_CEILING via defineString | (also adopted alongside) |

**User's choice:** 10,000 calls/mo. Also adopting the env-var-tunable mechanism for future raises.
**Notes:** Tension with Phase 2 D-15 budget alert captured in CONTEXT Open Considerations.

### Session schema

| Option | Description | Selected |
|--------|-------------|----------|
| Subcollection /sessions/{sid}/messages/{mid} | Unbounded growth; Phase 4 trigger fires per message | ✓ |
| Inline messages array on /sessions/{sid} | 1MB doc cap; harder delta detection | |
| Top-level /messages/{mid} with sessionId field | Extra index; loses locality | |

**User's choice:** Subcollection (Recommended).

### Message retention

| Option | Description | Selected |
|--------|-------------|----------|
| Forever — no auto-prune | Storage cost ~$0 at scale; PAY-08 history search depends on it | ✓ |
| Auto-prune after 30 days for free users | Cloud Scheduler complexity; matches PAY-08 7-day search | |
| Cap N messages per session | Hurts UX | |

**User's choice:** Forever for v1.0 (Recommended). Phase 7 may revisit.

---

## Runtime + observability + retry

### minInstances

| Option | Description | Selected |
|--------|-------------|----------|
| minInstances: 0 — cold-start tolerated | $0 baseline; ~2-4s cold start; warm within 15min window | ✓ |
| minInstances: 1 — always warm | $25/mo baseline; eliminates cold start; breaches budget | |
| minInstances: 0 + Cloud Scheduler ping cron every 5min | Hacky free workaround | |

**User's choice:** minInstances: 0 (Recommended).
**Notes:** Re-evaluate in Phase 7 if user feedback says "feels slow".

### Function runtime config

| Option | Description | Selected |
|--------|-------------|----------|
| Defaults that match 10s goal | timeout 60s, memory 512MiB, maxOutputTokens 1024, temp 0.7 | ✓ |
| Tighter cost ceiling | timeout 30s, memory 256MiB, maxOutputTokens 512 | |
| Conservative | timeout 60s, memory 1GiB, maxOutputTokens 2048 | |

**User's choice:** Defaults (Recommended). All exported as `MODEL_CONFIG` const from `gemini.ts`, versioned per D-04.

### Observability

| Option | Description | Selected |
|--------|-------------|----------|
| Per-call aggregate to /system/usage_log/{YYYY-MM-DD} | Daily totals queryable in Firebase Console | ✓ |
| Cloud Logging structured logs only | BigQuery sink needed for aggregates | |
| Both | Belt-and-suspenders | (logger also retained as default) |

**User's choice:** Aggregate doc + structured logs.

### Client retry policy

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-retry 2× exponential backoff on transient codes only | Reuses clientRequestId; idempotency dedupes | ✓ |
| No auto-retry — always surface | Worse UX; simpler code | |
| Auto-retry including resource-exhausted | Burns budget on quota errors | |

**User's choice:** Auto-retry 2× (Recommended).

---

## firestore.rules scope

| Option | Description | Selected |
|--------|-------------|----------|
| Minimum needed for AI-08 | /users/{uid}/usage/{date} read-only + /system/** server-only; sessions deferred to Phase 4 | ✓ |
| Full lockdown now | Also lock /sessions/{sid}/messages/{mid} server-side | |
| Test-only — harness scaffolded, lockdown deferred | Scaffolds rules-unit-testing only | |

**User's choice:** Minimum (Recommended).
**Notes:** Sessions + rewards lockdown is Phase 4's job (REWD-05, REWD-06).

---

## Refactor strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Single PR — atomic commits | Add repo → swap viewmodel → delete service → remove dep | ✓ |
| Two PRs with feature flag | Safer rollout; flag complexity | |
| Replace in place (keep GeminiService import) | Violates layered_imports | |

**User's choice:** Single PR (Recommended).
**Notes:** PR-3 in the 3-PR sequence.

---

## Premium-claim bypass

| Option | Description | Selected |
|--------|-------------|----------|
| Wire the check now | request.auth.token.premium → skip daily-cap | ✓ |
| Stub with TODO referencing Phase 5 | Explicit later edit | |
| Skip entirely | Phase 5 has to touch transaction logic later | |

**User's choice:** Wire now (Recommended).
**Notes:** Free no-op pre-Phase-5; locks the integration point cheaply.

---

## PR sequencing

| Option | Description | Selected |
|--------|-------------|----------|
| 3 PRs (server / rules / client+cleanup) | Matches Phase 2 cadence; binary scrub on PR-3 merge | ✓ |
| 2 PRs | Bigger PR-2; fewer review cycles | |
| 1 monolithic PR | Harder review | |
| 4 PRs (split server) | More sequencing overhead | |

**User's choice:** 3 PRs (Recommended).

---

## Testing strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Mock Vertex client at SDK boundary | GeminiClient interface + fake impl; CI uses fake | ✓ |
| Hit real Vertex in CI with separate test project | Real but costs $$$ | |
| Pure unit tests, manual integration | Less coverage | |

**User's choice:** Mock at SDK boundary (Recommended).
**Notes:** `npm run test:live` gated by env var for occasional real-Vertex checks; NOT in CI.

---

## Leaked-key rotation

| Option | Description | Selected |
|--------|-------------|----------|
| Rotate-via-Studio + document in BACKEND_SETUP.md | Manual revoke BEFORE PR-3 merges | ✓ |
| Rewrite git history (filter-repo) | Pointless once revoked; destructive | |
| Defer rotation | Doesn't satisfy AI-02 | |

**User's choice:** Rotate via Studio + document (Recommended).

---

## Existing chat history migration

| Option | Description | Selected |
|--------|-------------|----------|
| No migration needed | Current GeminiService is in-memory only | ✓ |
| Migration script | Re-write existing /sessions into new subcollection schema | |
| Drop existing data | Wipe on PR-3 merge | |

**User's choice:** No migration (likely correct; research must verify).
**Notes:** Research MUST grep `chat_viewmodel.dart` for set/add/update against `/sessions` — zero hits confirms.

---

## Email-verification gate (AUTH-02)

| Option | Description | Selected |
|--------|-------------|----------|
| Defer to Phase 7 | AUTH-02 belongs to Phase 7 polish | ✓ |
| Wire server-side check now | Belt-and-suspenders; crosses phase boundary | |

**User's choice:** Defer to Phase 7 (Recommended).
**Notes:** Stays within phase scope.

---

## Claude's Discretion

- TypeScript style choices beyond Phase 2 prettier defaults.
- Concrete shape of `MentorBotRepository.sendMessage()` Dart signature beyond the core fields.
- Where in `pubspec.yaml` `uuid: ^4.x` is added (alphabetical in `dependencies:` block).
- Whether `MentorBotRepository` exposes a `Result<T, E>` wrapper or throws `FirebaseFunctionsException` (default: throws — matches `PingRepository`).
- Concrete error-banner copy for TUTR-02 (Phase 7's UI polish — Phase 3 only defines error semantics).
- Whether to add a fallback Gemini model if `gemini-3.1-pro` isn't GA in asia-south1 at execute time (researcher decides; surface as CONTEXT amendment if needed).
- Test fixture mechanics for seeding `/system/quota/{YYYY-MM}` at ceiling (likely `tool/test-fixtures/seed-quota-at-ceiling.ts`).

## Deferred Ideas

- Streaming chat responses (AI-10 explicit defer to v1.1).
- Per-user monthly usage analytics dashboard (Phase 5 Admin Panel).
- Auto-prune old messages for free users (Phase 7).
- Routing premium users to a different Pro variant (Phase 5 amendment).
- A/B testing system prompts via Remote Config (Phase 7).
- Migrating from Vertex AI back to Google AI Studio (open option if cost comparison shifts).
- Belt-and-suspenders email-verification server-side check (Phase 7 AUTH-02).
- Session subcollection lockdown in firestore.rules (Phase 4).
- Git history scrub of the leaked Google AI Studio key (rejected — revoked key is no more sensitive than a known string).

## Open Considerations (carried into planning)

- **Budget alert tension (Phase 2 D-15 vs Phase 3 D-01 + D-10):** Pro × 10,000 calls/mo breaches the $10/mo alert. Default path: raise the alert to $50/mo pre-emptively and document in BACKEND_SETUP.md. NOT a Phase 3 plan task — solo dev manual gcloud invocation; CONTEXT flags it.
- **`gemini-3.1-pro` GA in asia-south1:** researcher MUST verify and pin the exact published model ID. If not GA, fall back to whichever current-gen Pro-class model IS GA (likely 2.x-pro or 1.5-pro). Surface as CONTEXT amendment.
