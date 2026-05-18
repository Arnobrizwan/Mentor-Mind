---
phase: 02-cloud-functions-scaffolding-app-check
plan: 08
type: execute
wave: 4
depends_on: ["02-04", "02-07"]
files_modified:
  - test/_helpers/emulator_setup.dart
  - lib/main.dart
autonomous: true
requirements: [FUNC-06]
pr_group: PR-3
tags: [use_functions_emulator, emulator_setup, main_dart_emulator_block, lib_must_not_import_test, port_5001]

must_haves:
  truths:
    - "D-18 honored: `configureEmulators()` extended with `FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001)`; lib/main.dart USE_EMULATOR guard extends the same call inline"
    - "Port 5001 matches firebase.json emulators.functions.port from Plan 02-04"
    - "lib/main.dart MUST NOT import from test/ (Phase 1 invariant; established in Plan 01-09) — the 4-line wiring is intentionally duplicated"
    - "Call uses `FirebaseFunctions.instance` (default region) — NOT `instanceFor(region:'asia-south1')` — per RESEARCH Pattern 7 + Pitfall 2 (the emulator redirect applies to all instances created before the region-scoped instance is first read; calling on .instance is the well-trodden path)"
    - "useFunctionsEmulator is synchronous (no await needed) — different from useAuthEmulator / useStorageEmulator"
    - "After this plan: `flutter run --dart-define=USE_EMULATOR=true` connects to the local Functions emulator at port 5001"
    - "Phase 1 login_smoke_test continues to work (D-11, D-24 honored — auth/firestore/storage emulator wiring is preserved; only adds Functions)"
  artifacts:
    - path: "test/_helpers/emulator_setup.dart"
      provides: "Extends configureEmulators() with FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001)"
      contains: "useFunctionsEmulator"
    - path: "lib/main.dart"
      provides: "Extends USE_EMULATOR guard with the same useFunctionsEmulator call inline"
      contains: "useFunctionsEmulator"
  key_links:
    - from: "test/_helpers/emulator_setup.dart"
      to: "firebase.json emulators.functions.port (Plan 02-04 = 5001)"
      via: "port literal 5001"
      pattern: "5001"
    - from: "lib/main.dart USE_EMULATOR block"
      to: "test/_helpers/emulator_setup.dart"
      via: "DUPLICATED — NOT imported (lib MUST NOT import test)"
      pattern: "5001"
---

<objective>
Extend two existing files with a single new line each, adding the Functions emulator redirect: `FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001)`. One copy lives in `test/_helpers/emulator_setup.dart`'s `configureEmulators()` (for integration tests); a matching duplicate lives in `lib/main.dart`'s `USE_EMULATOR` guard (for app-level emulator runs). The duplication is intentional — lib/ MUST NOT import test/ (Phase 1 invariant locked in Plan 01-09).

Purpose: Plan 02-04 added the Functions emulator entry to firebase.json (port 5001). Plan 02-07 added cloud_functions to pubspec.yaml + the firebase_functions_provider.dart. Plan 02-09's `ping_smoke_test.dart` will fail without this wiring because the SDK would route the `httpsCallable('ping')` invocation to production Firebase (which has no ping deployed in Phase 2 per D-23). The redirect MUST be called BEFORE any callable invocation; lib/main.dart's USE_EMULATOR block runs before `runApp` and therefore before any Riverpod provider is read.

Output: Two files modified, each gaining one line (plus an import in lib/main.dart). After commit, `flutter run --dart-define=USE_EMULATOR=true` connects to the local emulator; Plan 02-09's integration test setUpAll calls `configureEmulators()` and gets the redirect for free.
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
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-04-functions-emulator-config-PLAN.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-07-flutter-functions-sdk-PLAN.md
@test/_helpers/emulator_setup.dart
@lib/main.dart
@CLAUDE.md

<interfaces>
<!-- Self-modify patterns from 02-PATTERNS.md (Group 4 lines 162-222) -->

test/_helpers/emulator_setup.dart — CURRENT (repo state, full file ~32 lines):
  ```dart
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:firebase_storage/firebase_storage.dart';

  // ---------------------------------------------------------------------------
  // emulator_setup.dart — Configure Firebase SDKs to talk to the Local Emulator
  // Suite instead of the production project.
  //   ... [banner block]
  // Ports must match firebase.json emulators block:
  //   auth:      localhost:9099
  //   firestore: localhost:8080
  //   storage:   localhost:9199
  // ---------------------------------------------------------------------------

  // kUseEmulator is a compile-time const so the check is free at runtime.
  const bool kUseEmulator =
      String.fromEnvironment('USE_EMULATOR', defaultValue: 'false') == 'true';

  Future<void> configureEmulators() async {
    if (!kUseEmulator) return;
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
  }
  ```

test/_helpers/emulator_setup.dart — DESIRED (2 edits):

  Edit 1 — Add cloud_functions import (alphabetically; goes BETWEEN cloud_firestore and firebase_auth):
    ```dart
    import 'package:cloud_firestore/cloud_firestore.dart';
    import 'package:cloud_functions/cloud_functions.dart';
    import 'package:firebase_auth/firebase_auth.dart';
    import 'package:firebase_storage/firebase_storage.dart';
    ```

  Edit 2 — Append one line to `configureEmulators()` body (after the existing Storage line):
    ```dart
    Future<void> configureEmulators() async {
      if (!kUseEmulator) return;
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
      await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
      FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
    }
    ```

    NOTE: `useFunctionsEmulator` is SYNCHRONOUS (does not return a Future — confirmed in RESEARCH Pattern 7 line 219 "this call does NOT need `await`"). DO NOT add `await` even though the surrounding calls do.

  Edit 3 (recommended) — Update the banner comment ports block to mention functions:5001:
    ```dart
    // Ports must match firebase.json emulators block:
    //   auth:      localhost:9099
    //   firestore: localhost:8080
    //   storage:   localhost:9199
    //   functions: localhost:5001
    ```

lib/main.dart — CURRENT (relevant section after Plan 02-06):
  ```dart
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:firebase_app_check/firebase_app_check.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:firebase_core/firebase_core.dart';
  import 'package:firebase_storage/firebase_storage.dart';
  import 'package:flutter/foundation.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:hooks_riverpod/hooks_riverpod.dart';

  ...

    const bool useEmulator =
        bool.fromEnvironment('USE_EMULATOR', defaultValue: false);
    if (useEmulator) {
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
      await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
    }
  ```

lib/main.dart — DESIRED (2 edits):

  Edit 1 — Add cloud_functions import (alphabetically; goes BETWEEN cloud_firestore and firebase_app_check):
    ```dart
    import 'package:cloud_firestore/cloud_firestore.dart';
    import 'package:cloud_functions/cloud_functions.dart';
    import 'package:firebase_app_check/firebase_app_check.dart';
    ...
    ```

  Edit 2 — Append one line to the USE_EMULATOR `if (useEmulator) { ... }` body (after the existing Storage line):
    ```dart
    if (useEmulator) {
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
      await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
      FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
    }
    ```

    Same SYNCHRONOUS note — no await. The line is identical to the one in test/_helpers/emulator_setup.dart (intentional duplication).

Why the duplication is acceptable:
  - lib/ MUST NOT import test/ — Phase 1 invariant (anchor test 4 in Plan 01-08 enforces zero `Firebase.initializeApp` calls under test/; the analogous invariant for lib/ is "no test/ imports").
  - Plan 01-09 documents this exact tradeoff in its `<interfaces>` block: "lib/main.dart duplicates the 3-line wiring; the helper exists for the integration test, not for main.dart."
  - The duplication is 1 line; the alternative (creating a shared helper under lib/core/) would entangle production code with test-only behavior.

RESEARCH Pattern 7 + Pitfall 2 — useFunctionsEmulator on `instance` (NOT `instanceFor`):
  - `useFunctionsEmulator` is called on `FirebaseFunctions.instance` (the default region instance).
  - `firebase_functions_provider.dart` (Plan 02-07) returns `FirebaseFunctions.instanceFor(region: 'asia-south1')` — a DIFFERENT instance.
  - The two instances DO share the emulator redirect because the redirect is applied at the platform-channel level BEFORE any region scoping. RESEARCH §Pattern 7 line 469: "The emulator redirect must be applied before the region-scoped instance is first used. The ordering in lib/main.dart handles this: useFunctionsEmulator is called in the emulator block before runApp, which is before any Riverpod provider reads."
  - This is the path the firebase docs + community examples take — do NOT call `useFunctionsEmulator` on the `instanceFor` variant.

What this plan does NOT do:
  - Does NOT write integration_test/ping_smoke_test.dart (Plan 02-09).
  - Does NOT lift the CI functions: job (Plan 02-10).
  - Does NOT alter any pre-existing emulator wiring (firestore/auth/storage stay unchanged — preserves Phase 1's login_smoke_test).
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Extend test/_helpers/emulator_setup.dart with FirebaseFunctions.instance.useFunctionsEmulator</name>
  <files>test/_helpers/emulator_setup.dart</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/test/_helpers/emulator_setup.dart (CURRENT — confirm imports order + body of configureEmulators())
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-PATTERNS.md (§test/_helpers/emulator_setup.dart — lines 205-222: single new line addition)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-RESEARCH.md (§Pattern 7 — useFunctionsEmulator synchronous; no await)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-CONTEXT.md (D-18 — `configureEmulators()` extended)
  </read_first>
  <action>
    Step A — Read test/_helpers/emulator_setup.dart. Confirm 3 imports + the function body shape.

    Step B — Add cloud_functions import:
      Insert `import 'package:cloud_functions/cloud_functions.dart';` BETWEEN `import 'package:cloud_firestore/cloud_firestore.dart';` and `import 'package:firebase_auth/firebase_auth.dart';` (alphabetical order).

    Step C — Append one line to configureEmulators():
      Inside the function body, AFTER the existing `await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);` line and BEFORE the closing `}`, add:
      ```dart
        FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
      ```
      NO await. Match indentation (2 spaces) with the surrounding lines.

    Step D — Update the banner comment to add the Functions row:
      In the comment block "Ports must match firebase.json emulators block:", add a new line after the storage entry:
      ```dart
      //   functions: localhost:5001
      ```

    Step E — Final file content (full — verify by reading after edit):
      ```dart
      import 'package:cloud_firestore/cloud_firestore.dart';
      import 'package:cloud_functions/cloud_functions.dart';
      import 'package:firebase_auth/firebase_auth.dart';
      import 'package:firebase_storage/firebase_storage.dart';

      // ---------------------------------------------------------------------------
      // emulator_setup.dart — Configure Firebase SDKs to talk to the Local Emulator
      // Suite instead of the production project.
      //
      // ... [existing banner preserved] ...
      //
      // Ports must match firebase.json emulators block:
      //   auth:      localhost:9099
      //   firestore: localhost:8080
      //   storage:   localhost:9199
      //   functions: localhost:5001
      //
      // The USE_EMULATOR dart-define is also read by lib/main.dart to wire
      // the same redirects when running the full app under emulators.
      // ---------------------------------------------------------------------------

      const bool kUseEmulator =
          String.fromEnvironment('USE_EMULATOR', defaultValue: 'false') == 'true';

      Future<void> configureEmulators() async {
        if (!kUseEmulator) return;
        FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
        await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
        await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
        FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
      }
      ```

    Step F — Verify:
      `dart format test/_helpers/emulator_setup.dart` — no changes.
      `flutter analyze --no-fatal-infos test/_helpers/emulator_setup.dart` — exits 0.

    Step G — Commit:
      `git add test/_helpers/emulator_setup.dart`
      Commit message: `feat(test): extend configureEmulators with Functions emulator (port 5001) (Phase 2 PR-3 / FUNC-06; CONTEXT D-18)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "useFunctionsEmulator" test/_helpers/emulator_setup.dart &amp;&amp; grep -q "5001" test/_helpers/emulator_setup.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "import 'package:cloud_functions/cloud_functions.dart';" test/_helpers/emulator_setup.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "FirebaseFunctions\.instance\.useFunctionsEmulator\(.localhost.,\s*5001\)" test/_helpers/emulator_setup.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -qE "await\s+FirebaseFunctions\.instance\.useFunctionsEmulator" test/_helpers/emulator_setup.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --no-fatal-infos test/_helpers/emulator_setup.dart 2>&amp;1 | tee /tmp/p2-08-t1-analyze.log &amp;&amp; ! grep -qE '^\s*(error|warning) -' /tmp/p2-08-t1-analyze.log</automated>
  </verify>
  <acceptance_criteria>
    - test/_helpers/emulator_setup.dart imports cloud_functions.
    - Contains the literal `useFunctionsEmulator('localhost', 5001)`.
    - The call is NOT awaited (synchronous per RESEARCH Pattern 7).
    - flutter analyze exits 0 on the file.
  </acceptance_criteria>
  <done>
    Plan 02-09's `ping_smoke_test.dart` will call `configureEmulators()` in setUpAll and automatically get the Functions emulator redirect.
  </done>
</task>

<task type="auto">
  <name>Task 2: Extend lib/main.dart's USE_EMULATOR block with FirebaseFunctions.instance.useFunctionsEmulator</name>
  <files>lib/main.dart</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/lib/main.dart (CURRENT — after Plans 02-06; confirm import ordering + the USE_EMULATOR if-block contents)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-PATTERNS.md (§lib/main.dart — lines 165-203: Extension Point B for emulator block + the "lib MUST NOT import test" constraint)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-RESEARCH.md (§Pattern 7 lines 446-470 — same FirebaseFunctions.instance usage + ordering invariant)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-09-emulator-integration-smoke-PLAN.md (Phase 1 lib MUST NOT import test invariant)
  </read_first>
  <action>
    Step A — Read lib/main.dart. Confirm:
      - Imports include cloud_firestore, firebase_app_check (from Plan 02-06), firebase_auth, firebase_core, firebase_storage, flutter/foundation, flutter/material, flutter/services, hooks_riverpod.
      - Inside `void main() async`, after the FirebaseAppCheck.activate block (Plan 02-06 added), there's a `const bool useEmulator = bool.fromEnvironment(...)` line followed by `if (useEmulator) { ... }` containing 3 lines (firestore + auth + storage emulators).

    Step B — Add cloud_functions import:
      Insert `import 'package:cloud_functions/cloud_functions.dart';` BETWEEN `import 'package:cloud_firestore/cloud_firestore.dart';` and `import 'package:firebase_app_check/firebase_app_check.dart';` (alphabetical order).

    Step C — Append one line to the `if (useEmulator) { ... }` body:
      Inside the if block, AFTER `await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);` and BEFORE the closing `}`, add:
      ```dart
        FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
      ```
      NO await. Match indentation (4 spaces — emulator-block lines are inside the if which is inside main).

    Step D — Final relevant section of lib/main.dart:
      ```dart
      import 'package:cloud_firestore/cloud_firestore.dart';
      import 'package:cloud_functions/cloud_functions.dart';
      import 'package:firebase_app_check/firebase_app_check.dart';
      import 'package:firebase_auth/firebase_auth.dart';
      import 'package:firebase_core/firebase_core.dart';
      import 'package:firebase_storage/firebase_storage.dart';
      import 'package:flutter/foundation.dart';
      import 'package:flutter/material.dart';
      import 'package:flutter/services.dart';
      import 'package:hooks_riverpod/hooks_riverpod.dart';

      ...

        const bool useEmulator =
            bool.fromEnvironment('USE_EMULATOR', defaultValue: false);
        if (useEmulator) {
          FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
          await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
          await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
          FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
        }

        runApp(const ProviderScope(child: MentorMindsApp()));
      ```

    Step E — Critical "lib MUST NOT import test" check:
      `! grep -q "package:flutter_test\|package:integration_test\|/test/" lib/main.dart`
      Must succeed — lib/main.dart must NOT reference any test paths. The 1-line duplication of useFunctionsEmulator with test/_helpers/emulator_setup.dart is intentional.

    Step F — Build smokes:
      `flutter analyze --no-fatal-infos` — exits 0.
      `flutter build ios --no-codesign` — exits 0 (cloud_functions iOS plugin registers cleanly).
      `dart run custom_lint` — exits 0 (lib/main.dart imports cloud_functions; lib/main.dart is the entrypoint, NOT under lib/presentation/ or lib/application/ — the layered_imports rule scope is restricted to those layers).

    Step G — Commit:
      `git add lib/main.dart`
      Commit message: `feat(main): extend USE_EMULATOR guard with Functions emulator (port 5001) (Phase 2 PR-3 / FUNC-06; CONTEXT D-18)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "useFunctionsEmulator" lib/main.dart &amp;&amp; grep -q "5001" lib/main.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "import 'package:cloud_functions/cloud_functions.dart';" lib/main.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "FirebaseFunctions\.instance\.useFunctionsEmulator\(.localhost.,\s*5001\)" lib/main.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -qE "package:flutter_test|package:integration_test|/test/" lib/main.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; awk '/Firebase\.initializeApp/{init=NR} /FirebaseAppCheck\.instance\.activate/{ac=NR} /useFunctionsEmulator/{ue=NR} /runApp\(/{run=NR} END{ if(init==0||ac==0||ue==0||run==0) exit 1; if(!(init &lt; ac &amp;&amp; ac &lt; ue &amp;&amp; ue &lt; run)) exit 1; print "init="init" activate="ac" useFunctionsEmulator="ue" runApp="run" OK"}' lib/main.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --no-fatal-infos 2>&amp;1 | tee /tmp/p2-08-t2-analyze.log &amp;&amp; ! grep -qE '^\s*(error|warning) -' /tmp/p2-08-t2-analyze.log</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; dart run custom_lint 2>&amp;1 | tee /tmp/p2-08-t2-customlint.log &amp;&amp; ! grep -q 'layered_imports' /tmp/p2-08-t2-customlint.log</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter build ios --no-codesign 2>&amp;1 | tail -10 | tee /tmp/p2-08-t2-build.log; test $? -eq 0</automated>
  </verify>
  <acceptance_criteria>
    - lib/main.dart imports cloud_functions.
    - Contains the literal `useFunctionsEmulator('localhost', 5001)` inside the USE_EMULATOR if-block.
    - The call is NOT awaited (synchronous).
    - lib/main.dart does NOT import flutter_test, integration_test, or `/test/` (T-1-EMU-LEAK invariant from Phase 1 preserved).
    - Ordering invariant: Firebase.initializeApp → FirebaseAppCheck.activate → useFunctionsEmulator → runApp.
    - flutter analyze exits 0.
    - dart run custom_lint exits 0 with no layered_imports violations.
    - flutter build ios --no-codesign exits 0.
  </acceptance_criteria>
  <done>
    `flutter run --dart-define=USE_EMULATOR=true` now connects to the Functions emulator at localhost:5001. The Firestore/Auth/Storage emulator wiring is preserved (Phase 1's login_smoke_test continues to pass). Plan 02-09's integration test can call `configureEmulators()` in setUpAll and reach the ping callable via the emulator.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| lib/ ⇄ test/ | Phase 1 invariant: lib MUST NOT import test. The 1-line useFunctionsEmulator duplication preserves this; the alternative (a shared helper under lib/core/) would entangle production code with test-only concerns. |
| dev/CI run ⇄ Functions emulator | The emulator redirect routes httpsCallable() to localhost:5001; production Firebase is never contacted in emulator runs. RESEARCH Pitfall 2 documents the ordering invariant: redirect applied BEFORE any callable invocation. |
| FirebaseFunctions.instance ⇄ instanceFor(region:'asia-south1') | Two distinct instances. The emulator redirect applies to BOTH because it's at the platform-channel level (RESEARCH Pattern 7 line 469). Verify by running the integration test in Plan 02-09 against the emulator (no production contact). |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-2-08-PROD-CONTACT | Information Disclosure | useFunctionsEmulator called AFTER httpsCallable() first invocation — the call goes to production Firebase | mitigate | RESEARCH Pitfall 2 documents the ordering: lib/main.dart calls useFunctionsEmulator in the synchronous USE_EMULATOR block BEFORE `runApp` (and therefore before any Riverpod provider is read). configureEmulators() in test setUpAll runs BEFORE testWidgets bodies. Verify: awk gate confirms `useFunctionsEmulator` line precedes `runApp` line in lib/main.dart. |
| T-2-08-LIB-IMPORTS-TEST | Tampering | A future refactor extracts the 4-line emulator wiring into a shared helper under lib/, then imports it from test — breaks the lib-test separation | mitigate | Verify gate `! grep -qE "package:flutter_test\|package:integration_test\|/test/" lib/main.dart`. Phase 1 anchor test 4 enforces this from the test side; this gate enforces it from the lib side. |
| T-2-08-WRONG-PORT | Repudiation | A team-wide port change in firebase.json (e.g. 5555) requires updating BOTH lib/main.dart and test/_helpers/emulator_setup.dart — drift between them silently breaks one side | accept | Plan 02-04's firebase.json + this plan's two-file edit all use literal `5001`. Verify gates grep `5001` in both files. Drift detectable via integration test (Plan 02-09) — if firebase.json says 5001 but lib/main.dart says 5555, the smoke test fails. |
| T-2-08-AWAIT-ON-SYNC | Tampering | A future maintainer adds `await` to `FirebaseFunctions.instance.useFunctionsEmulator(...)` — TypeScript compiles but the unawaited Future warning becomes a behavior bug (useFunctionsEmulator is sync; await on a non-Future returns its value unwrapped — Dart's await-on-sync is a no-op but `flutter analyze` may flag with `unnecessary_await`) | accept | RESEARCH Pattern 7 + 02-PATTERNS.md both note "no await needed". Verify gate `! grep -qE "await.*useFunctionsEmulator"` catches drift; Plan 02-09's integration test would fail subtly if the await were misplaced before another emulator call. |
</threat_model>

<verification>
- test/_helpers/emulator_setup.dart contains the literal `useFunctionsEmulator('localhost', 5001)` (synchronous, no await).
- lib/main.dart contains the same literal inside the USE_EMULATOR if-block (synchronous, no await).
- Both files import cloud_functions.
- lib/main.dart does NOT import anything from test/ (lib-test separation preserved).
- Ordering: Firebase.initializeApp → FirebaseAppCheck.activate → useFunctionsEmulator → runApp.
- flutter analyze exits 0.
- dart run custom_lint exits 0 with zero layered_imports violations.
- flutter build ios --no-codesign exits 0.
</verification>

<success_criteria>
- D-18 met: both helper + main.dart wire the Functions emulator at port 5001.
- T-2-08-PROD-CONTACT mitigated (ordering invariant preserved).
- T-2-08-LIB-IMPORTS-TEST mitigated (lib has no test imports).
- FUNC-06 advances (emulator end of the round trip is reachable; Plan 02-09 will exercise it).
- Phase 1 login_smoke_test continues to work (D-11, D-24 — no removal of existing wiring).
</success_criteria>

<output>
Create `.planning/phases/02-cloud-functions-scaffolding-app-check/02-08-emulator-helper-wiring-SUMMARY.md` when done. Record:
1. The full diff of test/_helpers/emulator_setup.dart (1 import + 1 line).
2. The full diff of lib/main.dart (1 import + 1 line).
3. The awk-ordering check stdout from the verify block.
4. The `dart run custom_lint` line count of layered_imports matches (MUST be 0).
5. The `flutter build ios --no-codesign` exit code.
</output>
