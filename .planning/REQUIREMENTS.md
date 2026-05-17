# Requirements: MentorMinds

**Defined:** 2026-05-17
**Core Value:** A student preparing for O/A Levels can ask MentorBot a subject question and get a useful, curriculum-aligned answer in under 10 seconds — every single day, on a free tier that still feels usable.

## v1 Requirements

Requirements for the v1.0 hardening + 12-screen polish milestone. The 12 screens already exist as skeletons — these requirements define the contract for v1.0-shippable behavior. Traceability (which phase delivers which REQ) is filled in by the roadmapper.

### Architecture & Foundation

- [ ] **ARCH-01**: Codebase is restructured into `lib/presentation/screens/`, `lib/application/viewmodels/`, `lib/data/{repositories,services,models}/` with a hard one-way import rule (presentation → application → data) enforced by `custom_lint`.
- [ ] **ARCH-02**: Inline data models (ChatMessage, DashboardUser, MaterialItem, SessionItem, BadgeItem, etc.) are extracted from viewmodels into `lib/data/models/`.
- [ ] **ARCH-03**: Direct `FirebaseFirestore.instance` / `FirebaseAuth.instance` calls are removed from viewmodels in favor of repository providers in `lib/data/repositories/`.
- [ ] **ARCH-04**: Bundle ID is aligned to `com.mentorminds.mentorMinds` across Xcode project + Firebase iOS app registration + APNs association + BACKEND_SETUP.md.
- [ ] **ARCH-05**: iOS deployment target is bumped from 13.0 to 14.0 (unlocks App Attest as primary App Check provider).
- [ ] **ARCH-06**: Avatar upload path mismatch is fixed (`profile_viewmodel.dart` writes to a path allowed by `storage.rules`).
- [ ] **ARCH-07**: iOS Google Sign-In native config is populated (`GoogleService-Info.plist.CLIENT_ID` + `REVERSED_CLIENT_ID`, `Info.plist.CFBundleURLTypes`).

### Continuous Integration & Testing

- [ ] **CI-01**: GitHub Actions workflow runs `flutter analyze` on every PR (Ubuntu runner, Flutter 3.41.x pinned).
- [ ] **CI-02**: GitHub Actions workflow runs `flutter test` on every PR with coverage report uploaded as an artifact.
- [ ] **CI-03**: GitHub Actions workflow lints + builds the Cloud Functions TypeScript project on PRs that touch `functions/**`.
- [ ] **CI-04**: A smoke widget test exists for each of the 12 screens (asserts mount + key visible elements; no business logic).
- [ ] **CI-05**: A unit test exists for each viewmodel covering happy-path state transitions and at least one error path.
- [ ] **CI-06**: Firebase Local Emulator Suite (Auth + Firestore + Storage + Functions) is scaffolded and used as the default test environment.
- [ ] **CI-07**: `dev_dependencies` includes the v1.0 test harness: `mocktail`, `fake_cloud_firestore`, `firebase_auth_mocks`, `golden_toolkit`, `network_image_mock`, `integration_test`.

### Cloud Functions & App Check

- [ ] **FUNC-01**: A `functions/` monorepo exists at repo root (TypeScript, Node 20, `firebase-functions ^6.x` v2 API, region `asia-south1`).
- [ ] **FUNC-02**: A `ping` callable function is deployed with `enforceAppCheck: true` to validate the App Check + auth wiring end-to-end.
- [ ] **FUNC-03**: Firebase App Check is activated in `main.dart` with App Attest provider (release) + Debug provider (dev/CI); debug tokens are registered for every dev simulator.
- [ ] **FUNC-04**: A GCP Billing budget alert is configured at $10/month wired to admin email.
- [ ] **FUNC-05**: Artifact Registry retention policy is set to keep only the last 3 versions of each function image.
- [ ] **FUNC-06**: `cloud_functions ^5.x` Flutter SDK is added to `pubspec.yaml` and wired through `lib/data/services/`.

### AI Tutor Backend (Gemini Proxy)

- [ ] **AI-01**: A `mentorBotChat` callable function proxies all Gemini calls; reads `GEMINI_API_KEY` from Google Secret Manager (no client-side key).
- [ ] **AI-02**: `--dart-define=GEMINI_API_KEY` is removed from all build configs and the existing Google AI Studio key is rotated.
- [ ] **AI-03**: `google_generative_ai` Dart package is removed from `pubspec.yaml` after the proxy ships.
- [ ] **AI-04**: Free-tier daily cap is enforced server-side at **30 text messages + 3 image messages per UTC+6 day**, with a shared `QUOTA_TZ = 'Asia/Dhaka'` constant in both `lib/core/` and `functions/src/`.
- [ ] **AI-05**: Burst limit is enforced server-side: maximum 5 messages per 60 seconds per user.
- [ ] **AI-06**: An app-wide monthly Gemini call ceiling is enforced via `/system/quota/{YYYY-MM}` document; over-ceiling requests return `unavailable` with a generic "AI tutor temporarily unavailable" message.
- [ ] **AI-07**: All Gemini callable writes (`/sessions/{sid}`, `/users/{uid}/usage/{today}`) happen in a single transaction; client includes a deterministic `clientRequestId` (UUID) for idempotent retries.
- [ ] **AI-08**: `firestore.rules` lock `/users/{uid}/usage/{date}` to read-only for the owning client (Admin SDK writes via Function).
- [ ] **AI-09**: System prompt (Cambridge/Edexcel marking-scheme tone, curriculum-aligned) lives server-side in `functions/src/lib/gemini.ts` so it can be updated without an app release.
- [ ] **AI-10**: Tutor chat ships as **non-streaming** in v1.0 (typing indicator shown while awaiting Function response). Streaming deferred to v1.1.

### Server-Authoritative Rewards

- [ ] **REWD-01**: `onSessionWrite` Firestore trigger awards points idempotently based on session state deltas (first message of day, first-of-session, threshold crossings). Trigger dedupes by `clientRequestId` and document state.
- [ ] **REWD-02**: `onUserCreate` trigger initializes `/rewards/{uid}` and sets default custom claims (`{ role: 'student', premium: false }`).
- [ ] **REWD-03**: Rewards history is stored as an append-only subcollection at `/rewards/{uid}/ledger/{autoId}` (NOT an unbounded `history` array on the parent doc).
- [ ] **REWD-04**: Client-side `FieldValue.increment('points')` writes are removed from `chat_viewmodel`, `dashboard_viewmodel`, and `gamification_viewmodel`.
- [ ] **REWD-05**: `firestore.rules` forbid client writes to `points`, `badges`, `streak` on `/users/{uid}`; forbid all client writes under `/rewards/{uid}/**`.
- [ ] **REWD-06**: A `@firebase/rules-unit-testing` suite asserts the lockdown: tests that pass before lockdown FAIL after, tests that should fail before PASS after.
- [ ] **REWD-07**: Global leaderboard is cut from v1.0 scope; user sees only personal stats (points, streak, badges, history).

### Subscription & Premium (Stripe)

- [ ] **PAY-01**: A `/subscriptions/{uid}` Firestore document is created per user with the v2-ready schema (`tier`, `status`, `currentPeriodStart`, `currentPeriodEnd`, `provider`, `providerSubscriptionId`, `cancelAtPeriodEnd`, `metadata.grantedBy`).
- [ ] **PAY-02**: Stripe integration ships with: customer creation on first subscribe attempt, subscription creation (monthly + yearly), webhook handler for `customer.subscription.{created,updated,deleted}` and `invoice.{paid,payment_failed}`.
- [ ] **PAY-03**: A `setPremium` admin-only callable function flips a user to/from premium (writes `/subscriptions/{uid}` + `setCustomUserClaims(uid, { premium: true })`).
- [ ] **PAY-04**: Client force-refreshes ID token (`getIdToken(true)`) after admin grants premium or after a Stripe webhook flips the subscription so server-side gating sees the new claim within seconds.
- [ ] **PAY-05**: Premium UI gating reads `/users/{uid}/subscription.tier` (real-time stream); server-side Function gating reads `request.auth.token.premium` (custom claim).
- [ ] **PAY-06**: Premium upgrade modal links to a Stripe Checkout session (hosted Stripe page; no embedded card form in v1.0).
- [ ] **PAY-07**: Subscription cancellation flow: user can cancel from Profile → Manage Subscription → cancel at period end via Stripe Customer Portal.
- [ ] **PAY-08**: Premium tier unlocks: unlimited AI messages (no daily cap, only the app-wide monthly ceiling and burst limit apply); image attachment (free users get 3/day, premium gets unlimited within burst); full chat history search (free users get last 7 days).
- [ ] **PAY-09**: Image attachment is FREE for all users at 3/day quota (per research — table stakes since Photomath 2017). Premium removes the cap, not the feature.
- [ ] **PAY-10**: Full chat history search is FREE for all users (per research — keep the moat). Premium gets no extra benefit on search.

> ⚠️ **PAY risk**: Stripe-only for in-app digital subscriptions on iOS may violate App Store Guideline 3.1.1. Apple typically requires in-app purchase for digital goods consumed in-app. Acceptable mitigations: route subscribe through external web flow (Stripe Checkout opens in Safari, not in-app webview), OR plan to add Apple IAP in v1.1 before App Store submission. Phase planning must surface this before code lands.

### Authentication (Polish on Existing)

- [ ] **AUTH-01**: Register screen enforces email format, password strength (8+ chars, 1 upper, 1 number), and password confirmation match in real time per Screen 04 spec.
- [ ] **AUTH-02**: After registration, user receives email verification AND **cannot use the AI tutor or save sessions until verified** (hard block). All other navigation works; the gate lives inside `ChatViewModel.sendMessage` and `SessionsRepository.save`.
- [ ] **AUTH-03**: Verification reminder banner appears on Dashboard, Tutor, Materials, Search, Profile until `currentUser.emailVerified == true`; banner offers "Resend Email" action.
- [ ] **AUTH-04**: User can reset password via email link (already wired; verify works end-to-end on real iOS device).
- [ ] **AUTH-05**: Google Sign-In works end-to-end on iOS device (depends on ARCH-07).
- [ ] **AUTH-06**: Login + Register screens match Screen 03/04 spec (gradient header, prefix icons, error states, Google button styling).
- [ ] **AUTH-07**: Logout clears SharedPreferences (preserving `onboarding_complete`), signs out of both Firebase + Google, and routes to `/auth/login`.

### Onboarding (Polish on Existing)

- [ ] **ONBD-01**: Onboarding is a 3-page PageView (Welcome → Level → Subjects) matching Screen 02 spec.
- [ ] **ONBD-02**: Page 2 requires level selection (O-Level or A-Level) before "Continue" enables; selection persisted to `SharedPreferences.onboarding_level`.
- [ ] **ONBD-03**: Page 3 requires at least one subject before "Start Learning" enables; selections persisted to `SharedPreferences.onboarding_subjects`.
- [ ] **ONBD-04**: On completion, navigation passes level + subjects as query params to `/auth/register`; Register screen seeds the new user doc with these values.

### Splash & Routing (Polish on Existing)

- [ ] **SPLA-01**: Splash screen renders the brand-accurate gradient (#1A3C8F → #0D2660) + animated lettermark + dots loader per Screen 01 spec.
- [ ] **SPLA-02**: After 2000ms, routes based on auth state: not signed in + onboarding incomplete → `/onboarding`; not signed in + onboarding complete → `/auth/login`; signed in → role-routed to `/dashboard` (student/premium_student), `/dashboard/teacher` (teacher), `/admin` (admin).
- [ ] **SPLA-03**: Firestore role-fetch error during splash routes to `/auth/login` with an error snackbar.

### Student Dashboard (Polish on Existing)

- [ ] **DASH-01**: Dashboard renders `SliverAppBar` with time-of-day greeting (`Good [morning/afternoon/evening], {Name}!`), streak counter, and total points chip per Screen 05 spec.
- [ ] **DASH-02**: A Daily Challenge card is shown with today's challenge (subject + question), "Attempt Now" CTA, and a countdown to reset (UTC+6 midnight). Challenge content is rotated daily by a Cloud Scheduler job that writes to `/daily_challenges/{YYYY-MM-DD}`.
- [ ] **DASH-03**: Subject progress rings are shown horizontally for each of the user's selected subjects; ring fill = (sessions on subject this week) / (target = 5).
- [ ] **DASH-04**: Recent Sessions section shows the last 3 sessions; tapping opens that session in the AI Tutor screen.
- [ ] **DASH-05**: New Materials carousel shows the 6 most recent materials matching the user's subject list.
- [ ] **DASH-06**: Daily login points (+5) are awarded server-side by `onSessionWrite` trigger on the user's first session of the day; client surfaces a "+5 pts 🎉" toast when `/rewards/{uid}.history` adds the corresponding ledger entry.
- [ ] **DASH-07**: Bottom NavigationBar exists with 5 destinations (Home, AI Tutor, Materials, Rewards, Profile); admin users see an Admin destination instead of Rewards.

### AI Tutor Chat (Polish on Existing)

- [ ] **TUTR-01**: Chat screen renders per Screen 06 spec: subject selector dropdown, level pill, user/assistant bubbles with the specified shapes/colors, typing indicator while awaiting response, empty-state with 4-6 suggestion chips per subject.
- [ ] **TUTR-02**: Free users see a rate-limit banner at 80% of daily quota (24 of 30 text messages); a full-overlay card when 30/30 reached, offering "Upgrade to Premium" CTA.
- [ ] **TUTR-03**: Image attachment button is enabled for all users (FREE 3/day); shows upgrade prompt at quota; uploads via Firebase Storage to `uploads/{uid}/{ts}.jpg` (allowed by current rules), passes URL to `mentorBotChat` callable.
- [ ] **TUTR-04**: Each AI response can be copied (long-press copy button) and feedback-rated (👍/👎); feedback is logged to `/sessions/{sid}/feedback/{autoId}` for future quality analysis.
- [ ] **TUTR-05**: Session is auto-saved to `/sessions/{sid}` on every message exchange; user can resume any past session from Dashboard or Search.
- [ ] **TUTR-06**: Subject + level can be changed mid-session; subsequent messages include the new context to Gemini.
- [ ] **TUTR-07**: AI response is rendered via `flutter_markdown` (bold, bullets, code blocks); JetBrains Mono for code/formula blocks per brand spec.

### Materials Browser (Polish on Existing)

- [ ] **MATS-01**: Materials browser renders the 2-column grid + level/subject/type filter rows per Screen 07 spec.
- [ ] **MATS-02**: Search bar above grid filters by title (case-insensitive contains) with 300ms debounce.
- [ ] **MATS-03**: Pagination via DocumentSnapshot cursor (20 per page); "Load More" button appears at grid bottom; "All materials loaded" when no more.
- [ ] **MATS-04**: Tapping a material card opens a bottom sheet with title/subject/level/date + "Open" CTA; "Open" launches URL via `url_launcher` for PDFs/videos.
- [ ] **MATS-05**: Material view count increments on bottom sheet open (`FieldValue.increment(1)` on `/materials/{mid}.views`).
- [ ] **MATS-06**: Shimmer skeleton (6 cards) shows during initial load; empty-state illustration shows when filters yield zero results.

### Search (Polish on Existing)

- [ ] **SRCH-01**: Search screen auto-focuses search bar on open; shows recent searches (last 5 from SharedPreferences) and trending topic chips when empty.
- [ ] **SRCH-02**: Search results are tabbed (All / Materials / My Sessions); All tab merges and group-labels both sources.
- [ ] **SRCH-03**: Materials search uses Firestore prefix query on title; My Sessions search filters client-side on message content.
- [ ] **SRCH-04**: Matched text is highlighted in `kPrimary` color within result tiles.
- [ ] **SRCH-05**: All users can search their full session history (no Premium gate per PAY-10).

### Profile (Polish on Existing)

- [ ] **PROF-01**: Profile screen renders the gradient header + 3-column stats row + subscription card + grouped settings + danger zone per Screen 09 spec.
- [ ] **PROF-02**: User can edit name and avatar (avatar uploads via fixed path per ARCH-06).
- [ ] **PROF-03**: User can change password (re-auth then update; uses `EmailAuthProvider.credential`).
- [ ] **PROF-04**: User can update their subjects and level; updates `/users/{uid}` doc.
- [ ] **PROF-05**: User can manage subscription: free users see "Upgrade to Premium" → Stripe Checkout; premium users see "Manage Subscription" → Stripe Customer Portal.
- [ ] **PROF-06**: User can delete their account: confirmation dialog with typed confirmation, then deletes `/users/{uid}` + `/rewards/{uid}` + avatar in Storage + `FirebaseAuth.user.delete()`. (Required by App Store since 2022.)
- [ ] **PROF-07**: User can log out (clears prefs except `onboarding_complete`, signs out of Firebase + Google).

### Rewards / Gamification (Polish on Existing)

- [ ] **RWRD-01**: Rewards screen renders animated count-up of total points + progress card to next milestone per Screen 10 spec.
- [ ] **RWRD-02**: Badges tab shows earned grid + locked grid; locked badges show progress hint ("Ask 3 more questions to unlock"); tapping any badge opens a detail bottom sheet.
- [ ] **RWRD-03**: Leaderboard tab is CUT from v1.0; tab is removed from the TabBar (only Badges + History remain).
- [ ] **RWRD-04**: History tab shows chronological `PointsHistoryTile` list driven by `/rewards/{uid}/ledger/{autoId}` stream.
- [ ] **RWRD-05**: Badge celebration overlay (`BadgeCelebrationOverlay` shared widget) is triggered when the `/rewards/{uid}` stream emits a new badge in the `badges` array; auto-dismisses after 3s; confetti animation.
- [ ] **RWRD-06**: Badge unlock conditions are evaluated server-side in `onSessionWrite` (first_step ≥1 session, curious_learner ≥50 questions, dedicated_learner ≥5 sessions, week_warrior ≥7-day streak, month_master ≥30-day streak, diagram_detective ≥10 uploads, subject_expert ≥100 questions in one subject).

### Notifications (Polish on Existing + FCM Wiring)

- [ ] **NOTF-01**: `firebase_messaging` is fully wired: SDK initialized in `main.dart` before `runApp`; request permission with rationale; obtain FCM token; poll for APNs token (up to 10s); subscribe to topics `role_student` / `role_premium_student` / `role_teacher` / `role_admin` / `role_all` per the user's role.
- [ ] **NOTF-02**: Top-level background handler annotated with `@pragma('vm:entry-point')`; persists received messages to `/notifications/{nid}` so the in-app list mirrors push history.
- [ ] **NOTF-03**: Foreground messages display via `flutter_local_notifications` banner.
- [ ] **NOTF-04**: On `onTokenRefresh`, re-subscribe to all current topics.
- [ ] **NOTF-05**: Notifications screen renders the date-grouped list (Today / Yesterday / This Week) + filter chips (All / Announcements / Achievements / Reminders) + swipe-to-dismiss (marks read) per Screen 11 spec.
- [ ] **NOTF-06**: Unread count badge on top-app-bar bell icon (`/notifications` where `recipientRole in [user.role, 'all']` and `read == false`).
- [ ] **NOTF-07**: "Mark all read" action batch-writes `{read: true}` to all unread notifications for the user's role.
- [ ] **NOTF-08**: Tapping a notification opens detail bottom sheet; supports type-specific CTAs (new_material → "Open Material"; achievement → "View Rewards").

### Admin Panel (Polish on Existing)

- [ ] **ADMN-01**: Admin Panel uses `NavigationRail` on tablet/web breakpoints, `BottomNavBar` on mobile, with 5 destinations (Dashboard, Users, Content, Notifications, Analytics).
- [ ] **ADMN-02**: Dashboard tab shows stats grid (Total Users, Premium Users, Materials, Sessions Today) backed by Firestore count() queries; Recent Activity feed merges users + sessions + materials.
- [ ] **ADMN-03**: Users tab lists users (50 per page, cursor pagination) with filter chips, role/subscription badges; "⋮" menu offers Change Role, Toggle Premium (calls `setPremium` callable), Delete User.
- [ ] **ADMN-04**: Content tab provides upload form (title, subject, level, type, file picker → Firebase Storage `materials/{uuid}.ext` → `/materials/{mid}` doc); deletes remove from Storage + Firestore.
- [ ] **ADMN-05**: After material upload, FCM topic broadcast to `role_student` via `sendBroadcast` callable ("New material added: {title}").
- [ ] **ADMN-06**: Notifications tab provides broadcast form (title, message, target role, type); preview card; "Send" calls `sendBroadcast` callable.
- [ ] **ADMN-07**: Analytics tab shows charts via `fl_chart`: DAU line chart (last 30d), subject-distribution pie chart, weekly registrations bar chart.
- [ ] **ADMN-08**: Admin role is gated via `request.auth.token.role == 'admin'` custom claim AND `/users/{uid}.role == 'admin'`; non-admin routes to `/dashboard` with a "Not authorized" snackbar.

### Shared Components

- [ ] **SHRD-01**: `PremiumUpgradeModal` bottom sheet exists as a shared widget with gradient background, feature list, monthly/yearly Stripe price toggle, "Upgrade Now" CTA → Stripe Checkout, "Maybe Later" ghost button.
- [ ] **SHRD-02**: `BadgeCelebrationOverlay` shared widget (confetti animation, badge emoji scale-bounce, points chip, tap-to-dismiss, auto-dismiss 3s).
- [ ] **SHRD-03**: `OfflineBanner` widget mounted in the app shell, driven by `connectivity_plus` stream, slides in/out on connectivity change.

### Observability

- [ ] **OBSV-01**: `firebase_crashlytics ^4.x` is wired: `FlutterError.onError` + `PlatformDispatcher.instance.onError` + `runZonedGuarded` + Dart-side uncaught logging to Crashlytics.
- [ ] **OBSV-02**: iOS dSYM upload Run Script Phase is added to Xcode (Crashlytics native symbolication).
- [ ] **OBSV-03**: `firebase_analytics ^11.x` is wired: `FirebaseAnalyticsObserver` attached to GoRouter for automatic screen-view events.
- [ ] **OBSV-04**: Custom analytics events fire for: send_message, upload_image, complete_session, earn_badge, upgrade_started, upgrade_completed.
- [ ] **OBSV-05**: `package_info_plus` + `device_info_plus` populate Crashlytics keys (app version, build number, device model, iOS version).

### Code Quality

- [ ] **QUAL-01**: All 105 `withOpacity` deprecation warnings are resolved by migrating to `.withValues(alpha: ...)` per-file, each migration accompanied by a golden test (catches mid-tone shift on wide-gamut displays).
- [ ] **QUAL-02**: All 42 `prefer_const_constructors` warnings are resolved.
- [ ] **QUAL-03**: All 12 `depend_on_referenced_packages` warnings are resolved by adding `flutter_riverpod` to `dependencies` in `pubspec.yaml`.
- [ ] **QUAL-04**: `custom_lint` + `riverpod_lint` are added as `dev_dependencies` and pass on CI.
- [ ] **QUAL-05**: `flutter analyze` reports zero issues (errors, warnings, AND info) on main.
- [ ] **QUAL-06**: Riverpod codegen produces `*.g.dart` files for any `@riverpod` annotations (if used). If not used, the unused `riverpod_annotation` / `riverpod_generator` / `injectable` / `injectable_generator` / `get_it` packages are removed from `pubspec.yaml`.

## v2 Requirements

Deferred to a future milestone.

### Platforms

- **PLAT-01**: Android target (separate FCM setup, separate Firebase config, SHA-1 fingerprints, Play Store review)
- **PLAT-02**: Flutter web target
- **PLAT-03**: Dark mode

### AI Capabilities

- **AI2-01**: Token-streaming Gemini responses through `onCallStream`
- **AI2-02**: Past-paper marking-scheme mode (upload past paper → AI grades student answer with examiner-style commentary)
- **AI2-03**: Bangla/English bilingual answer toggle
- **AI2-04**: Voice input + TTS output for accessibility

### Social & Engagement

- **SOC2-01**: Cohort-based leaderboard (30-person buckets, weekly reset)
- **SOC2-02**: Friend-based leaderboard (add friends, see their points)
- **SOC2-03**: Study groups (shared sessions, peer comments)

### Premium / Payments

- **PAY2-01**: Apple In-App Purchase (StoreKit 2) — mandatory for iOS subscription compliance per Guideline 3.1.1 (see PAY risk note)
- **PAY2-02**: bKash payment rail (BD-native alternative for users without international cards)
- **PAY2-03**: Annual + lifetime tiers

### Content & Curriculum

- **CONT2-01**: Topic-level mastery tracking (per-subject, per-topic competency scores)
- **CONT2-02**: Teacher dashboard (assign content, view student progress)
- **CONT2-03**: User-uploaded materials (currently admin-only)
- **CONT2-04**: Multi-curriculum support (CIE A-Level + IB + other boards)

### Infrastructure

- **INFR-01**: Offline-first sync (local Firestore cache priming, offline message queue)
- **INFR-02**: Multi-region failover for Cloud Functions
- **INFR-03**: A/B test framework wired through Firebase Remote Config

## Out of Scope

| Feature | Reason |
|---------|--------|
| Android, web, macOS, Linux, Windows targets | iOS-only for v1.0. Adding more platforms triples integration testing surface. → v2 (PLAT-01/02) |
| Global all-users leaderboard | Per research: always-bottom-of-list problem destroys new-user motivation; incentivizes spamming. → v2 cohort-based (SOC2-01) |
| Teacher self-signup UX | Role exists in DB; admin promotion only for v1.0. Teacher dashboard is full product surface area. → v2 (CONT2-02) |
| In-app admin analytics beyond `fl_chart` Dashboard tab | Firebase Analytics + GA4 console is the production tool. v1.0 ships the basic 3 charts; advanced funnels live in GA4. |
| Bengali UI strings | O/A Level students study in English; localization is a v2 cost. → v2 (AI2-03 covers bilingual *answers*) |
| Streaming Gemini responses | Callable streaming SDK uncertain; ship non-streaming v1.0 with typing indicator. → v2 (AI2-01) |
| Offline-first sync | Connectivity banner only; no Firestore cache priming or offline queue. → v2 (INFR-01) |
| Token-by-token rendering in tutor bubbles | See above — depends on streaming. v1.0 renders the full message when Function returns. |
| Crash reporting beyond Crashlytics | No Sentry/Datadog/etc. Crashlytics is sufficient at v1.0 scale. |
| Free-tier global ad serving | Not contemplated. If monetization beyond Premium is needed, address in v2. |
| Premium "Upgrade later" reminder push | Anti-pattern; users hate these. Won't ship. |
| Crash + analytics on Cloud Functions | Cloud Run revision logs + Cloud Monitoring dashboards suffice; no APM tool. |
| iOS App Attest debug mode in CI | Use Debug provider only in CI; no real attestation needed for headless tests. |
| Universal Links / deep linking | Spec doesn't require it; `firebase_dynamic_links` is shutting down anyway. |

## Traceability

Filled in by the roadmapper. Each requirement maps to exactly one phase.

| Requirement | Phase | Status |
|-------------|-------|--------|
| (populated by gsd-roadmapper) | — | Pending |

**Coverage:**
- v1 requirements: ~110 total (see categorical lists above)
- Mapped to phases: 0 (pre-roadmap)
- Unmapped: ~110 ⚠️ — will be 0 after roadmap

---
*Requirements defined: 2026-05-17*
*Last updated: 2026-05-17 after initial definition*
