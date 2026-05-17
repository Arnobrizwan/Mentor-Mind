# Phase 1: Foundation — Refactor, CI, Test Harness, iOS Identity - Research

**Researched:** 2026-05-17
**Domain:** Flutter structural refactor, GitHub Actions CI, Firebase Emulator Suite, iOS bundle identity, custom_lint, Riverpod testing
**Confidence:** HIGH (most findings verified against pub.dev, live CLI, and official sources)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** Repositories are per-collection. Six repos: `UsersRepository`, `SessionsRepository`, `MaterialsRepository`, `NotificationsRepository`, `RewardsRepository`, `SubscriptionsRepository`.

**D-02:** Repositories return decoded domain models, never raw `QuerySnapshot`/`DocumentSnapshot`. Repos own all `fromDoc`/`toMap` mapping. Viewmodels never import `cloud_firestore`.

**D-03:** Extracted inline models live flat under `lib/data/models/`, one file per entity. No barrel files.

**D-04:** Repositories wired into viewmodels via Riverpod providers. SDK singletons exposed as providers (`firestoreProvider`, `firebaseAuthProvider`, `firebaseStorageProvider`) for `ProviderScope.overrides` in tests. No `get_it`, no `injectable`.

**D-05:** Viewmodels stay on vanilla `StateNotifier` + `StateNotifierProvider` in Phase 1. No `@riverpod` codegen migration.

**D-06:** Delete from `pubspec.yaml`: `riverpod_annotation` (dep), `riverpod_generator` (dev_dep), `injectable` (dep), `injectable_generator` (dev_dep), `get_it` (dep), `build_runner` (dev_dep).

**D-07:** Add `flutter_riverpod: ^2.6.1` to `dependencies` (QUAL-03 pulled forward from Phase 7).

**D-08:** Layer enforcement: `custom_lint` + `riverpod_lint` + a project-local custom_lint rule in `tool/lints/`. Rule bans Firebase SDK imports from `lib/presentation/**`. Rule also bans `lib/data/**` from importing `lib/presentation/**`. `dart run custom_lint` runs as a CI gate.

**D-09:** Harness + anchor tests strategy. Five anchor tests installed. Full smoke coverage deferred to Phase 7.

**D-10:** Firebase Local Emulator Suite: Auth + Firestore + Storage only. Functions emulator in Phase 2.

**D-11:** Test directory mirrors `lib/` structure: `test/presentation/screens/`, `test/application/viewmodels/`, `test/data/repositories/`, `test/data/models/`, `test/core/utils/`, `test/_support/`, `test/_helpers/`, `integration_test/`.

**D-12:** Goldens deferred to Phase 7. Install `golden_toolkit` now but write zero goldens.

**D-13:** CI gates: `flutter analyze --fatal-warnings`, `flutter test --coverage` (coverage artifact, no threshold), `dart run custom_lint`, conditional functions build (no-op stub until Phase 2).

**D-14:** Phase 1 ships as 3 grouped PRs (PR-1 refactor+extract, PR-2 repos+lint+cleanup, PR-3 CI+tests+iOS identity).

**D-15:** iOS toolchain: build against iOS 26 SDK (Xcode 26.x — confirmed Xcode 26.5 installed). Minimum deployment target: **iOS 14.2**.

**D-16:** Avatar fix in PR-3. Writes to `uploads/{uid}/{ts}_avatar.jpg`. No `storage.rules` change required.

### Claude's Discretion

- Internal naming for project-local lint rule (file name, rule id) — suggested `tool/lints/mentormind_layer_rules.dart` with rule id `layered_imports`.
- Test factory naming (`buildDashboardUser()`, etc.) under `test/_support/factories/`.
- Branch + PR title style — conventional commits per existing git log.
- Whether to delete the legacy `lib/features/` directory after `git mv` (yes — delete it).
- Exact `analysis_options.yaml` `analyzer.plugins` wiring.

### Deferred Ideas (OUT OF SCOPE)

- Riverpod 2 → 3 upgrade + `@riverpod` codegen migration (v1.1 milestone).
- `freezed` / `json_serializable` for `lib/data/models/`.
- Full smoke widget tests for all 12 screens + happy/error per viewmodel (Phase 7).
- Golden tests (Phase 7).
- Functions emulator + `functions/` Node toolchain (Phase 2).
- Coverage thresholds (Phase 7).
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ARCH-01 | Codebase restructured into `lib/presentation/screens/`, `lib/application/viewmodels/`, `lib/data/{repositories,services,models}/` with `custom_lint` enforcing one-way import rule | Structural mapping complete; 22 files to move; tool/lints/ custom rule pattern documented |
| ARCH-02 | Inline data models extracted from viewmodels into `lib/data/models/` | 12+ model classes identified across 7 viewmodel files; extraction mapping documented |
| ARCH-03 | Direct Firebase SDK calls removed from viewmodels in favor of repository providers | 6 repository pattern documented; `firestoreProvider` seam pattern defined |
| ARCH-04 | Bundle ID aligned to `com.mentorminds.mentorMinds` across Xcode + Firebase iOS app + APNs + `BACKEND_SETUP.md` | Full checklist documented; current state confirmed: `com.arnobrizwan.mentorminds` in 3 xcodeproj build configs |
| ARCH-05 | iOS deployment target bumped to 14.0+ (unlocks App Attest) | Confirmed 14.2 target; Podfile post_install hook pattern documented; Xcode 26.5 confirmed |
| ARCH-06 | Avatar upload path mismatch fixed | Root cause confirmed: `profile_viewmodel.dart:232` writes to `avatars/${uid}.jpg` but `storage.rules` only permits `uploads/{uid}/...`; one-line fix documented |
| ARCH-07 | iOS Google Sign-In native config populated | Gap confirmed: no `CLIENT_ID`/`REVERSED_CLIENT_ID` in current plist; full setup checklist documented |
| CI-01 | GitHub Actions workflow runs `flutter analyze` on every PR | `subosito/flutter-action@v2` workflow pattern documented; Flutter 3.41.x pinning strategy documented |
| CI-02 | GitHub Actions workflow runs `flutter test` with coverage upload | `--coverage` flag + artifact upload pattern documented |
| CI-03 | GitHub Actions workflow lints + builds Cloud Functions on `functions/**` changes | Conditional path-filter pattern documented; no-op stub until Phase 2 |
| CI-04 | Smoke widget test for each of the 12 screens | 5 anchor tests planned for Phase 1; full 12-screen coverage deferred to Phase 7 |
| CI-05 | Unit test for each viewmodel | Anchor test for `AuthViewModel` and `OnboardingViewModel` in Phase 1; full coverage Phase 7 |
| CI-06 | Firebase Local Emulator Suite scaffolded | `firebase.json` emulators block pattern; emulator hook pattern for `flutter test integration_test/` documented |
| CI-07 | dev_dependencies includes the v1.0 test harness | Compatible version pins verified against our Firebase SDK versions |
| QUAL-04 | `custom_lint` + `riverpod_lint` added to dev_dependencies and pass on CI | Version pair `custom_lint 0.7.7` + `riverpod_lint 2.6.5` confirmed compatible with Dart 3.11 and `riverpod 2.6.1` |
| QUAL-06 | Unused codegen packages removed; or `@riverpod` codegen wired | Decision confirmed: vanilla; all 6 packages deleted (D-06) |
</phase_requirements>

---

## Summary

Phase 1 is a **structural + plumbing** phase with zero behavioral changes. It has four independent work streams that land sequentially in three PRs:

**PR-1** is a pure `git mv` of 22 Dart files from `lib/features/` into `lib/presentation/screens/<feature>/` and `lib/application/viewmodels/<feature>/`, plus extraction of 12+ inline model classes into `lib/data/models/`. The only file body edits are the minimum needed to delete inline class definitions and add import statements — no logic changes.

**PR-2** builds the repository layer (6 repo classes + SDK provider seams), replaces direct Firebase singleton calls in all viewmodels, strips 6 unused packages from `pubspec.yaml`, adds `flutter_riverpod` to `dependencies`, and wires `custom_lint 0.7.7` + `riverpod_lint 2.6.5` + the project-local layer-enforcement rule.

**PR-3** lands the GitHub Actions CI workflow, 6 test dev-dependencies (with version-pinned compatibility for our Firebase ^5.x SDK stack), 5 anchor tests, Firebase Emulator Suite config, and the iOS identity changes: bundle ID to `com.mentorminds.mentorMinds`, deployment target to iOS 14.2, fresh `GoogleService-Info.plist` with `CLIENT_ID`/`REVERSED_CLIENT_ID`, `Info.plist` URL scheme entry, `Runner.entitlements` keychain update, and the one-line avatar path fix.

**Primary recommendation:** Execute strictly in PR-1 → PR-2 → PR-3 order. Each PR is independently rollbackable. Mixing refactor body edits with lint fixes or iOS changes destroys `git log --follow` and bisect utility.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| File rename / `git mv` | Developer workstation (git) | — | Pure VCS operation; no runtime tier involved |
| Repository abstraction | `lib/data/repositories/` | `lib/data/services/` (SDK providers) | Repos own Firestore queries; SDK provider seams enable test overrides |
| Model extraction | `lib/data/models/` | — | Domain entities belong in the data layer; viewmodels consume them |
| Layer enforcement rule | CI (`dart run custom_lint`) | `analysis_options.yaml` plugin registration | Enforced at analysis time; IDE surfaces violations in real time |
| GitHub Actions CI | CI runner (Ubuntu) | — | Headless; no native iOS simulator needed for analyze + test + custom_lint |
| Firebase Emulator Suite | Developer workstation / CI | — | Java-based local emulator; Auth + Firestore + Storage only |
| Integration test | iOS device / simulator | Firebase Emulator | `flutter test integration_test/` drives the emulator |
| iOS bundle ID / signing | Xcode project (native) | Firebase Console (backend) | Xcode owns the binary identity; Firebase Console registers the iOS app |
| iOS deployment target | Xcode project + Podfile | CocoaPods pod build configs | Both must agree; Podfile `post_install` hook updates pod targets |
| Avatar upload fix | `lib/application/viewmodels/profile/profile_viewmodel.dart` | `storage.rules` (no change needed) | One-line path change in viewmodel; rules already permit `uploads/{uid}/...` |
| Google Sign-In wiring | `ios/Runner/GoogleService-Info.plist` + `ios/Runner/Info.plist` | `lib/application/viewmodels/auth/auth_viewmodel.dart` | Native iOS config drives the native OAuth flow |

---

## Standard Stack

### Core (already in pubspec, locked)

| Library | Resolved Version | Purpose | Status |
|---------|-----------------|---------|--------|
| `flutter_riverpod` | 2.6.1 (transitive) → add as direct dep | State management foundation | Add to `dependencies` (D-07) |
| `hooks_riverpod` | 2.6.1 | Screen-layer Riverpod import | Keep; screens import this |
| `cloud_firestore` | 5.6.12 | Firestore SDK | Keep; latest in ^5.x series |
| `firebase_auth` | 5.7.0 | Auth SDK | Keep; latest in ^5.x series |
| `firebase_storage` | 12.4.10 | Storage SDK | Keep |
| `go_router` | 14.8.1 | Navigation | Keep |

### To Remove (D-06) [VERIFIED: pub.dev — confirmed unused by grep in lib/]

| Package | Currently | Remove From | Reason |
|---------|-----------|-------------|--------|
| `riverpod_annotation` | dep `^2.3.5` | `dependencies` | Zero `@riverpod` annotations in lib/ |
| `riverpod_generator` | dev_dep `^2.4.3` | `dev_dependencies` | Zero `.g.dart` files; build_runner not running |
| `injectable` | dep `^2.4.4` | `dependencies` | Zero `@injectable` annotations in lib/ |
| `injectable_generator` | dev_dep `^2.6.2` | `dev_dependencies` | No DI code-gen |
| `get_it` | dep `^7.7.0` | `dependencies` | DI via Riverpod only |
| `build_runner` | dev_dep `^2.4.12` | `dev_dependencies` | No codegen consumers after above removals |

### To Add

| Library | Version to Pin | Purpose | Why |
|---------|---------------|---------|-----|
| `flutter_riverpod` | `^2.6.1` | Direct dep (QUAL-03) | Clears 12 `depend_on_referenced_packages` warnings; removes latent v3 break |

### Dev Dependencies to Add (Test Harness — CI-07)

| Library | Version to Pin | Purpose | Compatibility Note |
|---------|---------------|---------|-------------------|
| `mocktail` | `^1.0.5` | Mock objects without codegen | No Firebase deps; works with any version [VERIFIED: pub.dev] |
| `fake_cloud_firestore` | `^3.1.0` | In-memory Firestore | Requires `cloud_firestore ^5.0.0` — compatible with our 5.6.12 [VERIFIED: pub.dev] |
| `firebase_auth_mocks` | `^0.14.2` | MockFirebaseAuth | Requires `firebase_auth ^5.0.0`, `firebase_core ^3.0.0` — compatible [VERIFIED: pub.dev] |
| `golden_toolkit` | `^0.15.0` | Golden image testing (installed, no goldens written in P1) | Flutter SDK dep; no Firebase deps [VERIFIED: pub.dev] |
| `network_image_mock` | `^2.1.1` | Prevents `Image.network` real HTTP in widget tests | No Firebase deps [VERIFIED: pub.dev] |
| `integration_test` | SDK | Flutter integration test harness | Part of Flutter SDK; add as `integration_test: { sdk: flutter }` |

### Lint Dev Dependencies to Add (QUAL-04, D-08)

| Library | Version to Pin | Compatibility |
|---------|---------------|--------------|
| `custom_lint` | `^0.7.7` | Dart SDK `>=3.0.0 <4.0.0` — compatible with Dart 3.11 [VERIFIED: pub.dev] |
| `riverpod_lint` | `^2.6.5` | Requires `riverpod 2.6.1`, `custom_lint_builder ^0.7.0` — matches our stack [VERIFIED: pub.dev] |

**CRITICAL VERSION COMPATIBILITY NOTE:**
- `fake_cloud_firestore 4.x` requires `cloud_firestore ^6.x` — NOT compatible with our `^5.x`. Pin to `^3.1.0`.
- `firebase_auth_mocks 0.15.x` requires `firebase_auth ^6.x` — NOT compatible with our `^5.x`. Pin to `^0.14.2`.
- `riverpod_lint 3.x` requires `riverpod 3.x` — NOT compatible with our locked `2.6.1`. Pin to `^2.6.5`.
- `custom_lint 0.8.x` is technically compatible with Dart 3.11, but `riverpod_lint 2.6.5` requires `custom_lint_builder ^0.7.0` which pins to `custom_lint 0.7.x`. Use `^0.7.7`.

**Version verification commands (run before plan execution):**
```bash
# Verify versions are still correct
flutter pub outdated  # confirm cloud_firestore, firebase_auth are still ^5.x
# After pubspec.yaml edits:
flutter pub get  # confirm all deps resolve without conflicts
```

---

## Package Legitimacy Audit

> slopcheck was invoked but flagged all packages as [SLOP] because it checked **PyPI** (Python) instead of **pub.dev** (Dart). This is a cross-ecosystem false positive — slopcheck does not support Dart/pub packages. All packages were verified manually against pub.dev and their official GitHub repositories.

| Package | Registry | Pub.dev Page | Source Repo | Pub.dev [VERIFIED] | Disposition |
|---------|----------|-------------|-------------|-------------------|-------------|
| `mocktail` | pub.dev | pub.dev/packages/mocktail | github.com/felangel/mocktail | v1.0.5, stable author | Approved |
| `fake_cloud_firestore` | pub.dev | pub.dev/packages/fake_cloud_firestore | github.com/atn832/fake_cloud_firestore | v3.1.0 for firebase 5.x | Approved (pin to ^3.1.0) |
| `firebase_auth_mocks` | pub.dev | pub.dev/packages/firebase_auth_mocks | github.com/atn832/firebase_auth_mocks | v0.14.2 for firebase_auth 5.x | Approved (pin to ^0.14.2) |
| `golden_toolkit` | pub.dev | pub.dev/packages/golden_toolkit | github.com/eBay/flutter_glove_box | v0.15.0 | Approved |
| `network_image_mock` | pub.dev | pub.dev/packages/network_image_mock | github.com/stelynx/network_image_mock | v2.1.1 | Approved |
| `custom_lint` | pub.dev | pub.dev/packages/custom_lint | github.com/invertase/dart_custom_lint | v0.7.7 (use 0.7.x for riverpod_lint 2.x) | Approved |
| `riverpod_lint` | pub.dev | pub.dev/packages/riverpod_lint | github.com/rrousselGit/river_pod | v2.6.5 (use 2.x for riverpod 2.x) | Approved |
| `flutter_riverpod` | pub.dev | pub.dev/packages/flutter_riverpod | github.com/rrousselGit/river_pod | v2.6.1 (already resolved) | Approved |
| `integration_test` | Flutter SDK | — | flutter/flutter | SDK package | Approved |

**Packages removed due to slopcheck [SLOP] verdict:** none (false ecosystem positive — all packages verified on pub.dev)
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture After Refactor

```
Flutter App (iOS only, v1.0)
│
├── lib/
│   ├── main.dart                          Entry: Firebase init + ProviderScope
│   ├── firebase_options.dart              FlutterFire CLI generated (regenerate after bundle ID flip)
│   │
│   ├── core/                              UNCHANGED — cross-feature foundation
│   │   ├── constants/ → app_colors.dart, app_text_styles.dart
│   │   ├── routes/   → app_router.dart (import paths updated)
│   │   ├── services/ → gemini_service.dart (survives until Phase 3)
│   │   ├── theme/    → app_theme.dart
│   │   └── utils/    → validators.dart
│   │
│   ├── presentation/                      NEW — all screen widgets
│   │   └── screens/
│   │       ├── auth/   → login_screen.dart, register_screen.dart
│   │       ├── dashboard/ → dashboard_screen.dart
│   │       ├── materials/ → materials_screen.dart
│   │       ├── notifications/ → notifications_screen.dart
│   │       ├── onboarding/  → onboarding_screen.dart
│   │       ├── profile/     → profile_screen.dart
│   │       ├── rewards/     → rewards_screen.dart
│   │       ├── search/      → search_screen.dart
│   │       ├── splash/      → splash_screen.dart
│   │       └── tutor/       → tutor_screen.dart
│   │
│   ├── application/                       NEW — all viewmodels
│   │   └── viewmodels/
│   │       ├── auth/          → auth_viewmodel.dart
│   │       ├── dashboard/     → dashboard_viewmodel.dart
│   │       ├── materials/     → materials_viewmodel.dart
│   │       ├── notifications/ → notifications_viewmodel.dart
│   │       ├── onboarding/    → onboarding_viewmodel.dart
│   │       ├── profile/       → profile_viewmodel.dart
│   │       ├── rewards/       → rewards_viewmodel.dart, gamification_viewmodel.dart
│   │       ├── search/        → search_viewmodel.dart
│   │       ├── splash/        → splash_viewmodel.dart
│   │       └── tutor/         → chat_viewmodel.dart
│   │
│   └── data/                              NEW — repositories, SDK providers, models
│       ├── models/                        Extracted from viewmodels (see model list)
│       │   ├── dashboard_user.dart        ← from dashboard_viewmodel.dart
│       │   ├── rewards_snapshot.dart      ← from dashboard_viewmodel.dart
│       │   ├── subject_progress.dart      ← from dashboard_viewmodel.dart
│       │   ├── session_item.dart          ← from dashboard_viewmodel.dart
│       │   ├── material_item.dart         ← from dashboard_viewmodel.dart + materials_viewmodel.dart
│       │   ├── badge_item.dart            ← from dashboard_viewmodel.dart
│       │   ├── chat_message.dart          ← from tutor/chat_viewmodel.dart
│       │   ├── app_notification.dart      ← from notifications_viewmodel.dart
│       │   ├── profile_user.dart          ← from profile_viewmodel.dart
│       │   ├── profile_stats.dart         ← from profile_viewmodel.dart
│       │   ├── badge_info.dart            ← merged from gamification+rewards viewmodels
│       │   └── leaderboard_entry.dart     ← from rewards_viewmodel.dart
│       ├── services/                      SDK providers (Riverpod seams)
│       │   ├── firebase_providers.dart    → firestoreProvider, firebaseAuthProvider, firebaseStorageProvider
│       │   └── (future: functions_service.dart in Phase 2)
│       └── repositories/                 Thin Firestore abstraction
│           ├── users_repository.dart
│           ├── sessions_repository.dart
│           ├── materials_repository.dart
│           ├── notifications_repository.dart
│           ├── rewards_repository.dart
│           └── subscriptions_repository.dart   (stub methods only)
│
└── test/                                  New mirror structure
    ├── core/utils/validators_test.dart    Anchor test 1
    ├── application/viewmodels/
    │   ├── onboarding_viewmodel_test.dart  Anchor test 2
    │   └── auth_viewmodel_test.dart        Anchor test 3
    ├── presentation/screens/
    │   └── dashboard_screen_test.dart      Anchor test 4
    ├── _support/factories/                 Test data builders
    ├── _helpers/                           ProviderScope helpers
    └── integration_test/                  (at repo root)
        └── login_smoke_test.dart           Anchor test 5
```

### Pattern 1: git mv Refactor — Preserving History

**What:** Rename files using `git mv` so `git log --follow` tracks history across the rename.

**When to use:** PR-1 only. Every screen and viewmodel file must be moved with this command, not by copy-delete.

**Critical rule:** `git mv` + import path updates MUST be committed together in a single commit per file or per batch. Do NOT put import updates in a second commit after the `git mv` commit — git tracks the rename at commit time and the analyzer will error on the first commit if imports aren't fixed simultaneously.

**Command pattern:**
```bash
# Create target directories first
mkdir -p lib/presentation/screens/{auth,dashboard,materials,notifications,onboarding,profile,rewards,search,splash,tutor}
mkdir -p lib/application/viewmodels/{auth,dashboard,materials,notifications,onboarding,profile,rewards,search,splash,tutor}
mkdir -p lib/data/{models,repositories,services}

# Example: move auth files
git mv lib/features/auth/login_screen.dart lib/presentation/screens/auth/login_screen.dart
git mv lib/features/auth/register_screen.dart lib/presentation/screens/auth/register_screen.dart
git mv lib/features/auth/auth_viewmodel.dart lib/application/viewmodels/auth/auth_viewmodel.dart

# Then immediately update all import paths in the moved files AND in all consumers
# (app_router.dart imports 11 screens and needs every path updated)
# Then git add and commit as one unit
```

**Verification:**
```bash
flutter analyze  # must remain at 0 errors after each batch
git log --follow --oneline -- lib/application/viewmodels/auth/auth_viewmodel.dart
# Should show: the move commit AND the original commit
```

**Gotchas:**
1. `lib/core/routes/app_router.dart` imports ALL 11 screens — its import block changes in its entirety during PR-1. This file is the single biggest import-update job.
2. The `tutor/` feature folder has TWO viewmodel files (`chat_viewmodel.dart`, `tutor_screen.dart`) — both move.
3. The `rewards/` feature has THREE files — `rewards_screen.dart`, `rewards_viewmodel.dart`, `gamification_viewmodel.dart`.
4. Relative import depths change: what was `../../core/constants/app_colors.dart` from `lib/features/auth/` becomes `../../../core/constants/app_colors.dart` from `lib/presentation/screens/auth/`.
5. Do NOT use IDE "Rename/Move" refactor for this — it creates a delete+add rather than a true git rename. Use `git mv` on the command line.
6. After moving, delete the now-empty `lib/features/` directory: `git rm -r lib/features/`.

### Pattern 2: Inline Model Extraction

**What:** Copy class definition from inside a viewmodel file to a new `lib/data/models/<entity>.dart` file, then replace the definition with an import in the viewmodel.

**When to use:** PR-1, as part of the same commit batch as the `git mv`. Extraction touches viewmodel bodies — confined to deleting the class definition and adding one import line.

**Models to extract (complete list):**

| Class | Source File | Target File | Conflict |
|-------|------------|-------------|---------|
| `DashboardUser` | `dashboard_viewmodel.dart:42` | `dashboard_user.dart` | — |
| `RewardsSnapshot` | `dashboard_viewmodel.dart:91` | `rewards_snapshot.dart` | — |
| `SubjectProgress` | `dashboard_viewmodel.dart:97` | `subject_progress.dart` | — |
| `SessionItem` | `dashboard_viewmodel.dart:108` | `session_item.dart` | — |
| `MaterialItem` | `dashboard_viewmodel.dart:143` | `material_item.dart` | Also `LearningMaterial` in `materials_viewmodel.dart:94` — decide canonical name |
| `BadgeItem` | `dashboard_viewmodel.dart:172` | `badge_item.dart` | — |
| `ChatMessage` | `chat_viewmodel.dart:20` | `chat_message.dart` | — |
| `AppNotification` | `notifications_viewmodel.dart:32` | `app_notification.dart` | — |
| `ProfileUser` | `profile_viewmodel.dart:17` | `profile_user.dart` | — |
| `ProfileStats` | `profile_viewmodel.dart:88` | `profile_stats.dart` | — |
| `BadgeInfo` | Both `gamification_viewmodel.dart:31` AND `rewards_viewmodel.dart:14` | `badge_info.dart` | DUPLICATE — merge into one definition; both viewmodels import from models |
| `LeaderboardEntry` | Both `gamification_viewmodel.dart:149` AND `rewards_viewmodel.dart:151` | `leaderboard_entry.dart` | DUPLICATE — same resolution |
| `RewardsDoc` | `gamification_viewmodel.dart:111` | `rewards_doc.dart` | — |
| `PointsHistory` | `gamification_viewmodel.dart:127` | `points_history.dart` | — |
| `Milestone` | `rewards_viewmodel.dart:104` | `milestone.dart` | — |
| `HistoryEntry` | `rewards_viewmodel.dart:126` | `history_entry.dart` | — |
| `EarnedBadge` | `rewards_viewmodel.dart:170` | `earned_badge.dart` | — |
| `MaterialSearchHit` | `search_viewmodel.dart:16` | `material_search_hit.dart` | — |
| `SessionSearchHit` | `search_viewmodel.dart:47` | `session_search_hit.dart` | — |
| `LearningMaterial` | `materials_viewmodel.dart:94` | `material_item.dart` OR `learning_material.dart` | Resolve vs `MaterialItem` above |

**Gotcha:** `BadgeInfo` is defined in BOTH `gamification_viewmodel.dart` and `rewards_viewmodel.dart`. They must be compared field-by-field and merged into a single canonical `lib/data/models/badge_item.dart` (or `badge_info.dart`). Same for `LeaderboardEntry`.

**Verification:**
```bash
flutter analyze  # must be 0 errors after extraction
grep -r "class BadgeInfo\|class LeaderboardEntry" lib/  # should show 0 hits after extraction
grep -r "class BadgeInfo\|class LeaderboardEntry" lib/data/models/  # should show exactly 1 hit each
```

### Pattern 3: Repository Provider Pattern (PR-2)

**What:** Expose Firebase SDK singletons as Riverpod providers so tests can override them. Repositories take these providers as constructor arguments via `ref.read(...)`.

**Canonical pattern for `lib/data/services/firebase_providers.dart`:**
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});
```

**Repository provider pattern:**
```dart
// lib/data/repositories/users_repository.dart
final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(
    firestore: ref.read(firestoreProvider),
    auth: ref.read(firebaseAuthProvider),
  );
});
```

**Test override pattern (from TESTING.md):**
```dart
// Source: lib/features tests — canonical Riverpod override pattern
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
    ],
    child: const MaterialApp(home: DashboardScreen()),
  ),
);
```

**Viewmodel constructor after PR-2:**
```dart
// Viewmodels receive repos via ref, not direct SDK instances
class DashboardViewModel extends StateNotifier<DashboardState> {
  DashboardViewModel(this._usersRepo, this._sessionsRepo, this._materialsRepo)
      : super(const DashboardState()) {
    _init();
  }

  final UsersRepository _usersRepo;
  final SessionsRepository _sessionsRepo;
  final MaterialsRepository _materialsRepo;
  // ... (no more _firestore = FirebaseFirestore.instance)
}

final dashboardViewModelProvider =
    StateNotifierProvider.autoDispose<DashboardViewModel, DashboardState>(
  (ref) => DashboardViewModel(
    ref.read(usersRepositoryProvider),
    ref.read(sessionsRepositoryProvider),
    ref.read(materialsRepositoryProvider),
  ),
);
```

### Pattern 4: custom_lint Layer Enforcement Rule (PR-2, D-08)

**What:** A project-local custom_lint rule that bans Firebase SDK imports from `lib/presentation/**` and bans `lib/data/**` from importing `lib/presentation/**`.

**Package structure for the rule (in `tool/lints/`):**
```
tool/lints/
├── pubspec.yaml         # name: mentormind_lints; depends on: custom_lint_builder: ^0.7.0
├── lib/
│   └── mentormind_lints.dart   # exports the plugin
└── src/
    └── layered_imports.dart    # the lint rule
```

**`tool/lints/pubspec.yaml`:**
```yaml
name: mentormind_lints
version: 0.0.1
publish_to: none

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  custom_lint_builder: ^0.7.0
  analyzer: ^7.0.0
```

**`analysis_options.yaml` wiring:**
```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  plugins:
    - custom_lint

linter:
  rules:
    # existing rules...
```

**`pubspec.yaml` dev_dependencies entry:**
```yaml
dev_dependencies:
  custom_lint: ^0.7.7
  riverpod_lint: ^2.6.5
  mentormind_lints:
    path: tool/lints
```

**Rule logic sketch for `layered_imports.dart`:**
```dart
// Bans firebase SDK imports in lib/presentation/**
// Bans lib/data/** imports from lib/presentation/**
// Rule id: 'layered_imports'
// [ASSUMED] - exact custom_lint_builder API based on training knowledge; 
// verify against https://pub.dev/packages/custom_lint_builder docs
```

**Run lint:**
```bash
dart run custom_lint
```

**Gotcha:** `custom_lint` requires Dart analysis server to be running or `dart run custom_lint` to be invoked separately — it does NOT run as part of `flutter analyze`. The CI workflow needs a separate step.

### Pattern 5: GitHub Actions CI Workflow (PR-3)

**Recommended `.github/workflows/ci.yml`:**
```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  flutter:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: '3.41.3'
          cache: true
      - run: flutter pub get
      - run: flutter analyze --fatal-warnings
      - run: dart run custom_lint
      - run: flutter test --coverage
      - uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage/lcov.info

  functions:
    runs-on: ubuntu-latest
    if: contains(github.event.head_commit.modified, 'functions/')
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: echo "Functions CI stub — no-op until Phase 2"
      # Phase 2 will replace with: npm ci && npm run lint && npm run build
```

**Key version pins:**
- `actions/checkout@v4` [VERIFIED: github.com/actions/checkout]
- `subosito/flutter-action@v2` — latest is v2.23.0 [VERIFIED: github.com/subosito/flutter-action]
- `actions/setup-node@v4` — latest is v6.4.0 but v4 is still current stable [VERIFIED: github.com/actions/setup-node]
- `actions/upload-artifact@v4` [VERIFIED: github.com/actions/upload-artifact]

**Gotcha — `--fatal-infos` vs `--fatal-warnings`:** Current codebase has 104 `withOpacity` info warnings + 42 `prefer_const` infos. Using `--fatal-infos` would fail CI immediately. `--fatal-warnings` only fails on `WARNING` severity and above — info-level warnings still appear but don't fail the build. This matches D-13.

**Gotcha — `dart run custom_lint` is separate from `flutter analyze`:** The CI step for `flutter analyze` and the step for `dart run custom_lint` are distinct commands. Both are needed.

### Pattern 6: Firebase Local Emulator Suite (PR-3)

**`firebase.json` emulators block to add:**
```json
{
  "firestore": { "rules": "firestore.rules", "indexes": "firestore.indexes.json" },
  "storage": { "rules": "storage.rules" },
  "emulators": {
    "auth": { "port": 9099 },
    "firestore": { "port": 8080 },
    "storage": { "port": 9199 },
    "ui": { "enabled": true, "port": 4000 }
  }
}
```

**Dart boot code for integration tests (in `integration_test/` bootstrap or `test/_helpers/emulator_setup.dart`):**
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

const bool _useEmulator =
    String.fromEnvironment('USE_EMULATOR', defaultValue: 'false') == 'true';

Future<void> configureEmulators() async {
  if (_useEmulator) {
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
  }
}
```

**Run integration tests against emulator:**
```bash
# Terminal 1:
firebase emulators:start --only auth,firestore,storage --import=emulator-data --export-on-exit=emulator-data

# Terminal 2:
flutter test integration_test/login_smoke_test.dart \
  --dart-define=USE_EMULATOR=true \
  -d <simulator-id>
```

**Prerequisites confirmed:**
- Firebase CLI 15.2.1 installed [VERIFIED: local `firebase --version`]
- Java OpenJDK 25.0.2 installed (required for emulators) [VERIFIED: local `java -version`]
- `firebase.json` exists at repo root but has no `emulators` block yet [VERIFIED: read firebase.json]

**Gotcha — emulators need Java:** Firebase Local Emulator Suite requires Java. Java is confirmed available (`openjdk 25.0.2`). No action needed.

**Gotcha — emulator data seeding:** For integration tests, the Auth emulator starts empty. The `login_smoke_test.dart` must either create a user programmatically or use `--import` with pre-seeded emulator data. For Phase 1's single smoke test, creating the user programmatically in `setUpAll` is simpler.

### Pattern 7: Anchor Test Examples

**Anchor Test 1 — Pure unit (`test/core/utils/validators_test.dart`):**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mentor_minds/core/utils/validators.dart';

void main() {
  group('Validators', () {
    group('email', () {
      test('returns null for valid email', () {
        expect(Validators.email('test@example.com'), isNull);
      });
      test('returns error for missing @', () {
        expect(Validators.email('notanemail'), isNotNull);
      });
    });
    // ... name, password, loginPassword, confirmPassword, role
  });
}
```

**Anchor Test 2 — ViewModel with SharedPreferences (`test/application/viewmodels/onboarding_viewmodel_test.dart`):**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mentor_minds/application/viewmodels/onboarding/onboarding_viewmodel.dart';

void main() {
  group('OnboardingViewModel', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });
    test('initial state has no level selected', () {
      final vm = OnboardingViewModel();
      expect(vm.state.selectedLevel, isNull);
    });
  });
}
```

**Anchor Test 3 — ViewModel with Firebase mocks (`test/application/viewmodels/auth_viewmodel_test.dart`):**
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mentor_minds/application/viewmodels/auth/auth_viewmodel.dart';
import 'package:mentor_minds/data/services/firebase_providers.dart';

void main() {
  group('AuthViewModel', () {
    test('loginWithEmail with invalid email returns null + sets error', () async {
      final container = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
          firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
        ],
      );
      addTearDown(container.dispose);
      final vm = container.read(authViewModelProvider.notifier);
      final result = await vm.loginWithEmail('not-an-email', 'password');
      expect(result, isNull);
      expect(container.read(authViewModelProvider).error, isNotNull);
    });
  });
}
```

**Anchor Test 4 — Widget test (`test/presentation/screens/dashboard_screen_test.dart`):**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:mentor_minds/application/viewmodels/dashboard/dashboard_viewmodel.dart';
import 'package:mentor_minds/presentation/screens/dashboard/dashboard_screen.dart';

void main() {
  testWidgets('DashboardScreen mounts without error', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardViewModelProvider.overrideWith(
              (ref) => FakeDashboardViewModel(),
            ),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      expect(find.byType(DashboardScreen), findsOneWidget);
    });
  });
}
```

**Anchor Test 5 — Integration test (`integration_test/login_smoke_test.dart`):**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mentor_minds/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('sign-in smoke test — emulator', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    // Creates a test user via emulator API, then verifies sign-in route
    // ...
  });
}
```

### Anti-Patterns to Avoid

- **Mixed commits:** Never put body logic edits and `git mv` in the same commit. Destroys `git log --follow`.
- **`flutter analyze --fatal-infos` in Phase 1 CI:** Would instantly fail on 104 `withOpacity` warnings. Use `--fatal-warnings` (D-13).
- **`fake_cloud_firestore ^4.x` or `firebase_auth_mocks ^0.15.x`:** These require Firebase SDK v6.x. Our codebase is pinned to v5.x. Use `^3.1.0` and `^0.14.2` respectively.
- **`riverpod_lint ^3.x`:** Requires `riverpod 3.x`. Use `^2.6.5`.
- **IDE move refactor:** Creates delete+add, not a rename. Use `git mv` on command line only.
- **Barrel files:** CLAUDE.md convention: no barrel files. No `lib/data/models/models.dart`.
- **`firebase emulators:start` without Java:** Emulators require Java; confirmed available but must be on PATH in CI.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Firebase mocking in unit tests | Custom `FakeFirestore` wrapper | `fake_cloud_firestore ^3.1.0` | Handles `where`/`orderBy`/`whereIn`/`limit` query semantics; battle-tested |
| Auth mocking | Custom `MockAuth` | `firebase_auth_mocks ^0.14.2` | Handles `signIn`/`signOut`/`currentUser`/`authStateChanges` stream |
| Mock objects | `implements FirebaseAuth` by hand | `mocktail ^1.0.5` | Null-safe, no codegen; `when()`/`verify()` API |
| Import dependency linting | `grep` in CI shell script | `custom_lint 0.7.7` + `riverpod_lint 2.6.5` | Analysis-time enforcement; IDE integration; survives refactors |
| Network image in widget tests | `setUp` that stubs `Image.network` | `network_image_mock ^2.1.1` | One-line `mockNetworkImagesFor()` wrapper |
| Git rename tracking | Delete + re-create file | `git mv` | `git log --follow` only works with `git mv` |

**Key insight:** The test dep version constraints are non-obvious — `fake_cloud_firestore 3.x` not `4.x`, `firebase_auth_mocks 0.14.x` not `0.15.x`, `riverpod_lint 2.x` not `3.x`. The wrong versions will fail `flutter pub get` due to incompatible Firebase SDK constraints.

---

## Common Pitfalls

### Pitfall 1: `git mv` + import update as separate commits
**What goes wrong:** First commit does only `git mv` (compile error). Second commit fixes imports. Result: git sees the first commit as a delete, not a rename — `git log --follow` only tracks from the second commit forward.
**Why it happens:** Attempt to keep commits small.
**How to avoid:** Stage both the `git mv` output AND the import-path fixes in a single commit per batch of files. Use `git add -p` to confirm what's staged before committing.
**Warning signs:** `git log --follow -- lib/application/viewmodels/auth/auth_viewmodel.dart` returns only one commit (the move), not the full history back to "Initial commit".

### Pitfall 2: Wrong package versions break `flutter pub get`
**What goes wrong:** `fake_cloud_firestore ^4.x` requires `cloud_firestore ^6.x`; `pub get` fails with version conflict.
**Why it happens:** Training data / pub.dev search suggests "latest" without checking our locked Firebase SDK version.
**How to avoid:** Pin exactly as documented: `fake_cloud_firestore: ^3.1.0`, `firebase_auth_mocks: ^0.14.2`, `riverpod_lint: ^2.6.5`, `custom_lint: ^0.7.7`. Run `flutter pub get` immediately after editing pubspec.yaml.
**Warning signs:** `Because mentor_minds depends on fake_cloud_firestore ^4.0.0 which requires cloud_firestore ^6.0.0, version solving failed.`

### Pitfall 3: `BadgeInfo` / `LeaderboardEntry` defined in two viewmodels
**What goes wrong:** Both `gamification_viewmodel.dart` and `rewards_viewmodel.dart` define `BadgeInfo` and `LeaderboardEntry` with potentially different fields. Extracting naively creates two model files, then import ambiguity.
**Why it happens:** Historical duplication — inline models grew organically.
**How to avoid:** Before extracting, compare the two definitions field-by-field. Merge into a single canonical definition. Import the single definition in both viewmodels. This is the trickiest part of PR-1.
**Warning signs:** `The name 'BadgeInfo' is defined in the libraries 'badge_info.dart' and 'badge_item.dart'`.

### Pitfall 4: `custom_lint` not running in CI because it's not part of `flutter analyze`
**What goes wrong:** `flutter analyze` passes; layer violation slips through because CI didn't run `dart run custom_lint`.
**Why it happens:** Assumption that `flutter analyze` runs all lints including `custom_lint` plugins.
**How to avoid:** Add a separate CI step: `- run: dart run custom_lint`. The plugin is registered in `analysis_options.yaml` for IDE use, but the CI workflow needs the explicit command.
**Warning signs:** CI badge is green but `dart run custom_lint` run locally shows layer violations.

### Pitfall 5: iOS deployment target bumped in Podfile but NOT in `Runner.xcodeproj`
**What goes wrong:** `pod install` succeeds with iOS 14.2 in Podfile, but the app signs with iOS 13.0 deployment target from `project.pbxproj`. Xcode warning: "Minimum deployment target ... is less than the minimum deployment target of the linked framework."
**Why it happens:** Podfile and `project.pbxproj` are edited independently.
**How to avoid:** Update ALL three locations atomically:
  1. `ios/Podfile` line 2: `platform :ios, '14.2'`
  2. `ios/Podfile` post_install hook: bump threshold from `< 13.0` to `< 14.2`
  3. `ios/Runner.xcodeproj/project.pbxproj`: three occurrences of `IPHONEOS_DEPLOYMENT_TARGET = 13.0` → `14.2` (lines 483, 617, 668 confirmed by grep)
Then run `pod install` to recompile pods.
**Warning signs:** `flutter build ios --no-codesign` warns "Minimum deployment target should be >= 14.2".

### Pitfall 6: Bundle ID flip without Firebase Console registration
**What goes wrong:** Code changes bundle ID to `com.mentorminds.mentorMinds` but the Firebase Console still has `com.arnobrizwan.mentorminds`. App launches but Firebase Auth fails silently (wrong bundle ID in `GoogleService-Info.plist`).
**Why it happens:** Code-only PR without the Firebase Console checklist.
**How to avoid:** Complete the BACKEND_SETUP.md manual checklist FIRST, then write the code changes. The checklist must include: (1) register new Firebase iOS app with `com.mentorminds.mentorMinds`, (2) download new `GoogleService-Info.plist`, (3) re-issue APNs `.p8`, (4) update Xcode signing identity.
**Warning signs:** `flutter run` succeeds but Firebase Auth throws `Error 10` or `operation-not-allowed`.

### Pitfall 7: Avatar fix path doesn't match the `storage.rules` allowed pattern
**What goes wrong:** Fix changes `avatars/${uid}.jpg` to `uploads/${uid}_avatar.jpg` (wrong), but `storage.rules` requires `uploads/{uid}/{file}` (uid as a subdirectory segment).
**Why it happens:** Misreading the storage.rules match pattern.
**How to avoid:** `storage.rules` line 11 is `match /uploads/{uid}/{allPaths=**}`. The path must be `uploads/{uid}/{anything}`. Correct fix: `_storage.ref('uploads/${user.uid}/${ts}_avatar.jpg')`. NOT `uploads/${user.uid}_avatar.jpg` (flat path doesn't match the wildcard).
**Warning signs:** Storage `permission-denied` persists after the fix.

### Pitfall 8: `google_sign_in` on iOS requires `REVERSED_CLIENT_ID` in both `GoogleService-Info.plist` AND `Info.plist` URL Types
**What goes wrong:** `REVERSED_CLIENT_ID` added to `GoogleService-Info.plist` but `Info.plist CFBundleURLTypes` not updated. `AppDelegate.swift:googleSignInStatus()` checks BOTH — returns `configured: false`.
**Why it happens:** Partial setup — only one file updated.
**How to avoid:** After downloading new `GoogleService-Info.plist`, copy the `REVERSED_CLIENT_ID` value and add it to `ios/Runner/Info.plist` as a URL scheme entry:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.YOUR_CLIENT_NUMBER</string>
    </array>
  </dict>
</array>
```
**Warning signs:** `googleSignInStatus()` returns `"configured": false, "reason": "Add the REVERSED_CLIENT_ID URL scheme to Info.plist"`.

---

## Code Examples

### Avatar Fix (ARCH-06) — One-liner in `profile_viewmodel.dart`

Current broken code (line 232):
```dart
final ref = _storage.ref('avatars/${user.uid}.jpg');
```

Fixed code:
```dart
final ref = _storage.ref(
  'uploads/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_avatar.jpg',
);
```

Also fix the delete path (line 429):
```dart
// OLD (broken):
await _storage.ref('avatars/$uid.jpg').delete();
// NEW (matches storage.rules + correct path):
// Best-effort delete — profile_viewmodel already has try/catch around this
// Since we don't store the exact path, we list the uploads/{uid}/ directory
// and delete items ending in '_avatar.jpg'. Or: store avatarStoragePath on the user doc.
// Simplest approach for Phase 1: skip the storage delete on account deletion; 
// focus on fixing the upload path only (blocking the QA path).
```

**Verification:** Upload an avatar on a physical iOS device or simulator with Firebase connected; confirm no `permission-denied` error in the debug console.

### `analysis_options.yaml` with custom_lint plugin

```yaml
# analysis_options.yaml — after PR-2
include: package:flutter_lints/flutter.yaml

analyzer:
  plugins:
    - custom_lint

linter:
  rules:
    # No changes to existing rules
```

### iOS Deployment Target Update (Podfile)

```ruby
# ios/Podfile — line 2 (uncomment and change)
platform :ios, '14.2'

# ... existing content ...

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      # Bump all pods to 14.2 minimum (was 13.0)
      current = config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f
      if current < 14.2
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.2'
      end
    end
  end
  # ... rest of post_install block unchanged
end
```

---

## State of the Art

| Old Approach | Current Approach | Changed | Impact on Phase 1 |
|--------------|-----------------|---------|-------------------|
| `riverpod_lint 2.x` + `custom_lint 0.7.x` | `riverpod_lint 3.x` + `custom_lint 0.8.x` (requires riverpod 3.x) | Riverpod 3 release | We stay on 2.x — use `riverpod_lint 2.6.5` + `custom_lint 0.7.7` |
| `fake_cloud_firestore 3.x` (firebase 5.x) | `fake_cloud_firestore 4.x` (firebase 6.x) | Firebase SDK v6 | We stay on firebase 5.x — use `fake_cloud_firestore 3.1.0` |
| iOS 13 minimum target | iOS 14+ (App Attest requires 14.0+) | App Attest GA | Bump to 14.2 in Phase 1; enables App Check in Phase 2 |
| `git mv` without import update | `git mv` + immediate import update in same commit | — | Both steps must be in same commit for `git log --follow` |
| `Color.withOpacity(x)` | `Color.withValues(alpha: x)` (Flutter 3.27+) | Flutter 3.27 | Phase 7 migration; Phase 1 must NOT touch these (destroys `git log --follow`) |

**Deprecated/outdated:**
- `build_runner`, `riverpod_generator`, `riverpod_annotation`, `injectable`, `injectable_generator`, `get_it`: All present in current pubspec but unused. Delete in PR-2.
- `ios/Podfile` deployment target threshold of `< 13.0` in post_install hook: Must be updated to `< 14.2` in PR-3.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Project-local `custom_lint` rule in `tool/lints/` with `custom_lint_builder ^0.7.0` will resolve without conflicts | Pattern 4: custom_lint | Rule package may need adjustment if `custom_lint_builder` API differs; low risk with version pinning |
| A2 | All Firebase pods currently used (`firebase_auth`, `firebase_core`, `cloud_firestore`, `firebase_storage`, `firebase_messaging`, `google_sign_in`) support iOS 14.2 minimum deployment target | iOS deployment target | A pod with a 15.0+ minimum would require either dropping the pod or bumping to iOS 15.0; probability is low given Firebase iOS support policies |
| A3 | The `FakeDashboardViewModel` test double in Anchor Test 4 can be a simple `StateNotifier` subclass with a hardcoded initial state | Code Examples | If `DashboardViewModel` constructor becomes complex after PR-2, the test double pattern may need factory helpers |
| A4 | Firebase Console re-registration of the new bundle ID `com.mentorminds.mentorMinds` will not require a new Google Cloud project | iOS Identity | Assumes the existing project `mentor-mind-aa765` will accept a second iOS app registration; Firebase supports multiple iOS apps per project |
| A5 | The `dart run custom_lint` command works on the Ubuntu GitHub Actions runner without additional setup | CI Pattern | Confirmed on Dart 3.11 (sdk constraint `>=3.0.0`); risk is near-zero |
| A6 | `BadgeInfo` in `gamification_viewmodel.dart` and `rewards_viewmodel.dart` have compatible field sets that merge cleanly | Model Extraction | If fields conflict, extraction will require one viewmodel to adapt its field accesses |

---

## Open Questions

1. **`BadgeInfo` / `LeaderboardEntry` field reconciliation**
   - What we know: Both `gamification_viewmodel.dart:31` and `rewards_viewmodel.dart:14` define `BadgeInfo`; both `gamification_viewmodel.dart:149` and `rewards_viewmodel.dart:151` define `LeaderboardEntry`.
   - What's unclear: Whether the field definitions are identical or diverge (research didn't read the actual field lists).
   - Recommendation: Planner should schedule a read of both definitions before the extraction task. If they differ, the merge task needs explicit field reconciliation instructions.

2. **APNs `.p8` key re-association after bundle ID flip**
   - What we know: Firebase Console requires an APNs auth key to be associated per iOS app registration. Flipping bundle ID requires registering a new iOS app, then re-associating the `.p8` key.
   - What's unclear: Whether the existing `.p8` key can be re-used for the new app or if a new key must be issued from Apple Developer console.
   - Recommendation: Include in `BACKEND_SETUP.md` that the existing `.p8` key CAN be re-uploaded to the new Firebase iOS app (Apple `.p8` keys are per team, not per bundle ID). No new key generation needed unless the old key was already used for APNs certificates (not auth keys).

3. **`LearningMaterial` vs `MaterialItem` naming conflict**
   - What we know: `dashboard_viewmodel.dart` defines `MaterialItem` (line 143) and `materials_viewmodel.dart` defines `LearningMaterial` (line 94). Both represent materials from the `/materials` Firestore collection.
   - What's unclear: Whether the two classes have the same fields or different projections.
   - Recommendation: Read both definitions; if they overlap substantially, canonicalize to `MaterialItem` (shorter, more consistent with `SessionItem`/`BadgeItem` naming in the same dashboard file).

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter | All Dart work | ✓ | 3.41.3 stable | — |
| Dart SDK | All Dart work | ✓ | 3.11.1 | — |
| Xcode | iOS build, deployment target change | ✓ | 26.5 (Build 17F42) | — |
| CocoaPods | iOS pod install | ✓ | 1.16.2 (pinned in Podfile.lock) | — |
| Firebase CLI | Emulator Suite, firebase.json | ✓ | 15.2.1 | — |
| Java | Firebase Emulator Suite | ✓ | OpenJDK 25.0.2 | — |
| FlutterFire CLI | `flutterfire configure` for new bundle ID | ✓ | 1.3.1 | Manual plist replacement |
| git | `git mv` for refactor | ✓ | (system git) | — |
| Node.js | Functions CI stub + seed tool | [ASSUMED] | Not checked in research | Only needed for functions lint step; stub is no-op |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None blocking Phase 1.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK bundled) |
| Config file | None — no `dart_test.yaml` yet |
| Quick run command | `flutter test test/core/utils/validators_test.dart` |
| Full suite command | `flutter test --coverage` |
| Custom lint command | `dart run custom_lint` |
| Integration test command | `flutter test integration_test/login_smoke_test.dart --dart-define=USE_EMULATOR=true -d <device>` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ARCH-01 | Layer enforcement — no Firebase imports in presentation | lint | `dart run custom_lint` | ❌ Wave 0 |
| ARCH-02 | Inline models extracted | unit (model parsing) | `flutter test test/data/models/` | ❌ Wave 0 |
| ARCH-03 | ViewModels use repos not direct Firebase | lint + unit | `dart run custom_lint` + `flutter test test/application/viewmodels/` | ❌ Wave 0 |
| ARCH-04 | Bundle ID correct | manual | Build + run on device | N/A |
| ARCH-05 | iOS 14.2 deployment | manual | `flutter build ios --no-codesign`; check Xcode summary | N/A |
| ARCH-06 | Avatar upload succeeds | manual | Upload avatar on simulator with Firebase Storage connected | N/A |
| ARCH-07 | Google Sign-In works on iOS device | manual | Sign in on physical device | N/A |
| CI-01 | `flutter analyze` runs on PRs | CI | `.github/workflows/ci.yml` push | ❌ Wave 0 |
| CI-02 | `flutter test --coverage` runs on PRs | CI | `.github/workflows/ci.yml` push | ❌ Wave 0 |
| CI-03 | Functions CI stub runs | CI | `.github/workflows/ci.yml` path filter | ❌ Wave 0 |
| CI-04 | Smoke widget test (partial — 1 of 12) | widget | `flutter test test/presentation/screens/dashboard_screen_test.dart` | ❌ Wave 0 |
| CI-05 | Viewmodel unit test (partial — 2 of 12) | unit | `flutter test test/application/viewmodels/` | ❌ Wave 0 |
| CI-06 | Emulator Suite boots + integration test runs | integration | `flutter test integration_test/ --dart-define=USE_EMULATOR=true` | ❌ Wave 0 |
| CI-07 | Test harness deps installed | unit (any test) | `flutter test` | ❌ Wave 0 |
| QUAL-04 | `dart run custom_lint` passes | lint | `dart run custom_lint` | ❌ Wave 0 |
| QUAL-06 | Unused packages removed | `pubspec` | `flutter pub get` no errors; `flutter analyze` clean | N/A |

### Sampling Rate
- **Per-task commit:** `flutter analyze --fatal-warnings` (prevents import errors accumulating)
- **Per-wave merge:** `flutter test --coverage` + `dart run custom_lint`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps (all new — no existing test infrastructure)
- [ ] `.github/workflows/ci.yml` — CI workflow file
- [ ] `firebase.json` `emulators:` block — emulator config
- [ ] `test/core/utils/validators_test.dart` — Anchor Test 1 (pure unit)
- [ ] `test/application/viewmodels/onboarding_viewmodel_test.dart` — Anchor Test 2
- [ ] `test/application/viewmodels/auth_viewmodel_test.dart` — Anchor Test 3
- [ ] `test/presentation/screens/dashboard_screen_test.dart` — Anchor Test 4
- [ ] `integration_test/login_smoke_test.dart` — Anchor Test 5
- [ ] `test/_support/factories/` — test factory builder files
- [ ] `test/_helpers/provider_scope_helpers.dart` — ProviderScope override helpers
- [ ] `tool/lints/` — project-local custom_lint rule package

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No direct change in Phase 1 | Firebase Auth (existing) |
| V3 Session Management | No direct change in Phase 1 | Firebase Auth refresh token (existing) |
| V4 Access Control | Partial — layer enforcement prevents presentation from bypassing repos | `custom_lint` layer rule |
| V5 Input Validation | No change | `validators.dart` (existing) |
| V6 Cryptography | No change | Firebase handles; never hand-rolled |

### Known Threat Patterns for Phase 1 Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Committing Firebase service-account JSON | Information Disclosure | `tool/seed/.gitignore` entry (CONCERNS.md §4c — check if it exists) |
| Gemini API key in compiled binary | Information Disclosure | Deferred to Phase 3 (`--dart-define` is still used; do NOT change in Phase 1) |
| `storage.rules` avatar path mismatch | Tampering | One-line fix in PR-3 (ARCH-06) |
| Unauthenticated routes reachable by URL | Elevation of Privilege | Deferred — no router `redirect:` guard in Phase 1 (documented anti-pattern) |

**Security item to verify before Phase 1 execution:** Check that `tool/seed/service-account.json` is properly gitignored. CONCERNS.md §4c flagged it was not gitignored at analysis time. Run: `git check-ignore -v tool/seed/service-account.json`. If not gitignored, add the entry to `.gitignore` as the first task.

---

## Sources

### Primary (HIGH confidence — verified via local CLI and pub.dev API)
- pub.dev API (`https://pub.dev/api/packages/<name>`) — all package versions and compatibility constraints verified
- `flutter --version` / `dart --version` — confirmed Flutter 3.41.3, Dart 3.11.1
- `xcodebuild -version` — confirmed Xcode 26.5
- `firebase --version` — confirmed Firebase CLI 15.2.1
- `java -version` — confirmed OpenJDK 25.0.2
- Local file reads: `pubspec.yaml`, `firebase.json`, `storage.rules`, `analysis_options.yaml`, `ios/Podfile`, `ios/Runner/Info.plist`, `ios/Runner/Runner.entitlements`, `ios/Runner/AppDelegate.swift`, `ios/Runner.xcodeproj/project.pbxproj`
- Local grep: confirmed `avatars/${uid}` path in `profile_viewmodel.dart:232`; confirmed no `CLIENT_ID` in `GoogleService-Info.plist`; confirmed 22 files to move; confirmed 3 xcodeproj deployment target entries at lines 483, 617, 668

### Secondary (MEDIUM confidence — official GitHub Actions / docs)
- `github.com/subosito/flutter-action` README — CI workflow pattern [CITED]
- `github.com/actions/checkout`, `setup-node`, `upload-artifact` — latest tags verified via GitHub API

### Tertiary (ASSUMED — based on training knowledge, not verified in this session)
- Project-local `custom_lint` rule structure (`tool/lints/` package with `custom_lint_builder`) — the API for authoring rules was not fetched from Context7 or docs in this session
- Firebase Console bundle ID re-registration procedure — standard procedure based on training knowledge; may have UI changes
- APNs `.p8` re-usability across Firebase iOS app registrations — training knowledge; confirm in Firebase Console docs before executing

---

## Metadata

**Confidence breakdown:**
- Package version compatibility: HIGH — all versions verified against pub.dev API with real HTTP calls
- `git mv` strategy: HIGH — standard git behavior; verified `git log --follow` on existing files
- iOS identity / bundle ID mechanics: MEDIUM — local files confirmed; Firebase Console procedure is ASSUMED
- custom_lint rule authoring: MEDIUM — package structure confirmed; rule implementation API is ASSUMED
- Anchor test patterns: HIGH — based on codebase patterns documented in TESTING.md and CONVENTIONS.md

**Research date:** 2026-05-17
**Valid until:** 2026-07-17 (package versions may advance; re-run `flutter pub outdated` before executing)

**Pre-planning verification items (MUST run before plan is finalized):**
1. `flutter pub outdated` — confirm `cloud_firestore`, `firebase_auth`, `firebase_storage` are still in the `^5.x` range (if upgraded to `^6.x`, bump the test dep version pins accordingly)
2. Read `gamification_viewmodel.dart:31-150` and `rewards_viewmodel.dart:14-170` — compare `BadgeInfo` and `LeaderboardEntry` field definitions for the merge decision (Open Question 1)
3. Read `dashboard_viewmodel.dart:143-171` and `materials_viewmodel.dart:94-130` — compare `MaterialItem` and `LearningMaterial` for the canonical naming decision (Open Question 3)
4. `git check-ignore -v tool/seed/service-account.json` — verify the service account key is gitignored before any git operations

---

## RESEARCH COMPLETE
