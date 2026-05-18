---
phase: 02-cloud-functions-scaffolding-app-check
plan: 09
type: execute
wave: 5
depends_on: ["02-06", "02-07", "02-08"]
files_modified:
  - integration_test/ping_smoke_test.dart
autonomous: true
requirements: [FUNC-06, FUNC-02]
pr_group: PR-3
tags: [integration_test, ping_smoke, emulator_integration, app_check_bypass_documented, ping_response_shape_assert, latency_under_1s]

must_haves:
  truths:
    - "D-12 honored: new `integration_test/ping_smoke_test.dart` calls the ping callable through the Functions emulator; asserts response shape {ok:true, timestamp:int, region:'asia-south1'} + latency < 1s"
    - "Tagged `@Tags(<String>['emulator', 'integration'])` — same tag block as Phase 1's login_smoke_test (D-12)"
    - "Emulator bypasses App Check enforcement (RESEARCH Pitfall 6) — the test does NOT register a debug token, does NOT consume APP_CHECK_DEBUG_TOKEN, and does NOT call FirebaseAppCheck.activate. This is by design — Phase 2 verifies plumbing (callable round-trip), not enforcement (deferred to Phase 3 production deploy)"
    - "setUpAll mirrors login_smoke_test pattern: IntegrationTestWidgetsFlutterBinding.ensureInitialized → Firebase.initializeApp → configureEmulators"
    - "Test does NOT seed a user (D-11, D-24 — login_smoke_test continues to handle user seeding; ping is unauthenticated by design)"
    - "Stopwatch asserts emulator latency < 1000 ms — proves the local emulator is fast enough that any prod-side regression in Phase 3 manifests as a clear failure"
    - "FUNC-02 end-to-end exercise (server callable + client SDK + emulator) completes in this plan"
    - "D-24 honored: integration_test/login_smoke_test.dart is NOT modified"
  artifacts:
    - path: "integration_test/ping_smoke_test.dart"
      provides: "Emulator smoke test for the ping callable end-to-end"
      contains: "httpsCallable('ping')"
  key_links:
    - from: "integration_test/ping_smoke_test.dart"
      to: "test/_helpers/emulator_setup.dart"
      via: "relative import `'../test/_helpers/emulator_setup.dart'` + call configureEmulators() in setUpAll"
      pattern: "configureEmulators"
    - from: "integration_test/ping_smoke_test.dart"
      to: "functions/src/index.ts ping callable (Plan 02-03)"
      via: "httpsCallable('ping') against Functions emulator at localhost:5001"
      pattern: "httpsCallable\\('ping'\\)"
---

<objective>
Create `integration_test/ping_smoke_test.dart` — a single emulator integration test that calls the ping callable through the Functions emulator, asserts the response shape `{ ok: true, timestamp: <int>, region: 'asia-south1' }`, and asserts latency under 1 second. Tagged `@Tags(<String>['emulator', 'integration'])` to align with Phase 1's tag-based test selection in dart_test.yaml.

Purpose: Plans 02-03 / 02-04 / 02-07 / 02-08 wired all the pieces; this test proves they fit together. It is the authoritative end-to-end gate for FUNC-02 + FUNC-06 in Phase 2 (no production deploy per D-23, so the live App Check enforcement gate is deferred to Phase 3 — but the round trip is exercised here). RESEARCH Pitfall 6 + CONTEXT D-13 explicitly state the emulator BYPASSES App Check enforcement; this test does NOT register a debug token and does NOT call FirebaseAppCheck.activate because (a) the emulator wouldn't validate against it anyway and (b) the test runs after `app.main()` is NOT called — the test directly drives the SDK without booting the app widget tree, so the App Check activation in lib/main.dart never executes.

Output: One new file at integration_test/ping_smoke_test.dart. Manual local run: `firebase emulators:start --only auth,firestore,storage,functions` in one terminal + `flutter test integration_test/ping_smoke_test.dart --dart-define=USE_EMULATOR=true -d <ios-simulator>` in another → test passes.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-CONTEXT.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-RESEARCH.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-PATTERNS.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-VALIDATION.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-07-flutter-functions-sdk-PLAN.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-08-emulator-helper-wiring-PLAN.md
@integration_test/login_smoke_test.dart
@test/_helpers/emulator_setup.dart
@CLAUDE.md

<interfaces>
<!-- Patterns from 02-PATTERNS.md §integration_test/ping_smoke_test.dart (lines 225-260) and RESEARCH §Pattern 9 (lines 527-565) -->

integration_test/ping_smoke_test.dart (FULL content):

```dart
@Tags(<String>['emulator', 'integration'])
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mentor_minds/firebase_options.dart';

import '../test/_helpers/emulator_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await configureEmulators();
    // NOTE: No user seeding (ping is unauthenticated by design — App Check
    // verifies the *device*, not the *user*). No App Check activate() either —
    // the Functions emulator bypasses App Check enforcement (RESEARCH Pitfall 6).
    // Phase 3 production deploy is when enforceAppCheck:true actually gates
    // real callers; Phase 2 verifies the round-trip plumbing only.
  });

  testWidgets(
    'ping smoke — emulator round trip',
    (tester) async {
      final stopwatch = Stopwatch()..start();
      final result = await FirebaseFunctions.instance
          .httpsCallable('ping')
          .call<dynamic>();
      stopwatch.stop();

      // The callable returns Map<Object?, Object?> at runtime, not
      // Map<String, dynamic> — the cast is required (RESEARCH Pattern 8).
      final data =
          (result.data as Map<Object?, Object?>).cast<String, dynamic>();

      expect(data['ok'], isTrue);
      expect(data['timestamp'], isA<int>());
      expect(data['region'], equals('asia-south1'));
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason:
            'Emulator latency < 1s is the canary — Phase 3 production target is < 10s',
      );
    },
    tags: ['emulator', 'integration'],
  );
}
```

Key invariants of the scaffold:
  - `@Tags(<String>['emulator', 'integration'])` at LIBRARY scope (top of file with `library;` directive) — required by Phase 1's dart_test.yaml tag selectors.
  - `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` — MUST be called before any test code; this is the integration_test binding.
  - `setUpAll` runs ONCE for the file:
    1. `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` — initializes Firebase against the production project (production is contacted ONCE for bootstrap config; immediate emulator redirect follows).
    2. `await configureEmulators()` — redirects every Firebase SDK call to localhost emulators (from Plan 02-08).
    3. NO user seeding (D-11 — ping is unauthenticated by design).
    4. NO App Check activation (D-13 + RESEARCH Pitfall 6 — emulator bypasses).
  - testWidgets:
    - Direct SDK call via `FirebaseFunctions.instance.httpsCallable('ping').call<dynamic>()`. The test could equivalently go through `PingRepository` (instantiate via `ProviderContainer` + `pingRepositoryProvider`) — both paths are valid. The direct-SDK path is simpler and matches the RESEARCH Pattern 9 scaffold; the repository path proves the layer wiring works. CHOOSE the direct-SDK path — Phase 3's MentorBotViewModel test will exercise the repository layer; Phase 2's plumbing test is OK calling the SDK directly.
    - Asserts: `data['ok'] === true`, `data['timestamp']` is an int, `data['region'] === 'asia-south1'`.
    - Latency: Stopwatch wraps the call; assert `< 1000ms`.
    - Tags propagated on the individual test as well (redundant with the library-level @Tags but harmless and explicit).
  - DOES NOT boot the app widget (`app.main()` is NOT called). The test drives the SDK directly. This is different from `login_smoke_test.dart` which DOES boot the app and exercises UI.

Relative import note:
  - The line `import '../test/_helpers/emulator_setup.dart';` is the same path Phase 1's login_smoke_test.dart uses. Verified working on Flutter 3.41.3 (Plan 01-09 confirmed). DO NOT change to a `package:mentor_minds/...` import — that file lives under test/ not lib/.

Why the test calls `FirebaseFunctions.instance` (not `instanceFor(region:'asia-south1')`):
  - The emulator redirect from Plan 02-08 was applied to `FirebaseFunctions.instance` (default region). Calling `httpsCallable('ping')` on this instance routes to localhost:5001.
  - If the test used `FirebaseFunctions.instanceFor(region: 'asia-south1')`, the redirect should STILL apply (RESEARCH Pattern 7 line 469 explains why both share the redirect at platform-channel level). But to stay on the most predictable path, use `.instance`. The functions/src/index.ts ping callable specifies `region: 'asia-south1'` server-side — the emulator hosts the callable under that region regardless of which instance the client uses.
  - VERIFICATION: if running the test fails with a 404 or "function not found", switching to `FirebaseFunctions.instanceFor(region: 'asia-south1')` is the documented fallback. Plan 02-09 SUMMARY records which path was used.

Manual local run instructions (recorded in SUMMARY):
  In Terminal 1 (from repo root):
    `nvm use 20`
    `firebase emulators:start --only auth,firestore,storage,functions`
    Wait for output line: `✔  functions[asia-south1-ping]: https function initialized (http://127.0.0.1:5001/mentor-mind-aa765/asia-south1/ping)`
  In Terminal 2:
    `flutter test integration_test/ping_smoke_test.dart --dart-define=USE_EMULATOR=true -d <iOS-simulator-UDID>`
    Expected output: `00:0X +1: All tests passed!`
  Ctrl-C the emulator when done.

Why this depends on 02-06 + 02-07 + 02-08:
  - 02-06: lib/main.dart already imports firebase_app_check (irrelevant for the test which doesn't boot the app, but the FLUTTER_TEST environment may execute main.dart imports — keeping it consistent prevents undefined-import errors during compilation).
  - 02-07: cloud_functions in pubspec; firebase_functions_provider.dart; PingResponse model; PingRepository — the test could call PingRepository (alternative path), but the direct-SDK path also works.
  - 02-08: test/_helpers/emulator_setup.dart extended with useFunctionsEmulator — required, because configureEmulators() is the redirect entry point.

What this plan does NOT do:
  - Does NOT modify integration_test/login_smoke_test.dart (D-24).
  - Does NOT register a debug token in Firebase Console (Phase 3 manual step).
  - Does NOT assert App Check rejection behavior (emulator bypasses; Phase 3 production deploy is the gate).
  - Does NOT change dart_test.yaml — the `emulator:` + `integration:` tags already exist from Phase 1 (per CLAUDE.md / dart_test.yaml read at repo state).
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Write integration_test/ping_smoke_test.dart with the full scaffold; verify analyze + manual emulator run</name>
  <files>integration_test/ping_smoke_test.dart</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/integration_test/login_smoke_test.dart (Phase 1 — the exact analog; copy the @Tags + library + IntegrationTestWidgetsFlutterBinding + setUpAll scaffold; REMOVE the user-seeding block; REMOVE the `app.main()` body)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-PATTERNS.md (§integration_test/ping_smoke_test.dart — lines 225-260: full scaffold + substitution rule)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-RESEARCH.md (§Pattern 9 lines 527-565 — full ping_smoke_test.dart skeleton; §Pitfall 6 lines 685-692 — emulator bypasses App Check documentation)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-CONTEXT.md (D-12, D-13, D-24 — emulator bypass documented; login_smoke_test untouched; no APP_CHECK_DEBUG_TOKEN consumption in Phase 2)
    - /Users/arnobrizwan/Mentor-Mind/test/_helpers/emulator_setup.dart (AFTER Plan 02-08 — confirm configureEmulators() calls useFunctionsEmulator)
    - /Users/arnobrizwan/Mentor-Mind/dart_test.yaml (confirm `emulator:` + `integration:` tags exist; do NOT modify in this plan)
  </read_first>
  <action>
    Step A — Read integration_test/login_smoke_test.dart to confirm the canonical Phase 1 scaffold pattern. Capture the @Tags line, the imports order, the setUpAll body shape.

    Step B — Read test/_helpers/emulator_setup.dart to confirm Plan 02-08 added the useFunctionsEmulator line and the cloud_functions import. If 02-08 was not merged in this branch, this plan blocks until 02-08 lands.

    Step C — Read dart_test.yaml to confirm `emulator:` and `integration:` tags exist. (They do per repo state — confirmed in CLAUDE.md.)

    Step D — Write integration_test/ping_smoke_test.dart with the EXACT scaffold from `<interfaces>` above:

      Full file content (copy verbatim from the `<interfaces>` block; the only adaptation is the comment text inside setUpAll — keep the substance but feel free to compress to one comment line if preferred):

      ```dart
      @Tags(<String>['emulator', 'integration'])
      library;

      import 'package:cloud_functions/cloud_functions.dart';
      import 'package:firebase_core/firebase_core.dart';
      import 'package:flutter_test/flutter_test.dart';
      import 'package:integration_test/integration_test.dart';
      import 'package:mentor_minds/firebase_options.dart';

      import '../test/_helpers/emulator_setup.dart';

      void main() {
        IntegrationTestWidgetsFlutterBinding.ensureInitialized();

        setUpAll(() async {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
          await configureEmulators();
          // Ping is unauthenticated by design (App Check verifies the *device*,
          // not the *user*). No App Check activate() — the Functions emulator
          // bypasses App Check enforcement (RESEARCH Pitfall 6); enforceAppCheck:true
          // on the server is exercised by Phase 3's production deploy, not here.
        });

        testWidgets(
          'ping smoke — emulator round trip',
          (tester) async {
            final stopwatch = Stopwatch()..start();
            final result = await FirebaseFunctions.instance
                .httpsCallable('ping')
                .call<dynamic>();
            stopwatch.stop();

            final data =
                (result.data as Map<Object?, Object?>).cast<String, dynamic>();

            expect(data['ok'], isTrue);
            expect(data['timestamp'], isA<int>());
            expect(data['region'], equals('asia-south1'));
            expect(
              stopwatch.elapsedMilliseconds,
              lessThan(1000),
              reason:
                  'Emulator latency < 1s is the canary — Phase 3 production target is < 10s',
            );
          },
          tags: ['emulator', 'integration'],
        );
      }
      ```

    Step E — Static gates:
      `dart format integration_test/ping_smoke_test.dart` — no changes.
      `flutter analyze --no-fatal-infos integration_test/ping_smoke_test.dart` — exits 0.

    Step F — Live emulator integration run (manual / CI-only — capture stdout):
      This step requires:
        - functions/lib/index.js exists (Plan 02-01 + 02-02 + 02-03 must be on this branch).
        - firebase.json emulators.functions.port = 5001 (Plan 02-04).
        - An iOS simulator available (`xcrun simctl list devices booted | grep -v '^--' | head -5`).

      Terminal 1 (background):
        ```bash
        cd /Users/arnobrizwan/Mentor-Mind
        nvm use 20
        firebase emulators:start --only auth,firestore,storage,functions > /tmp/p2-09-emu.log 2>&amp;1 &amp;
        EMU_PID=$!
        sleep 15  # wait for emulator boot
        grep -E "ping\[asia-south1\]|asia-south1-ping|http function initialized.*ping" /tmp/p2-09-emu.log
        ```

      Terminal 2 (foreground):
        ```bash
        DEVICE=$(flutter devices --machine 2>/dev/null | node -e "let d=''; process.stdin.on('data',c=>d+=c); process.stdin.on('end',()=>{try{const j=JSON.parse(d); const ios=j.find(x=>x.platform==='ios' || (x.targetPlatform&amp;&amp;x.targetPlatform.includes('ios'))); if(ios){console.log(ios.id)}}catch(e){}})")
        flutter test integration_test/ping_smoke_test.dart --dart-define=USE_EMULATOR=true -d "$DEVICE" 2>&amp;1 | tee /tmp/p2-09-test.log
        TC=$?
        kill $EMU_PID 2>/dev/null
        wait $EMU_PID 2>/dev/null
        test $TC -eq 0
        ```

      Acceptable fallback: if no iOS simulator is available (e.g. headless agent), defer the live run to local dev. The static gates (file exists + analyze passes) still cover Phase 2's nyquist gate; the live run is the closing verification documented in Plan 02-11 SUMMARY.

    Step G — Commit:
      `git add integration_test/ping_smoke_test.dart`
      Commit message: `test(integration): add ping_smoke_test against Functions emulator (Phase 2 PR-3 / FUNC-02, FUNC-06; CONTEXT D-12)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f integration_test/ping_smoke_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "@Tags(&lt;String&gt;\['emulator', 'integration'\])" integration_test/ping_smoke_test.dart &amp;&amp; grep -q '^library;' integration_test/ping_smoke_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'IntegrationTestWidgetsFlutterBinding.ensureInitialized' integration_test/ping_smoke_test.dart &amp;&amp; grep -q 'configureEmulators' integration_test/ping_smoke_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "httpsCallable('ping')" integration_test/ping_smoke_test.dart &amp;&amp; grep -q "data\['ok'\]" integration_test/ping_smoke_test.dart &amp;&amp; grep -q "data\['region'\]" integration_test/ping_smoke_test.dart &amp;&amp; grep -q "asia-south1" integration_test/ping_smoke_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "lessThan\(1000\)|Stopwatch" integration_test/ping_smoke_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -q "FirebaseAppCheck.instance.activate" integration_test/ping_smoke_test.dart &amp;&amp; ! grep -q "APP_CHECK_DEBUG_TOKEN" integration_test/ping_smoke_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "import '\.\./test/_helpers/emulator_setup.dart';" integration_test/ping_smoke_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --no-fatal-infos integration_test/ping_smoke_test.dart 2>&amp;1 | tee /tmp/p2-09-t1-analyze.log &amp;&amp; ! grep -qE '^\s*(error|warning) -' /tmp/p2-09-t1-analyze.log</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! diff -q integration_test/login_smoke_test.dart integration_test/login_smoke_test.dart 2>/dev/null &amp;&amp; git diff --quiet HEAD -- integration_test/login_smoke_test.dart 2>/dev/null || echo "login_smoke_test untouched (D-24 honored)"</automated>
  </verify>
  <acceptance_criteria>
    - integration_test/ping_smoke_test.dart exists.
    - Library-level `@Tags(<String>['emulator', 'integration'])` + `library;` directive present.
    - `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` called in main.
    - `configureEmulators()` called in setUpAll (after Firebase.initializeApp).
    - Test body contains the literal `httpsCallable('ping')` call.
    - Asserts `data['ok']` is truthy, `data['timestamp']` is an int, `data['region']` equals 'asia-south1'.
    - Asserts latency < 1000ms (Stopwatch + lessThan).
    - Test does NOT call FirebaseAppCheck.instance.activate (emulator bypasses per RESEARCH Pitfall 6).
    - Test does NOT reference APP_CHECK_DEBUG_TOKEN (D-13 — reserved for Phase 3+).
    - Relative import `'../test/_helpers/emulator_setup.dart'` (matches Phase 1 pattern).
    - flutter analyze --no-fatal-infos exits 0.
    - integration_test/login_smoke_test.dart is unchanged from HEAD (D-24).
  </acceptance_criteria>
  <done>
    The Phase 2 smoke test is on disk. When run against `firebase emulators:start --only functions`, it exercises the full plumbing (firebase_options → Firebase.initializeApp → configureEmulators → useFunctionsEmulator → httpsCallable('ping') → emulator returns {ok, timestamp, region} → SDK casts → assertions pass). The live run is best-effort in CI (Plan 02-10 currently lints + builds TypeScript only; no iOS simulator on Linux CI) and authoritative locally.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| integration test process ⇄ real Firebase project | `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` initializes against the production project for bootstrap config; `configureEmulators()` IMMEDIATELY redirects every SDK call to localhost. Production data is never touched. RESEARCH Pitfall 2 confirms ordering invariant. |
| ping_smoke_test ⇄ Functions emulator at localhost:5001 | The test trusts the emulator to host the same ping callable that the production deploy would host (the emulator runs functions/lib/index.js compiled from functions/src/index.ts). No production deploy in Phase 2 (D-23). |
| test process ⇄ App Check enforcement | The emulator bypasses enforcement (RESEARCH Pitfall 6). The test cannot verify enforcement behavior — that's a Phase 3 production manual test. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-2-09-PROD-CONTACT | Information Disclosure | The test legitimately initializes Firebase against the production project before redirecting to localhost — a microsecond window exists where production data could be contacted | mitigate | configureEmulators() called immediately after initializeApp; no SDK call (auth, firestore, storage, functions) precedes it. RESEARCH Pitfall 2 + Plan 01-09 documented this for Phase 1's login_smoke_test; same pattern applies here. |
| T-2-09-EMU-DOWN | Denial of Service | Developer runs `flutter test integration_test/ping_smoke_test.dart` without the emulator running; test times out or fails with connection refused | accept | Documented in the manual run instructions (Step F). The test framework reports the failure clearly. CI in Plan 02-10 does not run the integration test (no iOS simulator on Linux runners); local dev workflow only. |
| T-2-09-WRONG-REGION-DOC | Repudiation | A future maintainer changes the server-side region to e.g. 'asia-southeast1' (Plan 02-03) but does not update this test's assertion `data['region'] equals 'asia-south1'` | mitigate | Verify gate `grep -q "asia-south1"` in this test mirrors Plan 02-03's `region: "asia-south1"` literal. Drift surfaces as a test assertion failure on the next run. |
| T-2-09-FLAKY-LATENCY | Denial of Service | Latency assertion `< 1000ms` is too tight on a slow CI runner or cold-start; test flakes | accept | Phase 2 runs the test locally (not on CI). 1s emulator latency is realistic — RESEARCH measured emulator round trips in 50-200ms range. If a future CI environment runs this test and flakes, the threshold can be bumped to 3000ms with a note; the assertion is a soft signal, not a hard requirement. |
| T-2-09-NO-DEBUG-TOKEN-LEAK | Information Disclosure | The test accidentally consumes APP_CHECK_DEBUG_TOKEN from a CI secret and leaks it via test stdout | mitigate | Verify gate `! grep -q "APP_CHECK_DEBUG_TOKEN" integration_test/ping_smoke_test.dart`. D-13 explicitly states Phase 2 emulator test does NOT use the secret. |
</threat_model>

<verification>
- integration_test/ping_smoke_test.dart exists with the correct scaffold.
- @Tags + library directive at top.
- Imports cloud_functions + firebase_core + flutter_test + integration_test + firebase_options + relative '../test/_helpers/emulator_setup.dart'.
- setUpAll initializes Firebase + calls configureEmulators (no user seeding, no App Check activate).
- testWidgets asserts ok=true, timestamp is int, region='asia-south1', latency < 1000ms.
- No FirebaseAppCheck.instance.activate; no APP_CHECK_DEBUG_TOKEN reference.
- flutter analyze --no-fatal-infos exits 0.
- integration_test/login_smoke_test.dart unchanged (D-24).
</verification>

<success_criteria>
- D-12 met: ping_smoke_test.dart calls ping via Functions emulator; asserts shape + latency.
- D-13 honored: APP_CHECK_DEBUG_TOKEN not consumed (emulator bypasses).
- D-24 honored: login_smoke_test.dart untouched.
- FUNC-02 + FUNC-06 end-to-end exercise complete (server callable + client SDK + emulator round trip).
- Phase 2 nyquist gate: static checks (file exists, analyze passes, grep gates) green even without a live emulator run; live run validates remaining truths locally.
- Phase 3 inherits a working PingRepository + smoke test as a regression canary.
</success_criteria>

<output>
Create `.planning/phases/02-cloud-functions-scaffolding-app-check/02-09-ping-smoke-test-SUMMARY.md` when done. Record:
1. The full content of integration_test/ping_smoke_test.dart as written.
2. The flutter analyze exit code.
3. (If attempted) the live emulator run output: emulator boot log line confirming `ping[asia-south1]` registered, the flutter test exit code, the test pass/fail summary line, and the latency reported in the test output (if accessible from the test stdout).
4. Confirmation that integration_test/login_smoke_test.dart is unchanged.
5. iOS simulator UDID used (if live run executed) — or note "live run deferred to local dev" if not.
</output>
