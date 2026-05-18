---
phase: 02-cloud-functions-scaffolding-app-check
plan: 06
type: execute
wave: 4
depends_on: ["02-01", "02-02", "02-03", "02-04"]
files_modified:
  - pubspec.yaml
  - lib/main.dart
  - ios/Runner/Runner.entitlements
autonomous: true
requirements: [FUNC-03]
pr_group: PR-3
tags: [firebase_app_check, app_attest, debug_provider, kReleaseMode, runner_entitlements, app_attest_production_environment]

must_haves:
  truths:
    - "D-02 honored: App Attest provider on iOS 14+ release builds; Debug provider on dev simulators + CI. Provider selection lives in lib/main.dart AFTER `Firebase.initializeApp(...)` and BEFORE any provider/repository reads"
    - "kReleaseMode branch: `appleProvider: kReleaseMode ? AppleProvider.appAttest : AppleProvider.debug`"
    - "Runner.entitlements adds `com.apple.developer.devicecheck.appattest.environment = production` — forces App Attest production mode (RESEARCH Pitfall 1: sandbox tokens are rejected by Firebase)"
    - "pubspec.yaml adds `firebase_app_check: ^0.3.2+9` — NOT ^0.4.x (would force firebase_core ^4.x and break the Phase 1 lockstep per RESEARCH §Standard Stack)"
    - "lib/main.dart imports `package:firebase_app_check/firebase_app_check.dart` and `package:flutter/foundation.dart` (for kReleaseMode)"
    - "T-2-APPCHECK-BYPASS mitigated client-side (server-side mitigation is Plan 02-03's enforceAppCheck:true)"
    - "T-2-DEBUG-IN-PROD mitigated via kReleaseMode ternary"
    - "T-2-SANDBOX-ATTESTATION mitigated via Runner.entitlements production key"
    - "D-19 honored: PR-3 wires App Check end-to-end (server-side enforcement landed in PR-1 Plan 02-03; this plan adds the client-side activation)"
  artifacts:
    - path: "pubspec.yaml"
      provides: "firebase_app_check: ^0.3.2+9 dep (Apple App Attest + Debug providers)"
      contains: "firebase_app_check: ^0.3"
    - path: "lib/main.dart"
      provides: "FirebaseAppCheck.instance.activate(appleProvider: kReleaseMode ? AppleProvider.appAttest : AppleProvider.debug) AFTER Firebase init, BEFORE runApp"
      contains: "FirebaseAppCheck.instance.activate"
    - path: "ios/Runner/Runner.entitlements"
      provides: "Adds com.apple.developer.devicecheck.appattest.environment = production key (App Attest production mode)"
      contains: "com.apple.developer.devicecheck.appattest.environment"
  key_links:
    - from: "lib/main.dart FirebaseAppCheck.activate"
      to: "functions/src/index.ts enforceAppCheck: true (Plan 02-03)"
      via: "client emits token; server validates token (production only; emulator bypasses per RESEARCH Pitfall 6)"
      pattern: "FirebaseAppCheck"
    - from: "ios/Runner/Runner.entitlements appattest.environment = production"
      to: "App Attest hardware on iOS 14+ Secure Enclave"
      via: "iOS reads entitlement to switch attestation mode from sandbox to production"
      pattern: "appattest\\.environment"

unresolved_questions:
  - "Apple Developer Program account type (RESEARCH §Open Question 1; VALIDATION §Open Question A): App Attest requires a paid Apple Developer account. If `arnobrizwan23@gmail.com` is on a free account, the Runner.entitlements key will not compile against the App Attest capability and `AppleProvider.appAttest` will fail at runtime. Mitigation paths: (1) confirm paid account before merging PR-3 — proceed with appAttest as locked in D-02; (2) if free — substitute `AppleProvider.appAttestWithDeviceCheckFallback` (DeviceCheck works on free accounts) and update CONTEXT.md D-02 via amendment; (3) if free AND unwilling to upgrade — keep AppleProvider.debug universally and defer App Attest to Phase 6+ (breaks `enforceAppCheck` for any real production caller). The executor MUST surface the account status (paid vs free) before completing Task 1 and choose path (1) or (2)."
---

<objective>
Wire client-side App Check activation: add `firebase_app_check: ^0.3.2+9` to pubspec.yaml, insert `FirebaseAppCheck.instance.activate(appleProvider: kReleaseMode ? AppleProvider.appAttest : AppleProvider.debug)` into lib/main.dart between `Firebase.initializeApp` and the USE_EMULATOR block, and add the `com.apple.developer.devicecheck.appattest.environment = production` key to ios/Runner/Runner.entitlements.

Purpose: Plan 02-03 shipped server-side `enforceAppCheck: true` in PR-1; this plan completes the round trip by emitting valid App Check tokens from the iOS client. With both pieces, production callers without a registered debug token (or without App Attest hardware attestation) receive HTTP 401 / `unauthenticated` from any callable that opts in. The emulator continues to bypass App Check (RESEARCH Pitfall 6) — Phase 2's integration test (Plan 02-09) does NOT exercise the token validation path; that's a manual production verification step deferred to Phase 3's first production deploy.

Output: Three files modified. After commit, `flutter pub get` resolves cleanly (the ^0.3.2+9 constraint is compatible with the existing `firebase_core 3.15.2` — verified in RESEARCH §Standard Stack), `flutter analyze --no-fatal-infos` exits 0, and `flutter build ios --no-codesign` exits 0. The App Attest capability MUST also be added in Xcode → Signing & Capabilities (manual step recorded in SUMMARY).
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
@lib/main.dart
@ios/Runner/Runner.entitlements
@pubspec.yaml
@CLAUDE.md

<interfaces>
<!-- Self-modify patterns from 02-PATTERNS.md (Groups 4, 5, 6) -->

pubspec.yaml — CURRENT Firebase deps block (per repo state, lines 27-32):
  ```yaml
    # Firebase
    firebase_core: ^3.6.0
    firebase_auth: ^5.3.1
    cloud_firestore: ^5.4.3
    firebase_storage: ^12.3.2
    firebase_messaging: ^15.1.3
    google_sign_in: ^6.2.1
  ```

pubspec.yaml — APPEND (this plan adds firebase_app_check only; cloud_functions is Plan 02-07):
  ```yaml
    firebase_app_check: ^0.3.2+9
  ```
  Insert after `google_sign_in: ^6.2.1` line. Maintain 2-space indent + comment grouping.

  Version constraint is safety-critical (RESEARCH Pitfall 3):
  - `firebase_app_check ^0.4.x` requires `firebase_core ^4.x` — INCOMPATIBLE with the existing `firebase_core ^3.6.0` (resolved 3.15.2).
  - `firebase_app_check ^0.3.2+9` resolves cleanly against `firebase_core ^3.15.1` (compatible).
  - Run `flutter pub get` immediately after editing pubspec.yaml; the version solver MUST succeed without conflict messages.

lib/main.dart — CURRENT state (per repo read; relevant section lines 25-48):
  ```dart
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Firebase init failed: $e');
    }

    // When launched with --dart-define=USE_EMULATOR=true, ... [emulator block]
    const bool useEmulator =
        bool.fromEnvironment('USE_EMULATOR', defaultValue: false);
    if (useEmulator) {
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
      await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
    }

    runApp(const ProviderScope(child: MentorMindsApp()));
  ```

lib/main.dart — DESIRED edits (2 changes):
  Change 1 — Add imports (alphabetically grouped, after existing Firebase imports):
    ```dart
    import 'package:firebase_app_check/firebase_app_check.dart';
    import 'package:flutter/foundation.dart';  // kReleaseMode
    ```
    Existing imports order: cloud_firestore, firebase_auth, firebase_core, firebase_storage, flutter/material, flutter/services, hooks_riverpod.
    Insertion: `firebase_app_check` goes immediately after `firebase_core` (alphabetical). `flutter/foundation.dart` goes immediately before `flutter/material.dart` (alphabetical: foundation < material).

    Plan 02-07 will ALSO add `cloud_functions` import; this plan does NOT pre-add it (single-responsibility per plan).

  Change 2 — Insert FirebaseAppCheck.activate AFTER `Firebase.initializeApp` and BEFORE the USE_EMULATOR block:
    ```dart
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        debugPrint('Firebase init failed: $e');
      }

      // App Check — emits a token per-call for any callable with enforceAppCheck:
      // App Attest in release (iOS 14+ Secure Enclave hardware attestation);
      // Debug provider on dev simulators + CI (auto-generates a UUID token that
      // must be registered in Firebase Console; see BACKEND_SETUP.md §6).
      // The Functions emulator bypasses App Check validation (RESEARCH Pitfall 6).
      await FirebaseAppCheck.instance.activate(
        appleProvider: kReleaseMode
            ? AppleProvider.appAttest
            : AppleProvider.debug,
      );

      const bool useEmulator =
          bool.fromEnvironment('USE_EMULATOR', defaultValue: false);
      ...
    ```

    Critical ordering: `activate(...)` MUST run AFTER `Firebase.initializeApp(...)` and BEFORE `runApp(...)`. Both Plan 02-08's `useFunctionsEmulator` (in the USE_EMULATOR block) and Plan 02-07's `firebaseFunctionsProvider` reads happen later — activate must precede them so any callable invocation has a token-emission hook ready.

ios/Runner/Runner.entitlements — CURRENT state (per repo read):
  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
  	<key>keychain-access-groups</key>
  	<array>
  		<string>$(AppIdentifierPrefix)com.mentorminds.mentorMinds</string>
  	</array>
  </dict>
  </plist>
  ```

ios/Runner/Runner.entitlements — DESIRED state (insert one key-value pair BEFORE `</dict>`):
  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
  	<key>keychain-access-groups</key>
  	<array>
  		<string>$(AppIdentifierPrefix)com.mentorminds.mentorMinds</string>
  	</array>
  	<key>com.apple.developer.devicecheck.appattest.environment</key>
  	<string>production</string>
  </dict>
  </plist>
  ```

  Tab indentation matches existing keychain-access-groups (single tab, matching the existing plist's tab character).

  RESEARCH Pitfall 1 reminder:
  - Without this key, App Attest defaults to SANDBOX mode in dev builds. Firebase App Check REJECTS sandbox tokens. With the key set to `production`, App Attest always uses production attestation — works on both physical devices (with paid Apple Developer Program account) and is consistent with what Firebase Console expects.
  - Combined with the `kReleaseMode` ternary, the runtime flow is:
    - Debug builds (kReleaseMode == false): AppleProvider.debug — debug token, no App Attest call, no entitlement consulted.
    - Release builds (kReleaseMode == true): AppleProvider.appAttest — uses the entitlement, requests a PRODUCTION attestation.
  - The entitlement is harmless in debug builds (the Debug provider doesn't invoke App Attest) but mandatory in release.

Apple Developer Program note (RESEARCH Open Question 1 — surfaced in plan-level `unresolved_questions` frontmatter):
  - App Attest requires a PAID Apple Developer Program account ($99/yr).
  - If `arnobrizwan23@gmail.com` is on a FREE account, the Xcode App Attest capability cannot be enabled, the entitlement will not match a provisioning profile, and `flutter build ios` will fail signing.
  - The executor MUST verify account status (e.g. by checking the user's Apple Developer Portal access at https://developer.apple.com/account/) BEFORE running the build smoke. If FREE: switch to `AppleProvider.appAttestWithDeviceCheckFallback` (works on free accounts via DeviceCheck) and amend CONTEXT.md D-02; otherwise proceed with appAttest.

Xcode capability addition (MANUAL step — out of executor scope; recorded in SUMMARY):
  1. Open `ios/Runner.xcworkspace` in Xcode.
  2. Select the Runner target → Signing & Capabilities tab.
  3. Click `+ Capability` → choose `App Attest`.
  4. This adds the App Attest capability and updates the provisioning profile (if paid account; fails if free account).
  5. Save. The change is reflected in `ios/Runner.xcodeproj/project.pbxproj` (auto-modified).

  This Xcode step CANNOT be performed by the executor in headless mode. Plan 02-06 SUMMARY records "App Attest Xcode capability added: yes/no/blocked-on-paid-account".

What this plan does NOT do:
  - Does NOT add `cloud_functions` to pubspec.yaml (Plan 02-07's job).
  - Does NOT add `useFunctionsEmulator` to main.dart (Plan 02-08's job).
  - Does NOT create `firebase_functions_provider.dart` or `ping_repository.dart` (Plan 02-07's job).
  - Does NOT register a debug token in Firebase Console (manual step in BACKEND_SETUP.md §6 from Plan 02-05; out of executor scope).
  - Does NOT add the Xcode App Attest capability (manual step; out of executor scope; recorded in SUMMARY).
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add firebase_app_check to pubspec.yaml + run flutter pub get</name>
  <files>pubspec.yaml</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/pubspec.yaml (CURRENT — confirm existing Firebase deps block at lines 27-32; do NOT touch other versions)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-PATTERNS.md (§pubspec.yaml — lines 299-320: insertion point + version constraint safety note)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-RESEARCH.md (§Standard Stack lines 117-122 — `firebase_app_check: ^0.3.2+9` is the EXACT version compatible with firebase_core 3.15.2; §Pitfall 3 lines 654-662)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-CONTEXT.md (D-02 — App Attest + Debug provider; FirebaseAppCheck.instance.activate(...) site)
  </read_first>
  <action>
    Step A — Read pubspec.yaml. Locate the Firebase deps block (search for `firebase_core: ^3.6.0`). The block currently has 6 entries (firebase_core, firebase_auth, cloud_firestore, firebase_storage, firebase_messaging, google_sign_in).

    Step B — Append `firebase_app_check: ^0.3.2+9` AFTER `google_sign_in: ^6.2.1`. Use 2-space indent (matches existing block). NOTE: this plan adds firebase_app_check only — Plan 02-07 will add cloud_functions in the SAME block on a subsequent line. Do NOT pre-add cloud_functions here.

    Final block after this plan:
    ```yaml
      # Firebase
      firebase_core: ^3.6.0
      firebase_auth: ^5.3.1
      cloud_firestore: ^5.4.3
      firebase_storage: ^12.3.2
      firebase_messaging: ^15.1.3
      google_sign_in: ^6.2.1
      firebase_app_check: ^0.3.2+9
    ```

    Step C — Resolve:
      `flutter pub get`
      Must exit 0 with no "version solving failed" or "conflict" messages. If `flutter pub get` errors with a conflict on firebase_core, the constraint was wrong — verify the literal `^0.3.2+9` per RESEARCH §Standard Stack.

    Step D — Confirm the resolved version is in `pubspec.lock`:
      `grep -A1 'name: firebase_app_check' pubspec.lock | head -10`
      Expected: a `version: "0.3.2+9"` (or close range) line.

    Step E — Commit (this task only — Tasks 2 and 3 add their own commits to keep diffs reviewable):
      `git add pubspec.yaml pubspec.lock`
      Commit message: `feat(deps): add firebase_app_check ^0.3.2+9 — App Attest + Debug providers (Phase 2 PR-3 / FUNC-03; CONTEXT D-02)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -E '^\s*firebase_app_check:\s*\^?0\.3' pubspec.yaml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -E '^\s*firebase_app_check:\s*\^?0\.4' pubspec.yaml &amp;&amp; ! grep -E '^\s*firebase_app_check:\s*\^?[1-9]' pubspec.yaml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter pub get 2>&amp;1 | tee /tmp/p2-06-t1-pubget.log &amp;&amp; ! grep -iE 'version solving failed|conflict' /tmp/p2-06-t1-pubget.log</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -A1 '^  firebase_app_check:' pubspec.lock 2>/dev/null | grep -qE 'version:\s*"0\.3'</automated>
  </verify>
  <acceptance_criteria>
    - pubspec.yaml contains a `firebase_app_check: ^0.3.x` line in the Firebase deps block.
    - pubspec.yaml does NOT contain `firebase_app_check: ^0.4` or `^1` (would break firebase_core 3.x lockstep).
    - `flutter pub get` exits 0 with no solver conflicts.
    - pubspec.lock records firebase_app_check at a version starting with 0.3.
  </acceptance_criteria>
  <done>
    The firebase_app_check SDK is on the dep graph. Task 2 can now safely add the import + activate call in lib/main.dart.
  </done>
</task>

<task type="auto">
  <name>Task 2: Add FirebaseAppCheck.instance.activate(...) to lib/main.dart with kReleaseMode branch</name>
  <files>lib/main.dart</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/lib/main.dart (CURRENT — 50 lines; confirm exact line numbers of `Firebase.initializeApp` try-catch and `runApp` calls)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-PATTERNS.md (§lib/main.dart — lines 165-202: Extension Point A insertion site)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-RESEARCH.md (§Pattern 6 lines 418-444 — activate() placement, kReleaseMode, AppleProvider enum values)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-CONTEXT.md (D-02 — provider selection site)
  </read_first>
  <action>
    Step A — Read lib/main.dart. Confirm the exact line numbers:
      - `await Firebase.initializeApp(...)` and its `} catch (e) {` block.
      - The `const bool useEmulator = bool.fromEnvironment(...)` line.
      - The `runApp(const ProviderScope(...))` line.

    Step B — Add 2 new imports at the top of lib/main.dart:
      Insert IMMEDIATELY after `import 'package:firebase_core/firebase_core.dart';`:
        `import 'package:firebase_app_check/firebase_app_check.dart';`
      Insert IMMEDIATELY after `import 'package:firebase_storage/firebase_storage.dart';` (i.e. alphabetically before `import 'package:flutter/material.dart';`):
        `import 'package:flutter/foundation.dart';`  // for kReleaseMode

      Final imports block:
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
      ```

      NOTE: Plan 02-07 will ALSO add `import 'package:cloud_functions/cloud_functions.dart';` between `cloud_firestore` and `firebase_app_check` — this plan does NOT pre-add it. The current Phase 1 file does NOT have cloud_functions yet.

    Step C — Insert the FirebaseAppCheck.activate block.
      Position: AFTER the `try/catch` Firebase init block (current lines 25-31) and BEFORE `const bool useEmulator =` (current line 41).

      Insert the following 11 lines (including the trailing blank line for spacing):
      ```dart

        // App Check — emits a token per-call for any callable with
        // enforceAppCheck: App Attest in release (iOS 14+ Secure Enclave hardware
        // attestation); Debug provider on dev simulators + CI (auto-generates a
        // UUID token that must be registered in Firebase Console — see
        // BACKEND_SETUP.md §6). The Functions emulator bypasses App Check
        // validation (RESEARCH Pitfall 6) so Phase 2 emulator tests are unaffected.
        await FirebaseAppCheck.instance.activate(
          appleProvider: kReleaseMode
              ? AppleProvider.appAttest
              : AppleProvider.debug,
        );

      ```

    Step D — Verify build:
      `flutter analyze --no-fatal-infos`
      Expected: exits 0. The kReleaseMode constant + AppleProvider enum should resolve.

      `flutter build ios --no-codesign`
      Expected: exits 0. iOS build succeeds without the App Attest Xcode capability because debug builds use AppleProvider.debug which does NOT require the capability. (Release builds WOULD require it; this task does not run a release build.)

      If `flutter analyze` reports an error like "Undefined name 'kReleaseMode'", the import `import 'package:flutter/foundation.dart';` is missing. Add it.

    Step E — Commit:
      `git add lib/main.dart`
      Commit message: `feat(main): activate FirebaseAppCheck with kReleaseMode-branched provider (Phase 2 PR-3 / FUNC-03; CONTEXT D-02)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'FirebaseAppCheck.instance.activate' lib/main.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'AppleProvider.appAttest' lib/main.dart &amp;&amp; grep -q 'AppleProvider.debug' lib/main.dart &amp;&amp; grep -q 'kReleaseMode' lib/main.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "import 'package:firebase_app_check/firebase_app_check.dart';" lib/main.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "import 'package:flutter/foundation.dart';" lib/main.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; awk '/Firebase\.initializeApp/{init=NR} /FirebaseAppCheck\.instance\.activate/{ac=NR} /runApp\(/{run=NR} END{ if(init==0||ac==0||run==0) exit 1; if(!(init &lt; ac &amp;&amp; ac &lt; run)) exit 1; print "init="init" activate="ac" runApp="run" OK"}' lib/main.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --no-fatal-infos 2>&amp;1 | tee /tmp/p2-06-t2-analyze.log &amp;&amp; ! grep -qE '^\s*(error|warning) -' /tmp/p2-06-t2-analyze.log</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter build ios --no-codesign 2>&amp;1 | tee /tmp/p2-06-t2-build.log; test $? -eq 0</automated>
  </verify>
  <acceptance_criteria>
    - lib/main.dart contains the literal `FirebaseAppCheck.instance.activate` call.
    - lib/main.dart contains both `AppleProvider.appAttest` and `AppleProvider.debug` (kReleaseMode ternary).
    - lib/main.dart contains the literal string `kReleaseMode`.
    - Imports `package:firebase_app_check/firebase_app_check.dart` AND `package:flutter/foundation.dart` are present.
    - Ordering invariant: Firebase.initializeApp → FirebaseAppCheck.activate → runApp.
    - flutter analyze --no-fatal-infos exits 0.
    - flutter build ios --no-codesign exits 0.
  </acceptance_criteria>
  <done>
    Client-side App Check is wired with provider selection by build mode. Debug builds use the Debug provider (no Xcode capability needed); release builds use App Attest (which requires the Xcode capability + entitlement from Task 3 + paid Apple Developer Program account from the unresolved_question).
  </done>
</task>

<task type="auto">
  <name>Task 3: Add App Attest production environment to ios/Runner/Runner.entitlements</name>
  <files>ios/Runner/Runner.entitlements</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/ios/Runner/Runner.entitlements (CURRENT — 10 lines per repo state; confirm existing keychain-access-groups key + tab indentation)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-PATTERNS.md (§ios/Runner/Runner.entitlements — lines 268-291 self-modify rule + Apple Developer Program note)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-RESEARCH.md (§App Attest in Production lines 808-820 — entitlement key + Xcode capability requirement)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-VALIDATION.md (§Open Question A — Apple Developer Program paid account requirement)
  </read_first>
  <action>
    Step A — Confirm Apple Developer Program account status (unresolved_question — see plan frontmatter):
      The executor MUST check: is `arnobrizwan23@gmail.com` enrolled in the PAID Apple Developer Program ($99/yr)?
      - Verifiable by signing into https://developer.apple.com/account/ and confirming "Apple Developer Program — Member" appears.
      - If PAID: proceed with `AppleProvider.appAttest` as locked in CONTEXT D-02 (Task 2 already wrote this); the entitlement key below is valid.
      - If FREE: STOP this task. Surface to the user: "App Attest requires a paid Apple Developer account. Options: (a) enroll in the paid program before merging PR-3 (recommended); (b) amend CONTEXT D-02 to use `AppleProvider.appAttestWithDeviceCheckFallback` instead — change Task 2's `AppleProvider.appAttest` to that constant and DO NOT add the entitlement key; (c) defer App Attest to Phase 6+ (breaks enforceAppCheck for real callers)." Wait for user decision before proceeding.

      If the executor cannot verify the account status (no CLI to query developer portal), proceed conservatively: ADD the entitlement key (it's harmless on debug builds because the Debug provider doesn't invoke App Attest) AND record "account status unverified — verify in Xcode signing tab before release build" in the SUMMARY.

    Step B — Read ios/Runner/Runner.entitlements. Confirm the existing dict block contains a single key (`keychain-access-groups`) and an array containing `$(AppIdentifierPrefix)com.mentorminds.mentorMinds`.

    Step C — Edit the plist:
      Insert the following two lines (key + string) IMMEDIATELY BEFORE the closing `</dict>` tag and AFTER the existing `</array>` close. Use a single TAB character for indentation (matches existing keychain key).

      ```xml
      	<key>com.apple.developer.devicecheck.appattest.environment</key>
      	<string>production</string>
      ```

      Final file content (full):
      ```xml
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
      	<key>keychain-access-groups</key>
      	<array>
      		<string>$(AppIdentifierPrefix)com.mentorminds.mentorMinds</string>
      	</array>
      	<key>com.apple.developer.devicecheck.appattest.environment</key>
      	<string>production</string>
      </dict>
      </plist>
      ```

    Step D — Validate plist XML:
      `plutil -lint ios/Runner/Runner.entitlements`
      Must print `OK`.

    Step E — Build smoke:
      `flutter build ios --no-codesign`
      Must exit 0. The entitlement key alone does NOT require the Xcode App Attest capability for debug builds — debug builds use AppleProvider.debug which does not invoke App Attest hardware. Release builds WOULD require the capability + provisioning profile match, but `--no-codesign` skips that. The Xcode capability addition is the manual step recorded in the SUMMARY.

    Step F — Document the Xcode capability manual step in SUMMARY:
      Record: "MANUAL STEP REQUIRED: open ios/Runner.xcworkspace → Signing & Capabilities → + Capability → App Attest. Save. Commit `ios/Runner.xcodeproj/project.pbxproj` changes in a separate commit. Required for release builds; not required for debug builds or Phase 2 emulator tests."

    Step G — Commit:
      `git add ios/Runner/Runner.entitlements`
      Commit message: `feat(ios): add App Attest production environment entitlement (Phase 2 PR-3 / FUNC-03; RESEARCH Pitfall 1 — prevents sandbox token rejection)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'com.apple.developer.devicecheck.appattest.environment' ios/Runner/Runner.entitlements</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; awk '/com\.apple\.developer\.devicecheck\.appattest\.environment/{f=1; next} f &amp;&amp; /<string>production<\/string>/{print "ok"; exit 0} f{exit 1}' ios/Runner/Runner.entitlements | grep -q ok</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; plutil -lint ios/Runner/Runner.entitlements 2>&amp;1 | tee /tmp/p2-06-t3-plutil.log &amp;&amp; grep -q 'OK' /tmp/p2-06-t3-plutil.log</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'keychain-access-groups' ios/Runner/Runner.entitlements &amp;&amp; grep -q 'mentormindsmentorMinds\|com\.mentorminds\.mentorMinds' ios/Runner/Runner.entitlements</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter build ios --no-codesign 2>&amp;1 | tail -10 | tee /tmp/p2-06-t3-build.log; test $? -eq 0</automated>
  </verify>
  <acceptance_criteria>
    - Runner.entitlements contains the literal key `com.apple.developer.devicecheck.appattest.environment`.
    - The string value `production` follows immediately after that key.
    - The existing `keychain-access-groups` key is preserved.
    - plutil -lint reports OK.
    - flutter build ios --no-codesign exits 0.
  </acceptance_criteria>
  <done>
    The App Attest production environment is declared in the iOS entitlements. Sandbox attestation tokens will not be generated on release builds. The Xcode capability addition + paid Apple Developer Program account are the remaining gates for actual release builds — both are manual / out-of-executor-scope and recorded in the SUMMARY.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| iOS client ⇄ Firebase App Check service | App Attest hardware attestation runs on the Secure Enclave; the resulting token is sent to Firebase App Check service for validation; valid tokens are then forwarded to any callable with `enforceAppCheck: true`. Tokens are short-lived (~1 hour). |
| dev simulator ⇄ Debug provider | Debug provider generates a UUID at install time, persists it in keychain, prints it to Xcode console for one-time Firebase Console registration. Compromise of the UUID = unauthenticated access until the token is revoked from Firebase Console. |
| release build ⇄ App Attest sandbox vs production | The entitlement value (`sandbox` vs `production`) determines which Apple attestation endpoint is hit; Firebase only accepts `production`. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-2-APPCHECK-BYPASS | Spoofing | lib/main.dart + functions/src/index.ts — without client-side activation, ANY caller bypasses enforceAppCheck:true | mitigate | This plan adds `FirebaseAppCheck.instance.activate(...)` in lib/main.dart (Task 2) — the matching client-side half of Plan 02-03's server-side `enforceAppCheck: true`. Verify: grep lib/main.dart for `FirebaseAppCheck.instance.activate`. Server-side gate (Plan 02-03) is the actual enforcement; client side just emits the token. |
| T-2-DEBUG-IN-PROD | Elevation of Privilege | lib/main.dart — AppleProvider.debug shipped in release builds would allow any caller with a leaked debug token to bypass attestation | mitigate | `kReleaseMode` ternary: `kReleaseMode ? AppleProvider.appAttest : AppleProvider.debug`. kReleaseMode is a `const bool` from `package:flutter/foundation.dart` that is TRUE in release builds. Verify: grep lib/main.dart for the literal `kReleaseMode` adjacent to AppleProvider.appAttest. |
| T-2-SANDBOX-ATTESTATION | Spoofing | ios/Runner/Runner.entitlements — without the `appattest.environment = production` key, App Attest defaults to sandbox; Firebase App Check rejects sandbox tokens with UNAUTHENTICATED | mitigate | Task 3 adds the entitlement key. Verify: grep entitlements for `appattest.environment` and adjacency to `<string>production</string>`. |
| T-2-06-DEBUG-TOKEN-LEAK | Information Disclosure | A debug token UUID logged to Xcode console is screenshotted / committed to repo / shared in chat — attacker can call production callables impersonating that device | mitigate | Debug tokens registered in Firebase Console can be revoked instantly (BACKEND_SETUP.md §6 documents the revocation flow). Quarterly rotation of CI shared token (D-09). Phase 2 ships zero real tokens in repo (the entitlement uses no token; Plan 02-05's BACKEND_SETUP.md uses placeholder `<UUID>`). |
| T-2-06-FREE-ACCOUNT-DRIFT | Repudiation | Developer is on a free Apple Developer account; App Attest Xcode capability cannot be enabled; release build fails signing; `enforceAppCheck` rejects all real callers in production | accept (with surfacing) | Plan-level `unresolved_questions` block surfaces this BEFORE merging PR-3. Mitigation paths documented (enroll in paid / switch to appAttestWithDeviceCheckFallback / defer to Phase 6+). Executor MUST verify before completing Task 3. |
| T-2-06-WRONG-PROVIDER-VERSION | Tampering | A future maintainer bumps firebase_app_check to ^0.4.x — forces firebase_core ^4.x — breaks the rest of the Firebase deps lockstep | mitigate | RESEARCH Pitfall 3 documents this lockstep. Task 1 explicitly pins `^0.3.2+9`. CI (Plan 02-10) runs `flutter pub get` which fails on incompatible version solutions. |
</threat_model>

<verification>
- pubspec.yaml has `firebase_app_check: ^0.3.x` (not ^0.4 / ^1).
- flutter pub get exits 0 with no solver conflicts.
- lib/main.dart contains `FirebaseAppCheck.instance.activate`, `AppleProvider.appAttest`, `AppleProvider.debug`, `kReleaseMode`.
- Ordering: Firebase.initializeApp → FirebaseAppCheck.activate → runApp.
- lib/main.dart imports `firebase_app_check` and `flutter/foundation` (for kReleaseMode).
- ios/Runner/Runner.entitlements contains the `appattest.environment` key with value `production`.
- plutil -lint reports OK.
- flutter analyze --no-fatal-infos exits 0.
- flutter build ios --no-codesign exits 0.
</verification>

<success_criteria>
- D-02 met: App Check activated with App Attest (release) / Debug (dev) provider selection in lib/main.dart, after Firebase init, before runApp.
- T-2-APPCHECK-BYPASS, T-2-DEBUG-IN-PROD, T-2-SANDBOX-ATTESTATION all mitigated.
- FUNC-03 met (client-side activation + entitlements).
- unresolved_question on paid Apple Developer Program account surfaced for user decision before PR-3 merges.
- Plan 02-09's ping_smoke_test.dart will pass against the emulator regardless of App Check status (emulator bypasses per RESEARCH Pitfall 6).
- Production deploy in Phase 3 will validate App Check tokens end-to-end.
</success_criteria>

<output>
Create `.planning/phases/02-cloud-functions-scaffolding-app-check/02-06-app-check-activation-SUMMARY.md` when done. Record:
1. The full diff of pubspec.yaml (one added line).
2. The full diff of lib/main.dart (2 import lines + 11-line activate block).
3. The full diff of ios/Runner/Runner.entitlements (2 added lines).
4. `plutil -lint` output (must be "OK").
5. `flutter analyze --no-fatal-infos` exit code.
6. `flutter build ios --no-codesign` exit code + last 5 lines of output.
7. Apple Developer Program account status: PAID / FREE / UNVERIFIED — and which mitigation path was taken if not PAID.
8. Manual Xcode App Attest capability addition status: ADDED / DEFERRED / BLOCKED — and the timestamp / commit SHA of the `ios/Runner.xcodeproj/project.pbxproj` change if added.
</output>
