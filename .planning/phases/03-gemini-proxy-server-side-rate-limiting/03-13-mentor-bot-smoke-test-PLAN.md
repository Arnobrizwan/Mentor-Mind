---
phase: 03-gemini-proxy-server-side-rate-limiting
plan: 13
type: execute
wave: 6
depends_on: ["03-12"]
files_modified:
  - integration_test/mentor_bot_smoke_test.dart
autonomous: true
requirements: [AI-01, AI-07, AI-10]
pr_group: PR-3
tags: [integration_test, mentor_bot_smoke, emulator_integration, idempotency_live_test, fake_gemini_client_emulator, gemini_client_mode_fake, ping_smoke_test_analog]

must_haves:
  truths:
    - "AI-01 + AI-07 + AI-10 honored end-to-end: smoke test calls `MentorBotRepository.sendMessage(...)` against the Functions emulator with `GEMINI_CLIENT_MODE=fake` (per CONTEXT D-21), asserts the 5-field response shape, asserts idempotency (same clientRequestId → same messageId)"
    - "Mirror of plan 02-09 (`integration_test/ping_smoke_test.dart`): `@Tags(<String>['emulator', 'integration'])` + `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` + `setUpAll(Firebase.initializeApp + configureEmulators)` — same scaffold per RESEARCH §Pattern 9"
    - "Emulator bypasses App Check (Phase 2 RESEARCH Pitfall 6) — the test does NOT register a debug token; the Functions emulator allows the request through; this verifies plumbing not enforcement (Phase 7 polish does the live-device App Check smoke)"
    - "Two test cases: (1) 5-field response shape + latency &lt; 5000ms; (2) idempotency — two calls with the SAME clientRequestId return the SAME messageId"
    - "Uses `ProviderContainer` to read `mentorBotRepositoryProvider` (plan 03-11) — exercises the FULL Riverpod wiring, not a hand-rolled SDK call (validates the layer boundary)"
    - "Test uses the Phase 2 D-CONTEXT `configureEmulators()` helper from `test/_helpers/emulator_setup.dart` (Phase 2 Plan 02-08 already added useFunctionsEmulator)"
    - "Test does NOT seed a user — `mentorBotChat` requires `request.auth.uid`; the emulator's `IntegrationTestWidgetsFlutterBinding` provides anonymous-auth-OK behavior; if not, the test seeds via `FirebaseAuth.instance.signInAnonymously()` OR signs in with a test account (decide at execute time based on emulator behavior; document in SUMMARY)"
    - "AI-07 honored on the wire: idempotency test exercises the SAME network round-trip the production app will perform — proves the dedupe path works end-to-end"
    - "AI-10 honored on the wire: the response shape `{text, promptTokens, completionTokens, messageId, createdAt}` is single-Future, not Stream"
    - "Plan 03-14 will keep this test OUT of the Linux CI runner (no iOS simulator); the test is local-dev-only with explicit `--dart-define=USE_EMULATOR=true` invocation"
  artifacts:
    - path: "integration_test/mentor_bot_smoke_test.dart"
      provides: "NEW — emulator smoke test for mentorBotChat end-to-end via MentorBotRepository; 2 testWidgets cases (shape + idempotency)"
      contains: "mentorBotRepositoryProvider"
  key_links:
    - from: "integration_test/mentor_bot_smoke_test.dart"
      to: "test/_helpers/emulator_setup.dart (Phase 2 Plan 02-08)"
      via: "relative import `'../test/_helpers/emulator_setup.dart'` + configureEmulators() in setUpAll"
      pattern: "configureEmulators"
    - from: "integration_test/mentor_bot_smoke_test.dart"
      to: "functions/src/index.ts mentorBotChat (plan 03-06)"
      via: "MentorBotRepository.sendMessage → httpsCallable('mentorBotChat') → emulator at localhost:5001"
      pattern: "mentorBotRepositoryProvider"
    - from: "integration_test/mentor_bot_smoke_test.dart"
      to: "GEMINI_CLIENT_MODE=fake env var"
      via: "emulator process started with GEMINI_CLIENT_MODE=fake env (manual setup; documented in test header comment)"
      pattern: "GEMINI_CLIENT_MODE"
---

<objective>
Create `integration_test/mentor_bot_smoke_test.dart` — an emulator smoke test that exercises the full Phase 3 path end-to-end: Flutter client → `MentorBotRepository` (plan 03-11) → `httpsCallable('mentorBotChat')` → Functions emulator (running plan 03-06's handler with `GEMINI_CLIENT_MODE=fake`) → fake Gemini client returns canned response → server writes session subcollection docs → response shape returns to client. Two test cases: (1) 5-field response shape + latency &lt; 5s; (2) idempotency — two calls with the SAME clientRequestId return the SAME messageId.

Purpose: AI-01 + AI-07 + AI-10 each have unit-test coverage (plan 03-03 gemini.test, plan 03-05 rate_limit.test, plan 03-06 idempotency.test), but unit tests mock the boundaries. The smoke test proves the real wiring: Riverpod providers, Firebase Functions SDK, Functions emulator, the rate_limit transaction against the real Firestore emulator, and the idempotency cache write. This is the Phase 3 nyquist gate's end-to-end exercise (per VALIDATION row 03-13).

Output: 1 file NEW. One commit. Manual run: `firebase emulators:start --only auth,firestore,storage,functions` in one terminal (with `GEMINI_CLIENT_MODE=fake` in `functions/.env.local`) + `flutter test integration_test/mentor_bot_smoke_test.dart --dart-define=USE_EMULATOR=true -d <iOS-sim>` in another → test passes.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-CONTEXT.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-RESEARCH.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-PATTERNS.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-09-ping-smoke-test-PLAN.md
@integration_test/ping_smoke_test.dart
@test/_helpers/emulator_setup.dart
@lib/data/repositories/mentor_bot_repository.dart
@CLAUDE.md

<interfaces>
<!-- Patterns from 03-PATTERNS.md §integration_test/mentor_bot_smoke_test.dart lines 898-958 + Phase 2 ping_smoke_test.dart scaffold -->

integration_test/mentor_bot_smoke_test.dart (NEW — full file, copy verbatim):

```dart
// Phase 3 — emulator smoke test for mentorBotChat end-to-end.
//
// Mirrors integration_test/ping_smoke_test.dart (Phase 2 Plan 02-09):
//   - @Tags(<String>['emulator', 'integration']) at library scope
//   - IntegrationTestWidgetsFlutterBinding.ensureInitialized()
//   - setUpAll(Firebase.initializeApp + configureEmulators)
//   - No App Check activate() — emulator bypasses (RESEARCH Pitfall 6)
//
// REQUIRES the emulator to be running with GEMINI_CLIENT_MODE=fake:
//   1. Add `GEMINI_CLIENT_MODE=fake` to functions/.env.local (or export inline)
//   2. Run: firebase emulators:start --only auth,firestore,storage,functions
//   3. Wait for: ✔  functions[asia-south1-mentorBotChat]: ... initialized
//   4. Run: flutter test integration_test/mentor_bot_smoke_test.dart \
//             --dart-define=USE_EMULATOR=true -d <ios-simulator-UDID>
//
// The fake Gemini client returns the canned response per plan 03-03:
//   { text: 'Fake MentorBot response for testing.', promptTokens: 10, completionTokens: 20 }
// so this test exercises the WIRING + IDEMPOTENCY, not the model behavior.

@Tags(<String>['emulator', 'integration'])
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mentor_minds/data/models/mentor_bot_response.dart';
import 'package:mentor_minds/data/repositories/mentor_bot_repository.dart';
import 'package:mentor_minds/firebase_options.dart';
import 'package:uuid/uuid.dart';

import '../test/_helpers/emulator_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MentorBotRepository repo;

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await configureEmulators();
    // mentorBotChat requires request.auth.uid (plan 03-06). Anonymous auth
    // works against the emulator's Auth emulator with zero setup.
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    container = ProviderContainer();
    repo = container.read(mentorBotRepositoryProvider);
  });

  tearDownAll(() async {
    container.dispose();
    await FirebaseAuth.instance.signOut();
  });

  testWidgets(
    'mentorBotChat smoke — 5-field response shape via emulator',
    (tester) async {
      final sessionId = const Uuid().v4();
      final clientRequestId = const Uuid().v4();
      final stopwatch = Stopwatch()..start();

      final response = await repo.sendMessage(
        sessionId: sessionId,
        clientRequestId: clientRequestId,
        message: 'Hello MentorBot — smoke test',
      );

      stopwatch.stop();

      expect(response, isA<MentorBotResponse>());
      // Fake client returns canned 'Fake MentorBot response for testing.'
      expect(response.text, isNotEmpty);
      expect(response.messageId, isNotEmpty);
      expect(response.promptTokens, greaterThanOrEqualTo(0));
      expect(response.completionTokens, greaterThanOrEqualTo(0));
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(5000),
        reason:
            'Emulator latency &lt; 5s. Production target is &lt; 10s (cold start ~2-4s + Vertex ~3-5s).',
      );
    },
    tags: ['emulator', 'integration'],
  );

  testWidgets(
    'mentorBotChat smoke — idempotent retry returns SAME messageId',
    (tester) async {
      final sessionId = const Uuid().v4();
      final clientRequestId = const Uuid().v4(); // SAME id for both calls

      final first = await repo.sendMessage(
        sessionId: sessionId,
        clientRequestId: clientRequestId,
        message: 'Idempotency probe',
      );
      final second = await repo.sendMessage(
        sessionId: sessionId,
        clientRequestId: clientRequestId,
        message: 'Idempotency probe',
      );

      // Per plan 03-06 D-08: messageId === clientRequestId. Both calls return
      // the same id, proving the server-side dedupe path is hit.
      expect(second.messageId, equals(first.messageId));
      expect(second.text, equals(first.text));
    },
    tags: ['emulator', 'integration'],
  );
}
```

Key invariants of the scaffold (mirrors plan 02-09):
  - `@Tags(<String>['emulator', 'integration'])` at LIBRARY scope.
  - `library;` directive on its own line (Dart's "library" syntax for tag-bearing files).
  - `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` before any test code.
  - `setUpAll` initializes Firebase + redirects to emulators + signs in anonymously.
  - `ProviderContainer` is the test's Riverpod root (no widget tree booted — the test exercises the repository directly via the provider).
  - Each `testWidgets` repeats the `tags: [...]` for clarity (redundant with library-level @Tags but harmless).
  - `tearDownAll` disposes the container + signs out.

Why anonymous auth (not full sign-in flow):
  - `mentorBotChat` only reads `request.auth.uid` (a unique identifier); it does NOT check email-verification or custom claims (D-24 — AUTH-02 deferred to Phase 7).
  - Anonymous auth gives a stable uid for the test session — perfect for idempotency testing across two calls in the same session.
  - The Auth emulator's anonymous path is instant (no email round-trip).

Why this test uses the `mentorBotRepositoryProvider` (not direct `FirebaseFunctions.instance.httpsCallable`):
  - Validates the FULL Phase 3 PR-3 wiring: Riverpod provider → repository → cast → fromMap → return.
  - If the production app's `chat_viewmodel.dart` (plan 03-12) hits a wire-shape mismatch, this smoke test sees the same error.
  - Plan 02-09's ping smoke test used direct `FirebaseFunctions.instance` because it was Phase 2 plumbing-validation; Phase 3 ships the repository layer and tests it.

Manual run instructions (RECORD in SUMMARY):
  Terminal 1 (background — start emulator with fake Gemini client):
    ```bash
    cd /Users/arnobrizwan/Mentor-Mind
    # Set the env var the function reads at startup (plan 03-06 D-21).
    echo "GEMINI_CLIENT_MODE=fake" > functions/.env.local
    nvm use 20
    firebase emulators:start --only auth,firestore,storage,functions \
      > /tmp/p3-13-emu.log 2>&amp;1 &amp;
    sleep 18  # wait for emulator boot + functions compile
    grep -E "mentorBotChat|asia-south1-mentorBotChat" /tmp/p3-13-emu.log
    # Expect line: ✔  functions[asia-south1-mentorBotChat]: ... initialized
    ```

  Terminal 2 (foreground — run the smoke test):
    ```bash
    DEVICE=$(xcrun simctl list devices booted | grep -E "iPhone|iPad" | head -1 | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')
    flutter test integration_test/mentor_bot_smoke_test.dart \
      --dart-define=USE_EMULATOR=true -d "$DEVICE" 2>&amp;1 | tee /tmp/p3-13-test.log
    # Expected: 00:0X +2: All tests passed!
    ```

  Cleanup:
    ```bash
    kill %1 2>/dev/null  # stop the emulator
    rm functions/.env.local
    ```

What this plan does NOT do:
  - Does NOT call the real Vertex API (`GEMINI_CLIENT_MODE=fake` keeps the smoke test free of network deps + cost).
  - Does NOT test rate-limit enforcement (the fake client doesn't fire enough calls to hit the cap; plan 03-05 unit tests cover that).
  - Does NOT test App Check enforcement (the emulator bypasses; live-device App Check smoke is Phase 7 polish).
  - Does NOT modify dart_test.yaml — the `emulator:` + `integration:` tags exist from Phase 1.
  - Does NOT modify integration_test/login_smoke_test.dart or integration_test/ping_smoke_test.dart.
  - Does NOT run in CI (Linux runners can't host iOS simulators; plan 03-14 adds `npm test` but NOT `flutter test integration_test` — that's a future macOS-runner concern).
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create integration_test/mentor_bot_smoke_test.dart with the @Tags-decorated 2-test scaffold; verify analyze + (best-effort) manual emulator run</name>
  <files>integration_test/mentor_bot_smoke_test.dart</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/integration_test/ping_smoke_test.dart (Phase 2 Plan 02-09 — the EXACT analog scaffold; library directive, @Tags, setUpAll pattern)
    - /Users/arnobrizwan/Mentor-Mind/test/_helpers/emulator_setup.dart (Phase 2 D-CONTEXT — confirm configureEmulators() includes useFunctionsEmulator + useAuthEmulator)
    - /Users/arnobrizwan/Mentor-Mind/lib/data/repositories/mentor_bot_repository.dart (plan 03-11 — confirm mentorBotRepositoryProvider + sendMessage signature)
    - /Users/arnobrizwan/Mentor-Mind/lib/data/models/mentor_bot_response.dart (plan 03-11 — confirm MentorBotResponse fields)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-PATTERNS.md (§integration_test/mentor_bot_smoke_test.dart lines 898-958)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md (row `03-13-mentor-bot-smoke-test` line 66)
    - /Users/arnobrizwan/Mentor-Mind/dart_test.yaml (Phase 1 — confirm emulator: + integration: tags exist)
  </read_first>
  <action>
    Step A — Read `integration_test/ping_smoke_test.dart` to confirm the canonical Phase 2 scaffold (library directive, @Tags, setUpAll, testWidgets, tags propagation).

    Step B — Read `test/_helpers/emulator_setup.dart` to confirm:
      - `configureEmulators()` is exported.
      - It calls `useFunctionsEmulator('localhost', 5001)` (Phase 2 Plan 02-08).
      - It calls `useAuthEmulator('localhost', 9099)` (or similar) — confirm this AT READ TIME. If the Auth emulator is NOT redirected in `configureEmulators()`, the `signInAnonymously()` call would hit production Auth; this would still work (anonymous auth is cheap) but isn't the test intent. If Auth emulator isn't wired, document in the SUMMARY as a Phase 7 polish item OR add `FirebaseAuth.instance.useAuthEmulator('localhost', 9099)` to this test's setUpAll BEFORE the signInAnonymously call.

    Step C — Confirm dart_test.yaml has the tags:
      ```bash
      grep -E "emulator:|integration:" /Users/arnobrizwan/Mentor-Mind/dart_test.yaml
      # Expect: both tags defined.
      ```

    Step D — Write `integration_test/mentor_bot_smoke_test.dart` with the EXACT scaffold from the `<interfaces>` block.

    Step E — Static analysis:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      dart format integration_test/mentor_bot_smoke_test.dart  # idempotent — no changes expected
      flutter analyze --no-fatal-infos integration_test/mentor_bot_smoke_test.dart 2>&amp;1 | tee /tmp/p3-13-analyze.log
      test $? -eq 0
      ```

    Step F — Required-content greps:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      grep -q "@Tags(<String>\['emulator', 'integration'\])" integration_test/mentor_bot_smoke_test.dart
      grep -q '^library;' integration_test/mentor_bot_smoke_test.dart
      grep -q "IntegrationTestWidgetsFlutterBinding.ensureInitialized" integration_test/mentor_bot_smoke_test.dart
      grep -q "configureEmulators" integration_test/mentor_bot_smoke_test.dart
      grep -q "mentorBotRepositoryProvider" integration_test/mentor_bot_smoke_test.dart
      grep -q "repo.sendMessage" integration_test/mentor_bot_smoke_test.dart
      grep -q "messageId" integration_test/mentor_bot_smoke_test.dart
      grep -q "clientRequestId" integration_test/mentor_bot_smoke_test.dart
      grep -q "Uuid().v4()" integration_test/mentor_bot_smoke_test.dart
      # idempotency case present
      grep -q "idempotent retry returns SAME messageId" integration_test/mentor_bot_smoke_test.dart
      # No App Check activate (emulator bypasses)
      ! grep -q "FirebaseAppCheck.instance.activate" integration_test/mentor_bot_smoke_test.dart
      # No streaming
      ! grep -E 'await for|generateContentStream' integration_test/mentor_bot_smoke_test.dart
      # ping_smoke_test untouched
      git diff --name-only HEAD integration_test/ping_smoke_test.dart 2>/dev/null
      ```

    Step G — (Best-effort) live emulator run. This step is OPTIONAL — it requires:
      - functions/lib/index.js exists (plans 03-01..03-09 all merged).
      - An iOS simulator booted.
      - Node 20 + Firebase CLI.

      If those are available, run the manual sequence from the `<interfaces>` block (Terminal 1 starts the emulator with GEMINI_CLIENT_MODE=fake, Terminal 2 runs flutter test against the simulator). Record the test output. If a simulator is not available (headless agent), defer to local dev — the static analyze + grep gates already cover the file's correctness.

    Step H — Commit:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      git add integration_test/mentor_bot_smoke_test.dart
      git commit -m "test(integration): add mentor_bot_smoke_test against Functions emulator (Phase 3 PR-3; AI-01/AI-07/AI-10; mirrors ping_smoke_test)"
      ```
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f integration_test/mentor_bot_smoke_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "@Tags(&lt;String&gt;\['emulator', 'integration'\])" integration_test/mentor_bot_smoke_test.dart &amp;&amp; grep -q '^library;' integration_test/mentor_bot_smoke_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'IntegrationTestWidgetsFlutterBinding.ensureInitialized' integration_test/mentor_bot_smoke_test.dart &amp;&amp; grep -q 'configureEmulators' integration_test/mentor_bot_smoke_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'mentorBotRepositoryProvider' integration_test/mentor_bot_smoke_test.dart &amp;&amp; grep -q 'repo.sendMessage' integration_test/mentor_bot_smoke_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "Uuid().v4()" integration_test/mentor_bot_smoke_test.dart &amp;&amp; grep -q 'idempotent' integration_test/mentor_bot_smoke_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -q 'FirebaseAppCheck.instance.activate' integration_test/mentor_bot_smoke_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -E 'await for|generateContentStream' integration_test/mentor_bot_smoke_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "import '\\.\\./test/_helpers/emulator_setup.dart';" integration_test/mentor_bot_smoke_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --no-fatal-infos integration_test/mentor_bot_smoke_test.dart 2>&amp;1 | tail -3; test $? -eq 0</automated>
  </verify>
  <acceptance_criteria>
    - `integration_test/mentor_bot_smoke_test.dart` exists.
    - Library-level `@Tags(<String>['emulator', 'integration'])` + `library;` directive.
    - `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` called in main.
    - `configureEmulators()` called in setUpAll.
    - Anonymous-auth sign-in before each test session.
    - Reads `mentorBotRepositoryProvider` from a `ProviderContainer`.
    - 2 testWidgets cases: (a) 5-field response shape + latency < 5000ms; (b) idempotent retry returns same messageId.
    - Both cases use `Uuid().v4()` to generate sessionId + clientRequestId.
    - Idempotency case reuses the SAME clientRequestId across two calls.
    - No `FirebaseAppCheck.instance.activate` (emulator bypasses).
    - No streaming code path (AI-10).
    - Relative import `'../test/_helpers/emulator_setup.dart'` (matches ping_smoke_test).
    - `flutter analyze --no-fatal-infos` exits 0.
    - `integration_test/ping_smoke_test.dart` is unchanged.
  </acceptance_criteria>
  <done>
    The smoke test is on disk. Local run (with the emulator booted with `GEMINI_CLIENT_MODE=fake`) exercises the full Phase 3 path. CI does NOT run this test (no iOS simulator on Linux); plan 03-14 leaves it for local dev. Plan 03-15 closeout records whether the live run was attempted + passed.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| smoke test process ⇄ real Firebase project | Firebase.initializeApp targets production project for bootstrap config; configureEmulators() IMMEDIATELY redirects every SDK call to localhost. RESEARCH Pitfall 2 ordering invariant preserved (Phase 1 + Phase 2 already validated). |
| smoke test ⇄ Auth emulator | Anonymous sign-in against the Auth emulator (port 9099 typically) — stable test uid, no production data touched. |
| smoke test ⇄ Functions emulator | Calls hit localhost:5001; the Functions runtime uses `GEMINI_CLIENT_MODE=fake` so no real Vertex API call; emulator bypasses App Check enforcement. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-3-13-EMU-DOWN | Denial of Service | Developer runs `flutter test integration_test/mentor_bot_smoke_test.dart` without the emulator running | accept | Documented in the manual run instructions (this plan's task §F). The test framework reports the connection failure clearly. CI does not run this test. |
| T-3-13-PROD-VERTEX-CALL | Information Disclosure | GEMINI_CLIENT_MODE is not set to 'fake' in the emulator's functions/.env.local; smoke test triggers real Vertex calls + costs | mitigate | Test header comment explicitly states GEMINI_CLIENT_MODE=fake is required. Plan 03-15 closeout reads this SUMMARY and confirms the env var was set. Phase 7 polish: emulator helper auto-sets the env var. |
| T-3-13-FLAKY-LATENCY | Denial of Service | Latency assertion `< 5000ms` is too tight on a slow CI runner or cold-start | accept | Phase 3 runs this test LOCALLY (not in CI). 5s emulator latency is realistic — fake client returns in &lt; 1s; rate_limit transaction adds ~100ms; total &lt; 2s typically. If a future macOS-runner runs this and flakes, the threshold can be bumped. |
| T-3-13-ANON-AUTH-LEAK | Information Disclosure | Anonymous auth user signed in against PRODUCTION Auth (if configureEmulators didn't redirect Auth) — creates a real anonymous user in production | mitigate | Step B reads emulator_setup.dart to confirm useAuthEmulator is wired. If not wired, this plan ADDS the redirect in setUpAll BEFORE signInAnonymously. Otherwise the test creates an anonymous user in production (cleanup task). |
| T-3-13-IDEMP-RACE | Tampering | Two test calls fire so quickly that the idempotency cache read in plan 03-06 hasn't committed yet; second call enters as if first | accept | Plan 03-06 uses `await batch.commit()` BEFORE returning; the second call's read sees the committed doc. Plan 03-06's unit test verifies this. The smoke test reinforces it on the wire. |
| T-3-13-LOGIN-SMOKE-COLLISION | Repudiation | login_smoke_test.dart and mentor_bot_smoke_test.dart both run in `flutter test integration_test/` and share state via FirebaseAuth singleton | accept | mentor_bot_smoke_test signs in anonymously; login_smoke_test signs in with a test account. Order: when both run in same invocation, the second test's `setUpAll` re-signs-in fresh, replacing the previous user. tearDownAll signOut prevents leftover. |
</threat_model>

<verification>
- integration_test/mentor_bot_smoke_test.dart exists with the correct scaffold.
- @Tags + library directive at top.
- setUpAll initializes Firebase + configureEmulators + signInAnonymously.
- testWidgets cases assert 5-field response + idempotency.
- mentorBotRepositoryProvider used (not direct SDK call).
- No App Check activate; no streaming.
- flutter analyze --no-fatal-infos exits 0.
- ping_smoke_test.dart unchanged.
</verification>

<success_criteria>
- AI-01 + AI-07 + AI-10 end-to-end exercise ready.
- Local-run manual sequence documented.
- Plan 03-15 closeout records the manual-run outcome.
- Phase 7 / future macOS-runner-CI inherits the test.
</success_criteria>

<output>
Create `.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-13-mentor-bot-smoke-test-SUMMARY.md` when done. Record:
1. Full content of integration_test/mentor_bot_smoke_test.dart.
2. flutter analyze output (0 errors).
3. (If attempted) the live emulator run:
   - Emulator boot log line confirming `mentorBotChat[asia-south1]` registered.
   - The flutter test exit code.
   - The latency reported.
   - The two test outcomes (pass/fail).
   - The iOS simulator UDID.
4. (If deferred) "Live run deferred to local dev — static gates cover the file's correctness; Phase 3 nyquist gate still satisfied per VALIDATION §nyquist_compliant note."
5. Confirmation that configureEmulators() includes useAuthEmulator (or the explicit `useAuthEmulator` call added in this test's setUpAll).
6. Commit SHA.
7. Forward-pointer: plan 03-15 closeout records the live-run result if not yet performed.
</output>
</content>
