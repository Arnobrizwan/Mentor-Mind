---
phase: 02-cloud-functions-scaffolding-app-check
plan: 07
type: execute
wave: 4
depends_on: ["02-01", "02-02", "02-03", "02-04"]
files_modified:
  - pubspec.yaml
  - lib/data/services/firebase_functions_provider.dart
  - lib/data/models/ping_response.dart
  - lib/data/repositories/ping_repository.dart
autonomous: true
requirements: [FUNC-06]
pr_group: PR-3
tags: [cloud_functions_sdk, firebase_functions_provider, ping_repository, ping_response_model, layered_imports, asia_south1_region_pin]

must_haves:
  truths:
    - "Phase 1 D-01..D-04 honored: per-collection (here per-callable) repository with decoded domain model; SDK singleton exposed as Riverpod provider; package-style imports for cross-layer references; Provider<T>((ref) => SDK.instance) pattern"
    - "RESEARCH Standard Stack honored: `cloud_functions: ^5.6.2` (NOT ^6.x — would force firebase_core ^4.x per RESEARCH Pitfall 3)"
    - "D-17 region pin honored: firebase_functions_provider.dart returns `FirebaseFunctions.instanceFor(region: 'asia-south1')` — matches Plan 02-03's server-side `region: 'asia-south1'`"
    - "PingRepository returns a typed PingResponse domain model — never raw HttpsCallableResult (Phase 1 D-02)"
    - "PingResponse.fromMap uses safe-cast `as T? ?? default` pattern (Phase 1 model convention; RESEARCH Pattern 8 + 02-PATTERNS.md Group 3)"
    - "T-2-LAYER-BREACH mitigated: cloud_functions import restricted to lib/data/ — custom_lint layered_imports rule from Phase 1 enforces it"
    - "Non-obvious HttpsCallableResult.data cast (`Map<Object?, Object?>` → `Map<String, dynamic>`) handled correctly per RESEARCH Pattern 8"
    - "D-19 honored: PR-3 wiring — provider + repository + model land together"
  artifacts:
    - path: "pubspec.yaml"
      provides: "cloud_functions: ^5.6.2 dep"
      contains: "cloud_functions: ^5"
    - path: "lib/data/services/firebase_functions_provider.dart"
      provides: "Riverpod Provider<FirebaseFunctions> pinned to asia-south1 region"
      contains: "instanceFor(region: 'asia-south1')"
    - path: "lib/data/models/ping_response.dart"
      provides: "PingResponse domain model {ok, timestamp, region} + fromMap factory"
      contains: "factory PingResponse.fromMap"
    - path: "lib/data/repositories/ping_repository.dart"
      provides: "PingRepository wrapping httpsCallable('ping').call() — returns decoded PingResponse"
      contains: "httpsCallable('ping')"
  key_links:
    - from: "lib/data/repositories/ping_repository.dart"
      to: "lib/data/services/firebase_functions_provider.dart"
      via: "ref.read(firebaseFunctionsProvider)"
      pattern: "firebaseFunctionsProvider"
    - from: "lib/data/repositories/ping_repository.dart"
      to: "lib/data/models/ping_response.dart"
      via: "PingResponse.fromMap decode"
      pattern: "PingResponse"
    - from: "lib/data/services/firebase_functions_provider.dart"
      to: "functions/src/index.ts (Plan 02-03) — region pin"
      via: "literal 'asia-south1' string must match on both ends"
      pattern: "asia-south1"
---

<objective>
Add `cloud_functions: ^5.6.2` to pubspec.yaml, create three new Dart files under `lib/data/` (services/firebase_functions_provider.dart, models/ping_response.dart, repositories/ping_repository.dart) following Phase 1's repository + provider + safe-cast model patterns. The provider exposes `FirebaseFunctions.instanceFor(region: 'asia-south1')` matching Plan 02-03's server-side pin. The repository returns a typed PingResponse domain model — never raw HttpsCallableResult.

Purpose: The Flutter client needs a typed, layer-respecting path to call `httpsCallable('ping')`. Putting the SDK behind a Riverpod provider (`firebaseFunctionsProvider`) and a repository (`PingRepository`) mirrors Phase 1's `firebaseAuthProvider`/`AuthRepository` and `firestoreProvider`/`UsersRepository` patterns — so future Phase 3 work (MentorBotRepository for the Gemini callable) drops into the same shape without redesign. The `layered_imports` custom_lint rule (Phase 1 D-08) bans viewmodels from importing `cloud_functions` directly — they MUST go through `pingRepositoryProvider`. Phase 2 has no viewmodel consumer of PingRepository; the integration test (Plan 02-09) calls the SDK directly OR consumes the repository (either acceptable per CONTEXT.md `<code_context>` "NO viewmodel consumer in Phase 2").

Output: 4 files modified/created. After commit, `flutter pub get` resolves cleanly, `dart run custom_lint` reports zero layered_imports violations, `flutter analyze --no-fatal-infos` exits 0. Plan 02-08 can then call `useFunctionsEmulator('localhost', 5001)` from the same lib/main.dart that already imports cloud_functions (added in this plan).
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
@lib/data/services/firebase_providers.dart
@lib/data/repositories/users_repository.dart
@lib/data/models/chat_message.dart
@pubspec.yaml
@CLAUDE.md

<interfaces>
<!-- All patterns below come from 02-PATTERNS.md (Groups 1, 2, 3) and Phase 1 D-01..D-04 -->

pubspec.yaml — APPEND `cloud_functions: ^5.6.2` to Firebase deps block.
  Insertion position: AFTER `firebase_app_check: ^0.3.2+9` (added by Plan 02-06).
  Final block end:
    ```yaml
      firebase_app_check: ^0.3.2+9
      cloud_functions: ^5.6.2
    ```
  RESEARCH Pitfall 3 reminder: `cloud_functions ^6.x` requires `firebase_core ^4.x` — BANNED.

lib/data/services/firebase_functions_provider.dart (NEW; ~14 lines):
  Pattern: mirror `lib/data/services/firebase_providers.dart` (3 SDK singleton providers).
  Single file, single provider. Optional banner comment for documentation.

  ```dart
  import 'package:cloud_functions/cloud_functions.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';

  // ---------------------------------------------------------------------------
  // FirebaseFunctions SDK singleton provider — the test override seam.
  // Pinned to region 'asia-south1' to match the server-side `region: 'asia-south1'`
  // option on every callable in functions/src/index.ts (Plan 02-03). Cross-region
  // mismatch routes the call to us-central1 and 404s (RESEARCH Threat T-2-03-WRONG-REGION).
  //
  // Tests inject a mocked FirebaseFunctions via ProviderScope.overrides before
  // any repository provider is first read. The `useFunctionsEmulator` redirect
  // for local emulator runs lives in lib/main.dart's USE_EMULATOR block (Plan 02-08)
  // and in test/_helpers/emulator_setup.dart for integration tests.
  // ---------------------------------------------------------------------------

  final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) {
    return FirebaseFunctions.instanceFor(region: 'asia-south1');
  });
  ```

  Notes:
  - `FirebaseFunctions.instanceFor(region: 'asia-south1')` returns a REGION-SCOPED instance (different object than `FirebaseFunctions.instance`).
  - `useFunctionsEmulator` (Plan 02-08) is called on `FirebaseFunctions.instance` (default region) in lib/main.dart's emulator block — RESEARCH Pattern 7 documents this dual-instance interaction. The emulator redirect applies to ALL instances created BEFORE the region-scoped instance is first read, which is the case because lib/main.dart's emulator block runs before `ProviderScope`.

lib/data/models/ping_response.dart (NEW; ~25 lines):
  Pattern: mirror `lib/data/models/dashboard_user.dart` or `lib/data/models/chat_message.dart` fromMap factory.
  Plain Dart class — no Firestore deps (this model decodes from a callable result Map, not a Firestore snapshot).

  ```dart
  // ---------------------------------------------------------------------------
  // PingResponse — decoded response from the `ping` callable (functions/src/index.ts).
  // Server returns: { ok: true, timestamp: <ms-since-epoch>, region: 'asia-south1' }
  // ---------------------------------------------------------------------------

  class PingResponse {
    const PingResponse({
      required this.ok,
      required this.timestamp,
      required this.region,
    });

    final bool ok;
    final int timestamp;
    final String region;

    factory PingResponse.fromMap(Map<String, dynamic> map) {
      return PingResponse(
        ok: (map['ok'] as bool?) ?? false,
        timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
        region: (map['region'] as String?) ?? '',
      );
    }
  }
  ```

  Notes:
  - All three fields use safe-cast `as T? ?? default` — never bare `as bool` or `as int` (RESEARCH Pattern 8 + Phase 1 convention).
  - `(map['timestamp'] as num?)?.toInt()` handles both int (Dart int) and double (Dart wire) representations.
  - Factory (not static method) per existing model convention.

lib/data/repositories/ping_repository.dart (NEW; ~28 lines):
  Pattern: mirror `lib/data/repositories/users_repository.dart` constructor + provider.

  ```dart
  import 'package:cloud_functions/cloud_functions.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';

  import 'package:mentor_minds/data/models/ping_response.dart';
  import 'package:mentor_minds/data/services/firebase_functions_provider.dart';

  // ---------------------------------------------------------------------------
  // PingRepository — wraps the `ping` callable (region: asia-south1).
  // Returns a decoded PingResponse; never exposes raw HttpsCallableResult.
  // No viewmodel consumer in Phase 2 — the integration test (Plan 02-09) is
  // the first caller; Phase 3 MentorBotRepository follows this same shape.
  // ---------------------------------------------------------------------------

  class PingRepository {
    PingRepository({required FirebaseFunctions functions})
        : _functions = functions;

    final FirebaseFunctions _functions;

    Future<PingResponse> ping() async {
      final result = await _functions.httpsCallable('ping').call<dynamic>();
      // The callable returns Map<Object?, Object?> at runtime, not
      // Map<String, dynamic> — the cast is required (RESEARCH Pattern 8).
      final data = (result.data as Map<Object?, Object?>).cast<String, dynamic>();
      return PingResponse.fromMap(data);
    }
  }

  final pingRepositoryProvider = Provider<PingRepository>((ref) {
    return PingRepository(
      functions: ref.read(firebaseFunctionsProvider),
    );
  });
  ```

  Notes:
  - Package-style imports (`package:mentor_minds/...`) — Phase 1 D-14 + Plan 03 convention.
  - Constructor takes `FirebaseFunctions` as a NAMED REQUIRED param — Phase 1 pattern.
  - Provider at bottom of file uses `ref.read(firebaseFunctionsProvider)` (not `.watch`) — SDK instances never change.
  - No `autoDispose` — repositories are stateless and cheap to keep alive (Phase 1 pattern).
  - The cast `(result.data as Map<Object?, Object?>).cast<String, dynamic>()` is non-obvious — DO NOT simplify to `as Map<String, dynamic>` (that fails at runtime).

layered_imports compliance:
  - `cloud_functions` import is permitted in BOTH lib/data/services/ AND lib/data/repositories/ (the data layer).
  - Viewmodels (lib/application/viewmodels/) MUST NOT import `cloud_functions` — that goes through `pingRepositoryProvider`.
  - Phase 2 ships NO new viewmodels (PingRepository has no viewmodel consumer per CONTEXT.md code_context); this constraint is asserted by `dart run custom_lint` exiting 0 in the verify block.

What this plan does NOT do:
  - Does NOT add `useFunctionsEmulator` to lib/main.dart (Plan 02-08's job — single-responsibility).
  - Does NOT extend test/_helpers/emulator_setup.dart (Plan 02-08).
  - Does NOT write integration_test/ping_smoke_test.dart (Plan 02-09).
  - Does NOT write a viewmodel that consumes PingRepository — Phase 2 has no viewmodel consumer (CONTEXT.md `<code_context>`); Phase 3 introduces MentorBotViewModel as the first.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add cloud_functions to pubspec.yaml + pub get</name>
  <files>pubspec.yaml</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/pubspec.yaml (CURRENT — after Plan 02-06 added firebase_app_check; confirm the Firebase block now ends with firebase_app_check: ^0.3.2+9)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-PATTERNS.md (§pubspec.yaml — lines 299-320: insertion point + version constraint safety)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-RESEARCH.md (§Standard Stack lines 117-122 — `cloud_functions: ^5.6.2` exact pin; §Pitfall 3 — 6.x banned)
  </read_first>
  <action>
    Step A — Read pubspec.yaml. Confirm the Firebase deps block now ends with `firebase_app_check: ^0.3.2+9` (from Plan 02-06's Task 1).

    Step B — Append `cloud_functions: ^5.6.2` immediately after `firebase_app_check: ^0.3.2+9`. Use 2-space indent.

      Final Firebase deps block:
      ```yaml
        # Firebase
        firebase_core: ^3.6.0
        firebase_auth: ^5.3.1
        cloud_firestore: ^5.4.3
        firebase_storage: ^12.3.2
        firebase_messaging: ^15.1.3
        google_sign_in: ^6.2.1
        firebase_app_check: ^0.3.2+9
        cloud_functions: ^5.6.2
      ```

    Step C — Resolve:
      `flutter pub get`
      Must exit 0. If conflict: verify `^5.6.2` literal (NOT `^6` — RESEARCH Pitfall 3).

    Step D — Confirm resolved version in pubspec.lock:
      `grep -A1 '^  cloud_functions:' pubspec.lock | head -3`
      Expected: `version: "5.6.2"` (or 5.x compatible range).

    Step E — Commit:
      `git add pubspec.yaml pubspec.lock`
      Commit message: `feat(deps): add cloud_functions ^5.6.2 (Phase 2 PR-3 / FUNC-06)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -E '^\s*cloud_functions:\s*\^?5\.' pubspec.yaml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -E '^\s*cloud_functions:\s*\^?6\.' pubspec.yaml &amp;&amp; ! grep -E '^\s*cloud_functions:\s*\^?[7-9]' pubspec.yaml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter pub get 2>&amp;1 | tee /tmp/p2-07-t1-pubget.log &amp;&amp; ! grep -iE 'version solving failed|conflict' /tmp/p2-07-t1-pubget.log</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -A1 '^  cloud_functions:' pubspec.lock | grep -qE 'version:\s*"5\.'</automated>
  </verify>
  <acceptance_criteria>
    - pubspec.yaml has `cloud_functions: ^5.x` (not ^6 or higher).
    - flutter pub get exits 0 with no solver conflicts.
    - pubspec.lock records cloud_functions at a 5.x version.
  </acceptance_criteria>
  <done>
    cloud_functions SDK is on the dep graph alongside firebase_app_check (Plan 02-06). Tasks 2-4 can now safely import `package:cloud_functions/cloud_functions.dart`.
  </done>
</task>

<task type="auto">
  <name>Task 2: Create lib/data/services/firebase_functions_provider.dart with region 'asia-south1' pin</name>
  <files>lib/data/services/firebase_functions_provider.dart</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/lib/data/services/firebase_providers.dart (analog — copy the SDK singleton provider shape; this file has 3 providers — firestore, auth, storage)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-PATTERNS.md (§Group 1 — lines 44-71: exact verbatim substitution rule + layered_imports compliance note)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-RESEARCH.md (§Pattern 7 lines 446-468 — region pinning in instanceFor(); §Architecture Diagram lines 200-233)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-CONTEXT.md (D-17 — asia-south1 non-negotiable; D-01..D-04 Phase 1 baseline)
  </read_first>
  <action>
    Write the file with the EXACT content from `<interfaces>` above. Key invariants:
      - Two imports only: `cloud_functions`, `flutter_riverpod`.
      - One provider declaration: `firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) => FirebaseFunctions.instanceFor(region: 'asia-south1'))`.
      - Banner comment (5-10 lines) explaining: test override seam + region pin + cross-region failure mode + the emulator-redirect dual-instance note (RESEARCH Pattern 7).
      - No `autoDispose` (SDK singletons live for app lifetime).
      - No additional providers (other Firebase SDK providers live in firebase_providers.dart; Functions gets its own file to keep diff scope minimal).

    Verify:
      `dart format lib/data/services/firebase_functions_provider.dart` — must produce no changes (file already follows dart format).
      `flutter analyze --no-fatal-infos lib/data/services/firebase_functions_provider.dart` — exits 0.

    Commit:
      `git add lib/data/services/firebase_functions_provider.dart`
      Commit message: `feat(data): add firebaseFunctionsProvider — asia-south1 region pin (Phase 2 PR-3 / FUNC-06; Phase 1 D-04 pattern)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f lib/data/services/firebase_functions_provider.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "FirebaseFunctions.instanceFor(region: 'asia-south1')" lib/data/services/firebase_functions_provider.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'final firebaseFunctionsProvider' lib/data/services/firebase_functions_provider.dart &amp;&amp; grep -q "Provider&lt;FirebaseFunctions&gt;" lib/data/services/firebase_functions_provider.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "import 'package:cloud_functions/cloud_functions.dart';" lib/data/services/firebase_functions_provider.dart &amp;&amp; grep -q "import 'package:flutter_riverpod/flutter_riverpod.dart';" lib/data/services/firebase_functions_provider.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --no-fatal-infos lib/data/services/firebase_functions_provider.dart 2>&amp;1 | tee /tmp/p2-07-t2-analyze.log &amp;&amp; ! grep -qE '^\s*(error|warning) -' /tmp/p2-07-t2-analyze.log</automated>
  </verify>
  <acceptance_criteria>
    - File exists at lib/data/services/firebase_functions_provider.dart.
    - Contains the literal `FirebaseFunctions.instanceFor(region: 'asia-south1')`.
    - Declares `firebaseFunctionsProvider` as `Provider<FirebaseFunctions>`.
    - Imports cloud_functions + flutter_riverpod only.
    - flutter analyze exits 0 on this file.
  </acceptance_criteria>
  <done>
    The SDK singleton provider is in place. Task 4's repository can read it via ref.read(firebaseFunctionsProvider).
  </done>
</task>

<task type="auto">
  <name>Task 3: Create lib/data/models/ping_response.dart with safe-cast fromMap factory</name>
  <files>lib/data/models/ping_response.dart</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/lib/data/models/dashboard_user.dart (analog for `factory X.fromDoc/fromMap` + safe-cast `as T? ?? default` pattern — see lines 28-53)
    - /Users/arnobrizwan/Mentor-Mind/lib/data/models/chat_message.dart (analog for an inline fromMap with `(m['timestamp'] as ...)` patterns)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-PATTERNS.md (§Group 3 — lines 135-159: fromMap pattern + substitution rule)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-RESEARCH.md (§Pattern 8 lines 471-525 — full PingResponse + PingRepository skeleton)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-CONTEXT.md (`<specifics>` — "Ping response shape: { ok: true, timestamp: <ms>, region: 'asia-south1' }")
  </read_first>
  <action>
    Write the file with the EXACT content from `<interfaces>` above. Key invariants:
      - No imports needed (uses only Dart core types: bool, int, String, Map).
      - Class with 3 final fields: ok (bool), timestamp (int), region (String).
      - Const constructor with all 3 required named params.
      - `factory PingResponse.fromMap(Map<String, dynamic> map)` — uses `as T? ?? default` safe-cast for every field.
      - For `timestamp`: use `(map['timestamp'] as num?)?.toInt() ?? 0` — handles both int and double wire values.
      - Banner comment (3-5 lines) noting the server-side shape.

    Verify:
      `dart format lib/data/models/ping_response.dart` — must produce no changes.
      `flutter analyze --no-fatal-infos lib/data/models/ping_response.dart` — exits 0.

    Commit:
      `git add lib/data/models/ping_response.dart`
      Commit message: `feat(data): add PingResponse model with safe-cast fromMap (Phase 2 PR-3 / FUNC-06; RESEARCH Pattern 8)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f lib/data/models/ping_response.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'factory PingResponse.fromMap' lib/data/models/ping_response.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'class PingResponse' lib/data/models/ping_response.dart &amp;&amp; grep -q 'final bool ok' lib/data/models/ping_response.dart &amp;&amp; grep -q 'final int timestamp' lib/data/models/ping_response.dart &amp;&amp; grep -q 'final String region' lib/data/models/ping_response.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "map\['ok'\] as bool\?\s*\)\?\?\s*false" lib/data/models/ping_response.dart || grep -qE "map\['ok'\] as bool\?" lib/data/models/ping_response.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "as num\?\)\?.toInt\(\)" lib/data/models/ping_response.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --no-fatal-infos lib/data/models/ping_response.dart 2>&amp;1 | tee /tmp/p2-07-t3-analyze.log &amp;&amp; ! grep -qE '^\s*(error|warning) -' /tmp/p2-07-t3-analyze.log</automated>
  </verify>
  <acceptance_criteria>
    - File exists at lib/data/models/ping_response.dart.
    - Class PingResponse declared with 3 final fields (ok, timestamp, region).
    - `factory PingResponse.fromMap` present.
    - timestamp decode uses `(map['timestamp'] as num?)?.toInt()` pattern.
    - ok decode uses `(map['ok'] as bool?)` safe-cast pattern.
    - flutter analyze exits 0 on this file.
  </acceptance_criteria>
  <done>
    PingResponse is the typed return shape. Task 4's PingRepository will return Future<PingResponse>.
  </done>
</task>

<task type="auto">
  <name>Task 4: Create lib/data/repositories/ping_repository.dart with provider declaration</name>
  <files>lib/data/repositories/ping_repository.dart</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/lib/data/repositories/users_repository.dart (analog — copy constructor + provider declaration shape; this file is the closest pattern match)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-PATTERNS.md (§Group 2 — lines 80-127: full substitution rule + the non-obvious Map<Object?, Object?> cast)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-RESEARCH.md (§Pattern 8 lines 498-523 — full PingRepository skeleton)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-CONTEXT.md (D-01..D-04 — repository pattern + provider declaration)
  </read_first>
  <action>
    Write the file with the EXACT content from `<interfaces>` above. Key invariants:
      - 4 imports: cloud_functions, flutter_riverpod, package:mentor_minds/data/models/ping_response.dart, package:mentor_minds/data/services/firebase_functions_provider.dart.
      - PingRepository class with named-required-param constructor (`functions: FirebaseFunctions`).
      - Private field `_functions` (Phase 1 underscore-private convention).
      - `Future<PingResponse> ping()` method calling `_functions.httpsCallable('ping').call<dynamic>()`.
      - NON-OBVIOUS CAST: `(result.data as Map<Object?, Object?>).cast<String, dynamic>()` — DO NOT simplify (RESEARCH Pattern 8: the callable returns Map<Object?, Object?> at runtime).
      - Decoded via `PingResponse.fromMap(data)` — returns the typed model, NEVER raw HttpsCallableResult (Phase 1 D-02).
      - Bottom-of-file `pingRepositoryProvider = Provider<PingRepository>` reads `firebaseFunctionsProvider` via `ref.read`.
      - Banner comment noting no viewmodel consumer in Phase 2 + the layered_imports rule.

    Verify:
      `dart format lib/data/repositories/ping_repository.dart` — produces no changes.
      `flutter analyze --no-fatal-infos lib/data/repositories/ping_repository.dart` — exits 0.
      `dart run custom_lint` — exits 0 (no layered_imports violations because lib/data/repositories/ is allowed to import cloud_functions).

    Commit:
      `git add lib/data/repositories/ping_repository.dart`
      Commit message: `feat(data): add PingRepository wrapping httpsCallable('ping') — decoded PingResponse (Phase 2 PR-3 / FUNC-06; Phase 1 D-02 pattern)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f lib/data/repositories/ping_repository.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "httpsCallable('ping')" lib/data/repositories/ping_repository.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'class PingRepository' lib/data/repositories/ping_repository.dart &amp;&amp; grep -q 'final FirebaseFunctions _functions' lib/data/repositories/ping_repository.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'Future&lt;PingResponse&gt; ping' lib/data/repositories/ping_repository.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "as Map&lt;Object\?, Object\?&gt;" lib/data/repositories/ping_repository.dart &amp;&amp; grep -q "cast&lt;String, dynamic&gt;" lib/data/repositories/ping_repository.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "PingResponse.fromMap" lib/data/repositories/ping_repository.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'final pingRepositoryProvider' lib/data/repositories/ping_repository.dart &amp;&amp; grep -q "ref.read(firebaseFunctionsProvider)" lib/data/repositories/ping_repository.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "package:mentor_minds/data/services/firebase_functions_provider.dart" lib/data/repositories/ping_repository.dart &amp;&amp; grep -q "package:mentor_minds/data/models/ping_response.dart" lib/data/repositories/ping_repository.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --no-fatal-infos 2>&amp;1 | tee /tmp/p2-07-t4-analyze.log &amp;&amp; ! grep -qE '^\s*(error|warning) -' /tmp/p2-07-t4-analyze.log</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; dart run custom_lint 2>&amp;1 | tee /tmp/p2-07-t4-customlint.log &amp;&amp; ! grep -q 'layered_imports' /tmp/p2-07-t4-customlint.log</automated>
  </verify>
  <acceptance_criteria>
    - File exists at lib/data/repositories/ping_repository.dart.
    - Class PingRepository declared with required `functions: FirebaseFunctions` constructor param.
    - `Future<PingResponse> ping()` method exists.
    - Contains the literal `httpsCallable('ping')` call.
    - Contains the non-obvious cast `as Map<Object?, Object?>` followed by `.cast<String, dynamic>()`.
    - Decodes via `PingResponse.fromMap(data)`.
    - `pingRepositoryProvider` declared at bottom of file, reads `firebaseFunctionsProvider`.
    - Package-style imports for both ping_response.dart and firebase_functions_provider.dart.
    - flutter analyze --no-fatal-infos exits 0 across the tree.
    - dart run custom_lint exits 0 with NO `layered_imports` violations.
  </acceptance_criteria>
  <done>
    PingRepository is the typed boundary between Flutter and the ping callable. Plan 02-08 wires the emulator redirect; Plan 02-09's integration test will instantiate PingRepository (via the provider) and assert the response shape.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| viewmodel layer ⇄ cloud_functions SDK | The `layered_imports` custom_lint rule from Phase 1 bans direct cloud_functions imports in lib/application/viewmodels/. Viewmodels go through pingRepositoryProvider. Phase 2 has no viewmodel consumer; Phase 3's MentorBotViewModel will be the first. |
| PingRepository ⇄ raw HttpsCallableResult | Phase 1 D-02 bans exposing raw SDK types upstream. PingRepository decodes via PingResponse.fromMap before returning. |
| Server-side region 'asia-south1' ⇄ Client-side instanceFor(region: 'asia-south1') | Drift between the two literals would route calls to default us-central1 and 404. Verify gates grep BOTH ends for the string. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-2-LAYER-BREACH | Tampering | A viewmodel imports `cloud_functions` directly, bypassing PingRepository — breaks the layered architecture | mitigate | Phase 1's `layered_imports` custom_lint rule (Plan 01-02) bans `package:cloud_functions/...` imports outside lib/data/. Verify: `dart run custom_lint` exits 0 with zero `layered_imports` lines. |
| T-2-07-RAW-SDK-LEAK | Tampering | Viewmodel calls PingRepository().ping() and receives raw HttpsCallableResult instead of PingResponse — breaks Phase 1 D-02 | mitigate | PingRepository.ping() return type is `Future<PingResponse>` — compiler enforces. Verify: grep ping_repository.dart for `Future<PingResponse> ping`. |
| T-2-07-REGION-DRIFT | Repudiation | Client uses `instanceFor(region: 'asia-southeast1')` while server is 'asia-south1' — call 404s | mitigate | Both ends grepped for literal `'asia-south1'`. Plan 02-03 verify gates `region: "asia-south1"` in functions/src/index.ts; this plan's verify gates `instanceFor(region: 'asia-south1')` in firebase_functions_provider.dart. |
| T-2-07-WRONG-CAST | Tampering | A future maintainer simplifies `as Map<Object?, Object?>).cast<String, dynamic>()` to `as Map<String, dynamic>` — runtime cast failure | mitigate | Inline comment in ping_repository.dart explains the non-obvious cast (RESEARCH Pattern 8). Verify gate `grep -qE "as Map<Object\?, Object\?>"` catches drift. Phase 3's MentorBotRepository will inherit the same pattern. |
| T-2-07-VERSION-DRIFT-CLOUD | Tampering | A future bump to cloud_functions ^6.x breaks firebase_core ^3.x lockstep — all Firebase deps stop resolving | mitigate | RESEARCH Pitfall 3 + Plan 02-07 Task 1 verify gate `! grep '^\s*cloud_functions:\s*\^?6'`. CI `flutter pub get` in Plan 02-10 fails on incompatible solutions. |
</threat_model>

<verification>
- pubspec.yaml has `cloud_functions: ^5.6.2` (or compatible ^5.x).
- flutter pub get exits 0.
- lib/data/services/firebase_functions_provider.dart exists with `instanceFor(region: 'asia-south1')`.
- lib/data/models/ping_response.dart exists with `factory PingResponse.fromMap` + safe-cast fields.
- lib/data/repositories/ping_repository.dart exists with `Future<PingResponse> ping()` + the non-obvious cast + `pingRepositoryProvider`.
- flutter analyze --no-fatal-infos exits 0 across the tree.
- dart run custom_lint exits 0 with no layered_imports violations.
</verification>

<success_criteria>
- D-17 honored: asia-south1 region pinned client-side, matching Plan 02-03's server-side pin.
- D-01..D-04 (Phase 1) honored: repository + provider + decoded model + package imports.
- T-2-LAYER-BREACH mitigated: cloud_functions confined to lib/data/.
- T-2-07-RAW-SDK-LEAK + T-2-07-WRONG-CAST + T-2-07-REGION-DRIFT all mitigated.
- FUNC-06 met (SDK wired through lib/data/services + repository); the end-to-end exercise (emulator round trip) lands in Plan 02-09.
</success_criteria>

<output>
Create `.planning/phases/02-cloud-functions-scaffolding-app-check/02-07-flutter-functions-sdk-SUMMARY.md` when done. Record:
1. The pubspec.yaml diff (one added line, plus pubspec.lock entry for cloud_functions).
2. The full content of lib/data/services/firebase_functions_provider.dart.
3. The full content of lib/data/models/ping_response.dart.
4. The full content of lib/data/repositories/ping_repository.dart.
5. The `flutter analyze --no-fatal-infos` exit code.
6. The `dart run custom_lint` exit code + the line count of any `layered_imports` matches (MUST be 0).
</output>
