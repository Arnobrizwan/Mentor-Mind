# Roadmap: MentorMinds v1.0

## Overview

MentorMinds today is a feature-complete *skeleton* — 12 screens render, Gemini chat streams, rewards exist — but the app is not launchable: the Gemini API key ships in the iOS binary, the leaderboard accepts client-side `FieldValue.increment('points')` writes (trivially gameable), avatar uploads fail 100% of the time against `storage.rules`, FCM is declared but never imported, and the codebase carries 167 lint warnings with zero automated tests. The v1.0 milestone is therefore a **hardening + 12-screen polish pass**, not a build-from-zero project.

The journey is seven phases, **dependency-ordered horizontal layers**. Phase 1 lands the `lib/features/` → `lib/presentation/screens/` + `application/viewmodels/` + `data/{repos,services,models}/` refactor, scaffolds CI, fixes the avatar bug, and aligns the iOS bundle ID before any feature code is touched — so every later phase writes directly to the new tree. Phase 2 stands up Cloud Functions + App Check on a no-op `ping` callable, with billing guardrails on day zero. Phase 3 moves Gemini behind a server-side proxy with timezone-correct, transactional rate limiting. Phase 4 makes rewards server-authoritative via event-driven Firestore triggers + a same-deploy rules lockdown. Phase 5 lays Stripe subscriptions on top of v2-ready custom claims and ships the Admin Panel. Phase 6 wires FCM end-to-end (the highest-leverage retention task) and ships the Daily Challenge. Phase 7 is the per-screen polish pass plus lint burndown plus observability — done last because every prior phase has changed the API contract underneath.

Each phase ships a runnable app. UI polish is deliberately last because polishing a UI that's about to have its API surface (callable vs direct SDK, server-authored points, App-Check-protected reads) changed is wasted polish.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Foundation — Refactor, CI, Test Harness, iOS Identity** - Layer the codebase into `presentation/application/data`, scaffold GitHub Actions + Firebase Emulator Suite, fix avatar upload + iOS Google Sign-In, align bundle ID to `com.mentorminds.mentorMinds`, bump iOS deployment target 13→14.
- [ ] **Phase 2: Cloud Functions Scaffolding + App Check** - Stand up TypeScript `functions/` monorepo in `asia-south1`, deploy no-op `ping` callable, activate App Check (App Attest release + Debug dev), wire billing alert + Artifact Registry cleanup before any real callable lands.
- [ ] **Phase 3: Gemini Proxy + Server-Side Rate Limiting** - Move Gemini behind `mentorBotChat` callable reading the key from Secret Manager, enforce 30 text + 3 image per UTC+6 day in a single transaction, remove `--dart-define=GEMINI_API_KEY` and rotate the leaked key.
- [ ] **Phase 4: Server-Authoritative Rewards + Rules Lockdown** - Replace client `FieldValue.increment('points')` with idempotent `onSessionWrite` trigger writing to `/rewards/{uid}/ledger/{autoId}`; deploy `firestore.rules` lockdown in the same deploy with a rules-unit-testing suite that proves the lockdown.
- [ ] **Phase 5: Stripe Subscriptions + Premium Claims + Admin Panel** - Ship v2-ready `/subscriptions/{uid}` schema, Stripe Checkout + webhook + Customer Portal, `setPremium` admin callable with custom claims, and the full Admin Panel (Screen 12) with NavigationRail/BottomNavBar and 5 tabs.
- [ ] **Phase 6: FCM iOS Wiring + Notifications + Daily Challenge** - Wire `firebase_messaging` end-to-end with the strict permission → FCM token → APNs token → topic-subscribe sequence, ship Notifications screen (Screen 11) on real FCM payloads, ship Daily Challenge card (Cloud Scheduler → `/daily_challenges/{YYYY-MM-DD}`).
- [ ] **Phase 7: 12-Screen UI Polish + Shared Components + Observability + Lint Burndown** - Polish Splash, Onboarding, Auth, Dashboard, Tutor, Materials, Search, Profile, Rewards per spec; ship `PremiumUpgradeModal`/`BadgeCelebrationOverlay`/`OfflineBanner`; wire Crashlytics + Analytics + GoRouter observer + dSYM Run Script; resolve all 167 analyzer warnings with per-file goldens; drive `flutter analyze` to zero.

## Phase Details

### Phase 1: Foundation — Refactor, CI, Test Harness, iOS Identity
**Goal**: A layered, tested, CI-gated codebase running on the canonical iOS identity (`com.mentorminds.mentorMinds`, iOS 14+, working Google Sign-In + avatar uploads), with no behavioral changes — every later phase writes directly to the new tree.
**Depends on**: Nothing (first phase)
**Requirements**: ARCH-01, ARCH-02, ARCH-03, ARCH-04, ARCH-05, ARCH-06, ARCH-07, CI-01, CI-02, CI-03, CI-04, CI-05, CI-06, CI-07, QUAL-04, QUAL-06
**Success Criteria** (what must be TRUE):
  1. `lib/` is split into `lib/presentation/screens/`, `lib/application/viewmodels/`, `lib/data/{repositories,services,models}/` and a hard one-way import rule (presentation → application → data) is enforced by `custom_lint` running in CI.
  2. Every PR against `main` runs `flutter analyze`, `flutter test`, and (when `functions/**` changes) the TypeScript lint+build — all three gate merge; coverage artifact is uploaded.
  3. User can edit their avatar in Profile and the upload succeeds end-to-end against the deployed `storage.rules` (no more silent permission-denied), and user can complete Google Sign-In on a physical iOS device.
  4. The app builds, signs, and runs on an iOS 14+ device under bundle ID `com.mentorminds.mentorMinds` with Firebase iOS app registration + APNs association both matching; `BACKEND_SETUP.md` and Xcode agree.
  5. Firebase Local Emulator Suite (Auth + Firestore + Storage + Functions) boots locally and is the default target for `flutter test integration_test/`; the new `dev_dependencies` (`mocktail`, `fake_cloud_firestore`, `firebase_auth_mocks`, `golden_toolkit`, `network_image_mock`, `integration_test`) all resolve and have at least one smoke test exercising them.
**Plans**: TBD
**UI hint**: no

> **Rationale & non-negotiables.** The refactor is mechanical and zero-runtime-change; landing it first means every later phase writes to the new tree (cheaper). Per PITFALLS #5, the refactor MUST be a pure `git mv` PR (PR A) before any lint/body edits (Phase 7 = PR B) — mixing destroys `git log --follow`. The bundle ID swap (ARCH-04) is invasive (Xcode signing identity, Firebase iOS app re-registration, APNs `.p8` re-association, `BACKEND_SETUP.md` doc) and is best done now alongside the iOS 13→14 deployment bump (ARCH-05, unlocks App Attest as the primary App Check provider in Phase 2). Avatar fix (ARCH-06) is a one-liner but blocks Profile QA in Phase 7. Codegen decision (QUAL-06) belongs here so later phases know whether to write `@riverpod` or vanilla; `custom_lint` (QUAL-04) is added now to enforce the layered imports from day one.

### Phase 2: Cloud Functions Scaffolding + App Check
**Goal**: A live `functions/` monorepo in `asia-south1` with App Check enforced on a no-op `ping` callable, debug tokens registered for every dev simulator + CI, and day-zero billing guardrails — proving the plumbing green before any real callable lands.
**Depends on**: Phase 1
**Requirements**: FUNC-01, FUNC-02, FUNC-03, FUNC-04, FUNC-05, FUNC-06
**Success Criteria** (what must be TRUE):
  1. `functions/` exists at repo root (TypeScript, Node 20, `firebase-functions ^6.x` v2 API) with `functions/src/lib/{admin,errors,gemini,rate_limit,claims}.ts` helpers and a deployed `ping` callable in `asia-south1`.
  2. Calling `ping` from a dev simulator succeeds with a registered debug token and fails with `unauthenticated`/App-Check-rejected when no token is present — proving end-to-end App Check enforcement (`enforceAppCheck: true`).
  3. App Check is activated in `main.dart` with App Attest provider on iOS 14+ release builds and the Debug provider on dev/CI; debug tokens are documented in `BACKEND_SETUP.md` and the CI debug token is loaded from a GitHub Actions secret.
  4. GCP Billing budget alert is configured at $10/month wired to admin email, and Artifact Registry has a retention policy keeping only the last 3 versions of each function image.
  5. `cloud_functions ^5.x` Flutter SDK is in `pubspec.yaml`, wired through `lib/data/services/`, and a "call ping" smoke test passes against the emulator.
**Plans**: TBD
**UI hint**: no

> **Rationale & non-negotiables.** Per PITFALLS #1, App Check MUST be live before any callable enforces it — wire it on a no-op `ping` first so a dev outage doesn't cost a Gemini outage. Per PITFALLS #8, billing alert + region pin + Artifact Registry cleanup are day-zero, not a follow-up — `minInstances: 1` defaulted costs ~$25/mo at zero traffic. `asia-south1` is non-negotiable for Bangladesh users; changing region later requires redeploying clients. iOS 14+ (ARCH-05 from P1) is what makes App Attest viable.

### Phase 3: Gemini Proxy + Server-Side Rate Limiting
**Goal**: All Gemini calls flow through `mentorBotChat` callable reading `GEMINI_API_KEY` from Secret Manager, with transactional per-user UTC+6 daily caps (30 text + 3 image), burst limit, monthly app-wide ceiling, idempotent retries via `clientRequestId`, and the in-binary API key fully removed and rotated.
**Depends on**: Phase 2
**Requirements**: AI-01, AI-02, AI-03, AI-04, AI-05, AI-06, AI-07, AI-08, AI-09, AI-10
**Success Criteria** (what must be TRUE):
  1. A signed-in user sending a chat message hits `mentorBotChat` callable, receives a Gemini answer in under 10 seconds (non-streaming with typing indicator), and the user's 31st text message on the same UTC+6 day is rejected with a `resource-exhausted` error mapped to the rate-limit UI banner.
  2. Verified that no Gemini API key appears in any compiled artifact: `--dart-define=GEMINI_API_KEY` is removed from all build configs, the previously-leaked key is rotated in Google AI Studio, and `google_generative_ai` is no longer in `pubspec.yaml`.
  3. A double-tap or network retry submitting the same `(sessionId, clientRequestId)` is server-side idempotent — only one Gemini call is made, only one `/sessions/{sid}` message is written, only one `/users/{uid}/usage/{today}` increment lands (verified by integration test).
  4. `firestore.rules` lock `/users/{uid}/usage/{date}` to read-only for the owning client (Admin SDK writes via Function); a rules-unit test proves a direct client write attempt is rejected.
  5. When the monthly Gemini call ceiling at `/system/quota/{YYYY-MM}` is crossed, every subsequent call returns `unavailable` with the generic "AI tutor temporarily unavailable" message — verified by a test that pre-seeds the quota doc at the ceiling.
**Plans**: TBD
**UI hint**: no

> **Rationale & non-negotiables.** Per PITFALLS #3, `QUOTA_TZ = 'Asia/Dhaka'` is a shared constant in both `lib/core/` AND `functions/src/` — no raw `toISOString().slice(0,10)` anywhere. Per PITFALLS #4, the read-check-write on `/users/{uid}/usage/{today}.messageCount` MUST be a `runTransaction` in the FIRST version of the function, not a retrofit — per-doc write limit is ~1/sec and a non-transactional check lets a user get 11 free messages under burst. Per PITFALLS #2 + ARCHITECTURE Anti-pattern #3, idempotency via `clientRequestId` is mandatory before P4 (where the trigger awards points off the session write — duplicate session messages = double points). Free-tier cap is locked at 30 text + 3 image per UTC+6 day per user spec.

### Phase 4: Server-Authoritative Rewards + Rules Lockdown
**Goal**: Points, badges, streak, and ledger are written exclusively by `onSessionWrite` and `onUserCreate` triggers (idempotent, transactional, append-only ledger subcollection); all client paths writing `points`/`badges`/`streak` are deleted; `firestore.rules` lockdown deploys atomically with the triggers; a rules-unit suite proves the lockdown.
**Depends on**: Phase 3
**Requirements**: REWD-01, REWD-02, REWD-03, REWD-04, REWD-05, REWD-06, REWD-07
**Success Criteria** (what must be TRUE):
  1. A first-of-day session, a first-of-session message, and threshold crossings (5/10 sessions, 7-day streak, 50/100 questions in subject, 10 image uploads) award the correct points + badges via `onSessionWrite` without any client-side `FieldValue.increment('points')` call — verified by `git grep "FieldValue.increment.*points" lib/` returning zero hits in viewmodels.
  2. A new user signup triggers `onUserCreate` and within seconds `/rewards/{uid}` exists with `points: 0`, an empty `badges` array, and the user has default custom claims `{ role: 'student', premium: false }`.
  3. Verified that a malicious user using the Firebase REST API with their own valid ID token CANNOT write `points`, `badges`, or `streak` on `/users/{uid}` and CANNOT write any document under `/rewards/{uid}/**` — a `@firebase/rules-unit-testing` suite asserts both (FAIL before lockdown, PASS after).
  4. Rewards history is queryable as paginated `/rewards/{uid}/ledger/{autoId}` entries (append-only, sortable, one entry per award event); the unbounded `history: []` array pattern on `/rewards/{uid}` is fully retired and (if present in prod) migrated.
  5. Leaderboard is removed from the Rewards screen TabBar — user sees only personal stats (points, streak, badges, history) on Badges + History tabs; no global all-users leaderboard exists in v1.0.
**Plans**: TBD
**UI hint**: no

> **Rationale & non-negotiables.** Per ARCHITECTURE §8 + PITFALLS #2, the trigger AND the rules lockdown MUST deploy in the SAME `firebase deploy --only firestore:rules,functions` — leaving both client + trigger active produces double-writes and inflated point totals. Per ARCHITECTURE Anti-pattern #1, the chat callable in P3 writes ONLY `/sessions/{sid}` + `/users/{uid}/usage`; the trigger in P4 writes ONLY `/rewards/{uid}/ledger`. Failure isolation: a rewards write failure must not break chat. Eventarc delivers at-least-once, so the trigger MUST dedupe via `clientRequestId` (from P3) + document state delta. Global leaderboard is CUT per user decision (cohort + global both deferred to v2).

### Phase 5: Stripe Subscriptions + Premium Claims + Admin Panel
**Goal**: Premium tier is real-money-buyable via Stripe Checkout, server gating uses `request.auth.token.premium` custom claim (zero-Firestore-read), UI gating uses `/subscriptions/{uid}.tier` real-time stream, admin can manually grant/revoke premium via the Admin Panel — and the full Admin Panel (Screen 12 spec) ships: NavigationRail/BottomNavBar with Dashboard, Users, Content, Notifications, Analytics tabs.
**Depends on**: Phase 4
**Requirements**: PAY-01, PAY-02, PAY-03, PAY-04, PAY-05, PAY-06, PAY-07, PAY-08, PAY-09, PAY-10, ADMN-01, ADMN-02, ADMN-03, ADMN-04, ADMN-05, ADMN-06, ADMN-07, ADMN-08
**Success Criteria** (what must be TRUE):
  1. A free user can tap "Upgrade to Premium" → Stripe Checkout opens in an EXTERNAL Safari browser (NOT in-app webview, per App Store Guideline 3.1.1 mitigation), completes payment, the `customer.subscription.created` webhook fires, `/subscriptions/{uid}` flips to `{ tier: 'premium', status: 'active', provider: 'stripe' }`, the user's custom claim updates, the client force-refreshes the ID token, and within seconds the daily 30-message cap no longer applies on `mentorBotChat`.
  2. A premium user can cancel from Profile → Manage Subscription → Stripe Customer Portal; on `customer.subscription.deleted` the status flips to `cancelled` and access lasts until `currentPeriodEnd`.
  3. An admin user logs in, lands on `/admin`, sees the 5-tab NavigationRail (tablet) / BottomNavBar (mobile) with Dashboard (stats grid + recent activity), Users (50/page cursor pagination + role/subscription badges + ⋮ menu for Change Role / Toggle Premium via `setPremium` callable / Delete), Content (upload form → Firebase Storage + Firestore + broadcast to `role_student`), Notifications (broadcast form via `sendBroadcast` callable), and Analytics (DAU line + subject pie + weekly registrations bar via `fl_chart`).
  4. Verified that a non-admin user navigating to `/admin` is redirected to `/dashboard` with a "Not authorized" snackbar — the gate checks BOTH `request.auth.token.role == 'admin'` (custom claim) AND `/users/{uid}.role == 'admin'` (defense-in-depth).
  5. Image attachment in tutor chat is FREE for all users at 3/day quota (premium removes the cap, not the feature); full chat history search is FREE for all users (premium gets no extra benefit on search) — verified by free-account integration tests.
**Plans**: TBD
**UI hint**: yes

> **Rationale & non-negotiables.** Per PITFALLS #9, `/subscriptions/{uid}` ships with the FULL v2-ready schema (`tier`, `status`, `currentPeriodStart/End`, `provider`, `providerSubscriptionId`, `cancelAtPeriodEnd`, `metadata.grantedBy`) even though v1.0 only writes Stripe + manual fields — so future bKash/Apple IAP is a webhook handler, not a schema migration. **Stripe-only on iOS carries App Store Guideline 3.1.1 risk** (user-acknowledged); mitigation is Stripe Checkout opens in EXTERNAL Safari (not in-app webview); fallback path is Apple IAP added in v1.1 before App Store submission (PAY2-01 deferred). Custom claims (PAY-04) MUST precede the Admin Panel "Grant premium" UI — that's why these two requirement blocks share one phase. Image-attach + search-history stay FREE per research (table stakes since Photomath 2017 / sticky moat respectively). The Admin Panel is grouped here (not in P7 UI polish) because its grant-premium button calls `setPremium` and the broadcast form calls `sendBroadcast` — both backend-coupled.

### Phase 6: FCM iOS Wiring + Notifications + Daily Challenge
**Goal**: Push notifications are live end-to-end on iOS — the strict permission → FCM token → APNs token → topic-subscribe sequence is enforced, the background handler is top-level + `@pragma('vm:entry-point')`, and the Notifications screen (Screen 11) and Daily Challenge card on the Dashboard both render real FCM-delivered content.
**Depends on**: Phase 5
**Requirements**: NOTF-01, NOTF-02, NOTF-03, NOTF-04, NOTF-05, NOTF-06, NOTF-07, NOTF-08, DASH-02
**Success Criteria** (what must be TRUE):
  1. On first launch after install, the user sees a rationale screen, taps Continue, grants notification permission, and within 10 seconds the device is subscribed to `role_student` (or `role_premium_student` / `role_teacher` / `role_admin` based on role) plus `role_all`; subscription is verified by sending a test broadcast from Firebase Console that arrives on the device.
  2. With the app fully terminated, a Firebase Console test message wakes the device, the top-level `@pragma('vm:entry-point')` background handler runs, the message is persisted to `/notifications/{nid}`, and tapping the notification opens the app to the type-specific destination (new_material → material bottom sheet; achievement → Rewards screen).
  3. User can open the Notifications screen and see a date-grouped list (Today / Yesterday / This Week) with filter chips (All / Announcements / Achievements / Reminders), swipe-to-dismiss marks read, "Mark all read" batch-writes, and the bell-icon badge reflects unread count for the user's role.
  4. User can see a Daily Challenge card on the Dashboard with today's challenge (subject + question rotated daily by a Cloud Scheduler job writing to `/daily_challenges/{YYYY-MM-DD}`), an "Attempt Now" CTA that deep-links into the Tutor screen, and a countdown to UTC+6 midnight reset.
  5. After APNs token rotation (app reinstall / restore-from-backup / iOS upgrade), `onTokenRefresh` fires, all current topic subscriptions are re-established on the new token, and a server-side reconciler ensures the intent in `/users/{uid}.fcmTopics` matches FCM's actual state.
**Plans**: TBD
**UI hint**: yes

> **Rationale & non-negotiables.** Per PITFALLS #7, the FCM iOS sequence is the most-broken-in-the-wild integration in the stack — `subscribeToTopic` silently no-ops if called before APNs hands back the token, producing 30% silent delivery failure six weeks later. Strict ordering: `Firebase.initializeApp` → permission rationale → `requestPermission` → `getToken()` non-null → `getAPNSToken()` non-null (poll up to 10s) → `subscribeToTopic` → re-subscribe on `onTokenRefresh`. Background handler MUST be top-level + `@pragma('vm:entry-point')` or it gets tree-shaken in release builds. APNs `.p8` auth key (NOT `.p12` certificate). Xcode capabilities: Push Notifications + Background Modes → Remote notifications. Daily Challenge ships v1.0 per user decision and lives in P6 because it depends on the FCM topic infrastructure (Cloud Scheduler → topic broadcast for the "new daily challenge" notification).

### Phase 7: 12-Screen UI Polish + Shared Components + Observability + Lint Burndown
**Goal**: Every screen matches the 12-screen spec pixel-for-pixel, the three shared widgets (`PremiumUpgradeModal`, `BadgeCelebrationOverlay`, `OfflineBanner`) ship, Crashlytics + Analytics + dSYM upload + GoRouter screen-view observer are wired, and all 167 analyzer warnings are resolved with per-file goldens — `flutter analyze` reports zero issues on `main`.
**Depends on**: Phase 6
**Requirements**: AUTH-01, AUTH-02, AUTH-03, AUTH-04, AUTH-05, AUTH-06, AUTH-07, ONBD-01, ONBD-02, ONBD-03, ONBD-04, SPLA-01, SPLA-02, SPLA-03, DASH-01, DASH-03, DASH-04, DASH-05, DASH-06, DASH-07, TUTR-01, TUTR-02, TUTR-03, TUTR-04, TUTR-05, TUTR-06, TUTR-07, MATS-01, MATS-02, MATS-03, MATS-04, MATS-05, MATS-06, SRCH-01, SRCH-02, SRCH-03, SRCH-04, SRCH-05, PROF-01, PROF-02, PROF-03, PROF-04, PROF-05, PROF-06, PROF-07, RWRD-01, RWRD-02, RWRD-03, RWRD-04, RWRD-05, RWRD-06, SHRD-01, SHRD-02, SHRD-03, OBSV-01, OBSV-02, OBSV-03, OBSV-04, OBSV-05, QUAL-01, QUAL-02, QUAL-03, QUAL-05
**Success Criteria** (what must be TRUE):
  1. User can complete the entire happy path — Splash (brand gradient + animated lettermark) → Onboarding 3-page PageView (Welcome → Level → Subjects, persisted to SharedPreferences) → Register (password strength bar + ToS gate + email verification HARD block on Tutor + Sessions) → Login (gradient header + Google button) → Dashboard (SliverAppBar greeting + streak chip + subject progress rings + Recent Sessions + New Materials carousel) → Tutor (subject selector + typing indicator + 80%-rate-limit banner + suggestion chips + image attach + copy + 👍/👎 feedback) → Materials (2-col grid + filters + 300ms-debounced search + cursor pagination + bottom sheet + view-count increment + shimmer skeleton) → Search (auto-focus + recent + trending + tabbed All/Materials/Sessions + highlighted matches) → Profile (gradient header + stats row + subscription card + change password + delete account + logout) → Rewards (animated count-up + Badges + History tabs, Leaderboard removed) — every screen matches the 12-screen spec.
  2. `BadgeCelebrationOverlay` triggers with confetti + scale-bounce when `/rewards/{uid}` stream emits a new badge; `PremiumUpgradeModal` bottom sheet opens consistently when free users hit any quota gate; `OfflineBanner` slides in/out at the top of the app shell driven by `connectivity_plus`.
  3. Verified that a deliberately-thrown error in any viewmodel produces a Crashlytics record with `package_info_plus` + `device_info_plus` custom keys attached (app version, build number, device model, iOS version), and a real iOS crash produces a symbolicated stack trace via the dSYM Run Script Phase.
  4. `firebase_analytics` records screen-view events automatically via `FirebaseAnalyticsObserver` on GoRouter for every screen navigation, plus custom events fire for `send_message`, `upload_image`, `complete_session`, `earn_badge`, `upgrade_started`, `upgrade_completed` — verified in the Firebase Analytics DebugView console.
  5. `flutter analyze` reports zero issues (errors + warnings + info) on `main`; all 105 `withOpacity → withValues` migrations shipped with golden snapshots (splash gradient + tutor cluster refactored to `Color.fromARGB` with pre-baked alpha to avoid wide-gamut compositing shifts); all 42 `prefer_const` warnings resolved; `flutter_riverpod` added to `dependencies` resolving all 12 `depend_on_referenced_packages` warnings; `flutter test --tags golden` is a CI gate.
**Plans**: TBD
**UI hint**: yes

> **Rationale & non-negotiables.** Per ARCHITECTURE §8 + SUMMARY, this phase is LAST because every prior phase changed the API surface — polishing a UI before the underlying contract (callable vs direct SDK, server-authored points, App-Check-protected reads, FCM-delivered notification payloads) settled would waste the polish. Per PITFALLS #6, `withOpacity → withValues` is NOT a sed-replace — per-file migration with `golden_toolkit` snapshots; splash gradient + tutor 15+-hit cluster get refactored to `Color.fromARGB` with pre-baked alpha (wide-gamut compositing shift is invisible on simulator, visible on iPhone 14/15 P3 displays). Per PITFALLS #5, this is PR B from the Phase 1 PR A/PR B sequence — lint burndown lands ONLY after the pure refactor PR has merged. Email verification is a HARD block (not soft) on Tutor + Sessions per user decision — banner on Dashboard/Materials/Search/Profile is informational, but `ChatViewModel.sendMessage` and `SessionsRepository.save` reject unverified users at the call site. Observability is bundled here so it sees the polished error surfaces, not the in-progress ones.

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation — Refactor, CI, Test Harness, iOS Identity | 0/TBD | Not started | - |
| 2. Cloud Functions Scaffolding + App Check | 0/TBD | Not started | - |
| 3. Gemini Proxy + Server-Side Rate Limiting | 0/TBD | Not started | - |
| 4. Server-Authoritative Rewards + Rules Lockdown | 0/TBD | Not started | - |
| 5. Stripe Subscriptions + Premium Claims + Admin Panel | 0/TBD | Not started | - |
| 6. FCM iOS Wiring + Notifications + Daily Challenge | 0/TBD | Not started | - |
| 7. 12-Screen UI Polish + Shared Components + Observability + Lint Burndown | 0/TBD | Not started | - |

---

*Roadmap created: 2026-05-17 by gsd-roadmapper*
*Granularity: standard (7 phases — matches research baseline)*
*Coverage: 129/129 v1 requirements mapped, 0 orphaned*
