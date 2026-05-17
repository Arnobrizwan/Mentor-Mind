---
phase: 01-foundation-refactor-ci-test-harness-ios-identity
plan: 08
type: execute
wave: 2
depends_on: ["01-01", "01-03", "01-05"]
files_modified:
  - test/_support/factories/user_factory.dart
  - test/_support/factories/material_factory.dart
  - test/_support/factories/notification_factory.dart
  - test/_support/factories/message_factory.dart
  - test/_helpers/provider_scope_helpers.dart
  - test/core/utils/validators_test.dart
  - test/application/viewmodels/onboarding_viewmodel_test.dart
  - test/application/viewmodels/auth_viewmodel_test.dart
  - test/presentation/screens/dashboard_screen_test.dart
  - dart_test.yaml
autonomous: true
requirements: [CI-04, CI-05, CI-07]
requirements_addressed: [CI-04, CI-05, CI-07]
tags: [tests, anchor_tests, test_harness, mocktail, fake_cloud_firestore, firebase_auth_mocks, golden_toolkit, network_image_mock]

must_haves:
  truths:
    - "D-09: Harness + anchor tests strategy — Phase 1 ships exactly the 5 anchors (validators pure unit, onboarding_viewmodel via SharedPreferences mock, auth_viewmodel via mocktail+firebase_auth_mocks+fake_cloud_firestore, dashboard_screen widget test via ProviderScope.overrides, integration_test/login_smoke_test against emulator); full smoke coverage is deferred to Phase 7"
    - "Four anchor tests live in `test/` — one per new test-harness dev_dep category (`mocktail`, `fake_cloud_firestore`+`firebase_auth_mocks`, `network_image_mock`, validators-pure-unit); the 5th anchor (integration_test/login_smoke_test.dart) lives in Plan 09"
    - "`flutter test` exits 0 with all 4 tests passing"
    - "`flutter test --coverage` produces `coverage/lcov.info`"
    - "No test imports `package:mentor_minds/firebase_options.dart` or calls `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` (T-1-W0 — no real Firebase project credentials cross the test boundary)"
    - "Test directory mirrors lib/ structure per D-11 (`test/presentation/`, `test/application/`, `test/data/`, `test/core/`, plus `test/_support/` and `test/_helpers/`)"
    - "`golden_toolkit` is installed (CI-07) but ZERO golden files exist in `test/` (D-12 defers goldens to Phase 7)"
  artifacts:
    - path: "test/_helpers/provider_scope_helpers.dart"
      provides: "pumpWithProviders(...) helper that wires ProviderScope.overrides for SDK + repo seams"
      contains: "pumpWithProviders"
    - path: "test/_support/factories/user_factory.dart"
      provides: "buildDashboardUser / buildProfileUser test data builders"
      contains: "buildDashboardUser"
    - path: "test/core/utils/validators_test.dart"
      provides: "Anchor 1 — pure unit, no Firebase, exercises Validators boundaries"
      contains: "Validators.email"
    - path: "test/application/viewmodels/onboarding_viewmodel_test.dart"
      provides: "Anchor 2 — mocktail + SharedPreferences mock"
      contains: "SharedPreferences.setMockInitialValues"
    - path: "test/application/viewmodels/auth_viewmodel_test.dart"
      provides: "Anchor 3 — firebase_auth_mocks + fake_cloud_firestore + ProviderScope.overrides"
      contains: "MockFirebaseAuth|FakeFirebaseFirestore"
    - path: "test/presentation/screens/dashboard_screen_test.dart"
      provides: "Anchor 4 — widget test with network_image_mock + ProviderScope.overrideWith(viewmodel)"
      contains: "mockNetworkImagesFor"
    - path: "dart_test.yaml"
      provides: "Test tag config separating unit/widget/integration; emulator tag wired"
      contains: "tags"
  key_links:
    - from: "test/application/viewmodels/auth_viewmodel_test.dart"
      to: "lib/data/services/firebase_providers.dart"
      via: "ProviderScope.overrides for firestoreProvider + firebaseAuthProvider"
      pattern: "firestoreProvider\\.overrideWithValue|firebaseAuthProvider\\.overrideWithValue"
    - from: "test/presentation/screens/dashboard_screen_test.dart"
      to: "lib/application/viewmodels/dashboard/dashboard_viewmodel.dart"
      via: "ProviderScope.override dashboardViewModelProvider"
      pattern: "dashboardViewModelProvider"
---

<objective>
Land four anchor tests + scaffold the test harness directory structure so that CI-04 (smoke widget test), CI-05 (viewmodel unit test), and CI-07 (test deps installed and exercised) are partially satisfied for Phase 1 (full smoke coverage deferred to Phase 7 per D-09). Each anchor test exercises exactly one of the four new dev_deps so that "the deps work" is provable, not assumed: validators_test for pure unit, onboarding_viewmodel_test for `mocktail` + `SharedPreferences`, auth_viewmodel_test for `firebase_auth_mocks` + `fake_cloud_firestore`, dashboard_screen_test for `golden_toolkit` (install only — no golden) + `network_image_mock`.

Purpose: CI-04 / CI-05 / CI-07 are "the test harness is alive" requirements, not "every viewmodel + screen has a test" requirements (those are Phase 7). The anchor tests prove the harness boots, the SDK provider override pattern works for Riverpod, and CI's `flutter test --coverage` produces an artifact. Plan 10 (CI) wires `flutter test --coverage` as a blocking job; Plan 09 wires the emulator integration test (Anchor 5). This plan covers the four in-process anchors only.

Output: 4 test files + 4 factories + 1 provider-scope helper + 1 dart_test.yaml; `flutter test --coverage` green; coverage/lcov.info present; zero golden files; T-1-W0 mitigated (no real Firebase credentials cross the test boundary).
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-CONTEXT.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-PATTERNS.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md
@CLAUDE.md
@lib/core/utils/validators.dart
@lib/application/viewmodels/onboarding/onboarding_viewmodel.dart
@lib/application/viewmodels/auth/auth_viewmodel.dart
@lib/application/viewmodels/dashboard/dashboard_viewmodel.dart
@lib/presentation/screens/dashboard/dashboard_screen.dart
@lib/data/services/firebase_providers.dart
@lib/data/repositories/users_repository.dart
@lib/data/repositories/auth_repository.dart
@lib/data/models/dashboard_user.dart
@lib/data/models/badge_item.dart
@lib/data/models/session_item.dart
@lib/data/models/material_item.dart

<interfaces>
<!-- Anchor test specifications from RESEARCH § Pattern 7 lines 617-731 + CONTEXT.md D-09 + D-11 -->

Five anchor tests originally specified (D-09); this plan ships FOUR (the fifth — integration emulator smoke — is Plan 09):

  Anchor 1 — Validators pure-unit (`test/core/utils/validators_test.dart`):
    - Imports: `package:flutter_test/flutter_test.dart`, `package:mentor_minds/core/utils/validators.dart`.
    - No Firebase, no Riverpod, no SharedPreferences.
    - Covers: email / name / password / loginPassword / confirmPassword / role — happy + edge per the `Validators` abstract final class surface.
    - Exercises: NOTHING from the new dev_deps. This is the "pure unit baseline" — proves `flutter test` runs at all post-Plan-01.

  Anchor 2 — OnboardingViewModel + SharedPreferences mock (`test/application/viewmodels/onboarding_viewmodel_test.dart`):
    - Imports: `flutter_test`, `mocktail`, `shared_preferences`, the viewmodel.
    - `SharedPreferences.setMockInitialValues({})` in `setUp`.
    - Exercises: `mocktail` (CI-07).
    - One happy path (state initial value), one mutation path (selectedLevel update).

  Anchor 3 — AuthViewModel + Firebase mocks (`test/application/viewmodels/auth_viewmodel_test.dart`):
    - Imports: `flutter_test`, `flutter_riverpod`, `firebase_auth_mocks`, `fake_cloud_firestore`, the viewmodel, `lib/data/services/firebase_providers.dart`.
    - Uses `ProviderContainer(overrides: [firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()), firestoreProvider.overrideWithValue(FakeFirebaseFirestore())])` (RESEARCH § Anchor Test 3 lines 658-684).
    - Exercises: `firebase_auth_mocks` + `fake_cloud_firestore` (CI-07).
    - Test cases: (a) `loginWithEmail('not-an-email', 'password')` returns null + sets state.error; (b) `loginWithEmail` with valid pre-seeded user returns AuthDestination.studentDashboard or similar.

  Anchor 4 — DashboardScreen widget test (`test/presentation/screens/dashboard_screen_test.dart`):
    - Imports: `flutter_test`, `flutter_riverpod`, `network_image_mock`, the screen, the viewmodel.
    - `mockNetworkImagesFor` wrapper around `tester.pumpWidget`.
    - `ProviderScope(overrides: [dashboardViewModelProvider.overrideWith((ref) => FakeDashboardViewModel())])`.
    - `FakeDashboardViewModel` is a `StateNotifier<DashboardState>` subclass that returns a hardcoded `DashboardState` with sample `DashboardUser`, recent sessions, materials, badges. Define it inline in the test file (the codebase has no shared test doubles yet).
    - Exercises: `network_image_mock` + `golden_toolkit` (the latter only via the implicit `loadAppFonts()` call if used; no actual golden files — D-12).
    - Assertion: `find.byType(DashboardScreen)` returns one widget AND `find.text(<sample user's first name>)` returns one widget (the greeting header).

  Anchor 5 — Integration emulator smoke (`integration_test/login_smoke_test.dart`): **Plan 09**, not this plan.

Factories (D-11 + Claude's Discretion line 106):
  test/_support/factories/user_factory.dart — `DashboardUser buildDashboardUser({String uid = 'test-uid', String name = 'Test Learner', int points = 0, ...})` + `ProfileUser buildProfileUser(...)`.
  test/_support/factories/material_factory.dart — `MaterialItem buildMaterialItem(...)` + `LearningMaterial buildLearningMaterial(...)`.
  test/_support/factories/notification_factory.dart — `AppNotification buildAppNotification(...)`.
  test/_support/factories/message_factory.dart — `ChatMessage buildChatMessage(...)`.

ProviderScope helper (test/_helpers/provider_scope_helpers.dart):
  Future<void> pumpWithProviders(WidgetTester tester, Widget child, {List<Override> overrides = const [], bool wrapInMaterialApp = true});
  // Wraps `child` in ProviderScope + optional MaterialApp; calls tester.pumpWidget; awaits pump-and-settle.
  ProviderContainer makeContainer({List<Override> overrides = const []});
  // For pure logic tests that don't need a widget tree — uses ProviderContainer directly + addTearDown(container.dispose).

dart_test.yaml (D-11 + VALIDATION.md Wave 0 Requirements):
  tags:
    unit: { skip: false }
    widget: { skip: false }
    integration: { skip: false }   # default skip false; CI may pass --tags integration to run only those
    emulator: { skip: false }      # Plan 09's integration smoke test uses this tag

T-1-W0 mitigation rule (CONTEXT.md § threat model):
  NO test file imports `package:mentor_minds/firebase_options.dart`.
  NO test file calls `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.
  All Firebase access goes through `firebaseAuthProvider`/`firestoreProvider`/`firebaseStorageProvider` overrides with `FakeFirebaseFirestore`/`MockFirebaseAuth` substitutes.
  The integration test in Plan 09 is the only place real-but-emulated Firebase touches the test process.

Plan 03 import-convention dependency:
  Test imports of source files use the package-style `package:mentor_minds/...` form regardless of which convention Plan 03 chose for cross-feature imports inside lib/ — tests are external consumers and `package:` is unambiguous.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Scaffold test harness — factories, ProviderScope helper, dart_test.yaml</name>
  <files>test/_support/factories/user_factory.dart, test/_support/factories/material_factory.dart, test/_support/factories/notification_factory.dart, test/_support/factories/message_factory.dart, test/_helpers/provider_scope_helpers.dart, dart_test.yaml</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-CONTEXT.md (D-11 — directory structure; Claude's Discretion — factory naming)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md (§ Wave 0 Requirements — list of test/_support/factories files; dart_test.yaml mention)
    - /Users/arnobrizwan/Mentor-Mind/.planning/codebase/TESTING.md (if it exists — the recommended "Riverpod override pattern" recipe referenced in CONTEXT.md § canonical_refs line 128)
    - /Users/arnobrizwan/Mentor-Mind/lib/data/models/dashboard_user.dart (post-Plan-04 model — confirm constructor signature for the factory to build)
    - /Users/arnobrizwan/Mentor-Mind/lib/data/models/profile_user.dart (same)
    - /Users/arnobrizwan/Mentor-Mind/lib/data/models/session_item.dart (same)
    - /Users/arnobrizwan/Mentor-Mind/lib/data/models/material_item.dart (same)
    - /Users/arnobrizwan/Mentor-Mind/lib/data/models/learning_material.dart (same)
    - /Users/arnobrizwan/Mentor-Mind/lib/data/models/app_notification.dart (same)
    - /Users/arnobrizwan/Mentor-Mind/lib/data/models/chat_message.dart (same)
  </read_first>
  <action>
    Create the test/_support and test/_helpers scaffolding before writing any anchor test. Without factories + the pumpWithProviders helper, every anchor test repeats the same boilerplate; with them, each anchor test stays under 50 lines.

    Step A — `test/_support/factories/user_factory.dart`:
      ```
      import 'package:mentor_minds/data/models/dashboard_user.dart';
      import 'package:mentor_minds/data/models/profile_user.dart';

      DashboardUser buildDashboardUser({
        String uid = 'test-uid',
        String name = 'Test Learner',
        // ... all named params matching the constructor, each with a sensible default
      }) { return DashboardUser(uid: uid, name: name, ...); }

      ProfileUser buildProfileUser({String uid = 'test-uid', String name = 'Test Learner', String email = 'test@example.com', ...}) { ... }
      ```
      Match the CONSTRUCTOR signature exactly (read the model file). Use the same defaults across factories (`uid: 'test-uid'`, `name: 'Test Learner'`) for cross-test consistency.

    Step B — `test/_support/factories/material_factory.dart`:
      Builders for `MaterialItem` AND `LearningMaterial` (both extracted in Plan 04; both kept separate per PATTERNS.md verdict).
      For `MaterialItem`, the `gradient: List<Color>` field needs default colors — use `const [Color(0xFF1A3C8F), Color(0xFF00C9A7)]` (the brand palette from AppColors).

    Step C — `test/_support/factories/notification_factory.dart`:
      `AppNotification buildAppNotification({String id = 'notif-1', String title = 'Test', String body = 'Test body', String type = 'general', String recipientRole = 'student', DateTime? timestamp, bool read = false})`.

    Step D — `test/_support/factories/message_factory.dart`:
      `ChatMessage buildChatMessage({String id = 'msg-1', String content = 'hello', MessageRole role = MessageRole.user, DateTime? createdAt})`.
      Import the `MessageRole` enum from wherever Plan 04 left it (likely still inside `chat_viewmodel.dart` as a file-local enum, OR if Plan 04 extracted it to `lib/data/models/chat_message.dart` then import from there).

    Step E — `test/_helpers/provider_scope_helpers.dart`:
      ```
      import 'package:flutter/material.dart';
      import 'package:flutter_riverpod/flutter_riverpod.dart';
      import 'package:flutter_test/flutter_test.dart';

      Future<void> pumpWithProviders(
        WidgetTester tester,
        Widget child, {
        List<Override> overrides = const [],
        bool wrapInMaterialApp = true,
      }) async {
        final widget = wrapInMaterialApp ? MaterialApp(home: child) : child;
        await tester.pumpWidget(ProviderScope(overrides: overrides, child: widget));
        await tester.pumpAndSettle();
      }

      ProviderContainer makeContainer({List<Override> overrides = const []}) {
        final container = ProviderContainer(overrides: overrides);
        addTearDown(container.dispose);
        return container;
      }
      ```

    Step F — `dart_test.yaml` at repo root:
      ```yaml
      # dart_test.yaml — Phase 1 test tag configuration.
      # Tags partition the test suite so CI can run subsets:
      #   `flutter test --tags unit` — fast unit tests only
      #   `flutter test --tags widget` — widget tests
      #   `flutter test --tags emulator` — emulator-dependent integration tests (Plan 09)
      tags:
        unit:
        widget:
        emulator:
      ```
      Test files opt into tags via `@Tags(['unit'])` or `testWidgets('...', (tester) async {...}, tags: ['widget'])` — for Phase 1, leave tags optional (untagged tests still run with the default `flutter test` invocation). Tags become mandatory in Plan 09 for the emulator test.

    Step G — Run `flutter test` (no tests yet, but the analyzer must accept the new test files):
      `flutter analyze --fatal-warnings test/` → must exit 0.

    Commit message: `test(harness): scaffold factories + ProviderScope helpers + dart_test.yaml (Phase 1 / CI-07; D-11)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; for f in user_factory material_factory notification_factory message_factory; do test -f "test/_support/factories/${f}.dart" || { echo "MISSING: test/_support/factories/${f}.dart"; exit 2; }; done</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f test/_helpers/provider_scope_helpers.dart &amp;&amp; grep -q 'pumpWithProviders\b' test/_helpers/provider_scope_helpers.dart &amp;&amp; grep -q 'makeContainer\b' test/_helpers/provider_scope_helpers.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f dart_test.yaml &amp;&amp; grep -q '^tags:' dart_test.yaml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --fatal-warnings test/ 2>&amp;1 | tee /tmp/p1-08-t1-analyze.txt &amp;&amp; ! grep -qE '^\s*(error|warning) -' /tmp/p1-08-t1-analyze.txt</automated>
  </verify>
  <acceptance_criteria>
    - All 4 factory files exist at `test/_support/factories/`.
    - `test/_helpers/provider_scope_helpers.dart` exists and declares both `pumpWithProviders` and `makeContainer`.
    - `dart_test.yaml` exists at repo root with a `tags:` section.
    - `flutter analyze --fatal-warnings test/` exits 0.
    - No file under `test/` imports `package:mentor_minds/firebase_options.dart` (T-1-W0 invariant; verified by grep in Task 4).
  </acceptance_criteria>
  <done>
    Test harness scaffolding is in place. Anchor tests in Tasks 2 and 3 can use `pumpWithProviders` + factories instead of re-inventing them.
  </done>
</task>

<task type="auto">
  <name>Task 2: Anchor 1 (validators) + Anchor 2 (onboarding viewmodel)</name>
  <files>test/core/utils/validators_test.dart, test/application/viewmodels/onboarding_viewmodel_test.dart</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/lib/core/utils/validators.dart (the abstract final class surface — confirm method names: `email`, `name`, `password`, `loginPassword`, `confirmPassword`, `role`; each returns `String?` where null means valid)
    - /Users/arnobrizwan/Mentor-Mind/lib/application/viewmodels/onboarding/onboarding_viewmodel.dart (state class + StateNotifier methods; the `kSubjects` top-level constant)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md (§ Anchor Test 1 lines 619-637; § Anchor Test 2 lines 639-655)
  </read_first>
  <action>
    Two independent test files. Write Anchor 1 first because it has zero dependencies; Anchor 2 brings in `mocktail` + `SharedPreferences`.

    Step A — Anchor 1: `test/core/utils/validators_test.dart`:
      Pure unit test. Imports: `flutter_test`, `package:mentor_minds/core/utils/validators.dart`. No other deps.
      Test groups:
        - `Validators.email`: returns null for `test@example.com`; returns non-null for `'notanemail'`, `'no-at.com'`, `''`, `null`.
        - `Validators.name`: returns null for `'Test Learner'`; returns non-null for `''`, `null`, single character (if the rule rejects it).
        - `Validators.password`: returns null for a string ≥6 chars (read the rule from the source); returns non-null for `'abc'`, `''`, `null`.
        - `Validators.loginPassword`: similar; may differ from password (e.g. allow non-empty without length check). Mirror the actual rule.
        - `Validators.confirmPassword(password, confirm)`: returns null when both match; returns non-null when they differ.
        - `Validators.role(String?)`: returns null for `'student'` / `'teacher'` / `'admin'` (whatever the enum allows); returns non-null for anything else.
      Each test ≤3 lines (one `expect(... , isNull|isNotNull)` per case). No setUp / tearDown.

    Step B — Anchor 2: `test/application/viewmodels/onboarding_viewmodel_test.dart`:
      Imports: `flutter_test`, `mocktail` (even if not directly used in this minimal test — having the import proves the dep resolves), `shared_preferences`, the viewmodel.
      `setUp(() { SharedPreferences.setMockInitialValues({}); });` (RESEARCH § Anchor Test 2 line 647).
      Test cases (2 cases per CONTEXT.md D-09 "happy path + error path" pattern):
        1. `test('initial state has no level selected', () async { final vm = OnboardingViewModel(); expect(vm.state.selectedLevel, isNull); expect(vm.state.selectedSubjects, isEmpty); });`
        2. `test('selectLevel updates state', () async { final vm = OnboardingViewModel(); vm.selectLevel('O Level'); expect(vm.state.selectedLevel, 'O Level'); });`
      If `OnboardingViewModel` has dependencies (e.g. a `SharedPreferences` instance injected via constructor), the factory call needs to reflect them. Read the viewmodel; if it news up `SharedPreferences.getInstance()` itself, the test still works because of the mock initial values.

    Step C — Run `flutter test test/core/utils/validators_test.dart test/application/viewmodels/onboarding_viewmodel_test.dart`:
      Must exit 0.
      Capture output to confirm test count (≥6 in validators, ≥2 in onboarding) and zero failures.

    Commit message: `test(anchor): add validators + onboarding_viewmodel anchor tests (Phase 1 / CI-04, CI-05; D-09 anchors 1+2)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f test/core/utils/validators_test.dart &amp;&amp; test -f test/application/viewmodels/onboarding_viewmodel_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "import 'package:flutter_test/flutter_test\.dart'" test/core/utils/validators_test.dart &amp;&amp; grep -q 'Validators\.email' test/core/utils/validators_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "SharedPreferences\.setMockInitialValues" test/application/viewmodels/onboarding_viewmodel_test.dart &amp;&amp; grep -q "import 'package:mocktail" test/application/viewmodels/onboarding_viewmodel_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter test test/core/utils/validators_test.dart test/application/viewmodels/onboarding_viewmodel_test.dart 2>&amp;1 | tee /tmp/p1-08-t2-test.log &amp;&amp; grep -q 'All tests passed\|+0 -0' /tmp/p1-08-t2-test.log &amp;&amp; ! grep -q 'Some tests failed\|Tests failed' /tmp/p1-08-t2-test.log</automated>
  </verify>
  <acceptance_criteria>
    - Both anchor test files exist at the paths above.
    - `validators_test.dart` imports `flutter_test` and references `Validators.email`.
    - `onboarding_viewmodel_test.dart` calls `SharedPreferences.setMockInitialValues(...)` and imports `mocktail` (proves the dep is resolved even if mocks aren't strictly required for this trivial test).
    - `flutter test <both files>` exits 0 with "All tests passed" or equivalent zero-failure indicator.
  </acceptance_criteria>
  <done>
    Anchors 1 + 2 land. `mocktail` is exercised by import. The pure-unit baseline runs in <5 seconds. Plan 10's `flutter test --coverage` can produce coverage rows for `validators.dart` and `onboarding_viewmodel.dart`.
  </done>
</task>

<task type="auto">
  <name>Task 3: Anchor 3 (auth viewmodel + firebase mocks) + Anchor 4 (dashboard widget + network_image_mock)</name>
  <files>test/application/viewmodels/auth_viewmodel_test.dart, test/presentation/screens/dashboard_screen_test.dart</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/lib/application/viewmodels/auth/auth_viewmodel.dart (post-Plan-05 — uses AuthRepository; signature of `loginWithEmail`, error-mapping switch on FirebaseAuthException)
    - /Users/arnobrizwan/Mentor-Mind/lib/data/repositories/auth_repository.dart (Plan 05's auth repo — confirm its constructor params; the test overrides `firebaseAuthProvider` so the repo gets a `MockFirebaseAuth` instance)
    - /Users/arnobrizwan/Mentor-Mind/lib/data/services/firebase_providers.dart (the three SDK providers — test overrides them)
    - /Users/arnobrizwan/Mentor-Mind/lib/application/viewmodels/dashboard/dashboard_viewmodel.dart (post-Plan-05 — confirm the provider declaration to override; state class has `firstName` getter for the greeting assertion)
    - /Users/arnobrizwan/Mentor-Mind/lib/presentation/screens/dashboard/dashboard_screen.dart (post-Plan-03 — confirm widget hierarchy + text widgets to assert against)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md (§ Anchor Test 3 lines 658-684; § Anchor Test 4 lines 686-711)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-CONTEXT.md (D-12 — golden_toolkit installed but ZERO goldens written)
  </read_first>
  <action>
    Two more anchor tests. Anchor 3 exercises Firebase mocks; Anchor 4 exercises the widget + ProviderScope override pattern.

    Step A — Anchor 3: `test/application/viewmodels/auth_viewmodel_test.dart`:
      Imports:
        ```
        import 'package:flutter_riverpod/flutter_riverpod.dart';
        import 'package:flutter_test/flutter_test.dart';
        import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
        import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
        import 'package:mentor_minds/application/viewmodels/auth/auth_viewmodel.dart';
        import 'package:mentor_minds/data/services/firebase_providers.dart';
        import '../../_helpers/provider_scope_helpers.dart';
        ```
      Test cases (D-09: "one happy path + one error path"):
        1. `test('loginWithEmail with invalid email returns null + sets error', () async { ... });`
           Inside: create container with overrides for `firebaseAuthProvider` (`MockFirebaseAuth()`) + `firestoreProvider` (`FakeFirebaseFirestore()`). Read `authViewModelProvider.notifier`. Call `loginWithEmail('not-an-email', 'password')`. Expect return value `null` and `container.read(authViewModelProvider).error` is non-null.
        2. `test('loginWithEmail with valid email succeeds and returns destination', () async { ... });`
           Pre-seed `MockFirebaseAuth(mockUser: MockUser(uid: 'test-uid', email: 'test@example.com'))`. Pre-seed the `FakeFirebaseFirestore` with a `/users/test-uid` doc that has `role: 'student'`. Call `loginWithEmail('test@example.com', 'password123')`. Expect non-null `AuthDestination` (likely `AuthDestination.studentDashboard`).
      Use `makeContainer(overrides: [...])` from the helper for both cases.
      If `MockFirebaseAuth`'s API in `firebase_auth_mocks ^0.14.2` differs from training-data assumptions, follow the actual API surface — read pub.dev docs if necessary. The pattern `MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: '...'))` is the canonical form for `^0.14.x`.

    Step B — Anchor 4: `test/presentation/screens/dashboard_screen_test.dart`:
      Imports:
        ```
        import 'package:flutter/material.dart';
        import 'package:flutter_riverpod/flutter_riverpod.dart';
        import 'package:flutter_test/flutter_test.dart';
        import 'package:network_image_mock/network_image_mock.dart';
        import 'package:mentor_minds/application/viewmodels/dashboard/dashboard_viewmodel.dart';
        import 'package:mentor_minds/presentation/screens/dashboard/dashboard_screen.dart';
        import '../../_support/factories/user_factory.dart';
        ```
      Define a `FakeDashboardViewModel` class at the top of the test file:
        ```
        class FakeDashboardViewModel extends StateNotifier<DashboardState> implements DashboardViewModel {
          FakeDashboardViewModel() : super(DashboardState(
            isLoading: false,
            user: buildDashboardUser(name: 'Anchor Tester'),
            recentSessions: const [],
            materials: const [],
            // ... other DashboardState fields with safe defaults
          ));
          // Stub out viewmodel methods that the screen might call from event handlers.
          // For the smoke test (mount-only assertion), no-op overrides are enough.
          @override void noSuchMethod(Invocation invocation) {}
        }
        ```
      Test:
        ```
        testWidgets('DashboardScreen mounts and renders greeting', (tester) async {
          await mockNetworkImagesFor(() async {
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  dashboardViewModelProvider.overrideWith((ref) => FakeDashboardViewModel()),
                ],
                child: const MaterialApp(home: DashboardScreen()),
              ),
            );
            await tester.pump();
            expect(find.byType(DashboardScreen), findsOneWidget);
            expect(find.textContaining('Anchor'), findsWidgets);  // matches greeting "Hi, Anchor" or similar
          });
        });
        ```
      DO NOT call `await tester.pumpAndSettle()` — the dashboard has perpetual animations (shimmer) that never settle. Use `tester.pump()` for one frame only.
      DO NOT write a golden file (D-12). `golden_toolkit` is imported transitively by being in pubspec; we don't call `screenMatchesGolden` here.
      Tag the test with `tags: ['widget']` per the dart_test.yaml from Task 1.

    Step C — Run the new anchors plus the existing ones:
      `flutter test test/` → exits 0; all 4 anchor tests pass.
      Capture full output to `/tmp/p1-08-t3-test.log` and confirm 4+ test files contributed at least 7 passing tests in total (6 from validators, 2 from onboarding, 2 from auth, 1 from dashboard).

    Commit message: `test(anchor): add auth_viewmodel + dashboard_screen anchor tests (Phase 1 / CI-04, CI-05; D-09 anchors 3+4; D-12 no goldens)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f test/application/viewmodels/auth_viewmodel_test.dart &amp;&amp; test -f test/presentation/screens/dashboard_screen_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'MockFirebaseAuth\|MockUser' test/application/viewmodels/auth_viewmodel_test.dart &amp;&amp; grep -q 'FakeFirebaseFirestore' test/application/viewmodels/auth_viewmodel_test.dart &amp;&amp; grep -q 'firebaseAuthProvider\|firestoreProvider' test/application/viewmodels/auth_viewmodel_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'mockNetworkImagesFor' test/presentation/screens/dashboard_screen_test.dart &amp;&amp; grep -q 'dashboardViewModelProvider' test/presentation/screens/dashboard_screen_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; n=$(find test -name '*_test.dart' -type f | wc -l | tr -d ' '); test "$n" -ge 4</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter test test/ 2>&amp;1 | tee /tmp/p1-08-t3-test.log &amp;&amp; grep -q 'All tests passed' /tmp/p1-08-t3-test.log</automated>
  </verify>
  <acceptance_criteria>
    - Both anchor test files exist at the paths above.
    - `auth_viewmodel_test.dart` references `MockFirebaseAuth`, `FakeFirebaseFirestore`, and either `firebaseAuthProvider` or `firestoreProvider` (proves the override pattern from Plan 05's seam).
    - `dashboard_screen_test.dart` references `mockNetworkImagesFor` and `dashboardViewModelProvider` (proves both the network_image_mock dep + the ProviderScope.overrideWith pattern).
    - At least 4 `*_test.dart` files exist under `test/`.
    - `flutter test test/` exits 0 with "All tests passed" in stdout.
  </acceptance_criteria>
  <done>
    All 4 in-process anchors are alive. `mocktail`, `fake_cloud_firestore`, `firebase_auth_mocks`, `network_image_mock` are each exercised by at least one test. `golden_toolkit` is installed (verified by `flutter pub deps` in Plan 01) but no goldens written (D-12). Plan 10's `flutter test --coverage` job is ready to run.
  </done>
</task>

<task type="auto">
  <name>Task 4: Coverage gate + T-1-W0 invariant check + golden absence assertion</name>
  <files>(no edits — verification only)</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md (§ Validation Sign-Off — coverage artifact upload pattern; § Per-Task Verification Map row 01-w0-anchor-tests automated command)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-CONTEXT.md (D-12 — zero goldens in Phase 1)
  </read_first>
  <action>
    Three closure checks that prove the harness is CI-ready.

    Step A — Coverage artifact:
      Run `flutter test --coverage`. Confirm `coverage/lcov.info` exists and is non-empty.
      Record the row count of `coverage/lcov.info` in SUMMARY.md as a baseline. Coverage threshold is NOT enforced in Phase 1 (D-13).

    Step B — T-1-W0 invariant — no real Firebase project credentials in tests:
      `grep -RIn 'DefaultFirebaseOptions\.currentPlatform' test/ integration_test/ 2>/dev/null` — must return ZERO matches. (Plan 09's emulator test does NOT need `DefaultFirebaseOptions.currentPlatform` either — it uses `useFirestoreEmulator` overrides.)
      `grep -RIln "package:mentor_minds/firebase_options\.dart" test/ 2>/dev/null` — must return ZERO matches.
      `grep -RIn 'Firebase\.initializeApp' test/ 2>/dev/null` — must return ZERO matches in `test/` (Plan 09's `integration_test/login_smoke_test.dart` is the ONLY allowed `Firebase.initializeApp` site).

    Step C — D-12 zero-goldens invariant:
      `find test -name '*.png' -o -name '*goldens*' 2>/dev/null | wc -l` — must return 0. No golden image files; no `test/goldens/` directory.

    Commit message (if any cleanup): `chore(test): assert T-1-W0 + zero-goldens invariants (Phase 1 closure check)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; rm -f coverage/lcov.info; flutter test --coverage 2>&amp;1 | tee /tmp/p1-08-t4-coverage.log &amp;&amp; test -s coverage/lcov.info</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -RIn 'DefaultFirebaseOptions\.currentPlatform' test/ 2>/dev/null</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -RIln "package:mentor_minds/firebase_options\.dart" test/ 2>/dev/null</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -RIn 'Firebase\.initializeApp' test/ 2>/dev/null</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; n=$(find test -name '*.png' -type f 2>/dev/null | wc -l | tr -d ' '); test "$n" -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! test -d test/goldens</automated>
  </verify>
  <acceptance_criteria>
    - `coverage/lcov.info` exists and is non-empty after `flutter test --coverage`.
    - Zero references to `DefaultFirebaseOptions.currentPlatform`, `package:mentor_minds/firebase_options.dart`, or `Firebase.initializeApp` in `test/` (T-1-W0 closed for in-process tests).
    - Zero `*.png` files and no `test/goldens/` directory (D-12 honored).
  </acceptance_criteria>
  <done>
    Coverage artifact is producible. T-1-W0 is mitigated for all in-process tests (Plan 09 covers the emulator side). D-12 is honored — golden_toolkit is installed but not exercised. The CI-04, CI-05, CI-07 partial-Phase-1 requirements are satisfied; Phase 7 will extend coverage to all 12 screens + all viewmodels.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| test process ⇄ Firebase project | Tests must NEVER authenticate against the real `mentor-mind-aa765` project; mocks + fakes substitute every SDK seam |
| test fixtures ⇄ source models | Factories build canonical test data; deviation from the model's constructor signature breaks tests AND signals a model change that needs reconciliation |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-1-W0 | Information Disclosure | A test inadvertently importing `package:mentor_minds/firebase_options.dart` and calling `Firebase.initializeApp` would authenticate the test process against the real Firebase project, leak project metadata into the test runner's network, and potentially mutate production Firestore data | mitigate | Task 4 greps `test/` for `DefaultFirebaseOptions.currentPlatform`, `firebase_options.dart`, and `Firebase.initializeApp` — all three must return zero matches; the only allowed `Firebase.initializeApp` site is Plan 09's `integration_test/login_smoke_test.dart` which boots against the emulator (host:port overrides) |
| T-1-FLAKY | Repudiation | A widget test that calls `tester.pumpAndSettle()` on a screen with perpetual animations (shimmer) hangs forever, then times out, producing a flaky CI signal | mitigate | Anchor 4 uses `tester.pump()` for one frame only (RESEARCH § Anchor Test 4); Plan 10's CI workflow has the default 5-minute job timeout from GitHub Actions which would catch any regression |
| T-1-MOCK-LEAK | Information Disclosure | `mocktail` "fallbackValues" can leak across tests if not registered cleanly | accept | This plan's tests don't use `registerFallbackValue` extensively; Phase 7 may need additional fallback hygiene as the test surface grows |
</threat_model>

<verification>
- Test directory mirrors `lib/` per D-11 (`test/presentation/`, `test/application/`, `test/data/`, `test/core/`).
- 4 anchor tests + 4 factories + 1 ProviderScope helper + 1 dart_test.yaml.
- `flutter test --coverage` exits 0 with all anchor tests passing.
- `coverage/lcov.info` produced and non-empty.
- T-1-W0 invariant: zero real Firebase project references in `test/`.
- D-12 invariant: zero golden files; no `test/goldens/` directory.
- `flutter analyze --fatal-warnings` exits 0 across the whole tree (lib + test).
</verification>

<success_criteria>
- D-09 honored: 4 of 5 anchor tests installed (the 5th — emulator smoke — is Plan 09).
- D-11 honored: test directory mirrors lib/.
- D-12 honored: zero goldens.
- CI-04 partially satisfied (1 of 12 screens has a smoke test — full coverage Phase 7).
- CI-05 partially satisfied (2 of ~12 viewmodels — full coverage Phase 7).
- CI-07 satisfied: all 6 test deps are exercised by at least one test (mocktail in Anchor 2, fake_cloud_firestore + firebase_auth_mocks in Anchor 3, network_image_mock in Anchor 4, golden_toolkit by import-only per D-12, integration_test by Plan 09).
- T-1-W0 closed for in-process tests.
</success_criteria>

<output>
Create `.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-08-test-harness-anchors-SUMMARY.md` when done. Record: the file tree under `test/` (find . -name '*.dart' on the test dir), the test counts per file (passing/failing/total), the `flutter test --coverage` final summary line, the `coverage/lcov.info` row count, the literal `grep` outputs for the T-1-W0 invariant (DefaultFirebaseOptions + firebase_options + Firebase.initializeApp), and confirmation that `test/goldens/` does not exist.
</output>
