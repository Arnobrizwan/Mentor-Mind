---
phase: 01-foundation-refactor-ci-test-harness-ios-identity
plan: 09
type: execute
wave: 2
depends_on: ["01-01", "01-08"]
files_modified:
  - integration_test/login_smoke_test.dart
  - test/_helpers/emulator_setup.dart
  - lib/main.dart
  - dart_test.yaml
autonomous: true
requirements: [CI-06]
requirements_addressed: [CI-06]
tags: [integration_test, firebase_emulator, useAuthEmulator, useFirestoreEmulator, useStorageEmulator]

must_haves:
  truths:
    - "D-09: This plan ships anchor #5 of the 5 — `integration_test/login_smoke_test.dart` (the four others ship in Plan 08)"
    - "D-10: Emulator suite scope is Auth + Firestore + Storage only; the integration test targets the emulator by default via `useAuthEmulator`/`useFirestoreEmulator`/`useStorageEmulator`, and the Functions emulator is explicitly NOT wired (lands in Phase 2)"
    - "`integration_test/login_smoke_test.dart` exists and is tagged `emulator`"
    - "The test wires `FirebaseFirestore.useFirestoreEmulator('localhost', 8080)`, `FirebaseAuth.useAuthEmulator('localhost', 9099)`, `FirebaseStorage.useStorageEmulator('localhost', 9199)` BEFORE any Firestore/Auth/Storage call"
    - "`lib/main.dart` (or a test-only bootstrap) reads `--dart-define=USE_EMULATOR=true` and conditionally invokes the emulator wiring"
    - "Running `firebase emulators:start --only auth,firestore,storage` (from Plan 01's config) + `flutter test integration_test/login_smoke_test.dart --dart-define=USE_EMULATOR=true -d <simulator>` exits 0 with the test passing"
    - "The integration test creates a test user via the Auth emulator API in `setUpAll`, then exercises the sign-in path; verifies the dashboard route is reached"
    - "No real Firebase project credentials are used — `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` is allowed in this test (and only here per Plan 08 Task 4's exception)"
  artifacts:
    - path: "integration_test/login_smoke_test.dart"
      provides: "Anchor 5 — end-to-end sign-in smoke test against the Firebase Emulator Suite"
      contains: "useAuthEmulator|useFirestoreEmulator|useStorageEmulator"
    - path: "test/_helpers/emulator_setup.dart"
      provides: "configureEmulators() helper called from main.dart conditionally on USE_EMULATOR"
      contains: "useAuthEmulator"
    - path: "lib/main.dart"
      provides: "Conditional emulator wiring driven by --dart-define=USE_EMULATOR=true"
      contains: "USE_EMULATOR"
  key_links:
    - from: "integration_test/login_smoke_test.dart"
      to: "test/_helpers/emulator_setup.dart"
      via: "import + call configureEmulators() in setUpAll"
      pattern: "configureEmulators"
    - from: "lib/main.dart"
      to: "test/_helpers/emulator_setup.dart"
      via: "(test boot path only) — main.dart reads USE_EMULATOR and calls the helper if true"
      pattern: "USE_EMULATOR"
---

<objective>
Land Anchor 5 — the emulator-backed integration smoke test. CI-06 is satisfied when the Firebase Local Emulator Suite (Auth + Firestore + Storage; functions emulator is Phase 2 per D-10) is the default target for `flutter test integration_test/` and at least one test exercises the full sign-in → dashboard path against it. This plan adds (a) the integration test file, (b) the emulator-wiring helper used by both the integration test and the conditional `lib/main.dart` boot path, (c) a small `lib/main.dart` edit that calls the helper when `--dart-define=USE_EMULATOR=true` is passed.

Purpose: Plan 08 ships in-process anchor tests that never touch real Firebase. This plan completes the test pyramid by exercising the actual Firebase iOS SDKs against locally-running emulators — proving the Auth-Firestore-Storage triad works end-to-end before any feature phase relies on it. The `lib/main.dart` edit is the minimal surface change required to make `flutter run --dart-define=USE_EMULATOR=true` a developer-friendly local-loop without changing default production behavior.

Output: One integration test file under `integration_test/` (the directory itself is auto-created by `flutter create integration_test` or by file presence), the `configureEmulators()` helper, the `lib/main.dart` conditional boot, dart_test.yaml updated so the `emulator` tag selects only this test. Running the emulator + the test together produces a green pass.
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
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-01-deps-and-emulators-PLAN.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-08-test-harness-anchors-PLAN.md
@CLAUDE.md
@firebase.json
@lib/main.dart
@lib/firebase_options.dart
@lib/core/routes/app_router.dart
@lib/data/services/firebase_providers.dart

<interfaces>
<!-- Emulator wiring pattern from RESEARCH § Pattern 6 lines 564-616 -->

Emulator host:port assignments (Plan 01 firebase.json):
  auth:      localhost:9099
  firestore: localhost:8080
  storage:   localhost:9199
  ui:        localhost:4000   (not used by tests; only for human debugging)

`test/_helpers/emulator_setup.dart`:
  ```
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:firebase_storage/firebase_storage.dart';

  const bool kUseEmulator =
      String.fromEnvironment('USE_EMULATOR', defaultValue: 'false') == 'true';

  Future<void> configureEmulators() async {
    if (!kUseEmulator) return;
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
  }
  ```

`lib/main.dart` edit — minimal, after Firebase.initializeApp but before runApp:
  ```
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // ADD: read --dart-define=USE_EMULATOR and conditionally swap to localhost emulator ports.
  // Lives behind a const-conditional so release builds compile this branch out entirely.
  const useEmulator = String.fromEnvironment('USE_EMULATOR', defaultValue: 'false') == 'true';
  if (useEmulator) {
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
  }
  runApp(const ProviderScope(child: MentorMindsApp()));
  ```

  Three trade-offs to be aware of:
  - `String.fromEnvironment` is a CONST function — the comparison happens at COMPILE TIME if the literal is a const. Release builds without `--dart-define=USE_EMULATOR=true` get the entire `if` block tree-shaken.
  - The emulator-wiring imports (`cloud_firestore`, `firebase_auth`, `firebase_storage`) already exist in main.dart's deps via the Firebase init line. We are NOT introducing layered_imports violations because `lib/main.dart` is NOT under `lib/presentation/**` — it sits at the lib/ root and is the only legitimate Firebase init site.
  - Alternative would be to delegate to `configureEmulators()` from `test/_helpers/emulator_setup.dart` — but `lib/` MUST NOT import from `test/` (test code is not shipped). So main.dart duplicates the 3-line wiring; the helper exists for the integration test, not for main.dart.

`integration_test/login_smoke_test.dart`:
  ```
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:firebase_core/firebase_core.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:integration_test/integration_test.dart';
  import 'package:mentor_minds/firebase_options.dart';
  import 'package:mentor_minds/main.dart' as app;
  import '../test/_helpers/emulator_setup.dart';

  void main() {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();

    setUpAll(() async {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      await configureEmulators();
      // Pre-seed: create a test user in the Auth emulator if not already present.
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: 'smoke@example.com',
          password: 'smoke-password',
        );
      } catch (_) {
        // ignore — user may already exist from a previous emulator run with --import
      }
      // Pre-seed: write the user doc to /users/<uid> so the dashboard role-routing works.
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'role': 'student',
          'name': 'Smoke Tester',
          'level': 'O Level',
          'subjects': ['Math'],
          'points': 0,
          'badges': const <String>[],
        }, SetOptions(merge: true));
      }
      await FirebaseAuth.instance.signOut();  // start the test from signed-out state
    });

    testWidgets(
      'sign-in smoke — emulator → dashboard',
      (tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Find the Email field, type, find the Password field, type, tap Login.
        await tester.enterText(find.byType(TextFormField).at(0), 'smoke@example.com');
        await tester.enterText(find.byType(TextFormField).at(1), 'smoke-password');
        await tester.tap(find.text('Log in'));   // exact button label — confirm against login_screen.dart
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Assertion: dashboard is reached.
        expect(find.text('Hi, Smoke Tester'.split(',').first), findsOneWidget);  // or whatever greeting prefix
      },
      tags: ['emulator', 'integration'],
    );
  }
  ```

  Critical gotchas:
  - The test MUST run with `--dart-define=USE_EMULATOR=true` because `app.main()` reads this var; without it, the test app initializes against PRODUCTION Firebase and the test will (best case) fail with auth errors, (worst case) mutate production data.
  - The relative import `'../test/_helpers/emulator_setup.dart'` works because `integration_test/` sits at the repo root NEXT TO `test/`. Verify this works on Flutter 3.41.3 — if integration_test cannot reach `test/`, copy the helper into `integration_test/_emulator_setup.dart` instead and document the duplication.
  - The button label `'Log in'` must match the actual button in `login_screen.dart`. Read the screen file and use the literal label text. If the label uses a different localization key or Text widget structure, adjust the finder accordingly (e.g. `find.byKey(const ValueKey('login_button'))` if the screen uses keys).

`dart_test.yaml` update:
  ```yaml
  tags:
    unit:
    widget:
    emulator:
    integration:
  ```
  Add `integration:` alongside `emulator:`. The smoke test gets both tags so `flutter test --tags emulator` and `flutter test --tags integration` both select it.

Plan 01 prerequisite check:
  - `firebase.json` has `emulators` block (Plan 01 added).
  - `pubspec.yaml` has `integration_test: { sdk: flutter }` (Plan 01 added).
  - `tool/emulator-data/.gitkeep` exists (Plan 01 committed).

T-1-W0 boundary clarification:
  Plan 08 Task 4 asserted "no DefaultFirebaseOptions.currentPlatform or Firebase.initializeApp in test/". This rule does NOT extend to `integration_test/` — the integration test legitimately calls `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` BUT immediately follows it with `useAuthEmulator`/`useFirestoreEmulator`/`useStorageEmulator` calls that redirect every subsequent SDK operation to localhost. The production Firebase project is contacted exactly once (the initializeApp call) and only to read its bootstrap configuration; no auth handshake reaches it.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add emulator_setup helper + main.dart conditional boot + dart_test.yaml tag</name>
  <files>test/_helpers/emulator_setup.dart, lib/main.dart, dart_test.yaml</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/lib/main.dart (current state — confirm the exact line where `runApp(...)` is called; the emulator wiring must go AFTER `Firebase.initializeApp` and BEFORE `runApp`)
    - /Users/arnobrizwan/Mentor-Mind/dart_test.yaml (created by Plan 08 Task 1; add the `integration:` tag)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md (§ Pattern 6 — Dart boot code for integration tests lines 579-595)
    - /Users/arnobrizwan/Mentor-Mind/firebase.json (verify emulators block from Plan 01 — confirm ports match what the helper hardcodes)
  </read_first>
  <action>
    Step A — `test/_helpers/emulator_setup.dart`:
      Create the file with the exact 3-line wiring shown in `<interfaces>`. `kUseEmulator` is a top-level const so consumers can read it cheaply.

    Step B — Edit `lib/main.dart`:
      Read the current file (46 lines per CLAUDE.md). After the `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);` line (likely line ~15-20) and BEFORE the `runApp(const ProviderScope(child: MentorMindsApp()));` line, insert the 6-line conditional emulator block from `<interfaces>` above.

      Add imports at the top of main.dart:
        `import 'package:cloud_firestore/cloud_firestore.dart';`
        `import 'package:firebase_auth/firebase_auth.dart';`
        `import 'package:firebase_storage/firebase_storage.dart';`
      Only add the ones not already imported. `Firebase.initializeApp` is in `firebase_core` so that import already exists.

      DO NOT introduce any other changes to main.dart. The diff should be: 3 imports + 6-line conditional block. Keep portrait lock, status bar styling, ProviderScope wrap — all unchanged.

    Step C — Update `dart_test.yaml`:
      Add `integration:` under `tags:`. The keys are empty placeholders (Dart test reads tag names from this list).

    Step D — Smoke-build proves no regression in default build:
      `flutter build ios --no-codesign` (without --dart-define=USE_EMULATOR=true) — must exit 0; release-mode tree-shake removes the if-branch.

    Commit message: `feat(test): add emulator wiring helper + lib/main.dart conditional boot for USE_EMULATOR (Phase 1 / CI-06)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f test/_helpers/emulator_setup.dart &amp;&amp; grep -q 'useAuthEmulator\|useFirestoreEmulator\|useStorageEmulator' test/_helpers/emulator_setup.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "String\.fromEnvironment\(.*USE_EMULATOR" lib/main.dart &amp;&amp; grep -q 'useFirestoreEmulator\|useAuthEmulator\|useStorageEmulator' lib/main.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q '^\s*integration:' dart_test.yaml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter build ios --no-codesign 2>&amp;1 | tee /tmp/p1-09-t1-build.log; test $? -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --fatal-warnings 2>&amp;1 | tee /tmp/p1-09-t1-analyze.txt &amp;&amp; ! grep -qE '^\s*(error|warning) -' /tmp/p1-09-t1-analyze.txt</automated>
  </verify>
  <acceptance_criteria>
    - `test/_helpers/emulator_setup.dart` exists and contains all three `use*Emulator` calls.
    - `lib/main.dart` contains both the `String.fromEnvironment('USE_EMULATOR'...)` check AND at least one `use*Emulator` call inside the conditional.
    - `dart_test.yaml` has both `emulator:` and `integration:` keys under `tags:`.
    - `flutter build ios --no-codesign` exits 0 (default build still works; release tree-shakes the emulator branch).
    - `flutter analyze --fatal-warnings` exits 0 across the whole tree.
  </acceptance_criteria>
  <done>
    The emulator wiring is in place; main.dart conditionally redirects SDK calls when `--dart-define=USE_EMULATOR=true`; the helper is ready for the integration test to import.
  </done>
</task>

<task type="auto">
  <name>Task 2: Write integration_test/login_smoke_test.dart — Anchor 5</name>
  <files>integration_test/login_smoke_test.dart</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/lib/presentation/screens/auth/login_screen.dart (post-Plan-03 — confirm exact button label text ("Log in" vs "Login" vs "Sign In") and TextFormField order)
    - /Users/arnobrizwan/Mentor-Mind/lib/presentation/screens/dashboard/dashboard_screen.dart (post-Plan-03 — confirm the greeting text format e.g. `'Hi, $firstName'`)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md (§ Anchor Test 5 lines 714-731; § Pattern 6 — Run integration tests against emulator lines 597-606)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-CONTEXT.md (D-09 — Anchor 5: emulator suite + useAuthEmulator/useFirestoreEmulator)
    - /Users/arnobrizwan/Mentor-Mind/integration_test/ (directory may or may not exist — Flutter convention places it at repo root)
  </read_first>
  <action>
    Create `integration_test/login_smoke_test.dart`. The full file template is shown in `<interfaces>` above. Adapt the following details to the actual codebase state:

    Step A — Confirm UI text constants:
      Read `login_screen.dart`. Locate:
        - The Email TextFormField (first or second in the form? Order matters for `find.byType(TextFormField).at(N)`).
        - The Password TextFormField.
        - The login button. Capture its exact label text (most likely "Log in" per CLAUDE.md branding, but could be "Sign In" or "Login").
      Read `dashboard_screen.dart`. Locate the greeting Text widget. If it says `'Hi, Smoke'`, the assertion `find.text('Hi, Smoke Tester')` works; if it says `'Hi, Smoke!'`, adjust the matcher to `textContaining('Smoke')`.

    Step B — Write the test file following the template in `<interfaces>`:
      - `IntegrationTestWidgetsFlutterBinding.ensureInitialized();` at the top of `main()`.
      - `setUpAll` initializes Firebase, calls `configureEmulators()`, creates the test user via the Auth emulator API (idempotent with try/catch), writes the user doc to Firestore, signs out.
      - One `testWidgets` body that boots `app.main()`, enters credentials, taps login, asserts the dashboard route is reached.
      - Tag: `tags: ['emulator', 'integration']`.

    Step C — Local emulator + test run (CI runs this same sequence):
      In one terminal:
        `firebase emulators:start --only auth,firestore,storage --import=tool/emulator-data --export-on-exit=tool/emulator-data`
      In another terminal:
        `flutter test integration_test/login_smoke_test.dart --dart-define=USE_EMULATOR=true -d "<simulator-id>"`
      Capture stdout to `/tmp/p1-09-t2-emu-test.log`. Confirm the test passes.

      If the test fails because of button text mismatch, adjust the finder. If it fails because the dashboard greeting differs, adjust the assertion. The test logic is the closure target — small-text adjustments are allowed.

    Step D — Update `tool/emulator-data/` snapshot:
      The `--export-on-exit` flag dumps the emulator state to `tool/emulator-data/` when the emulator shuts down. Commit the resulting snapshot so subsequent runs (CI + dev) have deterministic seed data. The snapshot is `tool/emulator-data/<timestamp>/firestore_export/...` + `tool/emulator-data/<timestamp>/auth_export/...`. If the data is sensitive or huge, instead commit a `tool/emulator-data/README.md` documenting how a contributor re-creates the seed locally and DO NOT commit the actual dump. For Phase 1's single smoke user, the dump is tiny (<5KB) — commit it.

    Commit message: `test(integration): add login_smoke_test against Firebase Emulator Suite (Phase 1 / CI-06; D-09 Anchor 5)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f integration_test/login_smoke_test.dart &amp;&amp; grep -q 'IntegrationTestWidgetsFlutterBinding\.ensureInitialized' integration_test/login_smoke_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'useAuthEmulator\|useFirestoreEmulator\|useStorageEmulator\|configureEmulators' integration_test/login_smoke_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "tags:\s*\[.*emulator" integration_test/login_smoke_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --fatal-warnings integration_test/ 2>&amp;1 | tee /tmp/p1-09-t2-analyze.txt &amp;&amp; ! grep -qE '^\s*(error|warning) -' /tmp/p1-09-t2-analyze.txt</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; DEVICE=$(flutter devices --machine 2>/dev/null | node -e "let d=''; process.stdin.on('data',c=>d+=c); process.stdin.on('end',()=>{try{const j=JSON.parse(d); const ios=j.find(x=>x.platform==='ios' || (x.targetPlatform&amp;&amp;x.targetPlatform.includes('ios'))); if(ios){console.log(ios.id)}}catch(e){}})"); test -n "$DEVICE" || { echo "no iOS device — skipping emulator run in CI"; exit 0; }; ( firebase emulators:start --only auth,firestore,storage > /tmp/p1-09-t2-emu.log 2>&amp;1 &amp; EPID=$!; sleep 15; flutter test integration_test/login_smoke_test.dart --dart-define=USE_EMULATOR=true -d "$DEVICE" 2>&amp;1 | tee /tmp/p1-09-t2-test.log; TC=$?; kill $EPID 2>/dev/null; wait $EPID 2>/dev/null; true; test $TC -eq 0 || { cat /tmp/p1-09-t2-test.log; exit $TC; } )</automated>
  </verify>
  <acceptance_criteria>
    - `integration_test/login_smoke_test.dart` exists.
    - Test references `IntegrationTestWidgetsFlutterBinding.ensureInitialized` (required for integration_test).
    - Test references at least one `use*Emulator` call or imports `configureEmulators` from the helper.
    - Test is tagged `emulator` (and optionally `integration`).
    - `flutter analyze --fatal-warnings integration_test/` exits 0.
    - Full emulator + test run: emulator boots, test passes, exit code 0. (The verification command falls back to a no-op exit 0 if no iOS device is available — for local dev, the test MUST run on a real simulator; CI uses a path-filtered runner that may skip iOS-device-dependent steps.)
  </acceptance_criteria>
  <done>
    Anchor 5 lands. The emulator-backed sign-in flow works end-to-end on a local simulator. CI-06 is satisfied for Phase 1 (Auth + Firestore + Storage emulators are the default target). Functions emulator is added in Phase 2 per D-10.
  </done>
</task>

<task type="auto">
  <name>Task 3: Wave 0 readiness check + tool/emulator-data seed commit</name>
  <files>tool/emulator-data/** (or tool/emulator-data/README.md as fallback)</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md (§ Wave 0 Requirements — `tool/emulator-data/` committed seed; § Per-Task Verification Map row 01-w0-emulator-config)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-01-deps-and-emulators-PLAN.md (confirms Plan 01 committed only `.gitkeep`; this task populates the actual seed)
  </read_first>
  <action>
    Step A — Seed commit:
      If Task 2's `--export-on-exit` produced a `tool/emulator-data/<timestamp>/` snapshot, verify the dump contains:
        - `tool/emulator-data/<timestamp>/firestore_export/` directory with a `firestore_export.overall_export_metadata` file
        - `tool/emulator-data/<timestamp>/auth_export/` directory with `accounts.json` and `config.json`
      `git add tool/emulator-data/` and commit.

      If Task 2 did NOT produce a snapshot (e.g. emulators ran but were killed before export), document a manual re-seed procedure in `tool/emulator-data/README.md`:
        ```
        # Emulator Seed Data

        This directory holds the Firebase Local Emulator Suite seed for the Phase 1
        integration smoke test (CI-06 / Anchor 5).

        ## To regenerate:
        1. `firebase emulators:start --only auth,firestore,storage --import=tool/emulator-data --export-on-exit=tool/emulator-data`
        2. In a second terminal: `flutter test integration_test/login_smoke_test.dart --dart-define=USE_EMULATOR=true -d <device>`
        3. The integration test's setUpAll will create the smoke@example.com user + write the /users/{uid} doc.
        4. Ctrl-C the emulator. The shutdown writes a fresh snapshot here.
        5. `git add tool/emulator-data/ && git commit -m "chore(emulator): refresh seed snapshot"`
        ```

    Step B — Validation row close:
      VALIDATION.md row `01-w0-emulator-config` references `firebase emulators:start --only auth,firestore,storage,functions --import=tool/emulator-data` — note the `functions` in that command. Phase 1 does NOT include `functions` per D-10. When this plan ships, update VALIDATION.md row to omit `functions` from the import path (or note that `functions` is Phase 2). Either edit is acceptable — the row's `Status` should turn ✅ after this plan.
      Open `.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md`; flip the `01-w0-emulator-config` row's Status to ✅.

    Step C — Final sanity:
      Run the full anchor test suite:
        `flutter test test/` → exits 0 (the four in-process anchors from Plan 08).
        `flutter test --coverage` → produces `coverage/lcov.info`.
      Run the emulator integration test (with the seed in place):
        `firebase emulators:start --only auth,firestore,storage --import=tool/emulator-data` (in a background terminal)
        `flutter test integration_test/login_smoke_test.dart --dart-define=USE_EMULATOR=true -d <device>` → exits 0.
      Confirm `coverage/lcov.info` size is unchanged or slightly larger (the integration test contributes minimal coverage because it runs against the iOS toolchain, not a coverage-collecting Dart VM).

    Commit message: `chore(emulator): commit seed data for integration smoke test (Phase 1 / CI-06; Wave 0 close)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ( test -d tool/emulator-data &amp;&amp; ( ls tool/emulator-data/*.json tool/emulator-data/*/*.json tool/emulator-data/README.md 2>/dev/null | wc -l | tr -d ' ' | xargs -I{} test {} -ge 1 ) ) || ( test -f tool/emulator-data/README.md )</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter test test/ 2>&amp;1 | tee /tmp/p1-09-t3-test.log &amp;&amp; grep -q 'All tests passed' /tmp/p1-09-t3-test.log</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; rm -f coverage/lcov.info; flutter test --coverage 2>&amp;1 | tail -5 &amp;&amp; test -s coverage/lcov.info</automated>
  </verify>
  <acceptance_criteria>
    - Either `tool/emulator-data/` contains a non-empty dump (Auth export accounts.json + Firestore export metadata) OR `tool/emulator-data/README.md` exists with the regeneration procedure.
    - `flutter test test/` exits 0 (Plan 08 anchors still green).
    - `flutter test --coverage` exits 0 and `coverage/lcov.info` exists.
    - VALIDATION.md row `01-w0-emulator-config` status turned ✅ (manually or via this plan's executor edit).
  </acceptance_criteria>
  <done>
    Wave 0 emulator-config row is closed. The local-loop + CI integration test path is provable: emulators start from Plan 01's config, the integration test uses Plan 09's wiring, the seed is committed (or documented), and the test passes. Plan 10 can wire `firebase emulators:exec` as a CI workflow step.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| integration test process ⇄ real Firebase project | The test calls `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` once but immediately reroutes every subsequent SDK call to localhost via `use*Emulator` — production data is never touched |
| lib/main.dart `--dart-define=USE_EMULATOR=true` boot path ⇄ production builds | `String.fromEnvironment` is const-evaluated; release builds without the dart-define tree-shake the emulator branch entirely |
| `tool/emulator-data/` seed ⇄ git history | The seed is non-sensitive (test user smoke@example.com with a deterministic password) but resides in the repo; if a real user ever uses these credentials, the leakage is minor |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-1-W0 | Information Disclosure | The integration test legitimately initializes Firebase against the production project before redirecting to localhost — there is a microsecond window where, if the redirect fails, the test process is bound to production | mitigate | The `use*Emulator` calls happen in `setUpAll` BEFORE any Auth/Firestore op is attempted; the test user creation in `setUpAll` uses `FirebaseAuth.instance.createUserWithEmailAndPassword` which would 401 against production (signup may be disabled or rate-limited); the smoke@example.com email is intentionally non-real |
| T-1-EMU-LEAK | Spoofing | A future contributor copies the integration test pattern into a unit test, forgets the `useEmulator` calls, and the test process authenticates against production | mitigate | Plan 08 Task 4's invariant check (zero `Firebase.initializeApp` calls under `test/`) catches this — only `integration_test/` is allowed to initialize Firebase, and only after the emulator wiring helper is called |
| T-1-SEED-PII | Information Disclosure | The committed `tool/emulator-data/` snapshot accidentally containing real user PII from a contributor's earlier emulator session with imported real data | accept | Phase 1's snapshot is created in Task 2's clean-room run; if a contributor accidentally re-exports with personal data, the resulting commit is a pre-commit-hook concern (not enforced in Phase 1 — out of scope) |
| T-1-MAIN-BRANCH-LEAK | Tampering | A release build accidentally gets the `--dart-define=USE_EMULATOR=true` flag and ships an app that points at localhost | accept | The flag default is `false`; release CI workflows in Plan 10 do NOT pass `--dart-define=USE_EMULATOR=true`; the if-branch is tree-shaken when the flag is `false` at compile time |
</threat_model>

<verification>
- `test/_helpers/emulator_setup.dart` exists with `configureEmulators()` wiring all three emulators.
- `lib/main.dart` has the conditional `String.fromEnvironment('USE_EMULATOR')` boot path with `use*Emulator` calls inside.
- `dart_test.yaml` has both `emulator:` and `integration:` tags.
- `integration_test/login_smoke_test.dart` exists, tagged `emulator`, references `IntegrationTestWidgetsFlutterBinding.ensureInitialized` and at least one `use*Emulator` call.
- `flutter test test/` exits 0 (Plan 08 anchors).
- `flutter test --coverage` produces `coverage/lcov.info`.
- Full emulator integration test passes on a local simulator (Task 2 verification).
- Either `tool/emulator-data/<dump>` exists or `tool/emulator-data/README.md` documents the regeneration path.
- VALIDATION.md `01-w0-emulator-config` row turned ✅.
</verification>

<success_criteria>
- D-10 honored: Auth + Firestore + Storage emulators only; Functions deferred to Phase 2.
- CI-06 closed: emulator suite scaffolded, at least one integration test exercises it, the test is the default target for `flutter test integration_test/`.
- T-1-W0 mitigated for the integration test (real Firebase project initialized once for bootstrap, then immediately redirected to localhost).
- Plan 10 can add a CI workflow step `firebase emulators:exec --only auth,firestore,storage "flutter test integration_test/..."` once a Linux Flutter-iOS-toolchain runner is available (or skip the integration job on CI and run it locally).
</success_criteria>

<output>
Create `.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-09-emulator-integration-smoke-SUMMARY.md` when done. Record: the lib/main.dart diff (3 imports + 6-line block), the emulator_setup.dart file content (full), the login_smoke_test.dart file content (full), the literal output of the local emulator + test run (emulator boot lines + test pass/fail summary), the path to the committed seed (or the README.md fallback), the VALIDATION.md row status change, and any UI-text adjustments made (button label, greeting format) compared to the template in `<interfaces>`.
</output>
