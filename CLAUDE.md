<!-- GSD:project-start source:PROJECT.md -->
## Project

**MentorMinds**

AI-powered tutoring platform for O/A Level students in Bangladesh. Cambridge and Edexcel curricula. Built as a Flutter mobile app (iOS only today) backed by Firebase, with a Gemini-powered AI tutor ("MentorBot") that answers subject questions, analyses uploaded diagrams (Premium), and tracks streaks, points, and badges to drive daily learning habit.

**Core Value:** A student preparing for O/A Levels can ask MentorBot a subject question and get a useful, curriculum-aligned answer in under 10 seconds — every single day, on a free tier that still feels usable.

### Constraints

- **Tech stack**: Flutter 3.41 / Dart 3.11 — locked. Pubspec is set; major framework swap is off the table.
- **State management**: Riverpod 2.x via `hooks_riverpod` — locked. Existing code is consistent; switching to bloc/getx would be a full rewrite.
- **Backend**: Firebase (Auth, Firestore, Storage, Messaging, optionally Functions) — locked. No self-hosted backend.
- **AI provider**: Google Gemini (gemini-1.5-flash) — current choice. Could be reconsidered in v1.1+ but for v1.0 the integration exists.
- **Platform**: iOS-only for v1.0. Android/Web/macOS are explicitly out of scope.
- **Compliance**: Firebase API keys are public client config (acceptable per Firebase docs); real protection lives in `firestore.rules` + `storage.rules` + (future) App Check. Gemini API key must NOT remain in the compiled binary.
- **Team size**: Solo dev. Phase scope must be realistic for one engineer.
- **Brand**: #1A3C8F primary / #00C9A7 accent / #F5A623 gold / Poppins headers / Inter body / JetBrains Mono for AI output. Locked per spec.
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- Dart (Flutter app source) — all 30 files under `lib/` (~16,782 lines total)
- Swift (iOS host integration) — `ios/Runner/AppDelegate.swift`, `ios/Runner/SceneDelegate.swift`
- Objective-C (auto-generated Flutter plugin registrant) — `ios/Runner/GeneratedPluginRegistrant.{h,m}`
- Ruby (CocoaPods) — `ios/Podfile`
- JavaScript (Node.js seed script) — `tool/seed/seed.js`
## Runtime
- Dart SDK: `>=3.4.0 <4.0.0`
- Dart: `>=3.11.0 <4.0.0`
- Flutter: `>=3.38.4`
- `channel: stable`
- `revision: 48c32af0345e9ad5747f78ddce828c7f795f7159`
- `"version": "3.41.3"`
- `tool/seed/package.json` does not pin a `node` engine. `firebase-admin@^13.0.1` requires Node 18+.
- Flutter: pub (lockfile committed → `pubspec.lock`)
- iOS: CocoaPods `1.16.2` (from `ios/Podfile.lock`, lockfile committed)
- Node seed: npm (lockfile committed → `tool/seed/package-lock.json`)
## Frameworks
- `flutter` (SDK) — Material 3 UI; declarative widgets
- `hooks_riverpod` `^2.5.1` (resolved `2.6.1`) — `ProviderScope`, `StateNotifierProvider`, `ConsumerWidget`
- `flutter_hooks` `^0.20.5` — used alongside hooks_riverpod for stateful widgets
- `riverpod_annotation` `^2.3.5` (resolved `2.6.1`) — code-gen annotations (paired with `riverpod_generator` dev dep)
- `get_it` `^7.7.0` — service locator
- `injectable` `^2.4.4` (resolved `2.6.0`) — DI code-gen (paired with `injectable_generator` dev dep)
- NOTE: present in `pubspec.yaml` but no `injection.config.dart` is generated under `lib/` yet; ViewModels currently instantiate `FirebaseAuth.instance` / `FirebaseFirestore.instance` directly.
- `go_router` `^14.2.7` (resolved `14.8.1`) — declarative routing; configured in `lib/core/routes/app_router.dart` and wired via `MaterialApp.router(routerConfig: ...)` in `lib/main.dart`
- `flutter_animate` `^4.5.0` (resolved `4.5.2`) — declarative entrance/exit animation extensions
## Key Dependencies
- `firebase_core` `^3.6.0` (resolved `3.15.2`) — required initializer; wired in `lib/main.dart` via `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
- `firebase_auth` `^5.3.1` (resolved `5.7.0`) — email/password + Google auth (`lib/features/auth/auth_viewmodel.dart`)
- `cloud_firestore` `^5.4.3` (resolved `5.6.12`) — primary data store; used by every viewmodel that persists state
- `firebase_storage` `^12.3.2` (resolved `12.4.10`) — image uploads (`lib/features/tutor/chat_viewmodel.dart`, `lib/features/profile/profile_viewmodel.dart`)
- `firebase_messaging` `^15.1.3` (resolved `15.2.10`) — SDK installed only; NO Dart import sites (`grep` for `FirebaseMessaging` returns zero hits in `lib/`). Push notifications are not wired yet.
- `google_sign_in` `^6.2.1` (resolved `6.3.0`) — Google OAuth client; iOS configuration check goes through `MethodChannel('mentor_minds/native_config')` defined in `ios/Runner/AppDelegate.swift`
- `google_generative_ai` `^0.4.6` (resolved `0.4.7`) — Gemini SDK; wrapped in `lib/core/services/gemini_service.dart` using model `gemini-1.5-flash`
- `flutter_markdown` `^0.7.3` (resolved `0.7.7+1`) — renders MentorBot AI replies (tutor chat)
- `cached_network_image` `^3.4.1` — material thumbnails, avatars
- `shimmer` `^3.0.0` — loading skeletons
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
- `test/` exists at repo root but no `*_test.dart` files are present yet (only the auto-created `test/` folder). `flutter test` will be a no-op until tests are added.
## Configuration
- `lib/firebase_options.dart` — generated by FlutterFire CLI; defines `DefaultFirebaseOptions.ios` (and a copy under `.android`/`.macos`) for project `mentor-mind-aa765`
- `ios/Runner/GoogleService-Info.plist` — committed iOS Firebase config (project `mentor-mind-aa765`, bundle id `com.arnobrizwan.mentorminds`); IMPORTANT: this file currently has no `CLIENT_ID` / `REVERSED_CLIENT_ID`, so Google Sign-In is not actually wired (see `INTEGRATIONS.md`)
- `GEMINI_API_KEY` — passed via `--dart-define=GEMINI_API_KEY=<key>` and read in `lib/core/services/gemini_service.dart` as `String.fromEnvironment('GEMINI_API_KEY')`
- `tool/seed/service-account.json` — local-only Firebase Admin SDK service account (gitignored by `tool/seed/.gitignore`)
- `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`; no custom rules enabled/disabled yet (template defaults).
- `lib/main.dart` (46 lines) — initializes Firebase, locks portrait orientation, transparent status bar, wraps the app in `ProviderScope`, uses `MaterialApp.router`.
## iOS Toolchain
- `ios/Runner.xcworkspace` — Xcode workspace (open this, not the project)
- `ios/Runner.xcodeproj` — Xcode project
- `ios/Podfile` — CocoaPods spec; pinned via `ios/Podfile.lock` (CocoaPods `1.16.2`)
- `ios/Runner/Runner.entitlements` — keychain access group `$(AppIdentifierPrefix)com.arnobrizwan.mentorminds`
- Effective minimum: **iOS 13.0** (enforced in `ios/Podfile` `post_install` hook — bumps any pod whose target is below 13.0). The default `platform :ios` line is commented out.
- `ENABLE_USER_SCRIPT_SANDBOXING = 'NO'` for both Pods and the Runner aggregate — required for gRPC / BoringSSL-GRPC's "Create Symlinks to Header Folders" script (a known Firebase iOS issue).
- `ios/Runner/AppDelegate.swift` registers a `FlutterMethodChannel` named `mentor_minds/native_config` exposing `googleSignInStatus`, which the Dart `AuthViewModel` calls before showing the Google sign-in button.
- `NSPhotoLibraryUsageDescription` — diagram uploads
- `NSCameraUsageDescription` — capture diagrams for MentorBot
## Node.js Seed Tool
- Name: `mentor-minds-seed` (private, v1.0.0)
- Single dependency: `firebase-admin: ^13.0.1`
- Single script: `npm run seed` → `node seed.js`
- Idempotent seeder that:
- Accepts `--project=<id>` CLI override
- Output documented in `DATA.md`
## Platform Requirements
- macOS (Xcode required for iOS builds)
- Flutter stable channel, `>=3.38.4`
- Dart `>=3.11.0`
- Xcode 15+ with iOS 13.0+ simulator
- CocoaPods `1.16.x`
- Node.js 18+ (for `tool/seed`)
- A Gemini API key (https://aistudio.google.com/apikey) passed via `--dart-define=GEMINI_API_KEY=<key>` when running `flutter run`
- iOS app shipped through the App Store (deployment target iOS 13.0)
- Firebase backend hosted in Google Cloud project `mentor-mind-aa765` (rules + indexes deployed via `firebase deploy --only firestore:rules,firestore:indexes,storage`)
- Admin tasks (seeding, role/approval changes) performed manually via Firebase Console or `tool/seed/seed.js`
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Lint Configuration
- 0 errors.
- ~168 info-level warnings.
- Dominant categories:
## File Naming
| Layer | Suffix | Example |
|-------|--------|---------|
| View-models (Riverpod `StateNotifier` + state class + provider) | `_viewmodel.dart` | `lib/features/auth/auth_viewmodel.dart` |
| Screens (route-level widgets) | `_screen.dart` | `lib/features/dashboard/dashboard_screen.dart` |
| Services (singletons / SDK wrappers) | `_service.dart` | `lib/core/services/gemini_service.dart` |
| Theming primitives | `app_<thing>.dart` | `lib/core/constants/app_colors.dart`, `lib/core/theme/app_theme.dart`, `lib/core/constants/app_text_styles.dart` |
| Router | `app_router.dart` | `lib/core/routes/app_router.dart` |
| Utilities | bare noun | `lib/core/utils/validators.dart` |
| Entry point | `main.dart` | `lib/main.dart` |
## Directory Naming
## Class Naming
| Pattern | Examples |
|---------|----------|
| `<Feature>Screen` | `LoginScreen`, `DashboardScreen`, `TutorScreen`, `MaterialsScreen` |
| `<Feature>ViewModel extends StateNotifier<<Feature>State>` | `AuthViewModel`, `DashboardViewModel`, `ChatViewModel`, `NotificationsViewModel` |
| `<Feature>State` (immutable, `const` ctor, `copyWith`) | `AuthState`, `DashboardState`, `ChatState`, `NotificationsState`, `SplashState`, `OnboardingState` |
| `<Feature>Destination` enum for screen-driven routing | `AuthDestination`, `SplashDestination` |
| Domain entities decoded from Firestore | `DashboardUser`, `ProfileUser`, `ChatMessage`, `AppNotification`, `SessionItem`, `MaterialItem`, `BadgeItem`, `RewardsSnapshot` |
| Static-only helper "namespaces" | `abstract final class AppColors`, `abstract final class AppTextStyles`, `abstract final class AppTheme`, `abstract final class Validators`, `abstract final class AppRoutes`, `abstract final class NotificationFilter` |
## Member Naming
- Methods, fields, locals: `lowerCamelCase`.
- Private members: leading underscore (`_auth`, `_firestore`, `_streamUser`, `_mapLoginError`).
- Color constants in `AppColors`: `k`-prefixed `lowerCamelCase` — `kPrimary`, `kAccent`, `kGold`, `kBackground`, `kSurface`, `kTextDark`, `kTextMuted`, `kError`, `kSplashTop`, `kSplashBottom` (see `lib/core/constants/app_colors.dart`). The `k`-prefix convention applies **only** to `AppColors`; `AppTextStyles` uses unprefixed names (`displayLarge`, `bodyMedium`, `monoSmall`).
- Route name constants in `AppRoutes`: unprefixed `lowerCamelCase` strings — `splash`, `dashboard`, `teacherDashboard` (`lib/core/routes/app_router.dart:18-32`).
- Enum values: `lowerCamelCase` (`MessageRole.user`, `AuthErrorField.email`, `SplashDestination.studentDashboard`).
- Top-level constants for Gemini config: leading `_k` and `String.fromEnvironment` for secrets — `_kApiKey`, `_kModelName`, `_kSystemPrompt` in `lib/core/services/gemini_service.dart:13-15`.
- Top-level non-private constants: `lowerCamelCase` with `k` prefix — `kSubjects` (`lib/features/onboarding/onboarding_viewmodel.dart:11`).
- Private top-level helpers used inside a single file: leading underscore (`_subjectColors`, `_colorForSubject`, `_gradientForSubject`, `_stubProgress`, `_mapBadge` in `lib/features/dashboard/dashboard_viewmodel.dart`).
## Provider Naming
| Provider | Type | autoDispose? | File |
|---|---|---|---|
| `appRouterProvider` | `Provider<GoRouter>` | no | `lib/core/routes/app_router.dart:34` |
| `splashViewModelProvider` | `StateNotifierProvider<SplashViewModel, SplashState>` | **no** (intentional — comment at `lib/features/splash/splash_viewmodel.dart:113-117`: "the splash screen uses ref.read (not watch), so an autoDispose provider gets disposed during the await") | `lib/features/splash/splash_viewmodel.dart:117` |
| `onboardingViewModelProvider` | `StateNotifierProvider.autoDispose<OnboardingViewModel, OnboardingState>` | yes | `lib/features/onboarding/onboarding_viewmodel.dart:105` |
| `authViewModelProvider` | `StateNotifierProvider.autoDispose<AuthViewModel, AuthState>` | yes | `lib/features/auth/auth_viewmodel.dart:530` |
| `dashboardViewModelProvider` | `StateNotifierProvider.autoDispose<DashboardViewModel, DashboardState>` | yes | `lib/features/dashboard/dashboard_viewmodel.dart:669` |
| `chatViewModelProvider` | `StateNotifierProvider.autoDispose<ChatViewModel, ChatState>` | yes | `lib/features/tutor/chat_viewmodel.dart:590` |
| `geminiServiceProvider` | `Provider<GeminiService>` (with `ref.onDispose(svc.resetSession)`) | no | `lib/features/tutor/chat_viewmodel.dart:584` |
| `materialsViewModelProvider` | `StateNotifierProvider.autoDispose<...>` | yes | `lib/features/materials/materials_viewmodel.dart:431` |
| `searchViewModelProvider` | `StateNotifierProvider.autoDispose<...>` | yes | `lib/features/search/search_viewmodel.dart:414` |
| `profileViewModelProvider` | `StateNotifierProvider<...>` | no | `lib/features/profile/profile_viewmodel.dart:551` |
| `rewardsViewModelProvider` | `StateNotifierProvider<...>` | no | `lib/features/rewards/rewards_viewmodel.dart:497` |
| `gamificationViewModelProvider` | `StateNotifierProvider<...>` | no | `lib/features/rewards/gamification_viewmodel.dart:572` |
| `notificationsViewModelProvider` | `StateNotifierProvider<...>` | no | `lib/features/notifications/notifications_viewmodel.dart:318` |
| `badgeEarnedEventProvider` | `StreamProvider<BadgeInfo>` | no | `lib/features/rewards/gamification_viewmodel.dart:579` |
## State Management Pattern
- All fields `final`, `const` constructor with defaults.
- `copyWith` accepts explicit `clearX` booleans to set nullable fields back to `null` (because `?? this.x` cannot distinguish "don't touch" from "set to null"). Used as `clearError`, `clearUser`, `clearSession`, `clearImagePreview`, `clearFeedback`.
- UI-derived values exposed as getters on state, not stored — e.g. `firstName`, `greeting`, `subjects`, `badges`, `messagesRemaining`, `hasReachedLimit`, `showLimitWarning` on `ChatState` (`lib/features/tutor/chat_viewmodel.dart:135-142`).
- Streams owned by view-models are stored as `StreamSubscription` fields and cancelled in `dispose()`:
- After `await`, every state mutation is guarded by `if (!mounted) return;` (the `StateNotifier.mounted` flag), e.g. `dashboard_viewmodel.dart:554, 609`; `chat_viewmodel.dart:439, 555`.
## Widget Composition Style
| Style | Count | Used by |
|---|---|---|
| `ConsumerWidget` | 11 | `MentorMindsApp`, `RewardsScreen`, `_BadgesTab`, `_LeaderboardTab`, `ProfileScreen`, `_ProfileBody`, `_Header`, `_SettingsList`, `_LevelSheet`, `NotificationsScreen`, `_Header` (notifications), `_NotificationsList`, `_WelcomePage`, `_SelectLevelPage`, `_SelectSubjectsPage` |
| `ConsumerStatefulWidget` | 11 | `SplashScreen`, `LoginScreen`, `RegisterScreen`, `MaterialsScreen`, `DashboardScreen`, `SearchScreen`, `_EditProfileSheet`, `_SubjectsSheet`, `_ChangePasswordDialog`, `_DeleteAccountDialog`, `OnboardingScreen`, `TutorScreen` |
| `HookConsumerWidget` | **0** | — |
## Riverpod Import Convention
| Layer | Import | Why |
|---|---|---|
| Screens / widgets / router | `import 'package:hooks_riverpod/hooks_riverpod.dart';` | The host import — re-exports everything from `flutter_riverpod` plus hook-aware variants. |
| View-models / non-widget files | `import 'package:flutter_riverpod/flutter_riverpod.dart';` | Pure state plumbing, no widget concerns. |
| `lib/core/routes/app_router.dart` | `import 'package:flutter_riverpod/flutter_riverpod.dart';` | Exception — defines `appRouterProvider` and imports widgets. |
## Color & Theme Usage
- `AppColors.kXxx` references: **402** across feature files.
- `AppTextStyles.xxx` references: **179**.
- `Theme.of(context)` references: **1** (`lib/features/tutor/tutor_screen.dart:990`, only to seed `MarkdownStyleSheet.fromTheme`).
## Import Ordering
## Error Handling
## Logging
## Comments
- **Banner dividers** between major sections of a file (see State Management Pattern).
- **Method-level explanations** as a short paragraph above the method, plain `//` (not `///`). Example — `notifications_viewmodel.dart:185-188`:
- **Inline rationale** for surprising decisions. The single best example is the comment that explains why `splashViewModelProvider` is NOT `.autoDispose` (`splash_viewmodel.dart:113-117`).
- **Stub markers** for placeholder logic — e.g. `// Demo/stub progress per subject — deterministic variation until real per-subject progress tracking lands.` (`dashboard_viewmodel.dart:285-286`).
- **`///` doc comments** are used sparingly — only `Validators` and a handful of `profile_viewmodel` methods (e.g. "Returns null on success, user-facing error string otherwise."). View-models generally rely on banner comments and method names instead of dartdoc.
## Function & Method Design
- **Async-by-default** for any data path. Public actions on view-models return `Future<T?>` where `null` means "we set state.error, caller should bail" — e.g. `AuthViewModel.loginWithEmail` returns `Future<AuthDestination?>`.
- **Records** (Dart 3) used for compound returns when adding a class would be overkill: `Future<(String, List<String>)> _readOnboardingSelection()` at `lib/features/auth/auth_viewmodel.dart:362`.
- **Switch expressions** (Dart 3) preferred over `if/else` chains for code-to-message mapping (see `_mapLoginError`) and enum dispatch (`_navigateTo(AuthDestination destination)` in `login_screen.dart:69-78`).
- **Named parameters with `required`** for any method taking >2 args or any combination of booleans/nullable strings — see `registerWithEmail({required String name, required String email, ...})`.
- **`unawaited(...)`** from `dart:async` is used to mark intentional fire-and-forget side-effects so the analyzer doesn't warn. Examples: `unawaited(_saveSession())`, `unawaited(_incrementUsage())`, `unawaited(_awardPoints('complete_session'))` (`chat_viewmodel.dart:372-376`); `unawaited(_fetchStreak(uid))`, `unawaited(_awardDailyLoginIfNeeded(uid))` (`dashboard_viewmodel.dart:382-383`).
- **`growable: false`** on `.toList()` whenever the resulting list will never be mutated — common idiom in this codebase, see `dashboard_viewmodel.dart:82, 86, 246, 250` and many others.
## Module Design
- **No barrel files.** Every consumer imports the exact file it needs (`import 'auth_viewmodel.dart';`).
- **One feature = one directory** under `lib/features/<feature>/`. A feature is at minimum `<feature>_screen.dart` + `<feature>_viewmodel.dart`. Sub-widgets stay private (`_Xxx`) in the screen file until reuse is needed; nothing has crossed into `lib/shared/widgets/` yet.
- **Shared cross-feature primitives** belong in `lib/core/` and are namespaced via `abstract final class` (`AppColors`, `AppTextStyles`, `AppTheme`, `Validators`, `AppRoutes`).
- **Services** (`lib/core/services/gemini_service.dart`) are plain Dart classes exposed via a `Provider<...>` declared in the consuming view-model file (`geminiServiceProvider` lives next to `chatViewModelProvider`, not in the service file itself).
## Where Conventions Differ From `flutter_lints` Defaults
- `withOpacity` is currently allowed at lint level (info, not error) and the codebase is not yet migrated. New code MUST use `withValues(alpha: ...)`.
- `depend_on_referenced_packages` is currently breached project-wide (transitive `flutter_riverpod`). New view-models inherit this until `pubspec.yaml` is fixed.
- `prefer_const_constructors` fires on a handful of screens — add `const` to widget instantiations where the analyzer suggests it.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## System Overview
```text
```
## Component Responsibilities
| Component | Responsibility | File |
|-----------|----------------|------|
| App bootstrap | Firebase init, orientation lock, status bar, `ProviderScope` | `lib/main.dart` |
| Root widget | Mounts `MaterialApp.router` with the GoRouter from Riverpod | `lib/main.dart` (`MentorMindsApp`) |
| Router | Single `Provider<GoRouter>` listing all 13 routes by name | `lib/core/routes/app_router.dart` |
| Theme | Material 3 light theme, font + color tokens | `lib/core/theme/app_theme.dart` |
| Color tokens | Brand palette (primary, accent, gold, splash) | `lib/core/constants/app_colors.dart` |
| Typography tokens | Display / heading / body / mono `TextStyle` set | `lib/core/constants/app_text_styles.dart` |
| Validators | Pure-Dart form rule helpers | `lib/core/utils/validators.dart` |
| AI service | Streaming text + one-shot multimodal Gemini calls | `lib/core/services/gemini_service.dart` |
| Splash flow | Decides first destination from auth + onboarding state | `lib/features/splash/splash_viewmodel.dart` |
| Auth flow | Email/Google sign-in, registration, role-routing, password reset | `lib/features/auth/auth_viewmodel.dart` |
| Dashboard streams | User doc + sessions + materials + notifications + streak + daily reward | `lib/features/dashboard/dashboard_viewmodel.dart` |
| Tutor chat | Sessioned chat over Gemini, rate limiting, persistence, points | `lib/features/tutor/chat_viewmodel.dart` |
| Rewards | Points + badge ledger from `/rewards/{uid}` + `/users/{uid}` | `lib/features/rewards/rewards_viewmodel.dart` |
| Gamification | Cross-feature badge-earned event stream | `lib/features/rewards/gamification_viewmodel.dart` |
| Materials | Paginated + filterable browse over `/materials` | `lib/features/materials/materials_viewmodel.dart` |
| Search | Debounced search + recent-search history | `lib/features/search/search_viewmodel.dart` |
| Profile | Profile read/update, avatar upload, reauth, delete account | `lib/features/profile/profile_viewmodel.dart` |
| Notifications | Per-role notifications stream + filter tabs | `lib/features/notifications/notifications_viewmodel.dart` |
| Onboarding | Level + subject pick, persists to `SharedPreferences`, hands off to register | `lib/features/onboarding/onboarding_viewmodel.dart` |
## Pattern Overview
- One folder per feature under `lib/features/<name>/`, each containing exactly one `*_screen.dart` (View) and one `*_viewmodel.dart` (ViewModel) — with `tutor/` and `rewards/` adding a second viewmodel (`chat_viewmodel.dart`, `gamification_viewmodel.dart`).
- View widgets are `ConsumerWidget` or `ConsumerStatefulWidget` (from `hooks_riverpod`) and read viewmodels via top-level `StateNotifierProvider` globals named `<feature>ViewModelProvider`.
- State classes are plain immutable Dart classes (no Freezed) with hand-rolled `copyWith(... bool clearError = false)` flags for nullable fields.
- Models live **inline** at the top of each ViewModel file (e.g. `DashboardUser`, `SessionItem`, `MaterialItem`, `ChatMessage` in their respective `*_viewmodel.dart`). There is **no** dedicated `models/` directory.
- `hooks_riverpod` is the import used by views; `flutter_riverpod` is used inside viewmodel files. `flutter_hooks` and `riverpod_annotation` are pubspec-declared but **not used in source** (no `@riverpod`, no `part '*.g.dart'`, no codegen).
- `get_it` and `injectable` are pubspec-declared but **not wired** — DI is done via Riverpod providers only.
## Layers
- Purpose: Render screens and translate user input into ViewModel calls.
- Location: `lib/features/<name>/*_screen.dart`
- Contains: `ConsumerStatefulWidget` / `ConsumerWidget` shells plus many private `_Foo extends StatelessWidget` sub-widgets defined in the same file.
- Depends on: `core/constants/`, `core/theme/`, `core/routes/app_router.dart` (for `AppRoutes` name constants), and the feature's own `*_viewmodel.dart`.
- Used by: GoRouter route builders in `lib/core/routes/app_router.dart`.
- Purpose: Own all mutable UI state, mediate between the View and Firebase / Gemini.
- Location: `lib/features/<name>/*_viewmodel.dart`
- Contains: `class FooState`, `class FooViewModel extends StateNotifier<FooState>`, inline data models, and a bottom-of-file `final fooViewModelProvider = StateNotifierProvider...`.
- Depends on: `cloud_firestore`, `firebase_auth`, `firebase_storage`, `google_sign_in`, `shared_preferences`, `core/services/gemini_service.dart`, `core/utils/validators.dart`.
- Used by: matching `*_screen.dart` via `ref.watch / ref.read / ref.listen / ref.listenManual`.
- Purpose: Wrap non-Firebase SDKs and shared cross-feature logic.
- Location: `lib/core/services/`
- Contains: Currently only `gemini_service.dart`. Firebase SDKs are **not** wrapped — viewmodels call `FirebaseFirestore.instance` / `FirebaseAuth.instance` directly.
- Depends on: `google_generative_ai`.
- Used by: `chat_viewmodel.dart` via the `geminiServiceProvider` defined inline in that file.
- Purpose: Routing, theming, constants, pure helpers.
- Location: `lib/core/routes/`, `lib/core/theme/`, `lib/core/constants/`, `lib/core/utils/`.
- Contains: `app_router.dart`, `app_theme.dart`, `app_colors.dart`, `app_text_styles.dart`, `validators.dart`.
- Depends on: Flutter framework only (no Firebase).
- Used by: every feature.
- Location: `lib/shared/widgets/`
- Status: **Empty directory.** No cross-feature widget library exists yet — every screen reimplements its own pills, cards, shimmers, and headers as private `_Foo` widgets inside its `*_screen.dart`.
## Data Flow
### Primary Request Path (Tutor sending a chat message)
### Boot & Role Routing
### Dashboard (multi-stream)
- All state lives in `StateNotifier<TState>` instances behind globally-declared `StateNotifierProvider` variables at the bottom of each viewmodel file.
- No `Notifier` / `AsyncNotifier` (Riverpod 2.x new-API) or `riverpod_generator` codegen is used despite the deps being declared.
- Cross-feature reactivity uses providers that watch other providers (e.g. `badgeEarnedEventProvider` in `gamification_viewmodel.dart:579` is a `StreamProvider` that watches `gamificationViewModelProvider.notifier.badgeEarnedStream`).
## Key Abstractions
- Purpose: Self-contained MVVM slice (screen + viewmodel + inline models).
- Examples: `lib/features/dashboard/`, `lib/features/tutor/`, `lib/features/profile/`.
- Pattern: Folder name == feature; files inside follow `<feature>_screen.dart` + `<feature>_viewmodel.dart`. Some features add specialized siblings (`chat_viewmodel.dart`, `gamification_viewmodel.dart`).
- Purpose: Plain Dart class (no codegen) with `factory Foo.fromDoc(...)` / `Map<String, dynamic> toMap()` to translate Firestore docs.
- Examples: `DashboardUser`, `SessionItem`, `MaterialItem`, `BadgeItem` in `lib/features/dashboard/dashboard_viewmodel.dart`; `ChatMessage` in `lib/features/tutor/chat_viewmodel.dart:20`.
- Pattern: Defined inside the consuming viewmodel file; not exported elsewhere.
- Purpose: Centralize navigation tokens so screens never type raw paths.
- File: `lib/core/routes/app_router.dart` (`abstract final class AppRoutes`).
- Pattern: `context.goNamed(AppRoutes.tutor)` (the splash screen breaks this once with `context.go('/dashboard/teacher')` — see `splash_screen.dart:78`).
- Purpose: Discoverable global provider per feature.
- Convention: `final <feature>ViewModelProvider = StateNotifierProvider<...>.autoDispose(...)`.
- Exceptions (`NOT autoDispose`): `splashViewModelProvider`, `profileViewModelProvider`, `rewardsViewModelProvider`, `gamificationViewModelProvider`, `notificationsViewModelProvider` — each documented with a comment explaining why disposal would race an in-flight `await`.
## Entry Points
- Location: `lib/main.dart:10` (`void main() async`).
- Triggers: `flutter run` and platform launchers.
- Responsibilities: `WidgetsFlutterBinding.ensureInitialized`, portrait lock, transparent status bar, `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`, then `runApp(const ProviderScope(child: MentorMindsApp()))`.
- Location: `lib/main.dart:33` (`class MentorMindsApp extends ConsumerWidget`).
- Pattern:
- Location: `lib/core/routes/app_router.dart:34`.
- Definition:
- Routes (path → name → screen):
- Guards / redirects: **None.** There is no `redirect:` callback and no `refreshListenable`. Role gating is enforced imperatively by `SplashViewModel` and `AuthViewModel` returning a `*Destination` enum that the screen converts into `context.goNamed(...)`. `LoginScreen`, `RegisterScreen`, and every protected screen are reachable by URL without any router-level auth check.
- The `_PlaceholderScreen` (`app_router.dart:108`) is a private fallback used for `teacherDashboard` and `admin` until those screens are built.
## Theme System
| Token | Hex | Role |
|-------|-----|------|
| `kPrimary` | `#1A3C8F` | Deep indigo — buttons, focused borders, brand |
| `kAccent` | `#00C9A7` | Teal — secondary, splash glow, badges |
| `kGold` | `#F5A623` | Streak / achievement highlight |
| `kBackground` | `#F4F6FB` | Scaffold background |
| `kSurface` | `#FFFFFF` | Cards, app bar, input fill |
| `kTextDark` | `#1C1F2E` | Primary text |
| `kTextMuted` | `#6B7280` | Secondary text, hints |
| `kError` | `#EF4444` | Errors, error border |
| `kSplashTop` | `#1A3C8F` | Splash gradient top |
| `kSplashBottom` | `#0D2660` | Splash gradient bottom |
- `'Poppins'` — display / headings (`displayLarge` 32 / 700 down to `headingSmall` 16 / 600).
- `'Inter'` — body and labels (`bodyLarge` 16 / 400, `bodyMedium` 14, `bodySmall` 12; `labelLarge/Medium/Small` 500-weight).
- `'JetBrainsMono'` — AI output / code blocks (`monoBody` 13, `monoSmall` 11).
## Entry Point Flow (end-to-end)
```
```
## Architectural Constraints
- **Threading:** Standard Flutter — single UI isolate, async work via `Future` / `Stream`. No `compute()` / isolates anywhere.
- **Global state:** All Riverpod providers are top-level globals (one per file). `GeminiService` keeps an in-memory `_history` transcript that survives across `sendMessage` calls within one `geminiServiceProvider` lifetime; `chatViewModelProvider.autoDispose` drops both when no widget watches.
- **`autoDispose` discipline:** Long-running viewmodels that perform `await`s and write state afterwards (`SplashViewModel`, `ProfileViewModel`, `RewardsViewModel`, `NotificationsViewModel`, `GamificationViewModel`) are deliberately **not** `autoDispose` to avoid "used after dispose" exceptions during pending Futures — see the comment block at `lib/features/splash/splash_viewmodel.dart:113`.
- **Stream subscriptions:** Every viewmodel that opens Firestore streams cancels them in `dispose()` (`dashboard_viewmodel.dart:656`, `notifications_viewmodel.dart:308`, etc.).
- **`mounted` checks:** ViewModels guard post-await state writes with `if (!mounted) return;` before mutating `state`.
- **No DI container:** `get_it` / `injectable` are declared but unused. ViewModels new up `FirebaseAuth.instance` / `FirebaseFirestore.instance` themselves, which means they are **not unit-testable without Firebase emulator** unless refactored.
- **Circular imports:** None observed. The dependency direction is strictly `main` → `core/routes` → `features/*/screen` → `features/*/viewmodel` → `core/services` & `core/utils`. Viewmodels never import other features.
## Anti-Patterns
### Inline data models inside ViewModels
### Direct Firebase singleton access from ViewModels
### Mixing `context.goNamed` and raw `context.go`
### Provider declared but file ignores it
### Unauthenticated routes reachable by URL
## Error Handling
- Firebase error-code switches: `AuthViewModel._mapLoginError` / `_mapRegisterError` / `_mapResetError` / `_mapVerificationError` (`auth_viewmodel.dart:487-523`) collapse `FirebaseAuthException.code` into copy.
- Non-fatal stream errors (recent sessions, materials, notifications) are swallowed with a `// Non-fatal` comment so a single broken stream doesn't blank the dashboard (`dashboard_viewmodel.dart:458, 491, 511`).
- "Roll back on failure": `GeminiService.sendMessage` removes the just-appended user `Content` from `_history` on exception so retries aren't duplicated (`gemini_service.dart:87-91`).
- `copyWith(clearError: true)` flags everywhere — pattern to reset nullable `error` / `user` / `sessionId` / `imagePreview` slots, since plain `null` in `copyWith` means "no change".
## Cross-Cutting Concerns
- Firestore collections: `users`, `users/{uid}/usage/{yyyy-MM-dd}`, `rewards`, `sessions`, `materials`, `notifications`.
- Firebase Storage path: `uploads/{uid}/{ts}_{rand}.jpg` for chat image attachments (`chat_viewmodel.dart:483-490`).
- `SharedPreferences` keys: `onboarding_complete` (bool), `onboarding_level` (string), `onboarding_subjects` (JSON string array) — written by onboarding, read by splash + register.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
