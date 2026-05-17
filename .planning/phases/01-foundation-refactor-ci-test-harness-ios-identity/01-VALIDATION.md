---
phase: 1
slug: foundation-refactor-ci-test-harness-ios-identity
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-17
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `01-RESEARCH.md` § Validation Architecture (lines 966–1016).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (SDK-bundled) + `integration_test` (SDK) for emulator suite |
| **Config file** | None today — Wave 0 introduces `dart_test.yaml`, `firebase.json` `emulators:` block, and `tool/lints/` `custom_lint` plugin |
| **Quick run command** | `flutter analyze --fatal-warnings && flutter test test/core/utils/validators_test.dart` |
| **Full suite command** | `flutter test --coverage && dart run custom_lint` |
| **Integration command** | `flutter test integration_test/login_smoke_test.dart --dart-define=USE_EMULATOR=true -d <device>` |
| **Estimated runtime** | ~25 s quick · ~90 s full (post Wave 0) |

---

## Sampling Rate

- **After every task commit:** Run `flutter analyze --fatal-warnings` plus the closest unit test in `test/` (or `dart run custom_lint` on layer-rule tasks).
- **After every plan wave:** Run `flutter test --coverage && dart run custom_lint`.
- **Before `/gsd:verify-work`:** Full suite + emulator integration smoke must be green.
- **Max feedback latency:** 90 seconds (full suite).

> **Why `--fatal-warnings` not `--fatal-infos`** (RESEARCH § Pitfalls): the codebase carries ~104 `withOpacity` info-level warnings that Phase 7 is responsible for retiring. A `--fatal-infos` gate would red-light Phase 1 CI immediately.

---

## Per-Task Verification Map

> Task IDs are assigned by `gsd-planner` in Step 8. The rows below are the **requirement-to-test map** the planner must turn into concrete task rows. Each row already has an automated command except where marked **Manual**.

| Plan slug (planned) | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---|---|---|---|---|---|---|---|---|
| 01-w0-deps-and-emulators | 1 | CI-07, QUAL-06 | T-1-W0 | Test deps resolve, unused codegen deps removed | unit | `flutter pub get && flutter test` | ❌ W0 | ⬜ pending |
| 01-w0-emulator-config | 1 | CI-06 | T-1-W0 | Emulator suite boots Auth+Firestore+Storage+Functions | integration | `firebase emulators:start --only auth,firestore,storage,functions --import=tool/emulator-data` | ❌ W0 | ⬜ pending |
| 01-w0-anchor-tests | 1 | CI-04, CI-05, CI-07 | — | Five anchor tests exercise each new dev_dep at least once | unit + widget + integration | `flutter test --coverage && flutter test integration_test/ --dart-define=USE_EMULATOR=true` | ❌ W0 | ⬜ pending |
| 02-refactor-pure-git-mv | 2 | ARCH-01, ARCH-02 | — | `git log --follow` continuity preserved; layered tree exists | static | `git log --follow lib/presentation/screens/dashboard_screen.dart \| head -5` returns ≥2 commits | ❌ W0 | ⬜ pending |
| 03-layer-lint-rule | 2 | ARCH-01, ARCH-03, QUAL-04 | T-1-LAYER | Presentation cannot import `package:mentor_minds/data/...`; viewmodels cannot import `package:firebase_*` | lint | `dart run custom_lint` exits 0 | ❌ W0 | ⬜ pending |
| 04-model-extraction | 2 | ARCH-02 | — | All inline domain models live in `lib/data/models/` and round-trip via `fromDoc`/`toMap` | unit | `flutter test test/data/models/` | ❌ W0 | ⬜ pending |
| 05-repository-extraction | 2 | ARCH-03 | T-1-LAYER | Viewmodels depend on repository interfaces, not `FirebaseFirestore.instance` | unit | `flutter test test/application/viewmodels/` | ❌ W0 | ⬜ pending |
| 06-bundle-id-flip | 2 | ARCH-04 | T-1-IDENT | iOS build runs under `com.mentorminds.mentorMinds` | manual | `flutter build ios --no-codesign` + Xcode summary verify | N/A | ⬜ pending |
| 07-ios-deployment-target | 2 | ARCH-05 | — | `IPHONEOS_DEPLOYMENT_TARGET=14.0` in all 3 xcodeproj configs and Podfile; pods recompile | static + build | `grep -c "IPHONEOS_DEPLOYMENT_TARGET = 14" ios/Runner.xcodeproj/project.pbxproj` == 3 | N/A | ⬜ pending |
| 08-avatar-upload-fix | 2 | ARCH-06 | T-1-STORAGE | Profile avatar uploads succeed under deployed `storage.rules` | manual | Upload avatar on simulator with emulator Storage | N/A | ⬜ pending |
| 09-google-sign-in | 2 | ARCH-07 | T-1-IDENT | `REVERSED_CLIENT_ID` present in `Info.plist` URL Types; Google Sign-In completes on device | manual | Sign in on physical device after new `GoogleService-Info.plist` install | N/A | ⬜ pending |
| 10-ci-workflow | 3 | CI-01, CI-02, CI-03 | — | `analyze + test + coverage upload` runs on every PR; Functions lint+build runs when `functions/**` changes | CI | Open dummy PR; `.github/workflows/ci.yml` all jobs green; coverage artifact present | ❌ W0 | ⬜ pending |
| 11-codegen-decision-doc | 3 | QUAL-06 | — | `pubspec.yaml` matches the documented codegen choice (vanilla = remove `riverpod_annotation` + `injectable*`) | static | `grep -c "riverpod_annotation\|injectable" pubspec.yaml` == 0 (or recorded "kept" with rationale in CONTEXT.md) | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

> Planner MUST translate each row into one or more `<task>` entries inside the matching PLAN.md and copy the `Automated Command` into the task's `<verify>` / `<acceptance_criteria>` block.

---

## Wave 0 Requirements

- [ ] `pubspec.yaml` — add `mocktail`, `fake_cloud_firestore ^3.1.0`, `firebase_auth_mocks ^0.14.2`, `golden_toolkit`, `network_image_mock`, `integration_test`; remove `riverpod_annotation`, `injectable`, `injectable_generator`, `riverpod_generator`, `build_runner` (per codegen decision)
- [ ] `firebase.json` — add `emulators:` block (Auth 9099, Firestore 8080, Storage 9199, Functions 5001, UI 4000)
- [ ] `tool/emulator-data/` — committed seed (`firebase emulators:export tool/emulator-data` baseline)
- [ ] `tool/lints/` — project-local `custom_lint` plugin package (`custom_lint_builder ^0.7.7`)
- [ ] `analysis_options.yaml` — wire `custom_lint` plugin and `riverpod_lint ^2.6.5` (if codegen retained)
- [ ] `dart_test.yaml` — wire emulator tags
- [ ] `test/_support/factories/` — `userFactory`, `materialFactory`, `notificationFactory`, `messageFactory`
- [ ] `test/_helpers/provider_scope_helpers.dart` — `pumpWithProviders(...)` helper
- [ ] `test/core/utils/validators_test.dart` — Anchor 1 (pure unit, no Firebase)
- [ ] `test/application/viewmodels/onboarding_viewmodel_test.dart` — Anchor 2 (`mocktail`)
- [ ] `test/application/viewmodels/auth_viewmodel_test.dart` — Anchor 3 (`firebase_auth_mocks` + `fake_cloud_firestore`)
- [ ] `test/presentation/screens/dashboard_screen_test.dart` — Anchor 4 (widget + `network_image_mock` + `golden_toolkit`)
- [ ] `integration_test/login_smoke_test.dart` — Anchor 5 (emulator suite + `useAuthEmulator` / `useFirestoreEmulator`)
- [ ] `.github/workflows/ci.yml` — analyze + test + coverage upload + conditional Functions job

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Bundle ID swap propagates to Firebase Console + APNs | ARCH-04 | Requires Firebase Console + Apple Developer Portal access (human in the loop) | (1) Re-register iOS app in Firebase Console under `com.mentorminds.mentorMinds`; (2) re-download `GoogleService-Info.plist`; (3) re-associate APNs `.p8` key; (4) `flutter run` on physical device and confirm Auth still works |
| iOS deployment target bump 13 → 14 actually rebuilds pods | ARCH-05 | Requires Xcode toolchain run on the dev's Mac | `cd ios && pod deintegrate && pod install` then `flutter build ios --no-codesign` — expect zero deployment-target warnings |
| Avatar upload succeeds end-to-end against deployed `storage.rules` | ARCH-06 | Final proof requires the prod-deployed `storage.rules` to allow the new path | Build on simulator → log in → Profile → change avatar → confirm new image renders after relogin |
| Google Sign-In completes on a physical iOS device | ARCH-07 | Apple's Sign-In flow requires real device for full handshake | `flutter run -d <device-id>` → tap Google Sign-In → confirm session lands at `/dashboard` |
| `git log --follow` continuity after refactor | ARCH-01 | Verifies the "pure `git mv`" pitfall was honored | `git log --follow lib/presentation/screens/dashboard_screen.dart` returns commits older than the rename |

---

## Validation Sign-Off

- [ ] All planner-generated tasks have `<verify>` automated commands OR a Wave 0 dependency
- [ ] Sampling continuity: no 3 consecutive tasks without an automated verify command
- [ ] Wave 0 covers all `❌ W0` references above
- [ ] No watch-mode flags in any verify command (CI must be one-shot)
- [ ] Feedback latency < 90 s for full suite
- [ ] `flutter pub outdated` was run before pinning the test-harness versions in `pubspec.yaml`
- [ ] `git check-ignore -v tool/seed/service-account.json` confirms the seed key is gitignored
- [ ] `nyquist_compliant: true` set in this frontmatter after all rows above turn ✅

**Approval:** pending
