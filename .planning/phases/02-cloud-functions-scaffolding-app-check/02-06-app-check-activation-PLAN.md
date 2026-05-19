---
phase: 02-cloud-functions-scaffolding-app-check
plan: 06
type: execute
wave: 4
depends_on: ["02-01", "02-02", "02-03", "02-04"]
files_modified:
  - pubspec.yaml
  - lib/main.dart
autonomous: true
requirements: [FUNC-03]
pr_group: PR-3
tags: [firebase_app_check, app_attest_with_device_check_fallback, debug_provider, kReleaseMode]

must_haves:
  truths:
    - "D-02 honored (AMENDED 2026-05-19): `AppleProvider.appAttestWithDeviceCheckFallback` on iOS 14+ release builds; Debug provider on dev simulators + CI. Provider selection lives in lib/main.dart AFTER `Firebase.initializeApp(...)` and BEFORE any provider/repository reads."
    - "Provider literal: `appleProvider: kReleaseMode ? AppleProvider.appAttestWithDeviceCheckFallback : AppleProvider.debug`"
    - "Amendment rationale: Apple Developer Program account is FREE (not paid). App Attest capability + `appattest.environment = production` entitlement require paid enrollment; DeviceCheck does not. The fallback provider silently uses DeviceCheck when App Attest is unavailable, preserving `enforceAppCheck: true` semantics without the paid-tier gate. The original D-02 `Runner.entitlements` change is DROPPED."
    - "pubspec.yaml adds `firebase_app_check: ^0.3.2+9` — NOT ^0.4.x (would force firebase_core ^4.x and break the Phase 1 lockstep per RESEARCH §Standard Stack)"
    - "lib/main.dart imports `package:firebase_app_check/firebase_app_check.dart` and `package:flutter/foundation.dart` (for kReleaseMode)"
    - "T-2-APPCHECK-BYPASS mitigated client-side (server-side mitigation is Plan 02-03's enforceAppCheck:true)"
    - "T-2-DEBUG-IN-PROD mitigated via kReleaseMode ternary"
    - "T-2-SANDBOX-ATTESTATION N/A: appAttestWithDeviceCheckFallback uses DeviceCheck (no sandbox/production distinction); the appattest.environment entitlement is not consulted by DeviceCheck."
    - "D-19 honored: PR-3 wires App Check end-to-end (server-side enforcement landed in PR-1 Plan 02-03; this plan adds the client-side activation)"
  artifacts:
    - path: "pubspec.yaml"
      provides: "firebase_app_check: ^0.3.2+9 dep (Apple App Attest with DeviceCheck fallback + Debug providers)"
      contains: "firebase_app_check: ^0.3"
    - path: "lib/main.dart"
      provides: "FirebaseAppCheck.instance.activate(appleProvider: kReleaseMode ? AppleProvider.appAttestWithDeviceCheckFallback : AppleProvider.debug) AFTER Firebase init, BEFORE runApp"
      contains: "FirebaseAppCheck.instance.activate"
  key_links:
    - from: "lib/main.dart FirebaseAppCheck.activate"
      to: "functions/src/index.ts enforceAppCheck: true (Plan 02-03)"
      via: "client emits token; server validates token (production only; emulator bypasses per RESEARCH Pitfall 6)"
      pattern: "FirebaseAppCheck"

resolved_decisions:
  - "RESOLVED 2026-05-19: Apple Developer Program account is FREE. D-02 amended in 02-CONTEXT.md to substitute `AppleProvider.appAttestWithDeviceCheckFallback` for `AppleProvider.appAttest`. The Runner.entitlements appattest.environment key is NOT added (DeviceCheck does not require it). The Xcode App Attest capability is NOT added. If/when paid enrollment lands (Phase 6+), revisit to upgrade to pure `AppleProvider.appAttest` + entitlements + Xcode capability."
---

<objective>
Wire client-side App Check activation: add `firebase_app_check: ^0.3.2+9` to pubspec.yaml and insert `FirebaseAppCheck.instance.activate(appleProvider: kReleaseMode ? AppleProvider.appAttestWithDeviceCheckFallback : AppleProvider.debug)` into lib/main.dart between `Firebase.initializeApp` and the USE_EMULATOR block.

Purpose: Plan 02-03 shipped server-side `enforceAppCheck: true` in PR-1; this plan completes the round trip by emitting valid App Check tokens from the iOS client. With both pieces, production callers without a registered debug token (or without a valid DeviceCheck/App Attest token) receive HTTP 401 / `unauthenticated` from any callable that opts in. The emulator continues to bypass App Check (RESEARCH Pitfall 6) — Phase 2's integration test (Plan 02-09) does NOT exercise the token validation path; that's a manual production verification step deferred to Phase 3's first production deploy.

Output: Two files modified (pubspec.yaml + lib/main.dart). After commit, `flutter pub get` resolves cleanly (the ^0.3.2+9 constraint is compatible with the existing `firebase_core 3.15.2` — verified in RESEARCH §Standard Stack), `flutter analyze --no-fatal-infos` exits 0, and `flutter build ios --no-codesign` exits 0. NO Xcode capability needed (DeviceCheck does not require the App Attest capability).
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
@pubspec.yaml
@CLAUDE.md

<interfaces>
<!-- Self-modify patterns from 02-PATTERNS.md (Groups 4 and 5) -->

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
    Insertion: `firebase_app_check` goes immediately after `firebase_core` (alphabetical, since `_a` < `_c` < `_s`). `flutter/foundation.dart` goes immediately before `flutter/material.dart` (alphabetical: foundation < material).

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

      // App Check — emits a token per-call for any callable with enforceAppCheck.
      // Release builds use App Attest where available (iOS 14+ Secure Enclave),
      // silently falling back to DeviceCheck on devices/accounts where App Attest
      // is not provisioned. Debug builds use the Debug provider, which generates
      // a UUID token that must be registered in Firebase Console (BACKEND_SETUP.md §6).
      // The Functions emulator bypasses App Check validation (RESEARCH Pitfall 6).
      // Provider choice ratified by free-Apple-Developer-account decision (2026-05-19);
      // see CONTEXT D-02 amendment.
      await FirebaseAppCheck.instance.activate(
        appleProvider: kReleaseMode
            ? AppleProvider.appAttestWithDeviceCheckFallback
            : AppleProvider.debug,
      );

      const bool useEmulator =
          bool.fromEnvironment('USE_EMULATOR', defaultValue: false);
      ...
    ```

    Critical ordering: `activate(...)` MUST run AFTER `Firebase.initializeApp(...)` and BEFORE `runApp(...)`. Both Plan 02-08's `useFunctionsEmulator` (in the USE_EMULATOR block) and Plan 02-07's `firebaseFunctionsProvider` reads happen later — activate must precede them so any callable invocation has a token-emission hook ready.

NOT modified (originally planned in D-02, dropped per 2026-05-19 amendment):
  - ios/Runner/Runner.entitlements — would have added `com.apple.developer.devicecheck.appattest.environment = production`. Dropped because that key only affects App Attest (paid-account-gated); DeviceCheck does not consult it.
  - Xcode App Attest capability — manual step originally required for the paid path. Dropped; DeviceCheck capability is built into iOS and requires no opt-in.

What this plan does NOT do (unchanged):
  - Does NOT add `cloud_functions` to pubspec.yaml (Plan 02-07's job).
  - Does NOT add `useFunctionsEmulator` to main.dart (Plan 02-08's job).
  - Does NOT create `firebase_functions_provider.dart` or `ping_repository.dart` (Plan 02-07's job).
  - Does NOT register a debug token in Firebase Console (manual step in BACKEND_SETUP.md §6 from Plan 02-05; out of executor scope).
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
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-CONTEXT.md (D-02 — amended 2026-05-19 to `appAttestWithDeviceCheckFallback`; FirebaseAppCheck.instance.activate(...) site)
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

    Step E — Commit (this task only — Task 2 adds its own commit to keep diffs reviewable):
      `git add pubspec.yaml pubspec.lock`
      Commit message: `feat(deps): add firebase_app_check ^0.3.2+9 — App Attest+DeviceCheck fallback + Debug providers (Phase 2 PR-3 / FUNC-03; CONTEXT D-02 amended 2026-05-19)`.
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
  <name>Task 2: Add FirebaseAppCheck.instance.activate(...) to lib/main.dart with kReleaseMode branch using appAttestWithDeviceCheckFallback</name>
  <files>lib/main.dart</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/lib/main.dart (CURRENT — 50 lines; confirm exact line numbers of `Firebase.initializeApp` try-catch and `runApp` calls)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-PATTERNS.md (§lib/main.dart — lines 165-202: Extension Point A insertion site)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-RESEARCH.md (§Pattern 6 lines 418-444 — activate() placement, kReleaseMode, AppleProvider enum values incl. appAttestWithDeviceCheckFallback)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-CONTEXT.md (D-02 — amended 2026-05-19 to substitute appAttestWithDeviceCheckFallback for appAttest; rationale: free Apple Developer account)
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

      Insert the following 13 lines (including the trailing blank line for spacing) — use `AppleProvider.appAttestWithDeviceCheckFallback` (NOT `AppleProvider.appAttest`) per CONTEXT D-02 amendment:
      ```dart

        // App Check — emits a token per-call for any callable with enforceAppCheck.
        // Release builds use App Attest where available (iOS 14+ Secure Enclave),
        // silently falling back to DeviceCheck on devices/accounts where App Attest
        // is not provisioned. Debug builds use the Debug provider — auto-generates
        // a UUID token that must be registered in Firebase Console (BACKEND_SETUP §6).
        // The Functions emulator bypasses App Check validation (RESEARCH Pitfall 6).
        // Provider choice locked by free-Apple-Developer-account decision; see CONTEXT D-02.
        await FirebaseAppCheck.instance.activate(
          appleProvider: kReleaseMode
              ? AppleProvider.appAttestWithDeviceCheckFallback
              : AppleProvider.debug,
        );

      ```

    Step D — Verify build:
      `flutter analyze --no-fatal-infos`
      Expected: exits 0. The kReleaseMode constant + AppleProvider enum (including the `appAttestWithDeviceCheckFallback` value) should resolve.

      `flutter build ios --no-codesign`
      Expected: exits 0. iOS build succeeds without the App Attest Xcode capability because debug builds use AppleProvider.debug and release builds use the DeviceCheck-fallback provider — neither requires the App Attest capability or paid-account entitlements.

      If `flutter analyze` reports an error like "Undefined name 'kReleaseMode'", the import `import 'package:flutter/foundation.dart';` is missing. Add it. If it reports "Undefined name 'appAttestWithDeviceCheckFallback'", verify firebase_app_check resolved to ^0.3.2+9 (the enum value exists in 0.3.x; older versions may not have it).

    Step E — Commit:
      `git add lib/main.dart`
      Commit message: `feat(main): activate FirebaseAppCheck with kReleaseMode-branched provider (appAttestWithDeviceCheckFallback + debug) (Phase 2 PR-3 / FUNC-03; CONTEXT D-02 amended 2026-05-19)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'FirebaseAppCheck.instance.activate' lib/main.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'AppleProvider.appAttestWithDeviceCheckFallback' lib/main.dart &amp;&amp; grep -q 'AppleProvider.debug' lib/main.dart &amp;&amp; grep -q 'kReleaseMode' lib/main.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -qE 'AppleProvider\.appAttest[^W]' lib/main.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "import 'package:firebase_app_check/firebase_app_check.dart';" lib/main.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "import 'package:flutter/foundation.dart';" lib/main.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; awk '/Firebase\.initializeApp/{init=NR} /FirebaseAppCheck\.instance\.activate/{ac=NR} /runApp\(/{run=NR} END{ if(init==0||ac==0||run==0) exit 1; if(!(init &lt; ac &amp;&amp; ac &lt; run)) exit 1; print "init="init" activate="ac" runApp="run" OK"}' lib/main.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --no-fatal-infos 2>&amp;1 | tee /tmp/p2-06-t2-analyze.log &amp;&amp; ! grep -qE '^\s*(error|warning) -' /tmp/p2-06-t2-analyze.log</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter build ios --no-codesign 2>&amp;1 | tee /tmp/p2-06-t2-build.log; test $? -eq 0</automated>
  </verify>
  <acceptance_criteria>
    - lib/main.dart contains the literal `FirebaseAppCheck.instance.activate` call.
    - lib/main.dart contains `AppleProvider.appAttestWithDeviceCheckFallback` AND `AppleProvider.debug` (kReleaseMode ternary).
    - lib/main.dart does NOT contain the pure `AppleProvider.appAttest` literal (the amendment substituted the fallback variant).
    - lib/main.dart contains the literal string `kReleaseMode`.
    - Imports `package:firebase_app_check/firebase_app_check.dart` AND `package:flutter/foundation.dart` are present.
    - Ordering invariant: Firebase.initializeApp → FirebaseAppCheck.activate → runApp.
    - flutter analyze --no-fatal-infos exits 0.
    - flutter build ios --no-codesign exits 0.
  </acceptance_criteria>
  <done>
    Client-side App Check is wired with build-mode provider selection. Debug builds use the Debug provider; release builds use App Attest with silent DeviceCheck fallback (works on free Apple Developer accounts). NO Xcode capability addition needed; NO Runner.entitlements change needed.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| iOS client ⇄ Firebase App Check service | DeviceCheck (free-account fallback) or App Attest (when device-and-account-provisioned) hardware attestation runs on the iOS native stack; the resulting token is sent to Firebase App Check service for validation; valid tokens are then forwarded to any callable with `enforceAppCheck: true`. Tokens are short-lived (~1 hour). |
| dev simulator ⇄ Debug provider | Debug provider generates a UUID at install time, persists it in keychain, prints it to Xcode console for one-time Firebase Console registration. Compromise of the UUID = unauthenticated access until the token is revoked from Firebase Console. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-2-APPCHECK-BYPASS | Spoofing | lib/main.dart + functions/src/index.ts — without client-side activation, ANY caller bypasses enforceAppCheck:true | mitigate | This plan adds `FirebaseAppCheck.instance.activate(...)` in lib/main.dart (Task 2) — the matching client-side half of Plan 02-03's server-side `enforceAppCheck: true`. Verify: grep lib/main.dart for `FirebaseAppCheck.instance.activate`. Server-side gate (Plan 02-03) is the actual enforcement; client side just emits the token. |
| T-2-DEBUG-IN-PROD | Elevation of Privilege | lib/main.dart — AppleProvider.debug shipped in release builds would allow any caller with a leaked debug token to bypass attestation | mitigate | `kReleaseMode` ternary: `kReleaseMode ? AppleProvider.appAttestWithDeviceCheckFallback : AppleProvider.debug`. kReleaseMode is a `const bool` from `package:flutter/foundation.dart` that is TRUE in release builds. Verify: grep lib/main.dart for the literal `kReleaseMode` adjacent to `AppleProvider.appAttestWithDeviceCheckFallback`. |
| T-2-SANDBOX-ATTESTATION | Spoofing | N/A in this plan — the appAttestWithDeviceCheckFallback provider does NOT use the `appattest.environment` entitlement; DeviceCheck has no sandbox/production distinction. | not-applicable | The original sandbox-vs-production attack surface only applies to the pure App Attest provider. DeviceCheck uses Apple's per-device unique identifier flow, with no sandbox mode to misconfigure. If the paid Apple Developer account is acquired later and the provider is upgraded to pure `AppleProvider.appAttest`, the entitlement key must be added at that time. |
| T-2-06-DEBUG-TOKEN-LEAK | Information Disclosure | A debug token UUID logged to Xcode console is screenshotted / committed to repo / shared in chat — attacker can call production callables impersonating that device | mitigate | Debug tokens registered in Firebase Console can be revoked instantly (BACKEND_SETUP.md §6 documents the revocation flow). Quarterly rotation of CI shared token (D-09). Phase 2 ships zero real tokens in repo (Plan 02-05's BACKEND_SETUP.md uses placeholder `<UUID>`). |
| T-2-06-FREE-ACCOUNT-DRIFT | Repudiation | (RESOLVED 2026-05-19) Developer is on a free Apple Developer account; pure App Attest cannot be enabled. | resolved | Substituted `AppleProvider.appAttestWithDeviceCheckFallback` for `AppleProvider.appAttest` per CONTEXT D-02 amendment. DeviceCheck works on free accounts. No paid-tier capability needed. |
| T-2-06-WRONG-PROVIDER-VERSION | Tampering | A future maintainer bumps firebase_app_check to ^0.4.x — forces firebase_core ^4.x — breaks the rest of the Firebase deps lockstep | mitigate | RESEARCH Pitfall 3 documents this lockstep. Task 1 explicitly pins `^0.3.2+9`. CI (Plan 02-10) runs `flutter pub get` which fails on incompatible version solutions. |
</threat_model>

<verification>
- pubspec.yaml has `firebase_app_check: ^0.3.x` (not ^0.4 / ^1).
- flutter pub get exits 0 with no solver conflicts.
- lib/main.dart contains `FirebaseAppCheck.instance.activate`, `AppleProvider.appAttestWithDeviceCheckFallback`, `AppleProvider.debug`, `kReleaseMode`.
- lib/main.dart does NOT contain the bare `AppleProvider.appAttest` literal.
- Ordering: Firebase.initializeApp → FirebaseAppCheck.activate → runApp.
- lib/main.dart imports `firebase_app_check` and `flutter/foundation` (for kReleaseMode).
- ios/Runner/Runner.entitlements is UNCHANGED (verified by git: `git diff HEAD~1 -- ios/Runner/Runner.entitlements` returns empty).
- flutter analyze --no-fatal-infos exits 0.
- flutter build ios --no-codesign exits 0.
</verification>

<success_criteria>
- D-02 (AMENDED) met: App Check activated with App Attest + DeviceCheck fallback (release) / Debug (dev) provider selection in lib/main.dart, after Firebase init, before runApp.
- T-2-APPCHECK-BYPASS and T-2-DEBUG-IN-PROD mitigated. T-2-SANDBOX-ATTESTATION is not-applicable for the chosen provider. T-2-06-FREE-ACCOUNT-DRIFT is RESOLVED.
- FUNC-03 met (client-side activation; no entitlements needed for the fallback provider).
- Plan 02-09's ping_smoke_test.dart will pass against the emulator regardless of App Check status (emulator bypasses per RESEARCH Pitfall 6).
- Production deploy in Phase 3 will validate DeviceCheck (or App Attest where available) tokens end-to-end.
</success_criteria>

<output>
Create `.planning/phases/02-cloud-functions-scaffolding-app-check/02-06-app-check-activation-SUMMARY.md` when done. Record:
1. The full diff of pubspec.yaml (one added line).
2. The full diff of lib/main.dart (2 import lines + 13-line activate block using `appAttestWithDeviceCheckFallback`).
3. `flutter pub get` output excerpt (firebase_app_check resolved version).
4. `flutter analyze --no-fatal-infos` exit code.
5. `flutter build ios --no-codesign` exit code + last 5 lines of output.
6. Explicit note: "ios/Runner/Runner.entitlements UNCHANGED — D-02 amendment dropped the appattest.environment entitlement because the chosen provider (appAttestWithDeviceCheckFallback) uses DeviceCheck, which does not consult that key." Include `git diff HEAD~1 -- ios/Runner/Runner.entitlements` output (must be empty).
7. Explicit note: "Xcode App Attest capability NOT added — DeviceCheck capability is built into iOS and requires no opt-in. If paid Apple Developer enrollment lands later, revisit to upgrade to pure App Attest + capability + entitlement."
</output>
