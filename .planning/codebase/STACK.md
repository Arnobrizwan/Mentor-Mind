# Technology Stack

**Analysis Date:** 2026-05-17

MentorMinds is a Flutter + Firebase mobile app for O/A Level students in Bangladesh. The client is iOS-only today (no `android/` or `macos/` directories in the repo), with one auxiliary Node.js script (`tool/seed/`) that uses `firebase-admin` to seed Firestore.

## Languages

**Primary:**
- Dart (Flutter app source) — all 30 files under `lib/` (~16,782 lines total)
- Swift (iOS host integration) — `ios/Runner/AppDelegate.swift`, `ios/Runner/SceneDelegate.swift`

**Secondary:**
- Objective-C (auto-generated Flutter plugin registrant) — `ios/Runner/GeneratedPluginRegistrant.{h,m}`
- Ruby (CocoaPods) — `ios/Podfile`
- JavaScript (Node.js seed script) — `tool/seed/seed.js`

## Runtime

**Dart / Flutter SDK constraints (from `pubspec.yaml`):**
- Dart SDK: `>=3.4.0 <4.0.0`

**Resolved SDK requirements (from `pubspec.lock` → `sdks:`):**
- Dart: `>=3.11.0 <4.0.0`
- Flutter: `>=3.38.4`

**Flutter channel pinned (from `.metadata`):**
- `channel: stable`
- `revision: 48c32af0345e9ad5747f78ddce828c7f795f7159`

**Flutter tool version observed at last `pub get` (from `.flutter-plugins-dependencies`):**
- `"version": "3.41.3"`

**Node.js (seed script):**
- `tool/seed/package.json` does not pin a `node` engine. `firebase-admin@^13.0.1` requires Node 18+.

**Package manager:**
- Flutter: pub (lockfile committed → `pubspec.lock`)
- iOS: CocoaPods `1.16.2` (from `ios/Podfile.lock`, lockfile committed)
- Node seed: npm (lockfile committed → `tool/seed/package-lock.json`)

## Frameworks

**Core UI framework:**
- `flutter` (SDK) — Material 3 UI; declarative widgets

**State management:**
- `hooks_riverpod` `^2.5.1` (resolved `2.6.1`) — `ProviderScope`, `StateNotifierProvider`, `ConsumerWidget`
- `flutter_hooks` `^0.20.5` — used alongside hooks_riverpod for stateful widgets
- `riverpod_annotation` `^2.3.5` (resolved `2.6.1`) — code-gen annotations (paired with `riverpod_generator` dev dep)

**Dependency injection:**
- `get_it` `^7.7.0` — service locator
- `injectable` `^2.4.4` (resolved `2.6.0`) — DI code-gen (paired with `injectable_generator` dev dep)
- NOTE: present in `pubspec.yaml` but no `injection.config.dart` is generated under `lib/` yet; ViewModels currently instantiate `FirebaseAuth.instance` / `FirebaseFirestore.instance` directly.

**Routing:**
- `go_router` `^14.2.7` (resolved `14.8.1`) — declarative routing; configured in `lib/core/routes/app_router.dart` and wired via `MaterialApp.router(routerConfig: ...)` in `lib/main.dart`

**Animations:**
- `flutter_animate` `^4.5.0` (resolved `4.5.2`) — declarative entrance/exit animation extensions

## Key Dependencies

**Firebase (BoM-equivalent set):**
- `firebase_core` `^3.6.0` (resolved `3.15.2`) — required initializer; wired in `lib/main.dart` via `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
- `firebase_auth` `^5.3.1` (resolved `5.7.0`) — email/password + Google auth (`lib/features/auth/auth_viewmodel.dart`)
- `cloud_firestore` `^5.4.3` (resolved `5.6.12`) — primary data store; used by every viewmodel that persists state
- `firebase_storage` `^12.3.2` (resolved `12.4.10`) — image uploads (`lib/features/tutor/chat_viewmodel.dart`, `lib/features/profile/profile_viewmodel.dart`)
- `firebase_messaging` `^15.1.3` (resolved `15.2.10`) — SDK installed only; NO Dart import sites (`grep` for `FirebaseMessaging` returns zero hits in `lib/`). Push notifications are not wired yet.

**Auth provider:**
- `google_sign_in` `^6.2.1` (resolved `6.3.0`) — Google OAuth client; iOS configuration check goes through `MethodChannel('mentor_minds/native_config')` defined in `ios/Runner/AppDelegate.swift`

**AI:**
- `google_generative_ai` `^0.4.6` (resolved `0.4.7`) — Gemini SDK; wrapped in `lib/core/services/gemini_service.dart` using model `gemini-1.5-flash`

**UI:**
- `flutter_markdown` `^0.7.3` (resolved `0.7.7+1`) — renders MentorBot AI replies (tutor chat)
- `cached_network_image` `^3.4.1` — material thumbnails, avatars
- `shimmer` `^3.0.0` — loading skeletons

**Utils:**
- `shared_preferences` `^2.3.3` (resolved `2.5.5`) — onboarding selection cache; used in `lib/features/auth/auth_viewmodel.dart` (`onboarding_level`, `onboarding_subjects`)
- `connectivity_plus` `^6.0.5` (resolved `6.1.5`) — network reachability
- `intl` `^0.19.0` — date/number formatting
- `image_picker` `^1.1.2` (resolved `1.2.1`) — camera / photo library for premium-tier image attach in tutor chat

## Dev Dependencies

- `flutter_test` (SDK) — widget/unit test harness
- `build_runner` `^2.4.12` (resolved `2.5.4`) — code-gen driver
- `riverpod_generator` `^2.4.3` (resolved `2.6.5`) — generates Riverpod providers
- `injectable_generator` `^2.6.2` (resolved `2.7.0`) — generates DI graph
- `flutter_lints` `^4.0.0` — lint rule set included via `analysis_options.yaml`

**Tests directory:**
- `test/` exists at repo root but no `*_test.dart` files are present yet (only the auto-created `test/` folder). `flutter test` will be a no-op until tests are added.

## Configuration

**Firebase platform config:**
- `lib/firebase_options.dart` — generated by FlutterFire CLI; defines `DefaultFirebaseOptions.ios` (and a copy under `.android`/`.macos`) for project `mentor-mind-aa765`
- `ios/Runner/GoogleService-Info.plist` — committed iOS Firebase config (project `mentor-mind-aa765`, bundle id `com.arnobrizwan.mentorminds`); IMPORTANT: this file currently has no `CLIENT_ID` / `REVERSED_CLIENT_ID`, so Google Sign-In is not actually wired (see `INTEGRATIONS.md`)

**Build-time secrets:**
- `GEMINI_API_KEY` — passed via `--dart-define=GEMINI_API_KEY=<key>` and read in `lib/core/services/gemini_service.dart` as `String.fromEnvironment('GEMINI_API_KEY')`
- `tool/seed/service-account.json` — local-only Firebase Admin SDK service account (gitignored by `tool/seed/.gitignore`)

**Linting:**
- `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`; no custom rules enabled/disabled yet (template defaults).

**App scaffolding:**
- `lib/main.dart` (46 lines) — initializes Firebase, locks portrait orientation, transparent status bar, wraps the app in `ProviderScope`, uses `MaterialApp.router`.

## iOS Toolchain

**Workspace / project layout:**
- `ios/Runner.xcworkspace` — Xcode workspace (open this, not the project)
- `ios/Runner.xcodeproj` — Xcode project
- `ios/Podfile` — CocoaPods spec; pinned via `ios/Podfile.lock` (CocoaPods `1.16.2`)
- `ios/Runner/Runner.entitlements` — keychain access group `$(AppIdentifierPrefix)com.arnobrizwan.mentorminds`

**Deployment target:**
- Effective minimum: **iOS 13.0** (enforced in `ios/Podfile` `post_install` hook — bumps any pod whose target is below 13.0). The default `platform :ios` line is commented out.

**Xcode 15+ workaround in `ios/Podfile`:**
- `ENABLE_USER_SCRIPT_SANDBOXING = 'NO'` for both Pods and the Runner aggregate — required for gRPC / BoringSSL-GRPC's "Create Symlinks to Header Folders" script (a known Firebase iOS issue).

**iOS native bridge:**
- `ios/Runner/AppDelegate.swift` registers a `FlutterMethodChannel` named `mentor_minds/native_config` exposing `googleSignInStatus`, which the Dart `AuthViewModel` calls before showing the Google sign-in button.

**iOS permissions (from `ios/Runner/Info.plist`):**
- `NSPhotoLibraryUsageDescription` — diagram uploads
- `NSCameraUsageDescription` — capture diagrams for MentorBot

## Node.js Seed Tool

**Location:** `tool/seed/`

**`tool/seed/package.json`:**
- Name: `mentor-minds-seed` (private, v1.0.0)
- Single dependency: `firebase-admin: ^13.0.1`
- Single script: `npm run seed` → `node seed.js`

**`tool/seed/seed.js`:**
- Idempotent seeder that:
  1. Auths with `tool/seed/service-account.json` (preferred) or Application Default Credentials
  2. Creates/updates 4 Firebase Auth users (`student@`, `premium@`, `teacher@`, `admin@mentorminds.test`) with `emailVerified: true`
  3. `.set()`s `/users/{uid}` + `/rewards/{uid}` for each (merge mode)
  4. `.set()`s 15 docs under `/materials` and 5 under `/notifications` by fixed IDs
- Accepts `--project=<id>` CLI override
- Output documented in `DATA.md`

## Platform Requirements

**Development:**
- macOS (Xcode required for iOS builds)
- Flutter stable channel, `>=3.38.4`
- Dart `>=3.11.0`
- Xcode 15+ with iOS 13.0+ simulator
- CocoaPods `1.16.x`
- Node.js 18+ (for `tool/seed`)
- A Gemini API key (https://aistudio.google.com/apikey) passed via `--dart-define=GEMINI_API_KEY=<key>` when running `flutter run`

**Production:**
- iOS app shipped through the App Store (deployment target iOS 13.0)
- Firebase backend hosted in Google Cloud project `mentor-mind-aa765` (rules + indexes deployed via `firebase deploy --only firestore:rules,firestore:indexes,storage`)
- Admin tasks (seeding, role/approval changes) performed manually via Firebase Console or `tool/seed/seed.js`

---

*Stack analysis: 2026-05-17*
