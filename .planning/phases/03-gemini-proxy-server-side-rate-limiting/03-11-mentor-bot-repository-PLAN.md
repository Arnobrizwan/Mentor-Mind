---
phase: 03-gemini-proxy-server-side-rate-limiting
plan: 11
type: execute
wave: 5
depends_on: ["03-10"]
files_modified:
  - lib/data/models/mentor_bot_response.dart
  - lib/data/repositories/mentor_bot_repository.dart
  - test/data/repositories/mentor_bot_repository_test.dart
autonomous: true
requirements: [AI-01, AI-07]
pr_group: PR-3
tags: [mentor_bot_repository, mentor_bot_response_model, ping_repository_analog, layered_imports_lint, ai_01, ai_07, t_3_layer_breach, custom_lint_zero]

must_haves:
  truths:
    - "AI-01 honored (client side): `lib/data/repositories/mentor_bot_repository.dart` wraps `FirebaseFunctions.instance.httpsCallable('mentorBotChat').call(...)` — the single Dart-side entry point for invoking the Phase 3 server proxy"
    - "AI-07 honored (client side): `sendMessage` accepts `required String clientRequestId` so callers (plan 03-12 ChatViewModel) generate the UUID once and reuse it across retries — server-side idempotency dedupe (plan 03-06) takes over from there"
    - "D-CONTEXT Claude's-Discretion locked: signature is `Future<MentorBotResponse> sendMessage({required String sessionId, required String clientRequestId, required String message, String? imageUrl, String? subject, String? level})` — matches the callable's wire shape (plan 03-06 handler reads these exact field names)"
    - "Phase 1 D-02 repository pattern honored: `MentorBotRepository` mirrors `PingRepository` shape EXACTLY — constructor takes `FirebaseFunctions` via `ref.read(firebaseFunctionsProvider)`; method wraps `httpsCallable('NAME').call()`; returns decoded domain model"
    - "Phase 2 D-PATTERNS honored: `(result.data as Map<Object?, Object?>).cast<String, dynamic>()` cast — same shape as PingRepository (callable returns Map<Object?, Object?> at runtime, not Map<String, dynamic>)"
    - "Phase 1 D-14 honored: file uses `package:mentor_minds/...` imports (NOT relative imports)"
    - "Phase 1 D-04 honored: exposes `mentorBotRepositoryProvider` (Provider<MentorBotRepository>) alongside the existing `pingRepositoryProvider`"
    - "T-3-LAYER-BREACH mitigated (this side): `cloud_functions` import is confined to `lib/data/` — `MentorBotRepository` is the layer boundary; plan 03-12 viewmodel MUST NOT import cloud_functions"
    - "custom_lint `layered_imports` rule (Phase 1 Plan 01-02 + 01-05) checks zero violations after this plan"
    - "PingResponse-style decoded-model factory pattern honored: `MentorBotResponse.fromMap(Map<String, dynamic>)` with safe-cast `as T? ?? default` on every field (Phase 1 D-02 model convention)"
    - "AI-10 honored: repository returns `Future<MentorBotResponse>` (single future, NOT a Stream) — matches server-side non-streaming contract"
  artifacts:
    - path: "lib/data/models/mentor_bot_response.dart"
      provides: "NEW — MentorBotResponse class with fromMap factory; mirrors PingResponse shape with 5 fields (text, promptTokens, completionTokens, messageId, createdAt)"
      contains: "MentorBotResponse"
    - path: "lib/data/repositories/mentor_bot_repository.dart"
      provides: "NEW — MentorBotRepository class + mentorBotRepositoryProvider; single method sendMessage"
      contains: "mentorBotRepositoryProvider"
    - path: "test/data/repositories/mentor_bot_repository_test.dart"
      provides: "NEW — unit tests with a fake FirebaseFunctions (no Firebase init); verifies sendMessage builds the correct payload + decodes the response"
      contains: "MentorBotRepository"
  key_links:
    - from: "lib/data/repositories/mentor_bot_repository.dart"
      to: "lib/data/services/firebase_functions_provider.dart (Phase 2 Plan 02-07)"
      via: "constructor reads firebaseFunctionsProvider via ref.read"
      pattern: "firebaseFunctionsProvider"
    - from: "lib/data/repositories/mentor_bot_repository.dart"
      to: "functions/src/index.ts mentorBotChat (plan 03-06)"
      via: "httpsCallable('mentorBotChat').call(...)"
      pattern: "mentorBotChat"
    - from: "lib/data/repositories/mentor_bot_repository.dart"
      to: "lib/application/viewmodels/tutor/chat_viewmodel.dart (plan 03-12)"
      via: "viewmodel reads mentorBotRepositoryProvider via ref.read"
      pattern: "mentorBotRepositoryProvider"
---

<objective>
Create three files: (1) `lib/data/models/mentor_bot_response.dart` — a 5-field decoded response model mirroring `PingResponse.fromMap`; (2) `lib/data/repositories/mentor_bot_repository.dart` — a `PingRepository`-shaped wrapper that calls `httpsCallable('mentorBotChat').call(...)` with the 6 named parameters (sessionId, clientRequestId, message, imageUrl?, subject?, level?), decodes the result, and exposes `mentorBotRepositoryProvider`; (3) `test/data/repositories/mentor_bot_repository_test.dart` — unit tests that verify the wire shape using a fake `FirebaseFunctions`. After creation, run `flutter analyze --no-fatal-infos && dart run custom_lint` to confirm zero `layered_imports` violations (the `cloud_functions` import is in `lib/data/` — allowed).

Purpose: AI-01 + AI-07 require a single Dart-side gateway to the server proxy. The repository pattern (Phase 1 D-02) is the layer boundary: ViewModels never import `cloud_functions` directly; they go through `Repository.method()` and receive decoded domain models. Plan 03-12 swaps `chat_viewmodel.dart` from `_geminiService` to `_mentorBotRepository` — that swap only works if THIS repository exists first.

Output: 3 files NEW. One commit. `flutter analyze --no-fatal-infos` exits 0; `dart run custom_lint` reports zero violations; `flutter test test/data/repositories/mentor_bot_repository_test.dart` exits 0.
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
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-07-flutter-functions-sdk-PLAN.md
@lib/data/repositories/ping_repository.dart
@lib/data/services/firebase_functions_provider.dart
@CLAUDE.md

<interfaces>
<!-- Patterns from 03-PATTERNS.md §lib/data/models/mentor_bot_response.dart lines 677-715 + §lib/data/repositories/mentor_bot_repository.dart lines 722-771 -->

lib/data/models/mentor_bot_response.dart (NEW — full file, copy verbatim):

```dart
// ---------------------------------------------------------------------------
// MentorBotResponse — decoded response from the `mentorBotChat` callable.
//
// Server returns (plan 03-06 handler):
//   {
//     text: String,             // the assistant's reply
//     promptTokens: int,        // tokens consumed by the prompt (display + cost)
//     completionTokens: int,    // tokens consumed by the response
//     messageId: String,        // server-side messageId (==clientRequestId per D-08)
//     createdAt: int,           // epoch ms (Timestamp.toMillis on the server)
//   }
//
// Safe-cast every field per Phase 1 D-02 model convention (`as T? ?? default`).
// ---------------------------------------------------------------------------

class MentorBotResponse {
  const MentorBotResponse({
    required this.text,
    required this.promptTokens,
    required this.completionTokens,
    required this.messageId,
    required this.createdAt,
  });

  final String text;
  final int promptTokens;
  final int completionTokens;
  final String messageId;
  final DateTime createdAt;

  factory MentorBotResponse.fromMap(Map<String, dynamic> map) {
    final createdAtRaw = map['createdAt'];
    final createdAt = createdAtRaw is int
        ? DateTime.fromMillisecondsSinceEpoch(createdAtRaw)
        : (createdAtRaw is num
            ? DateTime.fromMillisecondsSinceEpoch(createdAtRaw.toInt())
            : DateTime.now());

    return MentorBotResponse(
      text: (map['text'] as String?) ?? '',
      promptTokens: (map['promptTokens'] as num?)?.toInt() ?? 0,
      completionTokens: (map['completionTokens'] as num?)?.toInt() ?? 0,
      messageId: (map['messageId'] as String?) ?? '',
      createdAt: createdAt,
    );
  }
}
```

lib/data/repositories/mentor_bot_repository.dart (NEW — full file, copy verbatim):

```dart
// ---------------------------------------------------------------------------
// MentorBotRepository — single entry point for the `mentorBotChat` callable.
//
// Phase 3 D-06: every send carries a clientRequestId (UUIDv4) so the server
// can idempotency-dedupe retries. Caller (ChatViewModel) generates the id
// once per user-initiated send and reuses it for retries.
//
// Phase 1 D-02 layering: ViewModels NEVER import `cloud_functions`; they
// import `package:mentor_minds/data/repositories/mentor_bot_repository.dart`
// instead. custom_lint `layered_imports` rule enforces this.
//
// Phase 2 D-PATTERNS cast: `httpsCallable().call()` returns a `result` whose
// `data` field is `Map<Object?, Object?>` at runtime — not Map<String,dynamic>.
// We cast via `.cast<String, dynamic>()` BEFORE passing to fromMap.
// ---------------------------------------------------------------------------

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/data/models/mentor_bot_response.dart';
import 'package:mentor_minds/data/services/firebase_functions_provider.dart';

class MentorBotRepository {
  MentorBotRepository({required FirebaseFunctions functions})
      : _functions = functions;

  final FirebaseFunctions _functions;

  /// Invokes the `mentorBotChat` callable on `asia-south1` with the given
  /// payload. Throws `FirebaseFunctionsException` on server-side rejection
  /// (resource-exhausted, unauthenticated, unavailable, internal, etc — D-07).
  ///
  /// Idempotency: pass the SAME [clientRequestId] across retries to get the
  /// SAME server-side messageId without re-invoking Gemini (D-CONTEXT D-06).
  Future<MentorBotResponse> sendMessage({
    required String sessionId,
    required String clientRequestId,
    required String message,
    String? imageUrl,
    String? subject,
    String? level,
  }) async {
    final result = await _functions
        .httpsCallable('mentorBotChat')
        .call<dynamic>(<String, dynamic>{
      'sessionId': sessionId,
      'clientRequestId': clientRequestId,
      'message': message,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (subject != null) 'subject': subject,
      if (level != null) 'level': level,
    });

    final data =
        (result.data as Map<Object?, Object?>).cast<String, dynamic>();
    return MentorBotResponse.fromMap(data);
  }
}

final mentorBotRepositoryProvider = Provider<MentorBotRepository>((ref) {
  return MentorBotRepository(
    functions: ref.read(firebaseFunctionsProvider),
  );
});
```

test/data/repositories/mentor_bot_repository_test.dart (NEW — full file, copy verbatim):

```dart
// Unit tests for MentorBotRepository.sendMessage.
//
// Strategy: instantiate MentorBotRepository directly with a fake FirebaseFunctions
// stub built via mocktail (or a hand-rolled fake). Verify:
//   1. Payload built from the 6 named parameters matches the wire shape.
//   2. fromMap decodes the canned callable response into MentorBotResponse.
//   3. Optional fields (imageUrl, subject, level) are omitted from the payload
//      when null (the if-null guard in the implementation).
//
// We avoid mocktail to keep this plan dependency-narrow — a hand-rolled fake is
// sufficient.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentor_minds/data/models/mentor_bot_response.dart';
import 'package:mentor_minds/data/repositories/mentor_bot_repository.dart';

class _FakeHttpsCallableResult implements HttpsCallableResult<dynamic> {
  _FakeHttpsCallableResult(this._data);
  final Object? _data;
  @override
  dynamic get data => _data;
}

class _FakeHttpsCallable implements HttpsCallable {
  _FakeHttpsCallable({required this.cannedResponse, required this.spy});
  final Map<String, dynamic> cannedResponse;
  final List<Object?> spy;

  @override
  Future<HttpsCallableResult<T>> call<T>([Object? parameters]) async {
    spy.add(parameters);
    return _FakeHttpsCallableResult(cannedResponse) as HttpsCallableResult<T>;
  }
}

class _FakeFirebaseFunctions implements FirebaseFunctions {
  _FakeFirebaseFunctions({required this.callable});
  final _FakeHttpsCallable callable;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    return callable;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('MentorBotRepository.sendMessage', () {
    test('builds the correct payload with all 6 fields', () async {
      final spy = <Object?>[];
      final fakeCallable = _FakeHttpsCallable(
        cannedResponse: <String, dynamic>{
          'text': 'hi',
          'promptTokens': 10,
          'completionTokens': 20,
          'messageId': 'mid-1',
          'createdAt': 1_700_000_000_000,
        },
        spy: spy,
      );
      final repo = MentorBotRepository(
        functions: _FakeFirebaseFunctions(callable: fakeCallable),
      );

      await repo.sendMessage(
        sessionId: 'sess-1',
        clientRequestId: 'req-1',
        message: 'Hello',
        imageUrl: 'gs://b/p.jpg',
        subject: 'Physics',
        level: 'A-Level',
      );

      expect(spy, hasLength(1));
      final payload = spy.first as Map<String, dynamic>;
      expect(payload['sessionId'], 'sess-1');
      expect(payload['clientRequestId'], 'req-1');
      expect(payload['message'], 'Hello');
      expect(payload['imageUrl'], 'gs://b/p.jpg');
      expect(payload['subject'], 'Physics');
      expect(payload['level'], 'A-Level');
    });

    test('omits optional fields when null', () async {
      final spy = <Object?>[];
      final fakeCallable = _FakeHttpsCallable(
        cannedResponse: <String, dynamic>{
          'text': 'hi',
          'promptTokens': 1,
          'completionTokens': 2,
          'messageId': 'mid',
          'createdAt': 0,
        },
        spy: spy,
      );
      final repo = MentorBotRepository(
        functions: _FakeFirebaseFunctions(callable: fakeCallable),
      );

      await repo.sendMessage(
        sessionId: 'sess-2',
        clientRequestId: 'req-2',
        message: 'Hi',
      );

      final payload = spy.first as Map<String, dynamic>;
      expect(payload.containsKey('imageUrl'), isFalse);
      expect(payload.containsKey('subject'), isFalse);
      expect(payload.containsKey('level'), isFalse);
      expect(payload.keys, containsAll(<String>['sessionId', 'clientRequestId', 'message']));
    });

    test('decodes the callable response into MentorBotResponse', () async {
      final fakeCallable = _FakeHttpsCallable(
        cannedResponse: <String, dynamic>{
          'text': 'Hello student',
          'promptTokens': 50,
          'completionTokens': 100,
          'messageId': 'mid-xyz',
          'createdAt': 1_710_000_000_000,
        },
        spy: <Object?>[],
      );
      final repo = MentorBotRepository(
        functions: _FakeFirebaseFunctions(callable: fakeCallable),
      );

      final response = await repo.sendMessage(
        sessionId: 'sess-3',
        clientRequestId: 'req-3',
        message: 'Q',
      );

      expect(response, isA<MentorBotResponse>());
      expect(response.text, 'Hello student');
      expect(response.promptTokens, 50);
      expect(response.completionTokens, 100);
      expect(response.messageId, 'mid-xyz');
      expect(response.createdAt.millisecondsSinceEpoch, 1_710_000_000_000);
    });

    test('decodes safely when fields are missing (defaults applied)', () async {
      final fakeCallable = _FakeHttpsCallable(
        cannedResponse: <String, dynamic>{}, // empty response
        spy: <Object?>[],
      );
      final repo = MentorBotRepository(
        functions: _FakeFirebaseFunctions(callable: fakeCallable),
      );

      final response = await repo.sendMessage(
        sessionId: 'sess-4',
        clientRequestId: 'req-4',
        message: 'Q',
      );

      expect(response.text, '');
      expect(response.promptTokens, 0);
      expect(response.completionTokens, 0);
      expect(response.messageId, '');
      // createdAt defaults to DateTime.now() — confirm it's recent (within 5s).
      final delta = DateTime.now().difference(response.createdAt).inSeconds;
      expect(delta.abs(), lessThan(5));
    });
  });
}
```

Why hand-rolled fakes (not mocktail):
  - The `FirebaseFunctions` class has a complex surface (~10 methods). Mocking it via mocktail requires `extends Mock` + `Fake` registration; the hand-rolled fake is ~30 lines and stays narrow.
  - `mocktail` is not currently a Phase 3 dep; adding it for one repository test is overkill. Phase 7 polish: standardize on mocktail if other repositories need richer mocks.
  - The `noSuchMethod` fallback in `_FakeFirebaseFunctions` catches any unexpected SDK method calls — the test fails loudly if the production code starts using something we didn't fake.

Why we cast `cannedResponse: <String, dynamic>` (not Map<Object?, Object?>):
  - The PRODUCTION code casts the SDK's `Map<Object?, Object?>` to `Map<String, dynamic>` before calling `fromMap`. Our fake skips the intermediate `Map<Object?, Object?>` representation — the test asserts the post-cast behavior is correct.
  - Phase 2 D-PATTERNS confirms the cast is necessary against the real SDK; the fake test verifies the decode logic AFTER the cast.

What this plan does NOT do:
  - Does NOT touch `lib/application/viewmodels/tutor/chat_viewmodel.dart` — plan 03-12 owns the swap.
  - Does NOT delete `lib/core/services/gemini_service.dart` — plan 03-12 owns deletion (atomic with viewmodel swap).
  - Does NOT remove `google_generative_ai` from `pubspec.yaml` — plan 03-12 owns that.
  - Does NOT add a `Future<Stream<String>>` streaming variant — AI-10 non-streaming v1.0.
  - Does NOT call `package:uuid` — the viewmodel (plan 03-12) generates the clientRequestId before invoking the repository.
  - Does NOT instrument App Check token — Phase 2 D-CONTEXT already wires it at the SDK level.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Create lib/data/models/mentor_bot_response.dart + lib/data/repositories/mentor_bot_repository.dart + test/data/repositories/mentor_bot_repository_test.dart; verify flutter analyze + flutter test + dart run custom_lint all green</name>
  <files>lib/data/models/mentor_bot_response.dart, lib/data/repositories/mentor_bot_repository.dart, test/data/repositories/mentor_bot_repository_test.dart</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/lib/data/repositories/ping_repository.dart (Phase 2 — the EXACT analog; copy structure verbatim, change names)
    - /Users/arnobrizwan/Mentor-Mind/lib/data/models/ping_response.dart (Phase 2 — fromMap pattern)
    - /Users/arnobrizwan/Mentor-Mind/lib/data/services/firebase_functions_provider.dart (Phase 2 Plan 02-07 — confirm `firebaseFunctionsProvider` export)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-PATTERNS.md (§lib/data/models/mentor_bot_response.dart lines 677-715 + §lib/data/repositories/mentor_bot_repository.dart lines 722-771)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-CONTEXT.md (D-06, D-CONTEXT §Claude's Discretion repository signature)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md (row `03-11-mentor-bot-repository` line 64)
    - /Users/arnobrizwan/Mentor-Mind/pubspec.yaml (confirm cloud_functions + flutter_riverpod deps present from Phase 2)
  </read_first>
  <behavior>
    - `MentorBotResponse.fromMap({})` returns an instance with `text=''`, `promptTokens=0`, `completionTokens=0`, `messageId=''`, `createdAt≈now`.
    - `MentorBotResponse.fromMap({'text':'hi','promptTokens':50,'completionTokens':100,'messageId':'mid','createdAt':1700000000000})` returns the matching values exactly.
    - `MentorBotRepository.sendMessage({sessionId, clientRequestId, message, imageUrl, subject, level})` calls `httpsCallable('mentorBotChat').call({...payload})` with all 6 fields included.
    - `MentorBotRepository.sendMessage` with only the 3 required fields produces a payload WITHOUT `imageUrl`, `subject`, `level` keys.
    - `mentorBotRepositoryProvider.read(...)` returns a MentorBotRepository wired to `ref.read(firebaseFunctionsProvider)`.
    - 4 flutter_test cases pass.
    - `flutter analyze --no-fatal-infos` exits 0 on the 3 new files.
    - `dart run custom_lint` reports zero `layered_imports` violations (cloud_functions import in lib/data/ is allowed).
  </behavior>
  <action>
    Step A — Read `lib/data/repositories/ping_repository.dart` and `lib/data/models/ping_response.dart` to capture the canonical Phase 2 shape. Confirm:
      - PingRepository constructor: `PingRepository({required FirebaseFunctions functions})`.
      - PingRepository method: `httpsCallable('ping').call<dynamic>()` + `(result.data as Map<Object?, Object?>).cast<String, dynamic>()` + `PingResponse.fromMap(data)`.
      - `pingRepositoryProvider = Provider<PingRepository>((ref) => PingRepository(functions: ref.read(firebaseFunctionsProvider)))`.

    Step B — TDD RED: Create `test/data/repositories/mentor_bot_repository_test.dart` with the EXACT content from the `<interfaces>` block. Run:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      flutter test test/data/repositories/mentor_bot_repository_test.dart 2>&amp;1 | tee /tmp/p3-11-red.log
      # Expect: compile failure — MentorBotRepository / MentorBotResponse don't exist yet.
      ```

    Step C — Create `lib/data/models/mentor_bot_response.dart` with the EXACT content from the `<interfaces>` block.

    Step D — Create `lib/data/repositories/mentor_bot_repository.dart` with the EXACT content from the `<interfaces>` block.

    Step E — Re-run the test:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      flutter test test/data/repositories/mentor_bot_repository_test.dart 2>&amp;1 | tee /tmp/p3-11-green.log
      # Expect: All 4 tests passed.
      ```

    Step F — Static analysis on the three new files:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      flutter analyze --no-fatal-infos \
        lib/data/models/mentor_bot_response.dart \
        lib/data/repositories/mentor_bot_repository.dart \
        test/data/repositories/mentor_bot_repository_test.dart \
        2>&amp;1 | tee /tmp/p3-11-analyze.log
      # Expect: 0 errors, 0 warnings.
      ```

    Step G — custom_lint (Phase 1 D-CONTEXT — layered_imports rule):
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      dart run custom_lint 2>&amp;1 | tee /tmp/p3-11-customlint.log
      # Expect: exit 0. Output should NOT show any 'layered_imports' violation
      # for the new files. (The MentorBotRepository legitimately imports
      # cloud_functions; the rule allows this because the file is under lib/data/.)
      ```

    Step H — Required-content greps:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      grep -q "class MentorBotResponse" lib/data/models/mentor_bot_response.dart
      grep -q "factory MentorBotResponse.fromMap" lib/data/models/mentor_bot_response.dart
      grep -q "as String?" lib/data/models/mentor_bot_response.dart
      grep -q "class MentorBotRepository" lib/data/repositories/mentor_bot_repository.dart
      grep -q "httpsCallable('mentorBotChat')" lib/data/repositories/mentor_bot_repository.dart
      grep -q "(result.data as Map<Object?, Object?>).cast<String, dynamic>()" lib/data/repositories/mentor_bot_repository.dart
      grep -q "mentorBotRepositoryProvider" lib/data/repositories/mentor_bot_repository.dart
      grep -q "firebaseFunctionsProvider" lib/data/repositories/mentor_bot_repository.dart
      # Phase 1 D-14: package-style imports (no relative)
      ! grep -E "import '\\.\\./" lib/data/repositories/mentor_bot_repository.dart
      ```

    Step I — Commit:
      ```bash
      git add lib/data/models/mentor_bot_response.dart \
              lib/data/repositories/mentor_bot_repository.dart \
              test/data/repositories/mentor_bot_repository_test.dart
      git commit -m "feat(data): add MentorBotRepository + MentorBotResponse model (Phase 3 PR-3; AI-01/AI-07; mirrors PingRepository)"
      ```
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f lib/data/models/mentor_bot_response.dart &amp;&amp; test -f lib/data/repositories/mentor_bot_repository.dart &amp;&amp; test -f test/data/repositories/mentor_bot_repository_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "class MentorBotResponse" lib/data/models/mentor_bot_response.dart &amp;&amp; grep -q "factory MentorBotResponse.fromMap" lib/data/models/mentor_bot_response.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "class MentorBotRepository" lib/data/repositories/mentor_bot_repository.dart &amp;&amp; grep -q "httpsCallable('mentorBotChat')" lib/data/repositories/mentor_bot_repository.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "mentorBotRepositoryProvider" lib/data/repositories/mentor_bot_repository.dart &amp;&amp; grep -q "firebaseFunctionsProvider" lib/data/repositories/mentor_bot_repository.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "result\.data as Map&lt;Object\?, Object\?&gt;\)\.cast&lt;String, dynamic&gt;" lib/data/repositories/mentor_bot_repository.dart OR grep -q "cast<String, dynamic>" lib/data/repositories/mentor_bot_repository.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -E "import '\\.\\./" lib/data/repositories/mentor_bot_repository.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter test test/data/repositories/mentor_bot_repository_test.dart 2>&amp;1 | grep -qE 'All tests passed|\+[0-9]+:'</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --no-fatal-infos lib/data/models/mentor_bot_response.dart lib/data/repositories/mentor_bot_repository.dart test/data/repositories/mentor_bot_repository_test.dart 2>&amp;1 | tail -3; test $? -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; dart run custom_lint 2>&amp;1 | tail -10 | tee /tmp/p3-11-customlint-verify.log; ! grep -E 'layered_imports.*mentor_bot' /tmp/p3-11-customlint-verify.log</automated>
  </verify>
  <acceptance_criteria>
    - `lib/data/models/mentor_bot_response.dart` defines `class MentorBotResponse` with 5 fields + `fromMap` factory.
    - `fromMap` uses `as T? ?? default` on every field (Phase 1 D-02 convention).
    - `lib/data/repositories/mentor_bot_repository.dart` defines `class MentorBotRepository` + `mentorBotRepositoryProvider`.
    - Repository constructor takes `FirebaseFunctions`; method calls `httpsCallable('mentorBotChat').call(...)` with the 6-field payload.
    - `(result.data as Map<Object?, Object?>).cast<String, dynamic>()` cast applied before `fromMap`.
    - Both new lib files use `package:mentor_minds/...` imports (no relative).
    - 4 flutter_test cases pass under `flutter test`.
    - `flutter analyze --no-fatal-infos` exits 0 on the 3 new files.
    - `dart run custom_lint` reports zero `layered_imports` violations on the new files.
  </acceptance_criteria>
  <done>
    The Dart-side gateway is ready. Plan 03-12 imports `package:mentor_minds/data/repositories/mentor_bot_repository.dart` and swaps `chat_viewmodel.dart` from `_geminiService` to `_mentorBotRepository`. Plan 03-13 integration smoke test exercises the repository against the Functions emulator.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| MentorBotRepository ⇄ FirebaseFunctions SDK | Repository is the ONLY caller of `httpsCallable('mentorBotChat')` from the Dart side. Phase 1 D-02 layering + custom_lint `layered_imports` rule enforce this. |
| MentorBotResponse ⇄ server wire shape | The `fromMap` factory tolerates missing fields (safe-cast default). If the server's response shape changes, the factory degrades gracefully — empty strings + 0 tokens. |
| sendMessage payload ⇄ wire JSON | The if-null guards omit optional fields from the payload; the server-side handler reads `data['imageUrl']` as `string | undefined` and branches accordingly (plan 03-06). |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-3-LAYER-BREACH | Tampering | A future viewmodel imports `cloud_functions` directly, bypassing the repository layer | mitigate | custom_lint `layered_imports` rule (Phase 1 Plan 01-02 + 01-05). Phase 3 PR-3 verify includes `dart run custom_lint` exit-0 gate. Plan 03-12 viewmodel grep gate also asserts no cloud_functions import. |
| T-3-11-PAYLOAD-DRIFT | Tampering | Server adds a new required field; client doesn't send it; server throws `internal` | mitigate | Tests for plan 03-06 idempotency.test.ts assert the exact payload shape consumed. If the server-side shape evolves, both the server handler test AND this repo test fail in lockstep. |
| T-3-11-RESPONSE-DROP | Information Disclosure | Server adds a new sensitive field (e.g. PII token); fromMap silently picks it up | accept | Current factory only extracts the 5 documented fields; unknown fields in the response are ignored. Adding a sensitive field would be a server-side design issue, not a client one. |
| T-3-11-CAST-FAIL | Denial of Service | Future Firebase SDK version changes the runtime type of `result.data` (e.g. dart-native Map<String, Object>) and the `.cast` throws | mitigate | The hand-rolled fake test exercises only the post-cast path. Plan 03-13 emulator smoke test exercises the live SDK path — a future SDK upgrade surfaces a fail there. |
| T-3-SC-UUID-INDIRECT | Tampering (supply chain) | This repository does NOT itself import `package:uuid` — only the viewmodel does (plan 03-12). The vetting from plan 03-10 covers this. | mitigate (inherited) | - |
</threat_model>

<verification>
- lib/data/models/mentor_bot_response.dart exports MentorBotResponse + fromMap.
- lib/data/repositories/mentor_bot_repository.dart exports MentorBotRepository + mentorBotRepositoryProvider.
- httpsCallable('mentorBotChat') is the wire name.
- 6-field payload built; optional fields omitted when null.
- cast<String, dynamic> applied to the SDK response.
- 4 flutter_test cases pass.
- flutter analyze --no-fatal-infos passes on new files.
- dart run custom_lint passes (no layered_imports violations).
</verification>

<success_criteria>
- AI-01 + AI-07 client-side gateway ready.
- Plan 03-12 can import `package:mentor_minds/data/repositories/mentor_bot_repository.dart` and swap.
- Phase 1 D-02 layering preserved (custom_lint zero).
- Plan 03-13 emulator smoke test has a typed repository to call.
</success_criteria>

<output>
Create `.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-11-mentor-bot-repository-SUMMARY.md` when done. Record:
1. Full content of lib/data/models/mentor_bot_response.dart.
2. Full content of lib/data/repositories/mentor_bot_repository.dart.
3. Full content of test/data/repositories/mentor_bot_repository_test.dart.
4. flutter test output (4 cases passed).
5. flutter analyze output (0 errors).
6. dart run custom_lint output (no layered_imports violations on new files).
7. Commit SHA.
8. Forward-pointer: plan 03-12 imports the repository and swaps chat_viewmodel.dart; plan 03-13 exercises via emulator smoke test.
</output>
</content>
