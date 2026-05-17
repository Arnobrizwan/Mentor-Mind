# Phase 1: Foundation — Refactor, CI, Test Harness, iOS Identity - Context

**Gathered:** 2026-05-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Land the structural refactor (`lib/features/` → `lib/presentation/screens/` + `lib/application/viewmodels/` + `lib/data/{repositories,services,models}/`), stand up GitHub Actions CI + Firebase Local Emulator Suite + a test harness with anchor tests, fix the avatar-upload path mismatch, wire iOS Google Sign-In native config, flip the bundle id to `com.mentorminds.mentorMinds`, build against iOS 26 SDK with iOS 14.2 minimum deployment, and enforce a one-way `presentation → application → data` import rule via `custom_lint` from day one.

**Zero behavioural change** in this phase. Every later phase writes directly to the new tree.

**Requirements covered:** ARCH-01..07, CI-01..07, QUAL-04, QUAL-06.
**Scope adjustment:** QUAL-03 (`flutter_riverpod` dep fix) is pulled forward from Phase 7 — the transitive-export risk makes deferral unsafe.

</domain>

<decisions>
## Implementation Decisions

### Repository abstraction shape (ARCH-03)

- **D-01:** Repositories are organised **per-collection**, not per-feature. Six repos live under `lib/data/repositories/`:
  - `UsersRepository` — `/users/{uid}` + `/users/{uid}/usage/{date}` reads
  - `SessionsRepository` — `/sessions/{sid}` + `/sessions/{sid}/feedback`
  - `MaterialsRepository` — `/materials` + view-count increment + cursor pagination
  - `NotificationsRepository` — `/notifications` per-role queries
  - `RewardsRepository` — `/rewards/{uid}` + `/rewards/{uid}/ledger/{autoId}` (subcollection lands in Phase 4)
  - `SubscriptionsRepository` — `/subscriptions/{uid}` (Phase 5 actually populates it; the repo is scaffolded with stub methods in Phase 1 so the import graph is stable)
- **D-02:** Repositories return **decoded domain models**, never raw `QuerySnapshot` / `DocumentSnapshot`. E.g. `MaterialsRepository.streamMaterials({...})` returns `Stream<List<MaterialItem>>`. Repos own all `fromDoc`/`toMap` mapping. Viewmodels never import `cloud_firestore`.
- **D-03:** Extracted inline models live **flat** under `lib/data/models/`, one file per entity (`chat_message.dart`, `dashboard_user.dart`, `session_item.dart`, `material_item.dart`, `badge_item.dart`, `app_notification.dart`, `profile_user.dart`, `rewards_snapshot.dart`, etc.). No barrel files; no per-collection grouping.
- **D-04:** Repositories are wired into viewmodels via **Riverpod providers**. SDK singletons are themselves exposed as providers (`firestoreProvider`, `firebaseAuthProvider`, `firebaseStorageProvider`) so `ProviderScope.overrides` can swap them in tests. No `get_it`, no `injectable`.

### Riverpod codegen + DI package cleanup (QUAL-06, +QUAL-03 pulled forward)

- **D-05:** Viewmodels stay on **vanilla `StateNotifier` + `StateNotifierProvider`** in Phase 1. No `@riverpod` codegen migration. The migration is bundled with the future Riverpod 2 → 3 upgrade (v1.1) — doing it inside the "pure git mv" refactor would destroy diff hygiene.
- **D-06:** Delete the following from `pubspec.yaml`:
  - `riverpod_annotation` (dep) — unused
  - `riverpod_generator` (dev_dep) — unused
  - `injectable` (dep) — unused
  - `injectable_generator` (dev_dep) — unused
  - `get_it` (dep) — unused
  - `build_runner` (dev_dep) — no remaining codegen consumer
- **D-07:** **Add `flutter_riverpod: ^2.6.1` to `dependencies`** (currently transitive-only via `hooks_riverpod`). Clears 12 `depend_on_referenced_packages` info hits and removes a latent v3 break. This is QUAL-03 pulled forward from Phase 7.
- **D-08:** Layer enforcement uses **`custom_lint` + `riverpod_lint` + a project-local custom_lint rule**:
  - `custom_lint` + `riverpod_lint` added to `dev_dependencies`
  - Project-local rule (in `tool/lints/` or `lib/_lints/`) bans `package:cloud_firestore`, `package:firebase_auth`, `package:firebase_storage`, `package:firebase_messaging` imports from `lib/presentation/**`
  - Same rule bans `lib/data/**` from importing `lib/presentation/**`
  - `dart run custom_lint` runs as a CI gate

### Test scaffolding depth (CI-04, CI-05, CI-06, CI-07)

- **D-09:** **Harness + anchor tests** strategy. Full smoke coverage is deferred to Phase 7. Phase 1 ships:
  - All 6 test deps installed (`mocktail`, `fake_cloud_firestore`, `firebase_auth_mocks`, `golden_toolkit`, `network_image_mock`, `integration_test`)
  - **Anchor tests** (≈5 total, one per category):
    1. `test/core/utils/validators_test.dart` — pure unit; covers `name`/`email`/`password`/`loginPassword`/`confirmPassword`/`role` boundaries
    2. `test/application/viewmodels/onboarding_viewmodel_test.dart` — uses `SharedPreferences.setMockInitialValues({})`; no Firebase
    3. `test/application/viewmodels/auth_viewmodel_test.dart` — uses `mocktail` + `firebase_auth_mocks` + `fake_cloud_firestore`; one happy path + one error path
    4. `test/presentation/screens/dashboard_screen_test.dart` — widget test using `ProviderScope.overrides` to inject a fake `DashboardViewModel`
    5. `integration_test/login_smoke_test.dart` — runs against the Firebase Emulator Suite; verifies sign-in + dashboard route
- **D-10:** Firebase Local Emulator Suite scope: **Auth + Firestore + Storage only.** `functions` emulator is configured in Phase 2 when `functions/` exists. `integration_test/` targets the emulator by default; unit + widget tests use `fake_cloud_firestore`/`firebase_auth_mocks` (in-process, no emulator startup cost).
- **D-11:** Test directory **mirrors `lib/` structure**: `test/presentation/screens/`, `test/application/viewmodels/`, `test/data/repositories/`, `test/data/models/`, `test/core/utils/`. Plus `test/_support/` (factories, fixtures) and `test/_helpers/` (ProviderScope helpers). `integration_test/` at repo root per Flutter convention.
- **D-12:** **Goldens are deferred to Phase 7.** Install `golden_toolkit` in Phase 1 (CI-07 requires it) but write zero goldens. Goldens make sense only after `AppTheme` stabilises in the polish phase; writing them now means rewriting them later.
- **D-13:** CI gates in Phase 1:
  - `flutter analyze --fatal-warnings` (NOT `--fatal-infos` — 167 info hits remain until Phase 7)
  - `flutter test --coverage`; upload `coverage/lcov.info` as a workflow artifact
  - No coverage threshold yet — gate is "tests pass", not "coverage ≥ X%"
  - `dart run custom_lint` (fails build on layer violations)
  - `functions/**` TypeScript lint+build workflow file is staged but no-op until Phase 2

### Refactor PR sequencing

- **D-14:** Phase 1 ships as **3 grouped PRs**, in order:
  - **PR-1 — Refactor & extract** (pure structural change, no body logic edits):
    - `git mv` every `lib/features/<x>/<x>_screen.dart` to `lib/presentation/screens/<x>/<x>_screen.dart`
    - `git mv` every `lib/features/<x>/<x>_viewmodel.dart` to `lib/application/viewmodels/<x>/<x>_viewmodel.dart`
    - Extract inline models from each viewmodel into `lib/data/models/<entity>.dart` (this WILL touch viewmodel bodies — confined to deleting the inline class and adding an `import`, nothing else)
    - Update import paths only — no logic changes
    - Preserves `git log --follow` for every renamed file
  - **PR-2 — Repository layer + lint + package cleanup**:
    - Add `lib/data/services/{firestore,firebase_auth,firebase_storage}_providers.dart`
    - Add `lib/data/repositories/{users,sessions,materials,notifications,rewards,subscriptions}_repository.dart` + their Riverpod providers
    - Replace `FirebaseFirestore.instance` / `FirebaseAuth.instance` / `FirebaseStorage.instance` direct calls in every viewmodel with `ref.read(repoProvider)`
    - Delete `riverpod_annotation`, `riverpod_generator`, `injectable`, `injectable_generator`, `get_it`, `build_runner` from `pubspec.yaml`
    - Add `flutter_riverpod` to `dependencies`
    - Add `custom_lint` + `riverpod_lint` to `dev_dependencies`
    - Add the project-local custom_lint rule + wire it in `analysis_options.yaml`
  - **PR-3 — CI + tests + iOS identity**:
    - `.github/workflows/ci.yml` (`flutter analyze --fatal-warnings`, `flutter test --coverage`, `dart run custom_lint`, conditional functions build)
    - Add 6 test deps to `dev_dependencies`
    - Configure emulators in `firebase.json` (Auth + Firestore + Storage)
    - Write the 5 anchor tests
    - **iOS identity changes go LAST in this PR** behind a manual Firebase Console checklist in `BACKEND_SETUP.md`:
      1. Register a new Firebase iOS app with bundle id `com.mentorminds.mentorMinds`
      2. Download the new `GoogleService-Info.plist` (now populated with `CLIENT_ID` + `REVERSED_CLIENT_ID`)
      3. Re-issue the APNs auth key (`.p8`) and re-associate with the new app
      4. Update Xcode signing identity to the new bundle id
    - Code changes that follow the checklist: Xcode project `PRODUCT_BUNDLE_IDENTIFIER`, `Info.plist.CFBundleURLTypes` URL scheme entry for Google Sign-In (the reversed client id), `ios/Runner/Runner.entitlements` `AppIdentifierPrefix` update, `ios/Podfile` `platform :ios, '14.2'`, `IPHONEOS_DEPLOYMENT_TARGET = 14.2` across `Runner.xcodeproj` build configurations + Pods `post_install` hook, swap `GoogleService-Info.plist`, run `flutter clean && flutterfire configure` to regenerate `lib/firebase_options.dart` for the new app
    - Avatar path fix (ARCH-06): `ProfileViewModel.updateProfile` writes to `uploads/{uid}/{ts}_avatar.jpg` (already-allowed path), not `avatars/{uid}.jpg`. Old `/users/{uid}.avatarUrl` references get backfilled to the new path lazily on the next profile save — no migration script
- **D-15:** **iOS toolchain:** build against **iOS 26 SDK** (Xcode 26.x). **Minimum deployment target: iOS 14.2** (one notch above the originally planned 14.0). 14.2 captures App Attest stability fixes; verifies all current pods (Firebase suite, `google_sign_in`, `connectivity_plus`, `image_picker`, `flutter_local_notifications`) support 14.2 — if any pod requires bumping, do it inside PR-3.
- **D-16:** **Avatar fix lives in PR-3.** Reuses the already-permitted `uploads/{uid}/{ts}.jpg` Storage path. No `storage.rules` change required. Backfill is lazy on next save.

### Claude's Discretion

- Internal naming for project-local lint rule (file name, rule id) — pick something obvious like `tool/lints/mentormind_layer_rules.dart` with rule id `layered_imports`.
- Test factory naming (`buildDashboardUser()`, `buildMaterialItem()` etc.) — standard factory pattern in `test/_support/factories/`.
- Branch + PR title style — solo dev, no external review process required.
- Whether to keep the legacy `lib/features/` directory empty after `git mv` (no — delete it).
- Exact `analysis_options.yaml` `analyzer.plugins` wiring for `custom_lint` — standard `custom_lint` install steps.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner) MUST read these before planning or implementing.**

### Phase scope + traceability
- `.planning/ROADMAP.md` §"Phase 1: Foundation" — phase goal, success criteria, non-negotiables, rationale (especially the PR-1 "pure git mv" rule, PITFALLS #5)
- `.planning/REQUIREMENTS.md` §Architecture & Foundation (ARCH-01..07), §Continuous Integration & Testing (CI-01..07), §Code Quality (QUAL-04, QUAL-06) — and the QUAL-03 row in Traceability (pulled forward into Phase 1 per D-07)
- `.planning/PROJECT.md` §Constraints + §Key Decisions — Riverpod-locked, iOS-only, Firebase-locked, brand-locked

### Codebase intelligence
- `.planning/codebase/STRUCTURE.md` — current `lib/features/` tree and stray `ios/android/` directory (delete)
- `.planning/codebase/ARCHITECTURE.md` — current MVVM pattern, layer dependencies, anti-patterns (especially Anti-pattern #1 "Inline data models" + Anti-pattern #3 "Direct Firebase singleton access" + Anti-pattern #4 "Provider declared but file ignores it")
- `.planning/codebase/CONVENTIONS.md` — file naming, class naming, provider-naming table, the `withOpacity` migration note, state pattern with `copyWith(clear*: true)` flags, no-barrel rule, `mounted` / `unawaited()` idioms
- `.planning/codebase/TESTING.md` — current zero-test surface, recommended deps + roles, fixture/factory location, Riverpod override pattern (use as the testing recipe for the 5 anchor tests)
- `.planning/codebase/CONCERNS.md` §3 (lint debt breakdown) and §6 (refactor scope) and §11 (bundle ID drift) — direct evidence backing each Phase 1 task
- `.planning/codebase/INTEGRATIONS.md` — Google Sign-In iOS native-config gap, Firebase config, `mentor_minds/native_config` method channel
- `.planning/codebase/STACK.md` — pinned package versions; the deletion list in D-06 must match what's actually in `pubspec.yaml`

### Source files touched by Phase 1
- `pubspec.yaml` — add `flutter_riverpod`, `custom_lint`, `riverpod_lint`; remove `riverpod_annotation`, `riverpod_generator`, `injectable`, `injectable_generator`, `get_it`, `build_runner`; add 6 test deps under `dev_dependencies`
- `analysis_options.yaml` — wire `custom_lint` plugin + reference project-local rule package
- `firebase.json` — emulators block for Auth + Firestore + Storage
- `lib/main.dart` — no changes in Phase 1 (App Check wiring is Phase 2)
- `lib/firebase_options.dart` — regenerate via `flutterfire configure` after bundle id flip
- `lib/features/**/*.dart` (every file) — `git mv` to the new tree in PR-1
- `lib/features/**/<feature>_viewmodel.dart` — inline model classes get removed in PR-1 (extraction); SDK calls get replaced with repo providers in PR-2
- `ios/Podfile` — `platform :ios, '14.2'`; `post_install` hook bumps any pod < 14.2
- `ios/Runner.xcodeproj/project.pbxproj` — `PRODUCT_BUNDLE_IDENTIFIER` + `IPHONEOS_DEPLOYMENT_TARGET`
- `ios/Runner/Info.plist` — `CFBundleURLTypes` for Google Sign-In
- `ios/Runner/GoogleService-Info.plist` — replaced with new-bundle-id download
- `ios/Runner/Runner.entitlements` — `keychain-access-groups` updated if bundle id prefix changes
- `BACKEND_SETUP.md` — manual checklist for Firebase Console + APNs steps (added in PR-3, FIRST in the PR)
- `tool/seed/seed.js` — no change unless the seed's `--project=<id>` target moves (it doesn't)
- `tool/lints/` (new) — project-local custom_lint rule package

### Existing rules / configs that constrain decisions
- `firestore.rules` — current rules permit `uploads/{uid}/{path=**}` writes for owner-only; the avatar fix in D-16 piggybacks on this
- `storage.rules` — same; no change required for ARCH-06
- `firestore.indexes.json` — no change in Phase 1

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets
- **`AppColors`, `AppTextStyles`, `AppTheme.light`, `AppRoutes`, `Validators`** (`lib/core/`) — all stay where they are (in `lib/core/`, not moved). They are cross-feature foundation; the refactor only moves `lib/features/` → `lib/presentation/screens/` + `lib/application/viewmodels/`. `lib/core/` is untouched.
- **`GeminiService`** (`lib/core/services/gemini_service.dart`) — survives Phase 1 unchanged. Phase 3 deletes it when the Cloud Function proxy lands.
- **`ChatViewModel`'s constructor injection of `GeminiService`** (`chat_viewmodel.dart:189-194`) is the only existing example of a testable seam. PR-2 extends this pattern to every viewmodel via repo providers.
- **`factory X.fromDoc(...)` constructors** on `DashboardUser`, `ProfileUser`, `ChatMessage`, `AppNotification`, `SessionItem`, `MaterialItem`, `BadgeItem` — survive the extraction. They move from inside viewmodel files to `lib/data/models/<entity>.dart` verbatim.
- **`abstract final class` namespaces** (`AppColors`, `AppRoutes`, etc.) — convention is established; the layer enforcement custom_lint rule should NOT lint these.
- **GoRouter route table** (`lib/core/routes/app_router.dart`) — survives but every screen import path inside it changes from `package:mentor_minds/features/.../X_screen.dart` to `package:mentor_minds/presentation/screens/.../X_screen.dart`. This is mechanical.

### Established patterns
- **`StateNotifier<TState>` + immutable state class + `copyWith(clear*: true)` flags** — keep verbatim. D-05 locks vanilla.
- **`StreamSubscription` cancelled in `dispose()`** — every viewmodel that opens Firestore streams already does this (`dashboard_viewmodel.dart:656`, `notifications_viewmodel.dart:308`). The refactor MUST preserve these.
- **`if (!mounted) return;` after `await`** — every viewmodel guards post-await state writes. Repos in PR-2 don't change this — they return Streams/Futures, the viewmodel still handles state.
- **`unawaited(...)`** intentional fire-and-forget — preserve (`chat_viewmodel.dart`, `dashboard_viewmodel.dart`).
- **`mentor_minds/native_config` MethodChannel** in `ios/Runner/AppDelegate.swift` exposing `googleSignInStatus` — the `AuthViewModel` calls it before showing the Google sign-in button. Keep the channel name stable through the bundle-id flip (channel names are app-scoped, not bundle-scoped).
- **Provider exception list (NOT autoDispose):** `splashViewModelProvider`, `profileViewModelProvider`, `rewardsViewModelProvider`, `gamificationViewModelProvider`, `notificationsViewModelProvider` — each has a comment explaining why disposal would race a pending await. **Preserve these comments and the autoDispose status verbatim.**

### Integration points
- **`appRouterProvider`** is read by `MaterialApp.router` in `MentorMindsApp`. After refactor, this provider doesn't move — but every screen widget it builds now lives under `lib/presentation/screens/`. Single line in `MentorMindsApp` doesn't change; the route table inside `app_router.dart` changes its imports.
- **`ProviderScope` wraps `MentorMindsApp`** in `main.dart`. Tests use a fresh `ProviderScope` per test with `overrides:` per the recipe in `TESTING.md` §Riverpod override pattern.
- **Method channel surface** for Google Sign-In status check is preserved; the Swift side gets a bundle-id update but the channel API is unchanged.

### Notes on what does NOT move in Phase 1
- `lib/core/` — stays put. It's the foundation; presentation/application/data all import from it.
- `lib/shared/widgets/` — currently empty. Cross-feature shared widgets (`PremiumUpgradeModal`, `BadgeCelebrationOverlay`, `OfflineBanner`) land in Phase 7 (SHRD-01/02/03) and live under `lib/presentation/widgets/` or `lib/presentation/shared/` — naming locked at the start of P7.
- `lib/firebase_options.dart` — auto-generated, untouched until the bundle-id flip in PR-3 when `flutterfire configure` regenerates it.

</code_context>

<specifics>
## Specific Ideas

- **iOS 26 SDK + iOS 14.2 minimum deployment target.** User-specified. Confirms the App Attest path for Phase 2 and avoids 14.0 → 14.1 known App Attest issues. Verify pod compatibility in PR-3; if Firebase pods or `google_sign_in` need a higher floor, document and bump together.
- **Solo-dev workflow.** No external code review process. PR titles and branches follow `conventional commits` (the repo already uses `docs:` / `chore:` prefixes per git log). The 3-PR sequence is for diff hygiene + rollback boundary, not review process.
- **`git log --follow` preservation is sacred.** PR-1 must be pure `git mv` plus the inline-model extraction (deleting class definitions, adding imports — body methods of viewmodels are untouched). Any temptation to "fix that one thing while I'm here" in PR-1 is rejected and held for Phase 7.
- **Avatar fix is opportunistic.** Already known broken; lives in PR-3 alongside iOS identity changes since both are user-visible and want a single QA sweep on a real device.

</specifics>

<deferred>
## Deferred Ideas

- **Riverpod 2 → 3 upgrade + `@riverpod` codegen migration** — bundled into a v1.1 milestone. The two are tied because Riverpod 3 deprecates `StateNotifier` in favour of `Notifier`/`AsyncNotifier`, and codegen is the idiomatic way to write them.
- **`freezed` / `json_serializable` for `lib/data/models/`** — not used in Phase 1. Hand-rolled `fromMap`/`toMap` are kept verbatim from the inline classes. Revisit if the model count grows or if Firestore converter types become a maintenance burden.
- **Full smoke widget tests for all 12 screens + happy/error per viewmodel (CI-04, CI-05 full coverage)** — deferred to Phase 7's polish work. Phase 1 ships only the 5 anchor tests; CI-04 and CI-05 are partially satisfied in P1 and fully satisfied in P7.
- **Golden tests** — installed (CI-07) but unused in Phase 1. Written in Phase 7 against the polished UI.
- **Functions emulator + `functions/` Node toolchain** — Phase 2's job.
- **Coverage thresholds** — none in P1. If desired, revisit at end of Phase 7 when the test surface is real.
- **Sentry / Datadog / other crash-reporting beyond Crashlytics** — out of scope per `REQUIREMENTS.md` §Out of Scope.

</deferred>

---

*Phase: 1-Foundation — Refactor, CI, Test Harness, iOS Identity*
*Context gathered: 2026-05-17*
