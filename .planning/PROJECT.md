# MentorMinds

## What This Is

AI-powered tutoring platform for O/A Level students in Bangladesh. Cambridge and Edexcel curricula. Built as a Flutter mobile app (iOS only today) backed by Firebase, with a Gemini-powered AI tutor ("MentorBot") that answers subject questions, analyses uploaded diagrams (Premium), and tracks streaks, points, and badges to drive daily learning habit.

## Core Value

A student preparing for O/A Levels can ask MentorBot a subject question and get a useful, curriculum-aligned answer in under 10 seconds — every single day, on a free tier that still feels usable.

## Requirements

### Validated

<!-- Inferred from existing code at the time of project init. None are "production validated" yet — the app has not shipped, but the capability exists in the codebase and runs in the simulator. -->

- ✓ Splash + auth-state-aware initial routing — existing (`lib/features/splash/`)
- ✓ Email/password + Google Sign-In login & registration — existing (`lib/features/auth/`)
- ✓ Three-page onboarding (welcome → level → subjects) — existing (`lib/features/onboarding/`)
- ✓ Student dashboard with sessions, materials, rewards entry points — existing (`lib/features/dashboard/`)
- ✓ Gemini-powered AI tutor chat with streaming responses + image attach — existing (`lib/features/tutor/`, `lib/core/services/gemini_service.dart`)
- ✓ Materials browser with subject/level filtering — existing (`lib/features/materials/`)
- ✓ Cross-content search across materials and past sessions — existing (`lib/features/search/`)
- ✓ Profile view + settings + logout — existing (`lib/features/profile/`)
- ✓ Rewards/gamification UI (points, badges, leaderboard, history) — existing (`lib/features/rewards/`)
- ✓ Notifications center with FCM topic-based delivery scaffold — existing (`lib/features/notifications/`)
- ✓ MVVM architecture via Riverpod 2.x `StateNotifier` + GoRouter — existing (`lib/core/routes/app_router.dart`)
- ✓ Firestore data model + security rules + indexes — existing (`firestore.rules`, `firestore.indexes.json`, `DATA.md`)

### Active

<!-- v1.0 milestone scope — see REQUIREMENTS.md for full REQ-ID breakdown -->

**12-screen polish per spec (frontend + backend contracts):**

- [ ] Refactor `lib/features/<name>/` → `lib/presentation/screens/<name>/` per spec path convention
- [ ] Splash: brand-accurate gradient + animated lettermark + dots loader (Screen 01)
- [ ] Onboarding: 3-page PageView matching spec layouts (Screen 02)
- [ ] Login: gradient header + Google button + reset-password flow (Screen 03)
- [ ] Register: password strength bar + role selector + ToS gate + email verification banner (Screen 04)
- [ ] Student Dashboard: SliverAppBar greeting + daily challenge + subject progress rings + carousels (Screen 05)
- [ ] AI Tutor Chat: subject selector dropdown + typing indicator + image preview + rate-limit banner + empty-state suggestions (Screen 06)
- [ ] Materials Browser: 2-col grid + level/subject/type filter rows + shimmer skeletons + detail bottom sheet (Screen 07)
- [ ] Search: tabbed results (All/Materials/Sessions) + recent searches + trending + premium lock on Sessions tab (Screen 08)
- [ ] Profile: gradient header + stats row + subscription card + grouped settings + danger zone (Screen 09)
- [ ] Rewards: tabbed Badges/Leaderboard/History + podium display + badge celebration overlay (Screen 10)
- [ ] Notifications: date-grouped list + swipe-to-dismiss + filter chips + detail bottom sheet (Screen 11)
- [ ] Admin Panel: NavigationRail (web/tablet) / BottomNavBar (mobile) + 5 tabs (Dashboard/Users/Content/Notifications/Analytics) with broadcast + upload + analytics charts (Screen 12)

**Shared components:**

- [ ] Premium Upgrade Modal (used across screens that hit free-tier limits)
- [ ] Badge Celebration Overlay (triggered on badge earn)
- [ ] Offline Banner (top of app shell, driven by connectivity_plus)

**Production hardening (HIGH-severity findings from codebase map):**

- [ ] **Fix avatar upload path mismatch** — `profile_viewmodel.dart:232` writes `avatars/{uid}.jpg`, `storage.rules` only allows `uploads/{uid}/...`. Currently 100% of avatar uploads fail in prod.
- [ ] **Server-authoritative points/rewards** — current `FieldValue.increment('points')` writes from client allowed by rules; leaderboard trivially gameable. Move to Cloud Function or restrict via rules with anti-tamper checks.
- [ ] **Gemini API key off-client** — currently baked into iOS binary via `--dart-define`. Move to Cloud Function proxy with App Check enforcement.
- [ ] **Wire Firebase Messaging** — SDK declared but never imported. Connect FCM background handler and topic subscriptions.
- [ ] **iOS Google Sign-In native config** — populate `GoogleService-Info.plist` `CLIENT_ID`/`REVERSED_CLIENT_ID` and `Info.plist` `CFBundleURLTypes`. Currently broken.
- [ ] **Bundle ID alignment** — `BACKEND_SETUP.md` says `com.mentorminds.mentorMinds`, Xcode project says `com.arnobrizwan.mentorminds`. Pick one.
- [ ] **Run Riverpod codegen** — toolchain declared but no `*.g.dart` files exist; any `@riverpod` annotations silently no-op.
- [ ] **Burn down lint debt** — 167 analyzer warnings (105 `withOpacity` → `withValues`, 42 `prefer_const`, 12 `depend_on_referenced_packages`).
- [ ] **CI + baseline tests** — GitHub Actions workflow running `flutter analyze` + `flutter test` on PR. At minimum: 1 unit test per viewmodel, smoke widget test per screen.

### Out of Scope

- **Android target** — iOS-only for v1.0. Android adds Play Store review, separate FCM setup, separate Firebase config, separate Google Sign-In SHA-1 fingerprint. Defer to v2.0.
- **Web target** — Flutter web is not configured. The spec mentions "Android + Web" but the brand is mobile-first and the AI tutor chat UX is tuned for touch.
- **Desktop targets (macOS/Linux/Windows)** — no demand signal.
- **Payment processing** — Premium upsell modal will be wired to a placeholder. Real bKash/Stripe integration deferred until product-market fit on free tier is proven.
- **Multi-language UI** — Bangladeshi students study in English at O/A Level. Bengali UI deferred.
- **Offline-first sync** — connectivity banner only. No local Firestore cache priming, no offline queue. Defer.
- **Teacher accounts beyond placeholder role** — `role: 'teacher'` exists in user doc but no teacher-specific screens or workflows in v1.0.
- **Dark mode** — toggle placeholder in Profile settings; no dark theme implementation in v1.0.

## Context

**Domain:** O/A Level prep in Bangladesh is a high-stakes, high-competition market. Students typically study Mathematics, Physics, Chemistry, Biology, English, ICT, Accounting, Economics, History, Geography. Cambridge International + Edexcel are the dominant exam boards. Existing competitors are mostly Bangla-language YouTube tutors and paid coaching centres — the differentiator here is on-demand AI tutoring at a price point students can self-fund.

**Codebase state at init:** 30 Dart files under `lib/`, ~17K LOC of production code, all 12 screens exist in skeleton form. Architecture is MVVM with Riverpod 2.x `StateNotifier`, navigation via GoRouter, backend wired to Firebase. The 12-screen spec the user provided is a **polish pass** — it's defining the target UX/contracts for screens that already roughly work, not building from zero. See `.planning/codebase/` for the full map (STACK, ARCHITECTURE, STRUCTURE, CONVENTIONS, TESTING, INTEGRATIONS, CONCERNS).

**Severity context:** The HIGH-severity findings in `CONCERNS.md` are blockers for any real launch — the leaderboard is currently a vanity metric anyone can spoof, every avatar upload silently fails, and the Gemini API key is in the binary. These are not "polish" — they're production gates.

**Single developer:** Arnob Rizwan Ahmad (UTM SE 2025). Solo project; no separate backend team. This shapes how much custom Cloud Function work is realistic.

## Constraints

- **Tech stack**: Flutter 3.41 / Dart 3.11 — locked. Pubspec is set; major framework swap is off the table.
- **State management**: Riverpod 2.x via `hooks_riverpod` — locked. Existing code is consistent; switching to bloc/getx would be a full rewrite.
- **Backend**: Firebase (Auth, Firestore, Storage, Messaging, optionally Functions) — locked. No self-hosted backend.
- **AI provider**: Google Gemini (gemini-1.5-flash) — current choice. Could be reconsidered in v1.1+ but for v1.0 the integration exists.
- **Platform**: iOS-only for v1.0. Android/Web/macOS are explicitly out of scope.
- **Compliance**: Firebase API keys are public client config (acceptable per Firebase docs); real protection lives in `firestore.rules` + `storage.rules` + (future) App Check. Gemini API key must NOT remain in the compiled binary.
- **Team size**: Solo dev. Phase scope must be realistic for one engineer.
- **Brand**: #1A3C8F primary / #00C9A7 accent / #F5A623 gold / Poppins headers / Inter body / JetBrains Mono for AI output. Locked per spec.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Refactor `lib/features/` → `lib/presentation/screens/` | User chose this in the spec; aligns folder name with intent (UI screens, not domain features). Cost is one-time import rewrite + GoRouter rewire. | — Pending |
| Horizontal Layers phase mode | User-selected. Existing code is feature-complete in skeleton; horizontal passes (refactor → rules/security → viewmodel cleanup → UI polish per spec) fit better than vertical MVP slices since there's no "first thin slice" left to ship. | — Pending |
| iOS-only for v1.0 | Existing project only has `ios/` folder. Adding Android+Web mid-milestone triples integration testing surface and delays shipping. | — Pending |
| Server-authoritative points via Cloud Function (or rules-with-checks) | Current client-side `FieldValue.increment` is gameable. Must close before launch. | — Pending |
| Gemini behind Cloud Function proxy | API key in compiled iOS binary is exfiltratable. Proxy via Function with App Check enforcement. | — Pending |
| YOLO + Standard granularity + Parallel + Research/PlanCheck/Verifier all on | User config selections. Standard granularity (5-8 phases) fits 12 screens grouped by functional area + security pass. | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-17 after initialization*
