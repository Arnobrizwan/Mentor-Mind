# Project Research Summary

**Project:** MentorMinds v1.0 (hardening + 12-screen polish milestone)
**Domain:** Flutter + Firebase iOS AI-tutoring app for O/A Level (Cambridge/Edexcel) students in Bangladesh
**Researched:** 2026-05-17
**Confidence:** MEDIUM overall (HIGH on codebase-grounded findings, MEDIUM on Firebase/Functions/SDK version specifics — web search and Context7 were unavailable; flag for re-verification before Phase 2)

> Source files (full detail): `.planning/research/{STACK,FEATURES,ARCHITECTURE,PITFALLS}.md` + `.planning/PROJECT.md`

---

## Executive Summary

MentorMinds today is a feature-complete *skeleton*: all 12 screens render, Gemini chat streams, rewards exist — but the app is not launchable. Three blockers dominate: the Gemini API key ships in the iOS binary, the leaderboard accepts client-side `FieldValue.increment('points')` (trivially gameable), and FCM is declared in `pubspec.yaml` but never imported. The v1.0 milestone is therefore a **hardening + polish pass**, not a build-from-zero project. Four independent research dimensions converge on the same answer: **fix the trust boundary before polishing the UI on top of it**, because every polished screen sits on top of a contract (callable vs direct SDK, server-authored points, App-Check-protected reads) that is about to change.

The recommended approach is a **seven-phase, dependency-ordered** sequence (refactor + CI → Functions skeleton + App Check → Gemini proxy → server-authoritative rewards → premium claims + Admin Panel → FCM → UI polish). Each phase ships a runnable app; UI polish is deliberately last so it isn't re-done when the API surface changes underneath. The stack additions are conservative — Cloud Functions Gen-2 on Node 20 (TypeScript), Firebase App Check (App Attest + DeviceCheck fallback), Crashlytics, Analytics, fl_chart for the Admin Panel, mocktail + fake_cloud_firestore + golden_toolkit for a test harness that does not yet exist, and GitHub Actions for CI. The single most opinionated cuts are (a) drop the Premium upgrade modal for v1.0 (App Store will reject a non-functional paywall), (b) replace the global leaderboard with a cohort or kill it, (c) keep image-attach and full search history FREE — they are table stakes, not monetization levers.

The top risks are sequencing failures, not technology choices. App Check enforcement turned on before debug tokens are registered locks every dev out of Firestore. The `lib/features/` → `lib/presentation/` refactor done in the same PR as `withOpacity → withValues` body edits destroys `git log --follow` and is un-reviewable. A naive `awardPoints` callable is replay-vulnerable even with App Check. A Cloud Function defaulted to `us-central1` adds 200ms per request for every Bangladeshi user and cannot be changed without re-deploying clients. Each has a concrete prevention strategy mapped to a specific phase.

---

## Key Findings

### Recommended Stack

Existing Flutter 3.41 / Riverpod 2.6 / firebase_core 3.15.x is **locked and correct**; v1.0 only adds new capabilities. All FlutterFire additions must come from the same BoM generation as `firebase_core ^3.15.2`.

| Layer | Package / Service | Version | Purpose | Confidence |
|---|---|---|---|---|
| Cloud Functions runtime | Node 20 LTS + TypeScript 5.4, `firebase-functions ^6.0` v2 API | n/a | Gen-2 functions; region `asia-south1` (Mumbai) | HIGH (runtime); MEDIUM (pin) |
| Gemini SDK (server) | `@google/genai ^1.0` (NOT deprecated `@google/generative-ai`) | ^1.0 | New unified Gemini SDK | HIGH |
| Optional streaming | `genkit + @genkit-ai/{googleai,firebase}` | ^1.0 | `onCallGenkit` token streaming; else non-streaming v1.0 | MEDIUM |
| Functions client | `cloud_functions` | `^5.2.0` | `httpsCallable('mentorBotChat')` | MEDIUM |
| App attestation | `firebase_app_check` | `^0.3.2` | App Attest (iOS 14+) + DeviceCheck fallback | MEDIUM |
| Crash reporting | `firebase_crashlytics` | `^4.1.0` | Native + Dart uncaught error capture | MEDIUM |
| Telemetry | `firebase_analytics` | `^11.3.0` | Screen views via `FirebaseAnalyticsObserver` on GoRouter | MEDIUM |
| Charts (Admin Panel) | `fl_chart` | `^0.69.0` | Screen 12 — pure Dart, no licence | MEDIUM |
| External links | `url_launcher` | `^6.3.0` | PDF material URLs, ToS, App Store rating | HIGH |
| Foreground push UI | `flutter_local_notifications` | `^18.0.0` | iOS foreground banner display | MEDIUM |
| Crashlytics breadcrumbs | `package_info_plus` / `device_info_plus` | `^8.0.0` / `^11.0.0` | App + device metadata | HIGH |
| Test harness (NEW) | `mocktail`, `fake_cloud_firestore`, `firebase_auth_mocks`, `golden_toolkit`, `network_image_mock`, `integration_test` | ^1.0.4, ^3.1.0, ^0.14.0, ^0.15.0, ^2.1.1 | Zero `dev_dependencies` today; baseline the suite | HIGH (mocktail, golden_toolkit); MEDIUM (others) |
| Static analysis | `custom_lint` + `riverpod_lint` | ^0.6.x + ^2.3.x | Catch Riverpod anti-patterns | MEDIUM |
| CI | GitHub Actions, `subosito/flutter-action@v2`, `ubuntu-latest` for analyze/test; macOS only for nightly iOS build smoke | n/a | Free tier sufficient; 5× cheaper than macOS for PR checks | HIGH |

**Removals:** `google_generative_ai` (Dart, after Phase 3 proxy lands); `--dart-define=GEMINI_API_KEY` → Google Secret Manager `defineSecret`; `firebase_dynamic_links` — do not add (service shuts down Aug 2025).

### Expected Features

| Bucket | Feature | Notes |
|---|---|---|
| **Table stakes (P1)** | Image attachment for diagrams | **FREE with 3/day quota** — Photomath set this expectation in 2017 |
| Table stakes (P1) | Visible rate-limit counter | Soft-warn at 80%. Existing `/users/{uid}/usage/{date}` doc supports it |
| Table stakes (P1) | Empty-state suggestion chips (4–6 per subject) | Anti-abandonment. Hardcoded per subject for v1.0 |
| Table stakes (P1) | Email verification soft-block | Banner, not hard gate |
| Table stakes (P1) | Push notifications wired end-to-end | Highest-leverage retention task; currently 0 imports of `firebase_messaging` |
| Table stakes (P1) | Server-authoritative points + audit ledger | Closes leaderboard cheat surface (HIGH-severity) |
| Table stakes (P1) | Connectivity banner + pull-to-refresh + account deletion | App Store deletion requirement since 2022 |
| Table stakes (P1) | Streak counter prominent on dashboard | Half-built in `dashboard_viewmodel.dart:365` |
| Table stakes (P1) | Subject progress rings (session-count, NOT mastery) | Cheapest v1.0 definition |
| **Differentiators (P1–P2)** | Curriculum-aligned system prompt (Cambridge/Edexcel marking-scheme style) | Pure prompt engineering. No global competitor does this for BD market |
| Differentiators (P2) | Daily challenge card (Cloud Scheduler → FCM topic) | Only ship if FCM wired same milestone |
| Differentiators (P1) | Cross-content search of own materials + sessions | Already built. **Keep FREE** — sticky moat |
| Differentiators (P1) | Badge celebration overlay with confetti (badge-earn only) | NOT per-message |
| Differentiators (P2) | Admin broadcast via FCM topics | Requires FCM wired + callable Cloud Function |
| Differentiators (P2) | Bangla/English bilingual answer toggle | Prompt engineering only; not in current spec — **recommend adding** |
| **Anti-features (CUT)** | Premium upgrade modal (no payment backend) | **CUT**. App Store Guideline 3.1.1 = reject. Replace with waitlist email capture |
| Anti-features (CUT) | Gating image attachment behind Premium | **CUT**. Photomath has been free for 9 years |
| Anti-features (CUT) | Gating search history behind Premium | **CUT**. Removes the moat for kilobytes of storage |
| Anti-features (REWORK) | Free tier of 10 msgs/day | **REWORK to 30–50 text + 3–5 image** |
| Anti-features (CUT/rescope) | Public global leaderboard | **CUT or scope to 30-person cohort.** Always-bottom problem destroys new-user motivation |
| Anti-features (CUT) | Teacher self-signup in registration UI | Hide role; keep DB field for admin promotion |
| Anti-features (CUT) | In-app admin analytics dashboard | Use Firebase Analytics + GA4 console |

**Deferred to v1.x / v2+:** bKash/Stripe payment, Premium tier (unlimited msgs, marking-scheme mode), past-paper marking-scheme mode, friend-based leaderboard, topic-level mastery, Android, web, dark mode, offline-first sync, voice/TTS, teacher dashboard.

### Architecture Approach

**Target state:** layered three-tier client (`lib/presentation/screens/` ← `lib/application/viewmodels/` ← `lib/data/{repositories,services,models}/`) on top of Firebase managed services PLUS a new Cloud Functions Gen-2 monorepo at `functions/` (TypeScript, Node 20, region `asia-south1`). The Function is sole writer to `/users/{uid}.points` and `/rewards/{uid}` after Phase 4; clients only *read* those documents. App Check is enforced on Functions, Firestore, and Storage.

**Hard import rule (enforced by layout, blocked at review):**
- `presentation/` may import `application/`, `core/`, `shared/`. **Never** `data/`.
- `application/` may import `data/`, `core/`. **Never** `presentation/`.
- `data/` may import `core/`. **Nothing else** from `lib/`.

**Major components:**
1. `lib/presentation/screens/<name>/` — `ConsumerWidget`. Zero Firebase imports.
2. `lib/application/viewmodels/<name>_viewmodel.dart` — `StateNotifier`. Reads repos via `ref.read(...)`.
3. `lib/data/repositories/` — Per-aggregate-root Firestore/Storage wrappers (users, sessions, rewards, materials, notifications).
4. `lib/data/services/` — `mentor_bot_client.dart`, `app_check_service.dart`, `messaging_service.dart` (NEW), `gemini_service.dart` (slimmed to talk to Function).
5. `lib/data/models/` — Lifted from inline ViewModels.
6. `functions/src/callables/` — `mentor_bot_chat.ts`, `mentor_bot_analyze_image.ts`, `set_premium.ts`.
7. `functions/src/triggers/` — `on_session_write.ts` (idempotent), `on_user_create.ts` (init rewards + claims).
8. Security rules: `points`, `badges`, `streak`, `usage.messageCount`, `/rewards/{uid}/*` all server-only writes.

**Two critical data flows:**
- **Flow A (chat):** `TutorScreen → ChatViewModel → MentorBotClient → httpsCallable('mentorBotChat')` [App Check token auto-attached] → Function verifies auth + App Check, `runTransaction` on `/users/{uid}/usage/{today}`, reads Gemini key from Secret Manager, calls `gemini-1.5-flash`, writes session + usage atomically, returns `{ text, sessionId, usageRemaining }`.
- **Flow B (rewards):** `mentorBotChat` writes `/sessions/{sid}` → Eventarc fires `onSessionWrite` trigger → idempotent award (dedupes by `clientRequestId` + document state delta) → transaction writes `/rewards/{uid}/ledger/{autoId}` (append-only subcollection, NOT array) + mirrors `points` to `/users/{uid}`. Client listens to `/rewards/{uid}` stream.

**Premium gating dual-stored:** Firestore `subscription.tier` field drives UI (real-time stream); `request.auth.token.premium` custom claim gates server-side calls (no Firestore read). `setPremium` callable writes both atomically; client force-refreshes ID token.

### Critical Pitfalls (top 10, ranked by likelihood × impact)

1. **App Check enforced before debug tokens registered.** Locks every dev simulator. **Stage: install → register tokens → watch Metrics ≥99% verified for 7 days → only then enforce.** (Phase 2)
2. **Replay-vulnerable rewards.** Legitimate app calling in a loop still wins under App Check. **Event-derived triggers (not callables) + idempotent transactions keyed on document state delta + `clientRequestId` + append-only `/rewards/{uid}/ledger/{autoId}` subcollection.** (Phase 4)
3. **Quota timezone drift.** UTC vs UTC+6 = quota appears to reset 6 hours late. **`QUOTA_TZ = 'Asia/Dhaka'` shared constant in both `lib/core/` + `functions/src/`; `Intl.DateTimeFormat('en-CA', { timeZone: QUOTA_TZ })`.** (Phase 3)
4. **Refactor PR mixed with body edits.** Destroys `git log --follow`. **Two strictly separate PRs: PR A pure `git mv` with byte-identical `flutter analyze`; PR B lint burndown afterward.** (Phase 1)
5. **`withOpacity → withValues` sed-replace shifts mid-tones 1–3% in wide-gamut compositing.** Visible on real iPhone 14/15 (P3 display), invisible on simulator. **Per-file migration with `golden_toolkit` snapshots; CI gate `flutter test --tags golden`.** (Phase 1 / Phase 7)
6. **FCM iOS topic subscribe silently no-ops before APNs token arrives.** 30% of TestFlight users get no broadcasts six weeks later. **Strict sequence: Firebase init → permission rationale → `requestPermission` → `getToken()` non-null → `getAPNSToken()` non-null (poll up to 10s) → `subscribeToTopic`. Re-subscribe on `onTokenRefresh`. Background handler MUST be top-level + `@pragma('vm:entry-point')`.** (Phase 6)
7. **Cloud Function billing surprise.** Forces Blaze; `minInstances: 1` = ~$25/mo at zero traffic. **Day-zero: `$10/mo` GCP budget alert; `asia-south1`; `minInstances: 0`, `maxInstances: 10`; Artifact Registry "keep last 3 versions".** (Phase 2)
8. **Hot-doc contention on `/users/{uid}/usage/{today}.messageCount`.** Per-doc write limit ≈1/sec; under burst load user gets 11 free messages. **`runTransaction` in the first version of the function; client 500ms debounce; per-test uid.** (Phase 3)
9. **Integration tests against real Firestore.** Pollutes Analytics, burns Gemini quota. **Firebase Local Emulator Suite default; `@firebase/rules-unit-testing`; one tagged `@integration_real` smoke test against `mentor-mind-dev`.** (Phase 1)
10. **Premium data model requires schema refactor when bKash/Stripe lands.** **Design `/subscriptions/{uid}` with full schema today (`tier`, `status`, `currentPeriodStart/End`, `provider`, `providerSubscriptionId`, `cancelAtPeriodEnd`, `metadata.grantedBy`); only populate v1.0 fields.** (Phase 5)

---

## Implications for Roadmap

All four research dimensions independently converge on a **seven-phase, dependency-ordered** sequence. Each phase ships a runnable app; UI polish deliberately last because every prior phase changes the contract underneath.

### Phase 1: Refactor + CI baseline + test harness
**Rationale:** Mechanical, zero-runtime-change first. Every subsequent phase edits viewmodels — landing the new layout first means later phases write directly to the new tree.
**Delivers:** `lib/features/` → `lib/presentation/screens/` + `application/viewmodels/` + `data/{repos,services,models}/`; models extracted; repositories wrap SDK; `dev_dependencies` baseline; GitHub Actions CI (analyze + test on PR); Firebase Local Emulator Suite scaffolding; avatar upload path mismatch fix (one-liner); iOS Google Sign-In native config; bundle ID alignment decision.
**Avoids:** #5 (refactor PR discipline), #6 (golden tests), #9 (emulator default)

### Phase 2: Cloud Functions scaffolding + App Check
**Rationale:** App Check must be live *before* any callable enforces it. Day-zero billing hygiene non-negotiable. Get plumbing green on no-op `ping` callable first.
**Delivers:** `functions/` monorepo (TypeScript, Node 20, ESLint); `functions/src/lib/{admin,errors,gemini,rate_limit,claims}.ts`; no-op `ping` callable deployed to `asia-south1` with `enforceAppCheck: true`; `firebase_app_check ^0.3.2` activated; debug tokens registered for every dev simulator + CI; `$10/mo` GCP budget alert; Artifact Registry cleanup policy; **decision: iOS deployment target bump 13→14** (App Attest min).
**Avoids:** #1 (staged App Check), #7 (billing hygiene)

### Phase 3: Gemini proxy + rate limiting
**Rationale:** Cuts in-binary API key leak (HIGH-severity). Defines rate limits in final shape — retrofitting in hot path is risky.
**Delivers:** `mentor_bot_chat.ts` with transactional read-check-write on usage doc; `QUOTA_TZ` shared constant; `lib/data/services/mentor_bot_client.dart` replaces direct Gemini calls; `--dart-define=GEMINI_API_KEY` removed; Google AI Studio key rotated; `google_generative_ai` removed from pubspec; `firestore.rules` lock `/users/{uid}/usage/{date}` read-only for client; **free-tier reworked from 10/day → 30–50 text + 3–5 image**; replay cache (24h dedupe on `(sessionId, msgIdx)` + `clientRequestId`); **non-streaming v1.0 ship** (typing indicator only).
**Avoids:** #3 (timezone), #8 (hot-doc transactional)

### Phase 4: Server-authoritative rewards + rules lockdown
**Rationale:** Closes leaderboard cheat surface (HIGH-severity). Trigger + rules lockdown MUST deploy together — otherwise double-writes inflate totals.
**Delivers:** `on_session_write.ts` (Eventarc idempotent); `on_user_create.ts` (init `/rewards/{uid}` + default claims); `/rewards/{uid}/ledger/{autoId}` append-only subcollection (replaces unbounded array; one-time migration if needed); client `_awardPoints` / `FieldValue.increment` paths fully removed; `firestore.rules` lockdown; rules-unit-testing suite asserts lockdown (FAIL before, PASS after).
**Avoids:** #2 (replay-vulnerable rewards)

### Phase 5: Premium claims + Admin Panel + subscription data model
**Rationale:** Premium UI gating meaningless until backend matches. Custom claims avoid per-call Firestore read. `/subscriptions/{uid}` schema locked NOW so future bKash/Stripe is just a webhook handler.
**Delivers:** `set_premium.ts` (admin-only, writes `/subscriptions/{uid}` + `setCustomUserClaims`); full `/subscriptions/{uid}` schema (v1.0 only populates manual-grant fields); `getIdToken(true)` force-refresh after admin grant; Admin Panel Screen 12 NavigationRail/BottomNavBar + Users tab with grant action; **decision: drop upgrade modal for v1.0 entirely** OR wire to waitlist email capture.
**Avoids:** #10 (v2-ready schema today)

### Phase 6: FCM iOS wiring + Notifications + Admin broadcast
**Rationale:** Highest-leverage retention task. iOS-specific gotchas warrant dedicated phase.
**Delivers:** `lib/data/services/messaging_service.dart` initialized in `main.dart` before `runApp`; strict permission → token → APNs token → subscribe sequence; top-level background handler with `@pragma('vm:entry-point')`; re-subscribe on `onTokenRefresh`; reconciler Cloud Function (writes `/users/{uid}.fcmTopics` intent; Admin SDK reconciles); APNs `.p8` auth key uploaded (NOT `.p12`); Xcode Push Notifications + Background Modes capabilities; `flutter_local_notifications`; `sendBroadcast.ts` admin callable; Screen 11 wired to real FCM payloads.
**Avoids:** #6 (FCM iOS sequence)

### Phase 7: UI polish per spec + lint burndown + observability
**Rationale:** Last because every prior phase changed the API surface. Lint burndown bundled here so per-file golden discipline protects against `withOpacity` regression.
**Delivers:** All 12 screens polished (brand gradients, fl_chart, shimmer skeletons, podium); shared widgets (`PremiumModal`, `BadgeOverlay`, `OfflineBanner`); per-file `withOpacity → withValues` migration with golden snapshots (splash gradient + tutor cluster refactored to `Color.fromARGB` with pre-baked alpha); `prefer_const` cleanup (42 warnings); `depend_on_referenced_packages` resolution (12 warnings); `custom_lint` + `riverpod_lint`; `firebase_crashlytics` + `firebase_analytics` wired with `FlutterError.onError` + `FirebaseAnalyticsObserver`; `package_info_plus` + `device_info_plus` for Crashlytics keys; `url_launcher` for PDFs/ToS/App Store; iOS dSYM Run Script; CI golden gate.
**Avoids:** #5 (PR B after PR A), #6 (per-file goldens)

### Phase Ordering Rationale (dependency arrows)

```
P1 (refactor + CI)
   ↓  later phases write to new tree directly (cheaper)
P2 (Functions + App Check)
   ↓  App Check MUST live before callables enforce it
P3 (Gemini proxy)
   ↓  rules lockdown on usage doc requires Function ownership
P4 (server rewards + rules lockdown)
   ↓  trigger + rules MUST deploy together to avoid double-writes
P5 (premium claims + Admin Panel)
   ↓  Admin Panel's grant button calls set_premium callable
P6 (FCM wiring)
   ↓  could parallel with P3-5 but iOS gotchas warrant focus; broadcast needs Functions
P7 (UI polish + lint + observability)
       — every prior phase changed API surface; polishing first wastes the polish
```

**Phases 1–6 are infrastructure/contracts** (each ships a runnable app). **Phase 7 is product polish** (single phase spanning 12 screens; week-sliceable internally). Phases 1–2 can time-slice in parallel for a solo dev; all others strictly sequential. **Do not put UI polish before security fixes.**

### Research Flags

**Need deeper research during planning:**
- **Phase 2** — Node 22 GA on Functions v2; `firebase_app_check ^0.3.2` Apple provider class name; iOS 13→14 deployment bump impact; CI debug token mechanics
- **Phase 3** — `cloud_functions ^5.x` SDK support for `onCallStream` (drives streaming vs non-streaming); Firestore region of `mentor-mind-aa765` (cross-region cost); final free-tier cap (30–50/day) per current Gemini Flash pricing
- **Phase 4** — `auth.user().onCreate` (v1) vs Identity Platform Eventarc trigger (v2) GA status; idempotency strategy review
- **Phase 5** — custom claim propagation latency (`getIdToken(true)` vs server cache); bKash integration scope

**Standard patterns (skip research-phase):** Phase 1 (refactor + CI + test harness), Phase 6 (FCM iOS catalogued in PITFALLS.md #7), Phase 7 (FlutterFire standard patterns)

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM | Choice of Node 20 + TS, v2 functions, `@google/genai`, GitHub Actions, mocktail, fl_chart are HIGH. Specific version pins MEDIUM — verify with `flutter pub outdated` before Phase 2 |
| Features | MEDIUM | Bucketing grounded in well-documented competitor patterns (Khanmigo, Photomath, Brainly, 10MS, Duolingo) and App Store policy. LOW on Gemini Flash per-token cost estimate |
| Architecture | MEDIUM | Layered three-tier refactor HIGH (direct code reading). Cloud Functions structure HIGH. LOW on streaming callable Flutter SDK; MEDIUM on App Check Apple provider min iOS, custom claim propagation timing |
| Pitfalls | MEDIUM-HIGH | All 10 grounded in either training-cutoff Firebase docs (HIGH on App Check, FCM iOS, hot-doc, Eventarc) or direct code reading (HIGH on refactor + `withOpacity` risk, quota TZ, replay shape) |

**Overall confidence: MEDIUM.** Recommendations architecturally sound and internally consistent across all four research dimensions. Unknowns are version-specific SDK questions that a 15–30 minute verification pass resolves.

### Gaps to Address (deferred-decision questions for the planner)

1. **bKash integration scope and timing** — Schema in Phase 5 accommodates `'manual' | 'bkash' | 'stripe' | 'apple_iap'`; question is *roadmap timing*, not schema design
2. **Streaming Gemini in v1.0 vs v1.1** — Hinges on `cloud_functions ^5.x` `onCallStream` support. **Default: non-streaming v1.0** (typing indicator); revisit only if SDK confirms + time budget allows
3. **iOS deployment target bump (13 → 14)** — App Attest availability. **Default: bump to 14** (iOS 13 addressable population effectively zero). Confirm with stakeholder
4. **Free-tier daily message cap final value** — 30/40/50 text + 3/5 image. Drives Gemini cost and banner copy. Lock constant in Phase 3 after Gemini Flash pricing pull
5. **Firestore region of `mentor-mind-aa765`** — If `nam5`/`us-central`, Functions in `asia-south1` pay ~150ms cross-region. Cannot be changed without project recreation. Surface in Phase 2 research
6. **Bundle ID alignment** — `com.mentorminds.mentorMinds` (BACKEND_SETUP.md) vs `com.arnobrizwan.mentorminds` (Xcode). Pick in Phase 1
7. **Daily Challenge card scope** — Ship v1.0 (depends on FCM in Phase 6) or defer v1.1? Currently P2
8. **Leaderboard final scope** — **Default: CUT for v1.0.** Personal stats + badges + streak sufficient
9. **Bangla/English bilingual answer toggle** — Cheap (prompt only), not in current spec. Lock in Phase 3 or defer
10. **Email verification gate strictness** — Soft block (banner) recommended over hard block (anti-abandonment); confirm with stakeholder

---

## Sources

**Primary (HIGH confidence — direct reads):**
- `.planning/PROJECT.md` — v1.0 scope, Active list, Constraints, Out of Scope
- `.planning/codebase/STACK.md` — existing FlutterFire BoM generation
- `.planning/codebase/ARCHITECTURE.md` — current MVVM layout + documented anti-patterns
- `.planning/codebase/CONCERNS.md` — HIGH-severity findings
- `pubspec.yaml` + `pubspec.lock`
- `lib/features/tutor/chat_viewmodel.dart:490-542` — replay-vulnerable shape
- `firestore.rules` — current rules with admitted MVP trade-offs
- `lib/core/routes/app_router.dart` — router imports

**Secondary (MEDIUM, training-cutoff Jan 2026):**
- Firebase docs (App Check Flutter, Cloud Functions Gen 2 pricing/regions, FCM iOS, Firestore quotas, Emulator Suite)
- Flutter/Dart docs (`Color.withOpacity` deprecation, `@pragma('vm:entry-point')` tree-shaking)
- Google Cloud (Secret Manager, Artifact Registry cleanup, Cloud Run min-instances pricing)
- Apple developer (APNs `.p8` vs `.p12`, App Attest vs DeviceCheck, Push capabilities)
- Competitor reference set: Khanmigo, Photomath, Socratic, Brainly, Quizlet, Chegg, Duolingo, 10 Minute School, Shikho, Save My Exams, Seneca Learning
- App Store Review Guideline 3.1.1

**Tertiary (LOW, needs validation before Phase 2):** exact patch pins; `cloud_functions ^5.x` `onCallStream`; Node 22 GA; custom claim propagation timing; Genkit 1.0 GA stability; Gemini Flash per-token cost

**Note:** WebSearch, WebFetch, Context7 CLI all denied this session. MEDIUM pins re-verify with `flutter pub outdated` before commit.

---

*Research completed: 2026-05-17*
*Ready for roadmap: yes*
*Synthesized: 1,835 source lines → ~470 line summary*
