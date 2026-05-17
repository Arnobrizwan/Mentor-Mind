# Testing Patterns

**Analysis Date:** 2026-05-17

## Test Framework

**Runner:** `flutter_test` (the SDK-bundled test runner — wraps Dart's `package:test` with widget-testing primitives).

**Declared in `pubspec.yaml`:**

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.12
  riverpod_generator: ^2.4.3
  injectable_generator: ^2.6.2
  flutter_lints: ^4.0.0
```

**Notably absent from `dev_dependencies`:**
- `integration_test` (Flutter's on-device end-to-end harness).
- `mocktail` / `mockito` (mock generation).
- `fake_cloud_firestore`, `firebase_auth_mocks`, `cloud_firestore_mocks` (Firebase fakes).
- `golden_toolkit` (golden-image testing).
- `patrol` (UI automation).
- `network_image_mock` (offline `Image.network` rendering).
- `riverpod_generator` is present but no `*_test.dart` consumes generated providers (no codegen artifacts exist anywhere in the repo).

**Config file:** none. No `dart_test.yaml`, no `flutter_test_config.dart`, no per-package overrides.

**Assertion library:** `expect` from `package:flutter_test/flutter_test.dart` (which re-exports `package:test`'s matchers).

**Run commands:**

```bash
flutter test                              # Run all tests in test/
flutter test test/widget_test.dart        # Single file
flutter test --coverage                   # Emit coverage/lcov.info
flutter test --reporter expanded          # Verbose
```

## Test File Organization

**Location:** `test/` at repo root, mirroring the standard Flutter scaffold.

**Files:**

```
test/
└── widget_test.dart           # Currently the only test file.
```

**Naming pattern (aspirational, since only one file exists today):** Flutter idiom is `<thing>_test.dart` — e.g. `auth_viewmodel_test.dart`, `login_screen_test.dart`. The current `test/widget_test.dart` follows the `flutter create` boilerplate name and should be renamed once real tests for the dashboard / chat / etc. land.

**No `integration_test/` directory** exists. There is no `test_driver/` either.

## Current Test File

**`test/widget_test.dart` — verbatim:**

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder', () {
    expect(1 + 1, 2);
  });
}
```

This is the entire test surface of the project. It replaces the original `flutter create` boilerplate `testWidgets(...)` (which `pumpWidget`-ed a `MyApp` that no longer exists) with a trivially-passing arithmetic check. There is **no** real verification of any production code in `lib/`.

## Test Structure (Idiomatic Targets for Future Work)

There is no codebase pattern to mirror because there is only one placeholder. The conventions below are the **Flutter-recommended** structure that future tests in this repo should follow, given the existing architecture (Riverpod 2.x + `StateNotifier`).

**Suite organization (idiomatic Flutter):**

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthViewModel', () {
    setUp(() {
      // Fresh dependencies per test.
    });

    tearDown(() {
      // Release resources.
    });

    group('loginWithEmail', () {
      test('returns null and sets error when email is invalid', () {
        // arrange / act / assert
      });

      test('returns AuthDestination.studentDashboard on success', () {});
    });
  });
}
```

**Widget tests** use `testWidgets` + `WidgetTester`:

```dart
testWidgets('LoginScreen shows email validation error', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authViewModelProvider.overrideWith((_) => FakeAuthVm())],
      child: const MaterialApp(home: LoginScreen()),
    ),
  );
  await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
  await tester.tap(find.text('Sign in'));
  await tester.pump();
  expect(find.text('Enter a valid email address'), findsOneWidget);
});
```

## Mocking

**Current approach:** none. No mocks, fakes, or test doubles exist anywhere in `lib/` or `test/`.

**Production code is tightly coupled to Firebase singletons.** Every view-model instantiates SDK clients directly inside the class:

```dart
final FirebaseAuth _auth = FirebaseAuth.instance;
final FirebaseFirestore _firestore = FirebaseFirestore.instance;
final FirebaseStorage _storage = FirebaseStorage.instance;
```
— pattern in `auth_viewmodel.dart`, `dashboard_viewmodel.dart`, `chat_viewmodel.dart`, `profile_viewmodel.dart`, `notifications_viewmodel.dart`, `rewards_viewmodel.dart`, `gamification_viewmodel.dart`, `materials_viewmodel.dart`, `search_viewmodel.dart`.

The single exception is `ChatViewModel`, which already accepts `GeminiService` via constructor injection (`chat_viewmodel.dart:189-194, 584-588`). That is the only view-model that can be unit-tested today without spinning up Firebase or refactoring.

**Recommended additions (when tests are introduced):**

| Dependency | Purpose |
|---|---|
| `mocktail: ^1.0.0` | Mock `FirebaseAuth`, `FirebaseFirestore` interfaces; no codegen required. Preferred over `mockito` because it works with null-safety out of the box. |
| `fake_cloud_firestore: ^3.0.0` | In-memory Firestore that honours `where` / `orderBy` / `whereIn`. Lets `DashboardViewModel`'s 4-stream init be tested end-to-end. |
| `firebase_auth_mocks: ^0.14.0` | Lightweight `MockFirebaseAuth` for sign-in / sign-out flows. |
| `firebase_storage_mocks: ^0.7.0` | For `ChatViewModel._uploadImage` and `ProfileViewModel.updateProfile` avatar paths. |
| `network_image_mock: ^2.1.1` | Wrap widget tests so `Image.network` / `CachedNetworkImage` don't try real HTTP. |
| `golden_toolkit: ^0.15.0` (or framework-native `matchesGoldenFile`) | Lock down theme regressions (`AppTheme.light`, palette tokens). |

**What to mock vs what not to mock (when tests land):**

- **DO mock** at the Firebase SDK boundary (`FirebaseAuth`, `FirebaseFirestore`, `FirebaseStorage`) — these are the integration points the view-models depend on.
- **DO** override Riverpod providers in widget tests via `ProviderScope(overrides: [...])` to substitute a `FakeAuthViewModel extends StateNotifier<AuthState>`. This is the canonical Riverpod test pattern and works with the existing `StateNotifierProvider.autoDispose` declarations.
- **DO NOT** mock plain value/state classes (`AuthState`, `DashboardState`, `ChatMessage`) — they are immutable and trivial to construct directly with their `const` constructors.
- **DO NOT** mock pure helpers (`Validators`, `AppColors`, `AppTextStyles`, `AppTheme`, `AppNotification.fromDoc`). Call them directly.
- **DO NOT** mock `GoRouter` — pass a real `GoRouter` with a stub route table, or assert on `context.goNamed` via a custom navigator observer.

## Fixtures and Factories

**Current state:** none.

**Recommended location when introduced:** `test/fixtures/` for canned Firestore document maps (JSON-ish), and `test/factories/` (or `test/_support/`) for in-code builders. Mirror the model files: `test/factories/dashboard_user_factory.dart` returning `DashboardUser` instances with sane defaults.

The existing `factory X.fromDoc(...)` constructors on `DashboardUser`, `ProfileUser`, `ChatMessage`, `AppNotification`, `SessionItem`, `MaterialItem` are already the right seam — feed them fake `Map<String, dynamic>` payloads (or `QueryDocumentSnapshot` mocks) and assert the parsed object.

## Coverage

**Current state:** effectively 0% of `lib/` is exercised. The placeholder test executes no production code.

**Enforcement:** none. No `min_coverage` flag, no CI gate, no `.coveragerc`-equivalent.

**View coverage locally (when tests exist):**

```bash
flutter test --coverage
# Generates coverage/lcov.info
genhtml coverage/lcov.info -o coverage/html   # requires lcov
open coverage/html/index.html
```

## Test Types

**Unit tests** — `test('...', () { ... })`. Not used. The first additions should target:

1. `lib/core/utils/validators.dart` — pure functions, zero dependencies, perfect starting point. Cover `name`, `email`, `password`, `loginPassword`, `confirmPassword`, `role` boundary cases.
2. `lib/features/onboarding/onboarding_viewmodel.dart` — no Firebase, only `SharedPreferences` (which has `SharedPreferences.setMockInitialValues({})` built into the package).
3. `lib/features/auth/auth_viewmodel.dart` validation paths — the input-checking branches in `loginWithEmail` / `registerWithEmail` run before any Firebase call and can be tested with throwaway state assertions.
4. Pure model parsing — `DashboardUser.fromDoc`, `ChatMessage.fromMap`, `AppNotification.fromDoc`, `_normalizeType` in `notifications_viewmodel.dart:83`.

**Widget tests** — `testWidgets('...', (tester) async { ... })`. Not used. Highest-value targets:

1. `LoginScreen` form validation flow (uses `Validators` and `_formKey.currentState.validate()`).
2. `OnboardingScreen` page transitions and subject toggling.
3. `DashboardScreen` empty / loading / error renders (drive by overriding `dashboardViewModelProvider` with a fake notifier emitting each `DashboardState`).
4. `_BadgesTab`, `_LeaderboardTab`, `_NotificationsList` — leaf widgets that consume providers via `ConsumerWidget`.

**Integration tests** — none. To add: `dev_dependencies: integration_test: { sdk: flutter }`, then `integration_test/<flow>_test.dart` files plus a `firebase_emulator_suite` config (Firestore + Auth + Storage emulators per `firebase.json`, which already exists at repo root). Run via `flutter test integration_test/<file>.dart -d <device>`.

**Golden tests** — none. Worth adding once `AppTheme.light` stabilises, to catch unintended visual regressions in the seven configured tokens (`appBarTheme`, `cardTheme`, `elevatedButtonTheme`, `inputDecorationTheme`, `dividerTheme`, `colorScheme`, `scaffoldBackgroundColor`).

## CI / CD

**No CI configured.** No `.github/workflows/` directory exists. No `bitbucket-pipelines.yml`, `.circleci/`, `.gitlab-ci.yml`, or `codemagic.yaml`. Tests are not run automatically on push or pull request.

**Recommended minimum** — `.github/workflows/ci.yml` running:

```bash
flutter pub get
flutter analyze
flutter test --coverage
```

…on `pull_request` and `push: main`. Add a build step (`flutter build apk --debug` and/or `flutter build ios --no-codesign`) once the test surface justifies the runtime cost.

## Common Patterns (for Future Tests)

**Async / stream testing:**

```dart
test('streamUser emits decoded DashboardUser', () async {
  final fake = FakeFirebaseFirestore();
  await fake.collection('users').doc('u1').set({'name': 'Arnob', 'role': 'student'});

  final vm = DashboardViewModel(/* injected fake */);
  await Future.delayed(Duration.zero); // let the stream fire
  expect(vm.state.user?.name, 'Arnob');
});
```

**Error-path testing (StateNotifier emits error into state, returns null):**

```dart
test('loginWithEmail with bad email sets error and returns null', () async {
  final vm = AuthViewModel();
  final result = await vm.loginWithEmail('not-an-email', 'pw');
  expect(result, isNull);
  expect(vm.state.error, contains('valid email'));
});
```

**Riverpod override pattern for widget tests:**

```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      dashboardViewModelProvider.overrideWith(
        (ref) => FakeDashboardViewModel(initial: DashboardState(
          dailyChallengeResetsAt: DateTime(2026, 5, 18),
          user: DashboardUser(/* ... */),
        )),
      ),
    ],
    child: const MaterialApp(home: DashboardScreen()),
  ),
);
```

This works because every screen-level provider in this repo is a `StateNotifierProvider` (see `CONVENTIONS.md` → Provider Naming) — `overrideWith` returns a fresh notifier per test.

## Testing Roadmap (Priority Order)

1. **Replace the placeholder with real unit tests for `Validators`** (`lib/core/utils/validators.dart`) — zero infrastructure required.
2. **Add `OnboardingViewModel` unit tests** using `SharedPreferences.setMockInitialValues`.
3. **Add `mocktail` + `fake_cloud_firestore` + `firebase_auth_mocks`** to `dev_dependencies` and write `AuthViewModel` happy/error path tests.
4. **Widget tests for `LoginScreen`, `RegisterScreen`, `OnboardingScreen`** (forms are the most regression-prone surface today).
5. **Spin up the Firebase Emulator Suite** (`firebase.json` already exists) and add `integration_test/` flows for register → login → dashboard → send-chat.
6. **Add `.github/workflows/ci.yml`** to run `flutter analyze` + `flutter test` on every PR.
7. **Add golden tests** for `AppTheme.light` smoke snapshots once UI is stable.

---

*Testing analysis: 2026-05-17*
