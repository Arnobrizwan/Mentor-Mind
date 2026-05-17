# Codebase Concerns

**Analysis Date:** 2026-05-17
**Project:** MentorMinds (Flutter app at `/Users/arnobrizwan/Mentor-Mind`)
**Scope:** Full repo, excluding `build/`, `.dart_tool/`, `ios/Pods/`, `.git/`.

> Severity legend — **HIGH**: blocks production / ships a real defect or security issue. **MED**: degrades quality, will bite in next 1–2 sprints. **LOW**: cosmetic / cleanup.

---

## 1. Platform gap — iOS-only project (HIGH)

**Issue.** The Flutter project was scaffolded with `flutter create -t app --platforms=ios` (or equivalent). Only iOS host code exists; Android, web, macOS, Windows, and Linux runners are absent. Repeated user-facing specs (and `BACKEND_SETUP.md`) reference Android, but `flutter build apk` / `flutter run -d chrome` cannot succeed.

**Evidence:**
- Only platform directory present is `ios/` — see repo root listing (no `android/`, `web/`, `macos/`, `linux/`, `windows/`).
- `lib/firebase_options.dart:21` throws `UnsupportedError` for `kIsWeb`; `lib/firebase_options.dart:35` and `:41` throw for Windows and Linux.
- `lib/firebase_options.dart:49-55` declares an `android` `FirebaseOptions` entry (so Firebase keys are registered), but there is no `android/app/build.gradle` for the Flutter tool to build against.
- `BACKEND_SETUP.md:24` and `:48` instruct readers to set up both iOS and Android, and `:137` references `cd android && ./gradlew clean` — indicating the intent diverges from what is checked in.
- A stray `ios/android/` directory exists (`/Users/arnobrizwan/Mentor-Mind/ios/android`) — likely a misplaced scaffolding artifact, not a real Android runner.

**Impact.** App ships iOS only. Any CI matrix, Play Store release, or web demo is impossible without re-scaffolding. The bundle ID drift compounds this (see #5 / Concern 11).

**Remediation.**
1. Run `flutter create --platforms=android,web . ` from repo root to add missing runners (will scaffold `android/`, `web/`).
2. Re-run `flutterfire configure` so `lib/firebase_options.dart` regenerates with valid `android`/`web` blocks plus drops the platform `UnsupportedError`s.
3. Delete the spurious `ios/android/` directory.
4. Align the Android `applicationId` with the iOS bundle id (`com.arnobrizwan.mentorminds`).

**Phase to address:** Phase 0 / "Platform bring-up" before any feature work. Blocks CI (#7), Crashlytics setup (#8), and the planned refactor (#6).

---

## 2. Dependency drift (MED)

**Issue.** `pubspec.lock` is significantly behind upstream. `flutter pub outdated` reports **60 packages have newer versions incompatible with current constraints**, **7 upgradable** within constraints, and **1 discontinued** (transitively).

**Evidence (from `flutter pub outdated` output at 2026-05-17):**

| Package | Current | Latest | Notes |
|---|---|---|---|
| `flutter_riverpod` (transitive) | `2.6.1` | `3.3.1` | Major bump; API differences in `Provider`, `Notifier` patterns. |
| `riverpod` | `2.6.1` | `3.2.1` | Same. |
| `riverpod_annotation` | `2.6.1` | `4.0.2` | Two majors behind. |
| `riverpod_generator` (dev) | `2.6.5` | `4.0.3` | Two majors behind. |
| `flutter_lints` (dev) | `4.0.0` | `6.0.0` | Two majors behind; would surface more issues. |
| `build_runner` (dev) | `2.5.4` | `2.15.0` | Many minors behind. |
| `intl` | `0.19.0` | `0.20.2` | Minor bump. |
| `injectable_generator` (dev) | `2.7.0` | `3.0.2` | Major. |
| `google_sign_in_ios` (transitive) | `5.9.0` | `6.3.0` | Major. |
| **`build_resolvers`** (transitive dev) | `2.5.4` | — | **DISCONTINUED** (`https://dart.dev/go/package-discontinue`) |
| **`build_runner_core`** (transitive dev) | `9.1.2` | — | **DISCONTINUED** |

**Impact.**
- Discontinued packages will not receive security or Dart-SDK-compatibility patches.
- Riverpod 2 → 3 contains breaking API changes (`StateNotifier` deprecation in 3.x, new `Notifier`/`AsyncNotifier` patterns). Delaying makes the eventual migration harder.
- `flutter_lints` 4 → 6 ships rules that already exist in our codebase as issues (#3), so the upgrade will surface even more lint debt.

**Remediation.**
1. Pin Riverpod 2.x for now (acceptable) but raise `hooks_riverpod` and `riverpod_annotation` together once codegen is wired up (#9).
2. Run `flutter pub upgrade --major-versions` in a dedicated branch and walk through each breaking change.
3. Upgrade `build_runner` + `riverpod_generator` together — this unblocks Concern #9.
4. Track the discontinued packages: when `build_runner` is upgraded, transitive `build_resolvers` / `build_runner_core` get replaced by their successors.

**Phase to address:** Phase 1 / "Foundation cleanup" after platform bring-up.

---

## 3. Lint debt — 167 analyzer issues (MED)

**Issue.** `flutter analyze` reports **167 info-level issues** (ran in 2.5s on 2026-05-17). All are info-level (no warnings/errors), so the build is green, but they signal real maintenance debt.

**Breakdown:**

| Lint rule | Count | Notes |
|---|---:|---|
| `deprecated_member_use` (`Color.withOpacity`) | **105** | Needs replacement with `.withValues(alpha: …)` — Flutter 3.27+ deprecated `withOpacity` due to precision loss. |
| `prefer_const_constructors` | 42 | Performance & rebuilds — straightforward fix. |
| `depend_on_referenced_packages` (`flutter_riverpod`) | **12** | `flutter_riverpod` imported in 12 files but only `hooks_riverpod` is declared in `pubspec.yaml`. The dependency resolves transitively today — fragile. |
| `use_build_context_synchronously` | 2 | Real correctness risk after `await` in widgets. |
| `prefer_const_literals_to_create_immutables` | 1 | |
| `prefer_null_aware_operators` | 1 | `lib/features/tutor/chat_viewmodel.dart:315` |
| `unused_import` | 1 | |

**Evidence (selected file:line citations):**
- `lib/features/splash/splash_screen.dart:180,211,214,220,226` — `withOpacity` cluster.
- `lib/features/tutor/tutor_screen.dart:332,486,502,516,542,594,599,835,852,882,1011,1176,1299,1314,1441` — heaviest concentration of `withOpacity` (15+ hits in one file).
- `lib/features/search/search_screen.dart:651,705,803,840,870,912,953,972,1029,1049` — 10+ hits.
- `lib/features/auth/auth_viewmodel.dart:7`, `lib/features/dashboard/dashboard_viewmodel.dart:6`, `lib/features/materials/materials_viewmodel.dart:5`, `lib/features/notifications/notifications_viewmodel.dart:6`, `lib/features/onboarding/onboarding_viewmodel.dart`, `lib/features/profile/profile_viewmodel.dart:8`, `lib/features/rewards/gamification_viewmodel.dart:6`, `lib/features/rewards/rewards_viewmodel.dart:6`, `lib/features/search/search_viewmodel.dart:6`, `lib/features/splash/splash_viewmodel.dart:3`, `lib/features/tutor/chat_viewmodel.dart:8`, `lib/core/routes/app_router.dart:2` — all import `flutter_riverpod` without a declared dep.

**Impact.**
- The `depend_on_referenced_packages` violation is a latent break: if `hooks_riverpod` ever drops `flutter_riverpod` from its export chain (it does in v3), every viewmodel + router fails to compile.
- 105 `withOpacity` calls will become hard errors once Flutter promotes the deprecation to a removal (already MED-priority in Flutter 3.27).
- Two `use_build_context_synchronously` hits can crash on unmount.

**Remediation.**
1. Add `flutter_riverpod: ^2.6.1` to `dependencies` in `pubspec.yaml` (one-line fix — clears 12 of 167 issues).
2. Sed-replace `.withOpacity(X)` → `.withValues(alpha: X)` across `lib/` (covers ~105 issues, mechanical).
3. Audit the two `use_build_context_synchronously` sites manually — they need `if (!context.mounted) return;` guards.
4. The remaining `prefer_const_*` items can be auto-fixed with `dart fix --apply`.
5. Tighten `analysis_options.yaml` (currently the default `package:flutter_lints/flutter.yaml`) — add `treat_unused_imports_as_warning` or escalate the offenders to `error` to prevent regression.

**Phase to address:** Phase 1 / "Foundation cleanup" — bundle with dependency upgrade.

---

## 4. Secrets handling (MED — partially correct, one blocker)

**Issue.** Three secret-adjacent concerns, with different severities:

### 4a. Firebase client config committed — acceptable (LOW)

- `lib/firebase_options.dart:50` — `apiKey: 'AIzaSyCxEDL0IhXgFZDGSvtC_GICQDFcwzUFF0s'` (Android).
- `lib/firebase_options.dart:58` — `apiKey: 'AIzaSyB9xmghvdBhWrKRzEDnGiu7vyPvuHWIS10'` (iOS).
- `lib/firebase_options.dart:67` — same iOS key reused for macOS.
- `ios/Runner/GoogleService-Info.plist` — same iOS key.

**This is fine.** Per Firebase's documentation, the iOS/Android/Web API key in `firebase_options.dart` and `GoogleService-Info.plist` is a **public client identifier**, not a secret. Real protection is enforced server-side via:
- `firestore.rules` (per-collection auth gates — reviewed in #5)
- `storage.rules` (per-path auth gates — see #5e)
- Firebase Auth user gating

**Remediation.** No code change required. Add a comment block at the top of `lib/firebase_options.dart` explaining that these keys are *public client config* and that security is enforced by rules + App Check. This pre-empts future contributors panicking and rotating keys that didn't need rotation.

### 4b. Gemini API key handling — correct (LOW)

- `lib/core/services/gemini_service.dart:13` — `const String _kApiKey = String.fromEnvironment('GEMINI_API_KEY');`
- No hard-coded fallback. Service gracefully degrades when key is missing (`lib/core/services/gemini_service.dart:55-56` returns a user-facing "AI tutor is not configured" message).
- `BACKEND_SETUP.md:97` documents the `--dart-define=GEMINI_API_KEY=…` pattern.

**This is correct for dev/CI**, but see #8 for the production concern (the key is still baked into the compiled binary and recoverable by an attacker).

### 4c. `tool/seed/service-account.json` exists locally and is NOT git-ignored — **HIGH**

- File present: `/Users/arnobrizwan/Mentor-Mind/tool/seed/service-account.json` (2391 bytes, perms `-rw-------`).
- `git check-ignore tool/seed/service-account.json` returns **nothing** — i.e., it is **not** gitignored.
- `git ls-files | grep service-account` returns **nothing** — i.e., it has not been committed *yet* (the only saving grace).
- `.gitignore` (full contents reviewed) has no entry for `service-account.json`, `tool/seed/service-account.json`, or `*.json` in `tool/seed/`.
- `tool/seed/seed.js:28-36` actively loads `./service-account.json` if present and uses it as the Firebase Admin credential — i.e., the workflow encourages keeping the file in-tree.

**Impact.** A single `git add tool/seed/` or `git add .` from a contributor would commit a Firebase Admin private key that grants **unrestricted** access to the entire `mentor-mind-aa765` Firestore + Auth project (including the ability to read every user's data and mint custom tokens). This bypasses every `firestore.rules` and `storage.rules` protection.

**Remediation (do this first, before any other concern):**
1. Add to `.gitignore`:
   ```gitignore
   # Firebase service-account keys — NEVER commit
   tool/seed/service-account.json
   **/service-account*.json
   **/*-firebase-adminsdk-*.json
   ```
2. Verify `git status --ignored` lists the file as ignored.
3. If the file was *ever* committed (review `git log --all --full-history -- tool/seed/service-account.json` — currently shows nothing, so we're safe), rotate the key in Firebase Console → Service Accounts → Generate new private key, and revoke the old one.
4. Consider switching `tool/seed/seed.js:38` to prefer Application Default Credentials (`gcloud auth application-default login`) so the JSON file isn't required at all.

**Phase to address:** **Phase 0 / Immediate.** Single highest-priority concern in this audit.

---

## 5. Firestore rules & data-model concerns (HIGH)

Cross-referencing every `collection('…')` call in `lib/` against `firestore.rules` and `storage.rules`. Collections referenced by client code:

| Collection | Used in | Rule coverage in `firestore.rules` |
|---|---|---|
| `users` | `lib/features/auth/auth_viewmodel.dart:295`, `lib/features/dashboard/dashboard_viewmodel.dart`, `lib/features/profile/profile_viewmodel.dart`, `lib/features/rewards/gamification_viewmodel.dart`, `lib/features/tutor/chat_viewmodel.dart:497,520` | `firestore.rules:49-72` ✅ |
| `users/{uid}/usage/{date}` | `lib/features/tutor/chat_viewmodel.dart:499`, `lib/features/dashboard/dashboard_viewmodel.dart:551` | `firestore.rules:77-79` ✅ |
| `rewards` | `lib/features/auth/auth_viewmodel.dart:296`, `lib/features/tutor/chat_viewmodel.dart:524`, `lib/features/rewards/gamification_viewmodel.dart:330,337` | `firestore.rules:86-89` ✅ |
| `sessions` | `lib/features/tutor/chat_viewmodel.dart` | `firestore.rules:96-115` ✅ |
| `sessions/{sid}/messages` | Legacy path (see `BACKEND_SETUP.md:117`) | `firestore.rules:111-115` ✅ |
| `materials` | `lib/features/materials/materials_viewmodel.dart:418`, `lib/features/search/search_viewmodel.dart` | `firestore.rules:122-126` ✅ |
| `notifications` | `lib/features/notifications/notifications_viewmodel.dart` | `firestore.rules:132-148` ✅ |

**Good news:** every collection referenced by client code has a matching rule block. No "ungated" collections.

### 5a. Client-side point mutations — known MVP trade-off but understated (HIGH)

`firestore.rules:65-70` lets any authenticated user `update` their own `/users/{uid}` doc as long as `role` and `isApproved` stay unchanged. `lib/features/tutor/chat_viewmodel.dart:520-521` (and `:527`), `lib/features/dashboard/dashboard_viewmodel.dart:590,596`, `lib/features/rewards/gamification_viewmodel.dart:330,337` all execute `FieldValue.increment(...)` on `points` *from the client*. There is no server-side validation that the increment is "earned".

**Impact.** A user with a debug build (or a forged write via the Firebase REST API using their own ID token) can grant themselves unlimited points, badges, and bypass the 10/day free-tier message limit. This makes the leaderboard (`lib/features/rewards/rewards_screen.dart:731,811`) trivially gameable and undermines any future monetisation of premium.

**Remediation.** Move point/badge mutations into a Cloud Function (`awardPoints`, `incrementUsage`) gated by App Check (#8) and tighten `firestore.rules:65-70` to deny client writes to `points`, `badges`, and the `usage.messageCount` field. The rules file already calls this out at `firestore.rules:7-11` as a known trade-off; tracking it here as a real concern, not just a comment.

**Phase to address:** Phase 3 / "Backend hardening" (alongside Cloud Functions, App Check).

### 5b. `/notifications` delete is global, but feels per-user (MED)

`firestore.rules:147` — `allow delete: if isSignedIn();` — *any* signed-in user can delete *any* notification document. The comment at `:145-146` admits this is a deliberate trade-off ("one user's delete removes the doc for everyone"). The client code in `lib/features/notifications/notifications_viewmodel.dart` exposes this as a per-user "dismiss" action; users will not expect it to affect other users.

**Impact.** A malicious user can wipe the global notification feed (announcements, teacher-approval reminders). Trolls love this.

**Remediation.** Replace the global delete with a per-user "dismissed" subdoc: `/users/{uid}/dismissedNotifications/{nid}`. Filter client-side. Update rules to deny `notifications` delete except for admins.

**Phase to address:** Phase 3.

### 5c. Notification read-state is global (MED, same root cause)

`firestore.rules:141-144` only allows toggling the `read` field, but `read` is **per-document**, not per-user. So when user A marks `notif_welcome` as read, the bell badge drops for everyone. The seed data (`tool/seed/seed.js:301,313,326,340,353` — every `read: false`) makes this visible.

**Remediation.** Same as #5b — move read-state into a per-user subcollection.

### 5d. `isApproved` field semantics drift (MED)

- `firestore.rules:60-61` enforces that on create, a teacher must have `isApproved == false`.
- `lib/features/auth/auth_viewmodel.dart:310` writes `'isApproved': role != 'teacher'` — i.e., students get `isApproved: true`, teachers get `false`. The rule actually requires teachers to be `false` so this **does** pass for teachers, but for students the rule does not actually check `isApproved` (it's an unbounded boolean).
- The seed script at `tool/seed/seed.js:378,392,406` sets `isApproved: true` for *every* role including teacher — i.e., the seeded `teacher@mentorminds.test` would **fail** the firestore-rule `create` precondition if it went through the client path. Because the seed uses Admin SDK (`tool/seed/seed.js:32`), it bypasses rules entirely, so this works at seed time but the divergence is real.

**Impact.** A future "re-create profile through client" flow for the seeded teacher will fail with `permission-denied`. The field has no consistent meaning across documents.

**Remediation.** Pick one: either `isApproved` means "approved to act as teacher" (only set on teachers, missing/false on students) or it means "approved to use the app" (true for everyone except pending teachers). The cleaner option is the former — drop `isApproved` from student writes in `lib/features/auth/auth_viewmodel.dart:310`, drop it from student seed entries, and update the rule.

### 5e. Storage rules deny avatar uploads — **active bug** (HIGH)

`lib/features/profile/profile_viewmodel.dart:232` writes to `avatars/${user.uid}.jpg`:
```dart
final ref = _storage.ref('avatars/${user.uid}.jpg');
await ref.putFile(...);
```
But `storage.rules:11` only allows writes under `uploads/{uid}/...`, and `storage.rules:21-23` is `match /{allPaths=**} { allow read, write: if false; }` — i.e., **every avatar upload from the production app fails with `permission-denied`**.

**Evidence.** Profile viewmodel has explicit error handling for this at `lib/features/profile/profile_viewmodel.dart:258-260` ("Storage permission denied. Check Storage rules.") — strongly suggesting this has already broken in QA.

**Impact.** Avatar editing in the profile screen is non-functional in production. Users can pick an image, the UI shows the upload spinner (`uploadingAvatar: true` at `:231,241`), and then they get the generic "Storage permission denied" message.

**Remediation.** Add to `storage.rules` (before the catch-all deny):
```
match /avatars/{uid}.{ext} {
  allow read: if request.auth != null;
  allow write: if request.auth != null
    && request.auth.uid == uid
    && request.resource.size < 2 * 1024 * 1024
    && request.resource.contentType.matches('image/.*');
  allow delete: if request.auth != null && request.auth.uid == uid;
}
```
Then `firebase deploy --only storage`.

**Phase to address:** Phase 1 (must fix before any v1 demo).

### 5f. DATA.md / BACKEND_SETUP.md / code schema drift (LOW)

- `BACKEND_SETUP.md:113` lists `/users/{uid}` fields including `updatedAt` — but `lib/features/auth/auth_viewmodel.dart` never writes `updatedAt` on create (only `createdAt` at `:312`). `lib/features/profile/profile_viewmodel.dart:227` does add it on update.
- `BACKEND_SETUP.md:117` calls out the legacy `messages/{mid}` subcollection vs. the inline `messages[]` array on `/sessions/{id}`. The current code uses inline (`lib/features/tutor/chat_viewmodel.dart:101,326`) and the legacy path is dead code, but the security rules still allow writes to it (`firestore.rules:111-115`). Harmless but confusing.
- `DATA.md:78` says "Video `fileUrl`s point to real YouTube pages. PDF `fileUrl`s are `example.com` placeholders" — confirmed in `tool/seed/seed.js:74,89,103,119` etc. Means tapping a non-video material in QA opens example.com.

**Remediation.** Once schema settles, regenerate `DATA.md` from a single source of truth (e.g., a `lib/core/models/*.dart` file annotated with `freezed` + a doc-gen step). Drop the legacy `messages/{mid}` rule.

**Phase to address:** Phase 4 / "Polish".

---

## 6. Architectural divergence: `lib/features/` vs spec'd `lib/presentation/screens/` (MED)

**Issue.** The pasted 12-screen spec proposes the structure:
```
lib/presentation/screens/<name>/<name>_screen.dart
lib/presentation/widgets/...
lib/domain/...
lib/data/...
```
Current code uses a flatter feature-first layout:
```
lib/features/<name>/<name>_screen.dart
lib/features/<name>/<name>_viewmodel.dart
```

**Evidence.** All 10 features live under `lib/features/`:
- `lib/features/splash/`, `lib/features/onboarding/`, `lib/features/auth/`, `lib/features/dashboard/`, `lib/features/tutor/`, `lib/features/materials/`, `lib/features/search/`, `lib/features/profile/`, `lib/features/rewards/`, `lib/features/notifications/`.
- `lib/core/routes/app_router.dart:5-15` imports every screen via `'../../features/<name>/<name>_screen.dart'` — 11 import lines that would all need rewriting.
- No `lib/presentation/`, `lib/domain/`, or `lib/data/` directories exist.

**Impact of accepting the spec's layout:**
- ~30 files moved (10 screens × 2 files + ~10 supporting files in `lib/shared/widgets/` and `lib/core/`).
- Every import path in those files updates.
- `lib/core/routes/app_router.dart` is rewritten end-to-end.
- GoRouter `name` constants at `lib/core/routes/app_router.dart:18-32` stay stable, but builder closures change.
- IDE refactors handle most of this; manual review needed for relative-import depth changes (`../../core` becomes `../../../core`).

**Recommendation.** Keep `lib/features/` (Riverpod community + go_router community both default to feature-first). If the spec is non-negotiable, do the move in a single isolated PR with no behavioural changes, gated behind `flutter analyze` + `flutter test` going green. Do **not** mix this refactor with the platform bring-up (#1) or the dependency upgrade (#2).

**Phase to address:** Phase 2 — only if the spec is enforced. Otherwise document the decision to keep `lib/features/` in `ARCHITECTURE.md`.

---

## 7. No CI, no automated checks, near-zero test coverage (HIGH)

**Issue.**
- No `.github/workflows/`, no `.gitlab-ci.yml`, no `bitrise.yml`, no `codemagic.yaml`. (`ls /Users/arnobrizwan/Mentor-Mind/.github 2>/dev/null` returns nothing.)
- `test/` contains exactly one file: `test/widget_test.dart` — a 7-line placeholder (`expect(1 + 1, 2)`).
- No integration tests under `integration_test/`.
- No `flutter analyze` / `flutter test` / `flutter build` automation.

**Evidence.**
- `test/widget_test.dart:1-7` — the boilerplate `MyApp()` test was replaced with a tautology to make `flutter test` green; nothing else exercises any production code.
- Total `lib/` LOC: **16,782**. Tested LOC: **0**.
- `lib/features/profile/profile_screen.dart` is 1605 lines; `lib/features/tutor/tutor_screen.dart` is 1483 lines; `lib/features/dashboard/dashboard_screen.dart` is 1325 lines — none under test.

**Impact.** Every refactor (especially #1 platform bring-up, #2 dep upgrade, #6 layout move) ships blind. Regressions in auth, points, or session storage will only be caught in manual QA.

**Remediation.**
1. Add GitHub Actions workflow `.github/workflows/ci.yml` running `flutter analyze`, `flutter test`, `flutter build ios --no-codesign` on every PR.
2. Write ViewModel-level unit tests first (they are pure Dart on top of Riverpod, no widget plumbing). Priority order: `chat_viewmodel.dart` (gamification + storage paths), `auth_viewmodel.dart` (registration branch), `dashboard_viewmodel.dart` (streak math at `:551`).
3. Add a single golden integration test covering the splash → login → dashboard happy path.
4. Set a soft coverage floor (start at 20%, escalate quarterly).

**Phase to address:** Phase 1 — set up scaffolding immediately even if coverage is low; backfill tests phase-by-phase.

---

## 8. Missing v1 production essentials (HIGH)

**Issue.** Several pieces expected of a v1 consumer app are absent or stubbed:

### 8a. No crash reporting

- `pubspec.yaml` does not include `firebase_crashlytics` or `sentry_flutter`.
- `lib/main.dart:10-31` — no `FlutterError.onError` handler, no `runZonedGuarded`, no `recordError`.
- Result: any uncaught exception in production is invisible to the team.

**Remediation.** Add `firebase_crashlytics: ^4.x` to `pubspec.yaml`. In `lib/main.dart`, after `Firebase.initializeApp`, wire:
```dart
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
PlatformDispatcher.instance.onError = (e, st) {
  FirebaseCrashlytics.instance.recordError(e, st, fatal: true);
  return true;
};
```
Requires #1 platform bring-up first (needs an `android/app/google-services.json` for Android side).

### 8b. No analytics

- No `firebase_analytics` in `pubspec.yaml`. The only mention of "analytics" in `lib/` is the marketing-copy string "Advanced analytics" at `lib/features/profile/profile_screen.dart:445`.
- Funnel data (onboarding → register → first chat) cannot be measured.

**Remediation.** Add `firebase_analytics` and a tiny wrapper `lib/core/services/analytics_service.dart`. Track at minimum: `app_open`, `sign_up`, `login`, `tutor_message_sent`, `material_opened`, `daily_reward_claimed`.

### 8c. No App Check

- No `firebase_app_check` in `pubspec.yaml`. Without App Check, the Firestore + Storage + Functions endpoints accept calls from any client that has the public API key — including a curl script with a forged ID token. Combined with #5a, this is a real exfiltration risk.

**Remediation.** Add `firebase_app_check: ^0.3.x`, enable DeviceCheck (iOS) and Play Integrity (Android — after #1). Enforce in Firebase Console for Firestore + Storage + Functions.

### 8d. Gemini API key exposed in compiled binary

- `lib/core/services/gemini_service.dart:13` — `String.fromEnvironment('GEMINI_API_KEY')` bakes the key into the IPA/APK at build time. Anyone who unzips the artifact and greps for `AIza` recovers the key.
- There is no per-user rate limiting beyond the client-side `messagesRemaining` counter (`lib/features/tutor/chat_viewmodel.dart:137`), which is trivially bypassed.

**Impact.** A leaked key can rack up arbitrary Gemini usage on our billing account. The free-tier 10/day limit only exists in client code — a modified client ignores it.

**Remediation.** Route Gemini calls through a Cloud Function:
- Client calls `httpsCallable('chatStream')` with `{text, subject, level, sessionId}`.
- Function authenticates via App Check + Firebase Auth token, enforces per-user daily quota in Firestore, then calls Gemini with a server-held secret key.
- Stream the response back via Firestore document writes or Server-Sent Events through a Cloud Run instance (Functions don't natively stream).
- Remove `--dart-define=GEMINI_API_KEY` from client builds.

**Phase to address:** Phase 3 / "Backend hardening" — all four items belong together.

### 8e. No global ErrorWidget, no Zone error handling

- `lib/main.dart` has no `ErrorWidget.builder` override. In release builds, any widget-build error renders a grey screen instead of a graceful fallback.

**Remediation.** Add a branded `ErrorWidget.builder` returning a "Something went wrong, please restart" `Scaffold` and report to Crashlytics.

---

## 9. Riverpod codegen never run (MED)

**Issue.** `pubspec.yaml:18` declares `riverpod_annotation: ^2.3.5` and `:56` declares `riverpod_generator: ^2.4.3` + `:55` `build_runner: ^2.4.12`. These exist *only* to enable the `@riverpod` codegen workflow. But:

- `find lib -name "*.g.dart"` returns **nothing**.
- `grep -rn "@riverpod" lib --include="*.dart"` returns **nothing**.

**Impact.** The three packages are dead weight. They contribute to the resolution backlog in #2 (each is one of the "60 outdated packages"), they discourage adding `@riverpod` providers because contributors think "codegen isn't set up", and they make the dependency footprint look more sophisticated than it is.

**Pick one of two paths.**

**Path A — Drop codegen entirely** (matches current style; recommended):
1. Remove `riverpod_annotation`, `riverpod_generator`, `build_runner`, `injectable_generator` from `pubspec.yaml` (lines 18, 55, 56, 57).
2. Keep `hooks_riverpod` + `get_it` + `injectable`-runtime if `injectable` is actively used (verify — `grep -rn "@injectable\|@LazySingleton" lib`).
3. Update `STACK.md` to reflect "vanilla Riverpod, no codegen".

**Path B — Wire up codegen** (if the team wants `@riverpod` syntax):
1. Run `dart run build_runner build --delete-conflicting-outputs`.
2. Migrate `lib/core/routes/app_router.dart:34` (`final appRouterProvider = Provider<GoRouter>(...)`) and 10 viewmodels to `@riverpod` syntax.
3. Add `*.g.dart` to `.gitignore` or commit the generated files (project policy decision).

**Phase to address:** Phase 1 — bundle with #2 (dependency cleanup).

---

## 10. `tool/seed/` script — purpose, risk, conflict surface (MED)

**Purpose.** `tool/seed/seed.js` is a Node.js Firebase Admin SDK script that populates the `mentor-mind-aa765` project with demo data so that the Materials browser, search, leaderboard, and notification bell have content on first launch.

**What it writes (`tool/seed/seed.js`):**
1. **4 Firebase Auth users + `/users/{uid}` + `/rewards/{uid}` docs** (`seed.js:368-472`):
   - `student@mentorminds.test` / `Student1!` (free, O Level)
   - `premium@mentorminds.test` / `Premium1!` (premium, A Level)
   - `teacher@mentorminds.test` / `Teacher1!` (teacher, isApproved=true)
   - `admin@mentorminds.test` / `Admin1!` (admin)
2. **15 documents in `/materials`** (`seed.js:65-290`) — 7 subjects (Math, Physics, Chemistry, Biology, English, ICT, Accounting). All `uploadedBy: 'seed_admin'`. Videos point to real YouTube URLs, PDFs point to `example.com` placeholders.
3. **5 documents in `/notifications`** (`seed.js:296-361`) — welcome, new-physics, streak-reminder, premium-teaser, teacher-approvals.

**Idempotency.** Script is fixed-ID; re-runs overwrite the same docs (`seed.js:486,497`). User-generated docs (`/sessions/{id}`, `/users/{uid}/usage/{date}`) are untouched (confirmed at `DATA.md:131-142`).

**Has it been run?** Unknown from filesystem alone, but `BACKEND_SETUP.md` doesn't reference it, `DATA.md` is structured as a "what was seeded" reference (so someone wrote it), and the Auth user-update branch at `seed.js:430-437` exists — strongly suggesting the script has been run at least once against `mentor-mind-aa765`.

**Production conflict surface (HIGH if pointed at prod):**
- The `*.test` email domain reduces collision risk with real users, **but** the test passwords are weak by design (`Student1!`, etc.) and are checked into `DATA.md:13-16` and `tool/seed/seed.js:371-413` in plaintext. Pointing this script at the production project would (a) create four test accounts whose credentials are world-readable in the repo, (b) overwrite any production document with ID `mat_quadratic_masterclass` etc., (c) put `notif_welcome` in front of every real user.
- The script has no environment guard (no `if (projectId === 'mentor-mind-prod') throw …`). The `--project=<id>` flag (`seed.js:25-26`) lets anyone aim it at any project they have Admin credentials for.

**Conflicts inside the demo project itself:**
- `tool/seed/seed.js:73,93,103` writes `fileUrl: 'https://firebasestorage.googleapis.com/v0/b/mentor-mind-aa765.firebasestorage.app/o/seed%2Fquadratic.pdf?alt=media'` — assumes a file exists at `seed/quadratic.pdf` in Cloud Storage. `storage.rules:21-23` denies reads to any path outside `uploads/{uid}/...` for non-authed users *and* signed-in users that don't own the path. So even the seeded students cannot fetch this PDF unless the storage rules are widened (or unless Firebase Storage's default ACL on uploaded objects is "public", which is no longer the case in 2026).
- The script writes `createdAt` via `Timestamp.fromDate(...)` (`seed.js:50,57`), not `FieldValue.serverTimestamp()`. Acceptable for demo data, but real-app reads at `lib/features/materials/materials_viewmodel.dart` may sort differently if the seeder's clock drifts.

**Remediation.**
1. Add an environment guard at the top of `seed.js`:
   ```js
   const ALLOWED = ['mentor-mind-aa765', 'mentor-mind-dev'];
   if (!ALLOWED.includes(admin.app().options.projectId)) {
     console.error(`Refusing to seed unknown project: ${admin.app().options.projectId}`);
     process.exit(1);
   }
   ```
2. Move the test credentials out of source: read from `tool/seed/seed.env` (gitignored) instead of inlining in `seed.js`.
3. Add a `tool/seed/README.md` describing exactly which Firebase project this is safe to run against and the consequences of mis-aiming it.
4. Add a `--dry-run` flag that logs what would be written without actually writing.
5. Upload the actual seed media to `gs://mentor-mind-aa765.firebasestorage.app/seed/*` and widen `storage.rules` to allow `read` (not write) on `seed/{path}` for authed users — otherwise the seeded video/PDF links 404 in-app.

**Phase to address:** Phase 1 (env guard + credentials) is fast and high-value. Phase 4 for the seed-media upload.

---

## 11. Bundle identifier inconsistency (LOW)

**Issue.** Multiple bundle IDs in the iOS project:

- `ios/Runner.xcodeproj/project.pbxproj:507,694,718` — `com.arnobrizwan.mentorminds` (the actual Runner target)
- `ios/Runner.xcodeproj/project.pbxproj:525,544,561` — `com.mentorminds.mentorMinds.RunnerTests` (the test target)
- `BACKEND_SETUP.md:24` — documents `com.mentorminds.mentorMinds` as the expected bundle ID.
- `lib/firebase_options.dart:63,72` — `iosBundleId: 'com.arnobrizwan.mentorminds'`

**Impact.** Documentation contradicts reality. When Android is scaffolded (#1), the contributor following `BACKEND_SETUP.md:24` will use `com.mentorminds.mentorMinds` as the `applicationId`, then `flutterfire configure` will register a second Firebase Android app that doesn't match the iOS bundle, and Google Sign-In / Dynamic Links will silently break across platforms.

**Remediation.** Pick one ID (`com.arnobrizwan.mentorminds` is already deployed). Update `BACKEND_SETUP.md:24`, change the test target ID, and document the chosen ID in `ARCHITECTURE.md`.

**Phase to address:** Phase 0 — fold into platform bring-up.

---

## 12. Fragile / large files (MED)

**Issue.** Six widget files exceed 1000 LOC, well past the comfortable "single-screen" budget. They mix layout, business logic, gesture handling, and state subscriptions.

| File | LOC | Risk |
|---|---:|---|
| `lib/features/profile/profile_screen.dart` | 1605 | Hardest to refactor; tightly couples avatar upload UI to the bug at #5e. |
| `lib/features/tutor/tutor_screen.dart` | 1483 | 15+ `withOpacity` hits (#3); streaming UI + image-attach + voice + markdown all in one widget. |
| `lib/features/dashboard/dashboard_screen.dart` | 1325 | Streak math at `dashboard_viewmodel.dart:551` is untested (#7). |
| `lib/features/rewards/rewards_screen.dart` | 1157 | Leaderboard rendering, susceptible to the points-injection issue at #5a. |
| `lib/features/search/search_screen.dart` | 1150 | 10+ `withOpacity` hits. |
| `lib/features/materials/materials_screen.dart` | 1147 | Material card grid; depends on broken seed URLs (#10). |

**Impact.** Any code review of these files takes 20+ minutes. The mental model needed to safely change one piece is high. They are the natural seams along which the #6 refactor would be most painful.

**Remediation.** Split each screen into:
- `<name>_screen.dart` (Scaffold + AppBar + body composition)
- `<name>/widgets/<part>.dart` (3–6 widget files per screen)
- ViewModel stays in `<name>_viewmodel.dart`

Set a soft ceiling of 400 LOC per file in `analysis_options.yaml` (the `lines_longer_than_80_chars` rule cousin).

**Phase to address:** Phase 2 / "Polish" — opportunistically, ideally fused with #6 if that refactor is accepted.

---

## Summary by phase

| Phase | Concerns | Priority |
|---|---|---|
| **Phase 0 — Immediate** | #4c (service-account leak risk), #1 (platform bring-up), #11 (bundle ID) | HIGH |
| **Phase 1 — Foundation cleanup** | #2 (deps), #3 (lints), #5e (storage rule for avatars), #7 (CI scaffolding), #9 (codegen decision), #10 (seed-script guards) | HIGH/MED |
| **Phase 2 — Layout & polish** | #6 (layout refactor, if accepted), #12 (split large files) | MED |
| **Phase 3 — Backend hardening** | #5a (server-side points), #5b/c (per-user notification state), #8 (Crashlytics + Analytics + App Check + Cloud-Function Gemini proxy) | HIGH |
| **Phase 4 — Polish** | #5d (isApproved semantics), #5f (schema doc drift), #10 (seed media upload) | LOW |

---

*Concerns audit: 2026-05-17*
