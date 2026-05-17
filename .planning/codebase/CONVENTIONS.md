# Coding Conventions

**Analysis Date:** 2026-05-17

## Lint Configuration

**Config file:** `analysis_options.yaml`

**Base ruleset:** `package:flutter_lints/flutter.yaml` (via `flutter_lints: ^4.0.0` in `pubspec.yaml`).

**Verbatim contents of `analysis_options.yaml`:**

```yaml
# The following line activates a set of recommended lints for Flutter apps,
# packages, and plugins designed to encourage good coding practices.
include: package:flutter_lints/flutter.yaml

linter:
  # The lint rules applied to this project can be customized in the
  # section below to disable rules from the `package:flutter_lints/flutter.yaml`
  # included above or to enable additional rules. A list of all available lints
  # and their documentation is published at https://dart.dev/lints.
  rules:
    # avoid_print: false  # Uncomment to disable the `avoid_print` rule
    # prefer_single_quotes: true  # Uncomment to enable the `prefer_single_quotes` rule
```

**Custom overrides:** None. No rules are disabled or added. No `analyzer:` block. No `exclude:` patterns (so generated files such as `lib/firebase_options.dart` are scanned — that file carries its own `// ignore_for_file: type=lint` on line 2).

**Current analyzer state (per `flutter analyze`):**
- 0 errors.
- ~168 info-level warnings.
- Dominant categories:
  - `deprecated_member_use` for `Color.withOpacity()` — 104 hits across `lib/` (sample: `lib/features/splash/splash_screen.dart:180,211,214,220,226`, `lib/features/auth/login_screen.dart:303,308,502`).
  - `depend_on_referenced_packages` — 16 view-model files import `package:flutter_riverpod/flutter_riverpod.dart` directly while `pubspec.yaml` declares only `hooks_riverpod: ^2.5.1` (which re-exports `flutter_riverpod` transitively). See `pubspec.yaml` lines 16–18 and every `*_viewmodel.dart` listed below.
  - `prefer_const_constructors` / `prefer_const_literals_to_create_immutables` — scattered across screens.

**Lint-ignore directives in `lib/`:** exactly one — `lib/firebase_options.dart:2` (`// ignore_for_file: type=lint`, on auto-generated FlutterFire output). All hand-written code is unsuppressed.

**Run analyzer:**
```bash
flutter analyze
```

## File Naming

**Rule:** lowercase `snake_case` for every `.dart` file. No exceptions in the current tree.

**Observed suffix conventions:**

| Layer | Suffix | Example |
|-------|--------|---------|
| View-models (Riverpod `StateNotifier` + state class + provider) | `_viewmodel.dart` | `lib/features/auth/auth_viewmodel.dart` |
| Screens (route-level widgets) | `_screen.dart` | `lib/features/dashboard/dashboard_screen.dart` |
| Services (singletons / SDK wrappers) | `_service.dart` | `lib/core/services/gemini_service.dart` |
| Theming primitives | `app_<thing>.dart` | `lib/core/constants/app_colors.dart`, `lib/core/theme/app_theme.dart`, `lib/core/constants/app_text_styles.dart` |
| Router | `app_router.dart` | `lib/core/routes/app_router.dart` |
| Utilities | bare noun | `lib/core/utils/validators.dart` |
| Entry point | `main.dart` | `lib/main.dart` |

**Outlier:** `lib/features/rewards/gamification_viewmodel.dart` lives next to `rewards_viewmodel.dart`. Same feature, two view-models — the file naming follows the suffix rule, the duplication is the anomaly (flagged in `CONCERNS.md`).

## Directory Naming

`snake_case` directories. Feature folders are singular nouns: `auth`, `dashboard`, `materials`, `notifications`, `onboarding`, `profile`, `rewards`, `search`, `splash`, `tutor`. Cross-cutting code lives under `lib/core/{constants,routes,services,theme,utils}/`. `lib/shared/widgets/` exists but is currently empty.

## Class Naming

`UpperCamelCase` throughout, with stable per-layer suffixes:

| Pattern | Examples |
|---------|----------|
| `<Feature>Screen` | `LoginScreen`, `DashboardScreen`, `TutorScreen`, `MaterialsScreen` |
| `<Feature>ViewModel extends StateNotifier<<Feature>State>` | `AuthViewModel`, `DashboardViewModel`, `ChatViewModel`, `NotificationsViewModel` |
| `<Feature>State` (immutable, `const` ctor, `copyWith`) | `AuthState`, `DashboardState`, `ChatState`, `NotificationsState`, `SplashState`, `OnboardingState` |
| `<Feature>Destination` enum for screen-driven routing | `AuthDestination`, `SplashDestination` |
| Domain entities decoded from Firestore | `DashboardUser`, `ProfileUser`, `ChatMessage`, `AppNotification`, `SessionItem`, `MaterialItem`, `BadgeItem`, `RewardsSnapshot` |
| Static-only helper "namespaces" | `abstract final class AppColors`, `abstract final class AppTextStyles`, `abstract final class AppTheme`, `abstract final class Validators`, `abstract final class AppRoutes`, `abstract final class NotificationFilter` |

Private widgets that are screen-local are prefixed with `_` and nested in the same screen file: `_BadgesTab`, `_LeaderboardTab`, `_ProfileBody`, `_Header`, `_SettingsList`, `_EditProfileSheet`, `_SubjectsSheet`, `_LevelSheet`, `_ChangePasswordDialog`, `_DeleteAccountDialog`, `_WelcomePage`, `_SelectLevelPage`, `_SelectSubjectsPage`, `_NotificationsList`. Public sub-widgets are not extracted to `lib/shared/widgets/` yet.

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

**Rule:** every Riverpod provider is `final <camelCaseName>Provider = ...` at the bottom of its owning file, after a divider comment:

```dart
// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final authViewModelProvider =
    StateNotifierProvider.autoDispose<AuthViewModel, AuthState>(
  (ref) => AuthViewModel(),
);
```
— `lib/features/auth/auth_viewmodel.dart:526-533`

**Observed provider inventory:**

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

**autoDispose heuristic in this codebase:** transient screen-scoped state (auth, onboarding, dashboard, chat, materials, search) uses `.autoDispose`; long-lived/app-scoped state (splash, profile, rewards, notifications, gamification) does not. Splash is the documented exception (see code comment cited above).

**No code generation in use.** Despite `riverpod_annotation: ^2.3.5` and `riverpod_generator: ^2.4.3` being declared in `pubspec.yaml`, there are **zero** `*.g.dart` files in `lib/` and zero `@riverpod` annotations. All providers are hand-written.

## State Management Pattern

**Pattern:** legacy Riverpod 2.x `StateNotifier<TState>` + plain `class TState { ... copyWith() }`. **NOT** `Notifier` / `AsyncNotifier` from the Riverpod 2.3+ "new" API.

**Canonical view-model shape (see `lib/features/auth/auth_viewmodel.dart`):**

```dart
class AuthState {
  final bool isLoading;
  final String? error;
  final AuthErrorField? errorField;
  final User? user;

  const AuthState({
    this.isLoading = false,
    this.error,
    this.errorField,
    this.user,
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    AuthErrorField? errorField,
    User? user,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      errorField: clearError ? null : (errorField ?? this.errorField),
      user: clearUser ? null : (user ?? this.user),
    );
  }
}

class AuthViewModel extends StateNotifier<AuthState> {
  AuthViewModel() : super(const AuthState());
  // ...
}
```

**State conventions:**
- All fields `final`, `const` constructor with defaults.
- `copyWith` accepts explicit `clearX` booleans to set nullable fields back to `null` (because `?? this.x` cannot distinguish "don't touch" from "set to null"). Used as `clearError`, `clearUser`, `clearSession`, `clearImagePreview`, `clearFeedback`.
- UI-derived values exposed as getters on state, not stored — e.g. `firstName`, `greeting`, `subjects`, `badges`, `messagesRemaining`, `hasReachedLimit`, `showLimitWarning` on `ChatState` (`lib/features/tutor/chat_viewmodel.dart:135-142`).
- Streams owned by view-models are stored as `StreamSubscription` fields and cancelled in `dispose()`:

```dart
StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sessionsSub;

@override
void dispose() {
  _userSub?.cancel();
  _sessionsSub?.cancel();
  // ...
  super.dispose();
}
```
— `lib/features/dashboard/dashboard_viewmodel.dart:348-351, 655-662`.

- After `await`, every state mutation is guarded by `if (!mounted) return;` (the `StateNotifier.mounted` flag), e.g. `dashboard_viewmodel.dart:554, 609`; `chat_viewmodel.dart:439, 555`.

**Section dividers:** all view-models use the same banner-style comment dividers to group state / destination / view-model / provider:

```dart
// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
```

This is universal — every `*_viewmodel.dart` in the repo follows it.

## Widget Composition Style

**Rule:** screens consume Riverpod via `ConsumerWidget` / `ConsumerStatefulWidget`. **`HookConsumerWidget` is not used anywhere** in `lib/`, and neither is any `flutter_hooks` API (`useState`, `useEffect`, `useTextEditingController`, …). `flutter_hooks: ^0.20.5` is declared in `pubspec.yaml:17` but unused — likely a stale dep.

**Verified inventory (grep over `lib/`):**

| Style | Count | Used by |
|---|---|---|
| `ConsumerWidget` | 11 | `MentorMindsApp`, `RewardsScreen`, `_BadgesTab`, `_LeaderboardTab`, `ProfileScreen`, `_ProfileBody`, `_Header`, `_SettingsList`, `_LevelSheet`, `NotificationsScreen`, `_Header` (notifications), `_NotificationsList`, `_WelcomePage`, `_SelectLevelPage`, `_SelectSubjectsPage` |
| `ConsumerStatefulWidget` | 11 | `SplashScreen`, `LoginScreen`, `RegisterScreen`, `MaterialsScreen`, `DashboardScreen`, `SearchScreen`, `_EditProfileSheet`, `_SubjectsSheet`, `_ChangePasswordDialog`, `_DeleteAccountDialog`, `OnboardingScreen`, `TutorScreen` |
| `HookConsumerWidget` | **0** | — |

**Choice rule observed:** stateful when the screen owns `TextEditingController`s, `FocusNode`s, a `Timer`, an `int _navIndex`, a `ProviderSubscription`, or `initState`/`dispose` lifecycle hooks (every stateful screen does at least one). Otherwise stateless `ConsumerWidget`.

**Listening to provider side-effects from a stateful screen** is done with `ref.listenManual`, stored as a `late final ProviderSubscription<TState>`, closed in `dispose()`:

```dart
late final ProviderSubscription<AuthState> _authListener;

@override
void initState() {
  super.initState();
  _authListener = ref.listenManual<AuthState>(authViewModelProvider, (
    previous,
    next,
  ) {
    final err = next.error;
    if (err != null && err != previous?.error && mounted) {
      _showSnack(err, background: AppColors.kError);
    }
  });
}

@override
void dispose() {
  _authListener.close();
  _emailCtrl.dispose();
  _passCtrl.dispose();
  super.dispose();
}
```
— `lib/features/auth/login_screen.dart:22-45`. Same pattern in `register_screen.dart`, `dashboard_screen.dart`, `tutor_screen.dart`.

**Reading the view-model:** `ref.read(<provider>.notifier).method(...)` for actions; `ref.watch(<provider>)` for state inside `build`. ~57 `ref.{read,watch,listen}` call-sites across `lib/`.

## Riverpod Import Convention

| Layer | Import | Why |
|---|---|---|
| Screens / widgets / router | `import 'package:hooks_riverpod/hooks_riverpod.dart';` | The host import — re-exports everything from `flutter_riverpod` plus hook-aware variants. |
| View-models / non-widget files | `import 'package:flutter_riverpod/flutter_riverpod.dart';` | Pure state plumbing, no widget concerns. |
| `lib/core/routes/app_router.dart` | `import 'package:flutter_riverpod/flutter_riverpod.dart';` | Exception — defines `appRouterProvider` and imports widgets. |

**Important pitfall — `depend_on_referenced_packages`.** Every `*_viewmodel.dart` plus `app_router.dart` (16 files total) imports `package:flutter_riverpod/flutter_riverpod.dart` even though `flutter_riverpod` is **not** a direct dependency in `pubspec.yaml` (only `hooks_riverpod` is — line 16). It works at runtime because `hooks_riverpod` exports `flutter_riverpod`, but the analyzer raises `depend_on_referenced_packages` for every file.

**Fix path (do this once):** add `flutter_riverpod: ^2.5.1` as a direct dependency under the `# State management` block in `pubspec.yaml:15-18`. Do not rewrite all 16 imports to `hooks_riverpod` — view-models intentionally avoid the hooks dependency.

## Color & Theme Usage

**Rule:** spot colours and palette tokens flow from `AppColors` (`lib/core/constants/app_colors.dart`); typography flows from `AppTextStyles` (`lib/core/constants/app_text_styles.dart`); broad surface styling (app bar, card, input, elevated button) flows from `AppTheme.light` (`lib/core/theme/app_theme.dart`).

**`AppColors` palette (verbatim):**

```dart
abstract final class AppColors {
  static const Color kPrimary    = Color(0xFF1A3C8F);
  static const Color kAccent     = Color(0xFF00C9A7);
  static const Color kGold       = Color(0xFFF5A623);
  static const Color kBackground = Color(0xFFF4F6FB);
  static const Color kSurface    = Color(0xFFFFFFFF);
  static const Color kTextDark   = Color(0xFF1C1F2E);
  static const Color kTextMuted  = Color(0xFF6B7280);
  static const Color kError      = Color(0xFFEF4444);

  static const Color kSplashTop    = Color(0xFF1A3C8F);
  static const Color kSplashBottom = Color(0xFF0D2660);
}
```

**Observed usage statistics:**
- `AppColors.kXxx` references: **402** across feature files.
- `AppTextStyles.xxx` references: **179**.
- `Theme.of(context)` references: **1** (`lib/features/tutor/tutor_screen.dart:990`, only to seed `MarkdownStyleSheet.fromTheme`).

**Convention:** prefer the constants over `Theme.of(context)`. The single `Theme.of(context)` is acceptable because `flutter_markdown` requires a `ThemeData`; do not introduce more.

**Fonts:** family names `Inter`, `Poppins`, `JetBrainsMono`, declared in `AppTheme` (`fontFamily: 'Inter'`) and `AppTextStyles` per-style. Asset declarations are not present in `pubspec.yaml`; only `assets/images/` is wired up.

**Inline hex colours:** allowed when the shade is local and non-reusable. Examples: subject-color map at `lib/features/dashboard/dashboard_viewmodel.dart:14-25` (10 brand colours per subject), `_kPrimary.darken` calculated via `HSLColor`. Do **not** add new inline colours that conceptually belong in `AppColors`.

**Deprecated colour API — migration pending.** 104 call-sites use the deprecated `Color.withOpacity(double)`. Examples:

```dart
color: Colors.white.withOpacity(0.70),                // splash_screen.dart:180
color: AppColors.kAccent.withOpacity(0.45),           // splash_screen.dart:214
disabledBackgroundColor: AppColors.kPrimary.withOpacity(0.6),  // login_screen.dart:502
```

**Replacement:** use `Color.withValues(alpha: 0.70)` (Flutter 3.27+). The migration is mechanical and non-semantic. New code MUST use `withValues(alpha: ...)`, not `withOpacity`. Tracked in `CONCERNS.md` as a sweep task.

## Import Ordering

**Order observed in every file** (matches Effective Dart and `directives_ordering` from `flutter_lints`):

1. **Dart SDK** imports — `import 'dart:async';`, `import 'dart:convert';`, `import 'dart:io';`.
2. **Blank line.**
3. **Package imports** — `import 'package:flutter/material.dart';`, then third-party packages alphabetically (`cloud_firestore`, `firebase_auth`, `flutter_animate`, `go_router`, `hooks_riverpod`, `intl`, …).
4. **Blank line.**
5. **Relative imports** — `import '../../core/constants/app_colors.dart';` then sibling files (`import 'auth_viewmodel.dart';`).

**Example (`lib/features/auth/login_screen.dart:1-9`):**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/routes/app_router.dart';
import 'auth_viewmodel.dart';
```

**Aliases:** none used. All imports are bare.

## Error Handling

**Pattern:** every Firebase / async call sits inside a `try` block. Catches are layered most-specific to least:

1. `on FirebaseAuthException catch (ex)` — auth-flow errors mapped to user-friendly strings via private `_mapXxxError(String code)` switch-expression helpers.
2. `on FirebaseException catch (ex)` — Firestore / Storage / Messaging plugin errors; debug-printed with `${ex.plugin}/${ex.code}` and surfaced with a message that mentions rules when `code == 'permission-denied'`.
3. `on PlatformException` — native channel errors (`auth_viewmodel.dart:203`, the `MethodChannel('mentor_minds/native_config')` for iOS Google Sign-In).
4. `catch (e, st)` or `catch (_)` — last-resort net for unknown failures.

**117 try/catch blocks** across `lib/`. Canonical example — `lib/features/auth/auth_viewmodel.dart:97-129`:

```dart
try {
  final cred = await _auth.signInWithEmailAndPassword(
    email: e,
    password: password,
  );
  // ...
} on FirebaseAuthException catch (ex) {
  debugPrint(
      'loginWithEmail FirebaseAuthException: ${ex.code} — ${ex.message}');
  state = state.copyWith(
    isLoading: false,
    error: _mapLoginError(ex.code),
  );
  return null;
} catch (e, st) {
  debugPrint('loginWithEmail unknown: $e\n$st');
  state = state.copyWith(
    isLoading: false,
    error: 'Login failed: $e',
  );
  return null;
}
```

**Error-mapper convention:** view-models declare private `_mapXxxError` methods using Dart 3 switch expressions:

```dart
String _mapLoginError(String code) => switch (code) {
      'user-not-found' => 'No account found with this email',
      'wrong-password' => 'Incorrect password',
      'invalid-email' => 'Invalid email address',
      'user-disabled' => 'This account has been disabled',
      'too-many-requests' => 'Too many attempts. Try again later.',
      'invalid-credential' => 'Incorrect email or password',
      'network-request-failed' =>
        'Network error. Check your connection and try again.',
      _ => 'Login failed. Please try again.',
    };
```
— `lib/features/auth/auth_viewmodel.dart:487-497`. Per-flow variants live in the same file: `_mapResetError`, `_mapRegisterError`, `_mapVerificationError`.

**`main.dart` bootstrap** wraps `Firebase.initializeApp` in `try { ... } catch (e) { debugPrint('Firebase init failed: $e'); }` so a misconfigured Firebase project does not hard-crash the splash. See `lib/main.dart:22-28`.

**Silent catches** (`catch (_) {}`) are deliberately used for non-fatal background side-effects — telemetry/usage increments, leaderboard fetches, point awards. Always preceded by a `// Non-fatal — ...` or `// Silent.` comment. Examples: `dashboard_viewmodel.dart:556-558,613-616`; `chat_viewmodel.dart:442-444, 506-508, 539-541`. **Rule:** silent catches are only for code paths whose failure must never disrupt the user; everything else must surface an error into state.

**Surfacing errors to the UI:** writing `state.error = msg` is the canonical path. Screens listen to `state.error` either by `ref.watch` (e.g. `DashboardScreen`) or `ref.listenManual` + `SnackBar` (e.g. `LoginScreen` — see Widget Composition section).

## Logging

**Tool:** `debugPrint` from `flutter/foundation.dart`. **No `print()` calls** in `lib/`. No structured logger (no `logger`, `logging`, `sentry`, or similar package).

**Format observed:** `'<method> <ExceptionType>: ${ex.code} — ${ex.message}'`, optionally with stack trace appended:

```dart
debugPrint('loginWithEmail FirebaseAuthException: ${ex.code} — ${ex.message}');
debugPrint('registerWithEmail unknown: $e\n$st');
debugPrint('updateProfile FirebaseException: ${e.code} — ${e.message}');
```

19 `debugPrint` call-sites total, concentrated in `auth_viewmodel.dart`, `profile_viewmodel.dart`, `notifications_viewmodel.dart`, `gamification_viewmodel.dart`. Use `debugPrint` (not `print`) for any future logging; `debugPrint` strips in release mode and the lint rule `avoid_print` from `flutter_lints` would flag `print`.

## Comments

**When to comment:** non-obvious behaviour, intentional deviations, legacy compatibility shims, and future-work markers.

**Style observed:**
- **Banner dividers** between major sections of a file (see State Management Pattern).
- **Method-level explanations** as a short paragraph above the method, plain `//` (not `///`). Example — `notifications_viewmodel.dart:185-188`:

  ```dart
  // -------------------------------------------------------------------------
  // streamNotifications(uid, role) — orderBy('timestamp') per spec. Docs
  // without a `timestamp` field will not appear; see seed.js migration.
  // -------------------------------------------------------------------------
  ```

- **Inline rationale** for surprising decisions. The single best example is the comment that explains why `splashViewModelProvider` is NOT `.autoDispose` (`splash_viewmodel.dart:113-117`).

- **Stub markers** for placeholder logic — e.g. `// Demo/stub progress per subject — deterministic variation until real per-subject progress tracking lands.` (`dashboard_viewmodel.dart:285-286`).

- **`///` doc comments** are used sparingly — only `Validators` and a handful of `profile_viewmodel` methods (e.g. "Returns null on success, user-facing error string otherwise."). View-models generally rely on banner comments and method names instead of dartdoc.

**No `TODO` / `FIXME` / `HACK` / `XXX` markers** in `lib/` — work-to-do is captured in inline prose comments rather than tagged markers.

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

---

*Convention analysis: 2026-05-17*
