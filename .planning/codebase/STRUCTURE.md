# Codebase Structure

**Analysis Date:** 2026-05-17

## Directory Layout

```
Mentor-Mind/
├── lib/                                  # All Dart source
│   ├── main.dart                         # App entry: Firebase init + ProviderScope + MentorMindsApp
│   ├── firebase_options.dart             # FlutterFire CLI-generated platform config (do not edit by hand)
│   ├── core/                             # Cross-feature foundation (no Firebase except via services)
│   │   ├── constants/
│   │   │   ├── app_colors.dart           # Brand color tokens (AppColors.kPrimary, kAccent, ...)
│   │   │   └── app_text_styles.dart      # Display / heading / body / mono TextStyle set
│   │   ├── routes/
│   │   │   └── app_router.dart           # AppRoutes name constants + appRouterProvider (GoRouter)
│   │   ├── services/
│   │   │   └── gemini_service.dart       # Streaming + multimodal Gemini 1.5 Flash wrapper
│   │   ├── theme/
│   │   │   └── app_theme.dart            # AppTheme.light — Material 3 ThemeData
│   │   └── utils/
│   │       └── validators.dart           # Pure form validators (name/email/password/role)
│   ├── features/                         # One folder per feature (MVVM slice)
│   │   ├── auth/
│   │   │   ├── auth_viewmodel.dart       # AuthViewModel + AuthState + AuthDestination enum
│   │   │   ├── login_screen.dart         # Email / Google sign-in + password reset
│   │   │   └── register_screen.dart      # Email registration + role pick + terms
│   │   ├── dashboard/
│   │   │   ├── dashboard_viewmodel.dart  # 4 Firestore streams + streak + daily reward
│   │   │   └── dashboard_screen.dart     # Home tab with sub-nav (Home/Tutor/Materials/Rewards/Profile)
│   │   ├── materials/
│   │   │   ├── materials_viewmodel.dart  # Paginated browse over /materials
│   │   │   └── materials_screen.dart     # Search field, level pills, filter sheet, grid
│   │   ├── notifications/
│   │   │   ├── notifications_viewmodel.dart  # Per-role notifications stream + tab filtering
│   │   │   └── notifications_screen.dart # All / Announcements / Achievements / Reminders tabs
│   │   ├── onboarding/
│   │   │   ├── onboarding_viewmodel.dart # Level + subject pick, writes SharedPreferences
│   │   │   └── onboarding_screen.dart    # Multi-page intro flow
│   │   ├── profile/
│   │   │   ├── profile_viewmodel.dart    # Profile read/update, avatar upload, reauth, delete
│   │   │   └── profile_screen.dart       # Profile + stats + edit + danger zone
│   │   ├── rewards/
│   │   │   ├── gamification_viewmodel.dart # Cross-feature badge-earned event stream
│   │   │   ├── rewards_viewmodel.dart    # Points + badge ledger from /rewards/{uid}
│   │   │   └── rewards_screen.dart       # Points header + Badges / Leaderboard / History tabs
│   │   ├── search/
│   │   │   ├── search_viewmodel.dart     # Debounced search + recent-search history + highlightMatch
│   │   │   └── search_screen.dart        # Search bar + result list
│   │   ├── splash/
│   │   │   ├── splash_viewmodel.dart     # Resolves first destination from auth + onboarding state
│   │   │   └── splash_screen.dart        # Animated gradient + lettermark + dots
│   │   └── tutor/
│   │       ├── chat_viewmodel.dart       # ChatViewModel + ChatMessage + geminiServiceProvider
│   │       └── tutor_screen.dart         # Chat UI + subject picker + level toggle + image attach
│   └── shared/
│       └── widgets/                      # EMPTY — no shared widget library exists yet
├── test/
│   └── widget_test.dart                  # Placeholder: `expect(1 + 1, 2);` — no real tests
├── tool/
│   └── seed/                             # Node script that seeds /materials and /notifications
│       ├── seed.js                       # Idempotent Admin-SDK seed
│       ├── package.json                  # Node deps for the seed tool
│       ├── package-lock.json
│       ├── README.md                     # Seed setup + run instructions
│       ├── service-account.json          # GITIGNORED Firebase Admin key (do NOT commit)
│       └── node_modules/                 # gitignored, installed via `npm install`
├── assets/
│   ├── images/                           # EMPTY — declared in pubspec.yaml as `- assets/images/`
│   └── fonts/                            # EMPTY — Poppins/Inter/JetBrainsMono referenced in code but no .ttf shipped
├── ios/                                  # Combined iOS + Android native shell (Android nested under ios/android/)
│   ├── Runner/                           # iOS Swift app
│   │   ├── AppDelegate.swift
│   │   ├── SceneDelegate.swift
│   │   ├── Info.plist
│   │   ├── Runner.entitlements
│   │   ├── Runner-Bridging-Header.h
│   │   ├── GoogleService-Info.plist      # Firebase iOS config
│   │   ├── GeneratedPluginRegistrant.{h,m}
│   │   ├── Assets.xcassets/              # iOS app icon + launch image
│   │   └── Base.lproj/                   # iOS storyboards
│   ├── Runner.xcodeproj/                 # Xcode project
│   ├── Runner.xcworkspace/               # Workspace (open this when working on iOS)
│   ├── RunnerTests/                      # iOS unit-test target
│   ├── Flutter/                          # Flutter iOS plugin config
│   ├── Pods/                             # CocoaPods install output (gitignored)
│   ├── .symlinks/                        # Flutter plugin symlinks (gitignored)
│   └── android/                          # NOTE: Android project is nested INSIDE ios/ in this repo
│       ├── app/
│       │   └── src/main/
│       │       ├── AndroidManifest.xml
│       │       ├── java/io/flutter/      # Java shim
│       │       ├── kotlin/com/mentorminds/mentor_minds/  # MainActivity.kt
│       │       └── res/                  # Mipmap icons, drawables, values
│       └── gradle/wrapper/
├── pubspec.yaml                          # Dart deps + asset declarations
├── pubspec.lock                          # Pinned dep versions
├── analysis_options.yaml                 # Lints (flutter_lints recommended set)
├── firebase.json                         # Firebase project config (Firestore rules + indexes paths)
├── firestore.rules                       # Security rules for users/rewards/sessions/materials/notifications
├── firestore.indexes.json                # Composite indexes for dashboard / materials queries
├── storage.rules                         # Cloud Storage rules for uploads/{uid}/
├── BACKEND_SETUP.md                      # Backend bring-up notes
├── DATA.md                               # Firestore schema documentation
├── README.md                             # Project intro
├── mentor_minds.iml                      # IntelliJ module file
├── build/                                # Flutter build output (gitignored)
└── .dart_tool/                           # Dart tooling cache (gitignored)
```

## Directory Purposes

**`lib/`:**
- Purpose: All Flutter / Dart source code.
- Contains: `main.dart`, `firebase_options.dart`, and the `core/` + `features/` + `shared/` trees.
- Key files: `main.dart` (entry), `firebase_options.dart` (auto-generated, do not edit).

**`lib/core/`:**
- Purpose: Cross-feature foundation that no feature owns alone.
- Contains: routing, theming, color/typography tokens, pure utility helpers, and SDK service wrappers.
- Constraint: Code under `core/` MUST NOT import anything from `lib/features/`. The dependency arrow always points `features → core`.

**`lib/core/constants/`:**
- Purpose: Compile-time visual tokens. No logic.
- Key files: `app_colors.dart`, `app_text_styles.dart`.

**`lib/core/routes/`:**
- Purpose: Navigation surface — route name constants and the GoRouter provider.
- Key file: `app_router.dart`.

**`lib/core/services/`:**
- Purpose: Wrappers around non-Firebase SDKs and any reusable async service.
- Key file: `gemini_service.dart`. Firebase SDKs are currently NOT wrapped here — viewmodels call them directly.

**`lib/core/theme/`:**
- Purpose: `ThemeData` definitions consumed by `MaterialApp.router`.
- Key file: `app_theme.dart`.

**`lib/core/utils/`:**
- Purpose: Pure-Dart helpers — no Flutter, no Firebase, no I/O.
- Key file: `validators.dart`.

**`lib/features/<name>/`:**
- Purpose: Self-contained MVVM slice for one product area.
- Required files: `<name>_screen.dart` (View) and `<name>_viewmodel.dart` (State + StateNotifier + Provider).
- Optional files: a second viewmodel for a specialized sub-flow (`chat_viewmodel.dart` inside `tutor/`, `gamification_viewmodel.dart` inside `rewards/`).
- Constraint: A feature MUST NOT import another feature's files. Cross-feature reuse goes through `core/` or `shared/`.

**`lib/shared/widgets/`:**
- Purpose: (Intended) reusable UI widgets used by multiple features.
- Status: **Empty.** Every screen reimplements its own pills, cards, headers, and shimmers as private `_Foo` classes inside its `*_screen.dart`. First time you need a widget in two features, lift it here.

**`test/`:**
- Purpose: Dart unit/widget tests.
- Status: Contains only a placeholder (`expect(1 + 1, 2);`). No real coverage yet.

**`tool/seed/`:**
- Purpose: Node.js Firebase Admin script that idempotently seeds `/materials` and `/notifications` so the app has demo data on a fresh project.
- Run from `tool/seed/` with `node seed.js` after `npm install`.
- `service-account.json` is gitignored — drop your Firebase service account key there.

**`assets/`:**
- Purpose: Bundled images and fonts.
- Status: Both `images/` and `fonts/` are empty. `pubspec.yaml` declares `- assets/images/` but no `fonts:` block, while `app_text_styles.dart` references font family names (`Poppins`, `Inter`, `JetBrainsMono`) that resolve to system fallbacks at runtime.

**`ios/`:**
- Purpose: Native iOS shell (Swift, CocoaPods).
- Key files: `Runner/AppDelegate.swift`, `Runner/Info.plist`, `Runner/GoogleService-Info.plist`, `Runner/Runner.entitlements`.

**`ios/android/`:**
- Purpose: Android shell. **Note:** Unusually nested *inside* `ios/` rather than at the repo root.
- Key files: `app/src/main/AndroidManifest.xml`, `app/src/main/kotlin/com/mentorminds/mentor_minds/MainActivity.kt`.

**Root config files:**
- `pubspec.yaml` / `pubspec.lock` — Dart dependencies.
- `analysis_options.yaml` — lints (`include: package:flutter_lints/flutter.yaml`).
- `firebase.json` — Firebase CLI project config.
- `firestore.rules` / `firestore.indexes.json` / `storage.rules` — backend security & indexes (deployed via `firebase deploy`).
- `BACKEND_SETUP.md`, `DATA.md`, `README.md` — human-facing docs.

## Key File Locations

**Entry Points:**
- `lib/main.dart`: `main()` initializes Firebase, sets orientation lock, mounts `ProviderScope(MentorMindsApp())`.
- `lib/main.dart` (`MentorMindsApp`): Root `ConsumerWidget` that builds `MaterialApp.router` with `appRouterProvider`.

**Configuration:**
- `lib/firebase_options.dart`: Generated per-platform Firebase config — regenerate via `flutterfire configure`, never hand-edit.
- `firebase.json`, `firestore.rules`, `firestore.indexes.json`, `storage.rules`: Backend config at repo root.
- `pubspec.yaml`: Dart deps and asset paths.

**Core Logic:**
- `lib/core/routes/app_router.dart`: All routes + `AppRoutes` name constants + the `appRouterProvider`.
- `lib/core/services/gemini_service.dart`: AI service — call via `chatViewModelProvider` only.
- `lib/core/theme/app_theme.dart`: The one and only `ThemeData`.
- `lib/core/constants/app_colors.dart`, `lib/core/constants/app_text_styles.dart`: Visual tokens.
- `lib/core/utils/validators.dart`: Pure form rules — also used by `AuthViewModel` registration flow.

**Feature ViewModels** (state + StateNotifier + Provider):
- `lib/features/auth/auth_viewmodel.dart`
- `lib/features/dashboard/dashboard_viewmodel.dart`
- `lib/features/materials/materials_viewmodel.dart`
- `lib/features/notifications/notifications_viewmodel.dart`
- `lib/features/onboarding/onboarding_viewmodel.dart`
- `lib/features/profile/profile_viewmodel.dart`
- `lib/features/rewards/rewards_viewmodel.dart`
- `lib/features/rewards/gamification_viewmodel.dart`
- `lib/features/search/search_viewmodel.dart`
- `lib/features/splash/splash_viewmodel.dart`
- `lib/features/tutor/chat_viewmodel.dart`

**Feature Screens** (Views):
- `lib/features/auth/login_screen.dart`, `lib/features/auth/register_screen.dart`
- `lib/features/dashboard/dashboard_screen.dart`
- `lib/features/materials/materials_screen.dart`
- `lib/features/notifications/notifications_screen.dart`
- `lib/features/onboarding/onboarding_screen.dart`
- `lib/features/profile/profile_screen.dart`
- `lib/features/rewards/rewards_screen.dart`
- `lib/features/search/search_screen.dart`
- `lib/features/splash/splash_screen.dart`
- `lib/features/tutor/tutor_screen.dart`

**Testing:**
- `test/widget_test.dart`: Single placeholder test. No real ViewModel/Widget coverage.

**Native:**
- `ios/Runner/AppDelegate.swift`: iOS Flutter entry, registers the `mentor_minds/native_config` MethodChannel referenced from `auth_viewmodel.dart:66`.
- `ios/android/app/src/main/kotlin/com/mentorminds/mentor_minds/MainActivity.kt`: Android Flutter entry.

## Naming Conventions

**Files:** `snake_case.dart`
- ViewModel files: `<feature>_viewmodel.dart` (e.g. `dashboard_viewmodel.dart`). Specialized sub-viewmodels use a descriptive name (`chat_viewmodel.dart`, `gamification_viewmodel.dart`).
- Screen files: `<feature>_screen.dart` (e.g. `tutor_screen.dart`, `login_screen.dart`). Even auth has two: `login_screen.dart` and `register_screen.dart`.
- Service files: `<name>_service.dart` (e.g. `gemini_service.dart`).
- Token / utility files: `app_<thing>.dart` for global tokens (`app_colors.dart`, `app_text_styles.dart`, `app_theme.dart`, `app_router.dart`) and plain `<noun>.dart` for utilities (`validators.dart`).

**Directories:** `snake_case` lowercase, singular for feature folders (`tutor`, `profile`, `dashboard`) and plural for collections of types (`features`, `widgets`, `routes`, `services`, `constants`, `utils`).

**Classes:** `PascalCase`.
- Widgets: `<Feature>Screen` (e.g. `DashboardScreen`), private sub-widgets prefixed with `_` (`_LogoSection`, `_RoleSelector`, `_LeaderboardRow`).
- ViewModels: `<Feature>ViewModel extends StateNotifier<<Feature>State>` (e.g. `class DashboardViewModel extends StateNotifier<DashboardState>`).
- State classes: `<Feature>State` — immutable, with hand-rolled `copyWith` and `clear<X>` flags for nullable resets.
- Models inside viewmodels: `<EntityName>` (e.g. `DashboardUser`, `SessionItem`, `MaterialItem`, `ChatMessage`).
- Enums: `PascalCase`; route names use `abstract final class AppRoutes` (not an enum) holding `static const String`s.

**Providers:** lowerCamelCase, top-level `final`.
- ViewModel providers: `<feature>ViewModelProvider` (e.g. `dashboardViewModelProvider`, `chatViewModelProvider`).
- Service providers: `<service>Provider` (e.g. `geminiServiceProvider` in `chat_viewmodel.dart:584`).
- Other providers: descriptive (`appRouterProvider`, `badgeEarnedEventProvider`).

**Private helpers / constants:** prefix `_` for private (e.g. `_kApiKey`, `_kModelName`, `_kSystemPrompt`, `_subjectColors`) and `k` for compile-time visual constants (e.g. `AppColors.kPrimary`).

## Where to Add New Code

**New feature (e.g. "quizzes"):**
1. Create `lib/features/quizzes/`.
2. Add `lib/features/quizzes/quizzes_viewmodel.dart` containing:
   - inline data models (if not shared),
   - `class QuizzesState` (immutable + `copyWith` + `clear*` flags),
   - `class QuizzesViewModel extends StateNotifier<QuizzesState>` (Firebase / service calls inside, no widget imports),
   - bottom of file: `final quizzesViewModelProvider = StateNotifierProvider.autoDispose<QuizzesViewModel, QuizzesState>((ref) => QuizzesViewModel());`.
3. Add `lib/features/quizzes/quizzes_screen.dart` extending `ConsumerWidget` or `ConsumerStatefulWidget`; private sub-widgets in the same file.
4. Add a route name to `AppRoutes` in `lib/core/routes/app_router.dart` and append a `GoRoute(path: '/quizzes', name: AppRoutes.quizzes, builder: (_, __) => const QuizzesScreen())` to the `routes:` list.
5. Navigate from other features via `context.goNamed(AppRoutes.quizzes)`.

**New screen inside an existing feature:**
- Add a second `<purpose>_screen.dart` next to the existing one (e.g. `lib/features/auth/forgot_password_screen.dart`) and register a new `GoRoute` in `app_router.dart`.

**Reusable widget used by 2+ features:**
- Place it in `lib/shared/widgets/<name>.dart` (this directory is currently empty — you'll be the first contributor). Keep it free of feature state; pass data and callbacks in via constructor.

**Cross-feature data model:**
- Lift it to `lib/core/models/<entity>.dart` (this folder does not yet exist — create it). Both viewmodels then import from `core/models/`.

**New external SDK wrapper:**
- Add `lib/core/services/<name>_service.dart` modelled on `gemini_service.dart`.
- Expose a `final <name>ServiceProvider = Provider<<Name>Service>((ref) => <Name>Service());`. Wire any disposal logic with `ref.onDispose(...)` (see `chat_viewmodel.dart:586`).

**New Firestore-backed feature:**
- Prefer adding a thin repository under `lib/core/services/` (e.g. `users_repository.dart`) instead of calling `FirebaseFirestore.instance` from the new ViewModel directly. This is a divergence from current convention but improves testability — see ARCHITECTURE.md Anti-Patterns.

**Theme / brand additions:**
- New color → `AppColors` in `lib/core/constants/app_colors.dart`.
- New `TextStyle` → `AppTextStyles` in `lib/core/constants/app_text_styles.dart`.
- New themed widget defaults → extend `AppTheme.light` in `lib/core/theme/app_theme.dart`.

**Form validation rule:**
- Add a `static String? <rule>(...)` to `Validators` in `lib/core/utils/validators.dart`.

**Backend rule / index changes:**
- Edit `firestore.rules`, `firestore.indexes.json`, or `storage.rules` at the repo root and deploy via the Firebase CLI.

**Demo data for a new collection:**
- Extend `tool/seed/seed.js` and re-run `node seed.js` (idempotent — re-runs overwrite by fixed doc IDs).

## Special Directories

**`build/`:**
- Purpose: Flutter build output (artifacts, intermediate `.dart_tool` snapshots).
- Generated: Yes (by `flutter build` / `flutter run`).
- Committed: No (gitignored).

**`.dart_tool/`:**
- Purpose: Dart pub cache + package config.
- Generated: Yes (by `flutter pub get`).
- Committed: No (gitignored).

**`ios/Pods/`:**
- Purpose: CocoaPods installed dependencies for iOS.
- Generated: Yes (by `pod install`).
- Committed: No.

**`ios/.symlinks/`:**
- Purpose: Symlinks Flutter plugins into the iOS Pods install.
- Generated: Yes.
- Committed: No.

**`tool/seed/node_modules/`:**
- Purpose: npm install output for the seed script.
- Generated: Yes (by `npm install` in `tool/seed/`).
- Committed: No (gitignored via `tool/seed/.gitignore`).

**`tool/seed/service-account.json`:**
- Purpose: Firebase Admin SDK service account key for the seed script.
- Generated: Manually downloaded from Firebase Console.
- Committed: **No — gitignored. Never commit.**

## Notable Divergences from Spec

- The spec described `lib/presentation/screens/...`; the actual layout is `lib/features/<name>/` with the screen and viewmodel co-located in the same folder rather than split into `presentation/` + `viewmodel/` trees.
- The spec mentioned `riverpod_generator` codegen; it is declared in `pubspec.yaml` but **not used anywhere**. Every viewmodel is a hand-written `StateNotifier`, and there are zero `*.g.dart` files or `@riverpod` annotations.
- The spec mentioned `hooks_riverpod`; it is imported in screen files (`main.dart`, splash, dashboard, tutor) but `flutter_hooks` itself is not used — there are no `HookConsumerWidget`s or `useState` / `useEffect` calls.
- The spec mentioned a dedicated `models/` location; there is none — models live inline at the top of their owning viewmodel files.
- The spec mentioned `lib/shared/widgets/`; the folder exists but is **empty**.
- Android sources are nested inside `ios/android/` rather than at the repo root.
- `assets/images/` and `assets/fonts/` are declared / referenced but empty — fonts resolve to system fallbacks.

---

*Structure analysis: 2026-05-17*
