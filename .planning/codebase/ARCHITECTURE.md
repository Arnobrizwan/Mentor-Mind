<!-- refreshed: 2026-05-17 -->
# Architecture

**Analysis Date:** 2026-05-17

## System Overview

```text
┌──────────────────────────────────────────────────────────────────┐
│                       Presentation Layer                         │
│                  (Flutter widgets — ConsumerWidget /             │
│                   ConsumerStatefulWidget per feature)            │
├──────────────────┬──────────────────┬───────────────────────────┤
│  *_screen.dart   │ Local sub-widget │  Theme / typography       │
│ `lib/features/`  │   (StatelessW.)  │  `lib/core/theme/`,       │
│                  │                  │  `lib/core/constants/`    │
└────────┬─────────┴────────┬─────────┴───────────┬───────────────┘
         │  ref.watch / ref.read / ref.listen     │
         ▼                                         ▼
┌──────────────────────────────────────────────────────────────────┐
│                         ViewModel Layer                          │
│            `lib/features/<name>/*_viewmodel.dart`                │
│  StateNotifier<TState> exposed via StateNotifierProvider         │
│  (mostly `.autoDispose`; long-lived ones explicitly omit it)     │
└──────────────────────────────────┬───────────────────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              ▼                    ▼                    ▼
┌─────────────────────┐ ┌────────────────────┐ ┌────────────────────┐
│  GeminiService      │ │  FirebaseAuth      │ │  FirebaseFirestore │
│ `lib/core/services/ │ │  FirebaseStorage   │ │  collections:      │
│  gemini_service.dart│ │  GoogleSignIn      │ │  users, rewards,   │
│ ` thin SDK wrapper  │ │ (instantiated      │ │  sessions,         │
│  + streaming +      │ │  inline inside     │ │  materials,        │
│  vision             │ │  viewmodels)       │ │  notifications     │
└─────────────────────┘ └────────────────────┘ └────────────────────┘
                                   │
                                   ▼
                ┌────────────────────────────────┐
                │  Firebase backend / Gemini API │
                │  (network)                     │
                └────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                       Cross-Cutting                              │
│   `lib/core/routes/app_router.dart` — GoRouter Provider          │
│   `lib/core/utils/validators.dart`  — pure form rules            │
│   `lib/firebase_options.dart`       — generated platform config  │
│   `SharedPreferences` — onboarding flags, level/subject cache    │
└──────────────────────────────────────────────────────────────────┘
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

**Overall:** MVVM (Model–View–ViewModel) over Riverpod 2.x StateNotifier, with a feature-folder layout. No repository / service-locator layer — viewmodels talk to Firebase SDKs and `GeminiService` directly.

**Key Characteristics:**
- One folder per feature under `lib/features/<name>/`, each containing exactly one `*_screen.dart` (View) and one `*_viewmodel.dart` (ViewModel) — with `tutor/` and `rewards/` adding a second viewmodel (`chat_viewmodel.dart`, `gamification_viewmodel.dart`).
- View widgets are `ConsumerWidget` or `ConsumerStatefulWidget` (from `hooks_riverpod`) and read viewmodels via top-level `StateNotifierProvider` globals named `<feature>ViewModelProvider`.
- State classes are plain immutable Dart classes (no Freezed) with hand-rolled `copyWith(... bool clearError = false)` flags for nullable fields.
- Models live **inline** at the top of each ViewModel file (e.g. `DashboardUser`, `SessionItem`, `MaterialItem`, `ChatMessage` in their respective `*_viewmodel.dart`). There is **no** dedicated `models/` directory.
- `hooks_riverpod` is the import used by views; `flutter_riverpod` is used inside viewmodel files. `flutter_hooks` and `riverpod_annotation` are pubspec-declared but **not used in source** (no `@riverpod`, no `part '*.g.dart'`, no codegen).
- `get_it` and `injectable` are pubspec-declared but **not wired** — DI is done via Riverpod providers only.

## Layers

**Presentation (View):**
- Purpose: Render screens and translate user input into ViewModel calls.
- Location: `lib/features/<name>/*_screen.dart`
- Contains: `ConsumerStatefulWidget` / `ConsumerWidget` shells plus many private `_Foo extends StatelessWidget` sub-widgets defined in the same file.
- Depends on: `core/constants/`, `core/theme/`, `core/routes/app_router.dart` (for `AppRoutes` name constants), and the feature's own `*_viewmodel.dart`.
- Used by: GoRouter route builders in `lib/core/routes/app_router.dart`.

**ViewModel:**
- Purpose: Own all mutable UI state, mediate between the View and Firebase / Gemini.
- Location: `lib/features/<name>/*_viewmodel.dart`
- Contains: `class FooState`, `class FooViewModel extends StateNotifier<FooState>`, inline data models, and a bottom-of-file `final fooViewModelProvider = StateNotifierProvider...`.
- Depends on: `cloud_firestore`, `firebase_auth`, `firebase_storage`, `google_sign_in`, `shared_preferences`, `core/services/gemini_service.dart`, `core/utils/validators.dart`.
- Used by: matching `*_screen.dart` via `ref.watch / ref.read / ref.listen / ref.listenManual`.

**Core Services:**
- Purpose: Wrap non-Firebase SDKs and shared cross-feature logic.
- Location: `lib/core/services/`
- Contains: Currently only `gemini_service.dart`. Firebase SDKs are **not** wrapped — viewmodels call `FirebaseFirestore.instance` / `FirebaseAuth.instance` directly.
- Depends on: `google_generative_ai`.
- Used by: `chat_viewmodel.dart` via the `geminiServiceProvider` defined inline in that file.

**Core Foundation:**
- Purpose: Routing, theming, constants, pure helpers.
- Location: `lib/core/routes/`, `lib/core/theme/`, `lib/core/constants/`, `lib/core/utils/`.
- Contains: `app_router.dart`, `app_theme.dart`, `app_colors.dart`, `app_text_styles.dart`, `validators.dart`.
- Depends on: Flutter framework only (no Firebase).
- Used by: every feature.

**Shared (placeholder):**
- Location: `lib/shared/widgets/`
- Status: **Empty directory.** No cross-feature widget library exists yet — every screen reimplements its own pills, cards, shimmers, and headers as private `_Foo` widgets inside its `*_screen.dart`.

## Data Flow

### Primary Request Path (Tutor sending a chat message)

1. User taps Send → `TutorScreen` calls `ref.read(chatViewModelProvider.notifier).sendMessage(text)` (`lib/features/tutor/tutor_screen.dart`).
2. `ChatViewModel.sendMessage` (`lib/features/tutor/chat_viewmodel.dart:297`) appends a user + placeholder assistant `ChatMessage` and flips `isStreaming = true`.
3. ViewModel iterates `_gemini.sendMessage(...)` (`lib/core/services/gemini_service.dart:62`) and writes each chunk into the placeholder via `_updateMessage` → `state = state.copyWith(messages: ...)`.
4. On completion, viewmodel fires `_saveSession()` to `/sessions/{id}`, `_incrementUsage()` to `/users/{uid}/usage/{yyyy-MM-dd}`, and (first message only) `_awardPoints('complete_session')` writing to `/users/{uid}` + `/rewards/{uid}` (`chat_viewmodel.dart:407, 492, 511`).
5. `TutorScreen` re-renders because it `ref.watch`es `chatViewModelProvider`.

### Boot & Role Routing

1. `main()` initializes Firebase and runs `ProviderScope(child: MentorMindsApp())` (`lib/main.dart:10`).
2. `MentorMindsApp` (`ConsumerWidget`) does `ref.watch(appRouterProvider)` and returns `MaterialApp.router` (`lib/main.dart:33`).
3. `appRouterProvider` builds a `GoRouter` with `initialLocation: '/'` → `SplashScreen` (`lib/core/routes/app_router.dart:34`).
4. `SplashScreen.initState` waits 2 s, then `ref.read(splashViewModelProvider.notifier).resolveDestination()` (`lib/features/splash/splash_screen.dart:39`).
5. `SplashViewModel.resolveDestination` (`lib/features/splash/splash_viewmodel.dart:53`):
   - If `FirebaseAuth.instance.currentUser != null`, reads `/users/{uid}.role` and maps to `studentDashboard | teacherDashboard | admin`.
   - Else reads `SharedPreferences.onboarding_complete` and returns `login` or `onboarding`.
6. `SplashScreen` calls `context.goNamed(...)` against the matching `AppRoutes.*` constant.

### Dashboard (multi-stream)

1. `DashboardViewModel._init()` opens four streams concurrently: user doc, recent sessions (limit 3), recent materials (`whereIn` over user.subjects, limit 6), and unread notifications (`dashboard_viewmodel.dart:365`).
2. Each stream pushes new state via `state = state.copyWith(...)`. The user stream additionally **resubscribes** materials/notifications when `subjects` or `role` change (`dashboard_viewmodel.dart:422-429`).
3. `_fetchStreak(uid)` and `_awardDailyLoginIfNeeded(uid)` run as fire-and-forget Futures; the latter sets `justAwardedDailyPoints` so the screen can show a one-shot toast and call `ackDailyAward()` to clear it.

**State Management:**
- All state lives in `StateNotifier<TState>` instances behind globally-declared `StateNotifierProvider` variables at the bottom of each viewmodel file.
- No `Notifier` / `AsyncNotifier` (Riverpod 2.x new-API) or `riverpod_generator` codegen is used despite the deps being declared.
- Cross-feature reactivity uses providers that watch other providers (e.g. `badgeEarnedEventProvider` in `gamification_viewmodel.dart:579` is a `StreamProvider` that watches `gamificationViewModelProvider.notifier.badgeEarnedStream`).

## Key Abstractions

**Feature module:**
- Purpose: Self-contained MVVM slice (screen + viewmodel + inline models).
- Examples: `lib/features/dashboard/`, `lib/features/tutor/`, `lib/features/profile/`.
- Pattern: Folder name == feature; files inside follow `<feature>_screen.dart` + `<feature>_viewmodel.dart`. Some features add specialized siblings (`chat_viewmodel.dart`, `gamification_viewmodel.dart`).

**Inline data model:**
- Purpose: Plain Dart class (no codegen) with `factory Foo.fromDoc(...)` / `Map<String, dynamic> toMap()` to translate Firestore docs.
- Examples: `DashboardUser`, `SessionItem`, `MaterialItem`, `BadgeItem` in `lib/features/dashboard/dashboard_viewmodel.dart`; `ChatMessage` in `lib/features/tutor/chat_viewmodel.dart:20`.
- Pattern: Defined inside the consuming viewmodel file; not exported elsewhere.

**Route name constants:**
- Purpose: Centralize navigation tokens so screens never type raw paths.
- File: `lib/core/routes/app_router.dart` (`abstract final class AppRoutes`).
- Pattern: `context.goNamed(AppRoutes.tutor)` (the splash screen breaks this once with `context.go('/dashboard/teacher')` — see `splash_screen.dart:78`).

**Provider naming:**
- Purpose: Discoverable global provider per feature.
- Convention: `final <feature>ViewModelProvider = StateNotifierProvider<...>.autoDispose(...)`.
- Exceptions (`NOT autoDispose`): `splashViewModelProvider`, `profileViewModelProvider`, `rewardsViewModelProvider`, `gamificationViewModelProvider`, `notificationsViewModelProvider` — each documented with a comment explaining why disposal would race an in-flight `await`.

## Entry Points

**App entry:**
- Location: `lib/main.dart:10` (`void main() async`).
- Triggers: `flutter run` and platform launchers.
- Responsibilities: `WidgetsFlutterBinding.ensureInitialized`, portrait lock, transparent status bar, `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`, then `runApp(const ProviderScope(child: MentorMindsApp()))`.

**Root widget:**
- Location: `lib/main.dart:33` (`class MentorMindsApp extends ConsumerWidget`).
- Pattern:
  ```dart
  final router = ref.watch(appRouterProvider);
  return MaterialApp.router(
    title: 'MentorMinds',
    theme: AppTheme.light,
    routerConfig: router,
    debugShowCheckedModeBanner: false,
  );
  ```

**Router provider:**
- Location: `lib/core/routes/app_router.dart:34`.
- Definition:
  ```dart
  final appRouterProvider = Provider<GoRouter>((ref) {
    return GoRouter(
      initialLocation: '/',
      debugLogDiagnostics: false,
      routes: [ /* 13 GoRoute entries */ ],
    );
  });
  ```
- Routes (path → name → screen):

  | Path | Name (`AppRoutes.*`) | Builds |
  |------|----------------------|--------|
  | `/` | `splash` | `SplashScreen` |
  | `/onboarding` | `onboarding` | `OnboardingScreen` |
  | `/auth/login` | `login` | `LoginScreen` |
  | `/auth/register` | `register` | `RegisterScreen` |
  | `/dashboard` | `dashboard` | `DashboardScreen` |
  | `/dashboard/teacher` | `teacherDashboard` | `_PlaceholderScreen(label: 'Teacher Dashboard')` |
  | `/tutor` | `tutor` | `TutorScreen` |
  | `/materials` | `materials` | `MaterialsScreen` |
  | `/search` | `search` | `SearchScreen` |
  | `/profile` | `profile` | `ProfileScreen` |
  | `/rewards` | `rewards` | `RewardsScreen` |
  | `/notifications` | `notifications` | `NotificationsScreen` |
  | `/admin` | `admin` | `_PlaceholderScreen(label: 'Admin Panel')` |

- Guards / redirects: **None.** There is no `redirect:` callback and no `refreshListenable`. Role gating is enforced imperatively by `SplashViewModel` and `AuthViewModel` returning a `*Destination` enum that the screen converts into `context.goNamed(...)`. `LoginScreen`, `RegisterScreen`, and every protected screen are reachable by URL without any router-level auth check.
- The `_PlaceholderScreen` (`app_router.dart:108`) is a private fallback used for `teacherDashboard` and `admin` until those screens are built.

## Theme System

**File:** `lib/core/theme/app_theme.dart` — single `abstract final class AppTheme` exposing `static ThemeData get light` (no dark theme).

**Material 3:** `useMaterial3: true` with `ColorScheme.fromSeed(seedColor: AppColors.kPrimary)`.

**Brand tokens** (`lib/core/constants/app_colors.dart`):

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

**Typography** (`lib/core/constants/app_text_styles.dart`) — three font families used directly via `fontFamily:` strings, **declared in code but the asset bundle is empty** (`assets/fonts/` exists but contains no `.ttf` and `pubspec.yaml` declares no `fonts:` block):
- `'Poppins'` — display / headings (`displayLarge` 32 / 700 down to `headingSmall` 16 / 600).
- `'Inter'` — body and labels (`bodyLarge` 16 / 400, `bodyMedium` 14, `bodySmall` 12; `labelLarge/Medium/Small` 500-weight).
- `'JetBrainsMono'` — AI output / code blocks (`monoBody` 13, `monoSmall` 11).

**Themed widgets:** `AppBarTheme` (transparent status bar, no elevation), `CardThemeData` (16px radius, no elevation), `ElevatedButtonThemeData` (full-width 52 h, 12 px radius, Inter 16/600), `InputDecorationTheme` (12 px radius, `#E5E7EB` border, primary-tinted focused border, error border), `DividerThemeData` (1 px `#E5E7EB`).

## Entry Point Flow (end-to-end)

```
flutter run
  └─► main() — lib/main.dart:10
        ├─► WidgetsFlutterBinding.ensureInitialized()
        ├─► SystemChrome.setPreferredOrientations([portraitUp, portraitDown])
        ├─► SystemChrome.setSystemUIOverlayStyle(transparent statusBar)
        ├─► Firebase.initializeApp(DefaultFirebaseOptions.currentPlatform)
        │     └─► catches and debugPrints on failure (does NOT abort startup)
        └─► runApp(ProviderScope(MentorMindsApp))
              └─► MentorMindsApp.build (ConsumerWidget)
                    └─► MaterialApp.router(routerConfig: ref.watch(appRouterProvider))
                          └─► GoRouter '/' → SplashScreen
                                ├─► 2 s gradient + lettermark animation
                                ├─► SplashViewModel.resolveDestination()
                                │     ├─► FirebaseAuth.instance.currentUser?
                                │     │     ├─► YES → read /users/{uid}.role
                                │     │     │         → admin | teacher | student
                                │     │     │           → SplashDestination.{admin|teacherDashboard|studentDashboard}
                                │     │     └─► NO  → SharedPreferences.onboarding_complete?
                                │     │               ├─► true  → SplashDestination.login
                                │     │               └─► false → SplashDestination.onboarding
                                └─► context.goNamed(AppRoutes.<destination>)
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

**What happens:** `ChatMessage`, `DashboardUser`, `SessionItem`, `MaterialItem`, `BadgeItem`, `SubjectProgress`, `RewardsSnapshot` are all declared at the top of their owning `*_viewmodel.dart` rather than in a shared `models/` package.
**Why it's wrong here:** Two features can't share a model without one importing the other's viewmodel and pulling in Firebase + business logic transitively. `DashboardUser` and the `User` projection embedded in `ProfileViewModel` already overlap.
**Do this instead:** When a model is reused (or about to be), lift it into `lib/core/models/<entity>.dart` and have both viewmodels import it. See the duplication between `dashboard_viewmodel.dart:42` and the profile state.

### Direct Firebase singleton access from ViewModels

**What happens:** Every viewmodel calls `FirebaseAuth.instance` / `FirebaseFirestore.instance` directly (e.g. `dashboard_viewmodel.dart:345`, `auth_viewmodel.dart:69-70`, `chat_viewmodel.dart:195-197`).
**Why it's wrong here:** Cannot inject a fake for unit tests; the placeholder `test/widget_test.dart` confirms there are no real ViewModel tests. Also couples MVVM tightly to Firebase — replacing the backend would require touching every viewmodel.
**Do this instead:** Introduce thin repositories under `lib/core/services/` (e.g. `users_repository.dart`, `sessions_repository.dart`) exposed as `Provider`s, mirroring `geminiServiceProvider` in `chat_viewmodel.dart:584`.

### Mixing `context.goNamed` and raw `context.go`

**What happens:** `splash_screen.dart:78` uses `context.go('/dashboard/teacher')` instead of `context.goNamed(AppRoutes.teacherDashboard)`.
**Why it's wrong here:** Defeats the whole point of the `AppRoutes` name constants and silently breaks if the path is ever renamed.
**Do this instead:** Always go through `context.goNamed(AppRoutes.<x>)`.

### Provider declared but file ignores it

**What happens:** `pubspec.yaml` declares `flutter_hooks`, `riverpod_annotation`, `riverpod_generator`, `get_it`, `injectable`, `injectable_generator` — none are imported anywhere under `lib/`.
**Why it's wrong here:** Bloats the dependency surface and confuses readers about which patterns are in play.
**Do this instead:** Either commit to codegen (`@riverpod` notifiers) for new viewmodels or remove the unused packages.

### Unauthenticated routes reachable by URL

**What happens:** GoRouter has no `redirect` and no `refreshListenable`; protected routes like `/dashboard`, `/profile`, `/tutor` are reachable without an authenticated user. The viewmodel will then push an "You are not signed in" error state instead of bouncing the user back.
**Do this instead:** Add a `redirect:` in `appRouterProvider` that reads `FirebaseAuth.instance.authStateChanges()` (wrapped in a Riverpod `StreamProvider` + `Listenable`) and rewrites to `/auth/login` when unauthenticated, except for `splash` / `onboarding` / `/auth/*`.

## Error Handling

**Strategy:** Catch in the ViewModel, translate Firebase error codes to user-facing copy, store on `state.error`. The View shows the error via a `SnackBar` or inline message and tells the ViewModel to clear it.

**Patterns:**
- Firebase error-code switches: `AuthViewModel._mapLoginError` / `_mapRegisterError` / `_mapResetError` / `_mapVerificationError` (`auth_viewmodel.dart:487-523`) collapse `FirebaseAuthException.code` into copy.
- Non-fatal stream errors (recent sessions, materials, notifications) are swallowed with a `// Non-fatal` comment so a single broken stream doesn't blank the dashboard (`dashboard_viewmodel.dart:458, 491, 511`).
- "Roll back on failure": `GeminiService.sendMessage` removes the just-appended user `Content` from `_history` on exception so retries aren't duplicated (`gemini_service.dart:87-91`).
- `copyWith(clearError: true)` flags everywhere — pattern to reset nullable `error` / `user` / `sessionId` / `imagePreview` slots, since plain `null` in `copyWith` means "no change".

## Cross-Cutting Concerns

**Logging:** `debugPrint(...)` from `flutter/foundation.dart` — used inside auth viewmodel catch blocks (e.g. `auth_viewmodel.dart:115, 327, 340, 352`). No structured logger.

**Validation:** Centralized in `lib/core/utils/validators.dart` (`Validators.name / email / password / loginPassword / confirmPassword / role`). `AuthViewModel.registerWithEmail` runs them sequentially and sets `state.errorField: AuthErrorField.{name|email|password|generic}` so the View can highlight the offending input (`auth_viewmodel.dart:216-268`).

**Authentication:** `FirebaseAuth` directly (email/password + Google via `GoogleSignIn`). Profile docs at `/users/{uid}` carry the `role` field which is the single source of truth for role routing; both `SplashViewModel._resolveRoleDestination` and `AuthViewModel._resolveRoleDestination` read it identically and return their own destination enum (`auth_viewmodel.dart:469-485`, `splash_viewmodel.dart:73-97`). iOS-specific Google Sign-In status is probed via a `MethodChannel('mentor_minds/native_config')` (`auth_viewmodel.dart:66, 188-206`).

**Persistence:**
- Firestore collections: `users`, `users/{uid}/usage/{yyyy-MM-dd}`, `rewards`, `sessions`, `materials`, `notifications`.
- Firebase Storage path: `uploads/{uid}/{ts}_{rand}.jpg` for chat image attachments (`chat_viewmodel.dart:483-490`).
- `SharedPreferences` keys: `onboarding_complete` (bool), `onboarding_level` (string), `onboarding_subjects` (JSON string array) — written by onboarding, read by splash + register.

**Configuration:** `GEMINI_API_KEY` is read via `String.fromEnvironment('GEMINI_API_KEY')` (`gemini_service.dart:13`) and must be passed at build time with `--dart-define=GEMINI_API_KEY=<key>`. If unset, `GeminiService.isAvailable` is `false` and the service returns `unavailableMessage` instead of throwing.

---

*Architecture analysis: 2026-05-17*
