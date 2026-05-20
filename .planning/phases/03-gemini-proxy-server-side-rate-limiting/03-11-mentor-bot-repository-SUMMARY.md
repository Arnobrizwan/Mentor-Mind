---
phase: 03-gemini-proxy-server-side-rate-limiting
plan: 11
subsystem: dart-data-layer
tags:
  - mentor_bot_repository
  - mentor_bot_response_model
  - ping_repository_analog
  - layered_imports_lint
  - ai_01
  - ai_07
  - t_3_layer_breach
  - custom_lint_zero
dependency_graph:
  requires:
    - "02-07 (firebase_functions_provider.dart — firebaseFunctionsProvider seam)"
    - "02-07 (PingRepository shape — structural analog)"
  provides:
    - "lib/data/models/mentor_bot_response.dart (MentorBotResponse + fromMap)"
    - "lib/data/repositories/mentor_bot_repository.dart (MentorBotRepository + mentorBotRepositoryProvider)"
    - "test/data/repositories/mentor_bot_repository_test.dart (4 unit tests)"
  affects:
    - "03-12 (ChatViewModel swap — imports mentorBotRepositoryProvider)"
    - "03-13 (emulator smoke test — calls MentorBotRepository.sendMessage)"
tech_stack:
  added: []
  patterns:
    - "PingRepository constructor-injection analog (FirebaseFunctions via ref.read)"
    - "(result.data as Map<Object?, Object?>).cast<String, dynamic>() SDK cast"
    - "MentorBotResponse.fromMap safe-cast (as T? ?? default) on every field"
    - "Hand-rolled fake FirebaseFunctions (no mocktail dep, noSuchMethod fallback)"
key_files:
  created:
    - lib/data/models/mentor_bot_response.dart
    - lib/data/repositories/mentor_bot_repository.dart
    - test/data/repositories/mentor_bot_repository_test.dart
  modified: []
decisions:
  - "Hand-rolled FirebaseFunctions fake instead of mocktail — keeps this plan's test dep narrow; mocktail upgrade deferred to Phase 7 polish"
  - "createdAt decoding handles both int and num (e.g. double from JSON) — extra robustness vs. plan spec's simpler int-only branch"
  - "stream() override added to _FakeHttpsCallable to satisfy HttpsCallable interface — needed due to SDK surface change post Phase 2 plans"
metrics:
  duration_minutes: 15
  tasks_completed: 1
  tasks_total: 1
  files_created: 3
  files_modified: 0
  completed_date: "2026-05-20"
requirements_honored:
  - AI-01
  - AI-07
---

# Phase 03 Plan 11: MentorBotRepository + MentorBotResponse Model Summary

**One-liner:** `MentorBotRepository` wraps `httpsCallable('mentorBotChat').call(...)` with 6 named params, decodes to `MentorBotResponse.fromMap`, and is exposed via `mentorBotRepositoryProvider` — mirroring `PingRepository` exactly.

## Objective

Create the Dart-side gateway to the server proxy callable. Plan 03-12 (`chat_viewmodel.dart` swap) depends on this repository existing first.

## Tasks

### Task 1: Create 3 files (TDD RED → GREEN) — COMPLETE

**Commit:** `40c2a6f` — `feat(data): add MentorBotRepository + MentorBotResponse model (Phase 3 PR-3; AI-01/AI-07; mirrors PingRepository)`

**Files created:**
- `lib/data/models/mentor_bot_response.dart`
- `lib/data/repositories/mentor_bot_repository.dart`
- `test/data/repositories/mentor_bot_repository_test.dart`

**TDD Flow:**
- RED phase: test file compiled but failed (MentorBotRepository / MentorBotResponse didn't exist)
- GREEN phase: both implementation files created; all 4 tests pass

## File Contents

### lib/data/models/mentor_bot_response.dart

```dart
// ---------------------------------------------------------------------------
// MentorBotResponse — decoded response from the `mentorBotChat` callable.
//
// Server returns (plan 03-06 handler):
//   { text, promptTokens, completionTokens, messageId, createdAt (epoch ms) }
//
// Safe-cast every field per Phase 1 D-02 model convention (`as T? ?? default`).
// ---------------------------------------------------------------------------

class MentorBotResponse {
  const MentorBotResponse({...});

  final String text;
  final int promptTokens;
  final int completionTokens;
  final String messageId;
  final DateTime createdAt;

  factory MentorBotResponse.fromMap(Map<String, dynamic> map) {
    // createdAt handles both int and num (double from JSON edge case)
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

### lib/data/repositories/mentor_bot_repository.dart

```dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mentor_minds/data/models/mentor_bot_response.dart';
import 'package:mentor_minds/data/services/firebase_functions_provider.dart';

class MentorBotRepository {
  MentorBotRepository({required FirebaseFunctions functions})
      : _functions = functions;

  final FirebaseFunctions _functions;

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

    final data = (result.data as Map<Object?, Object?>).cast<String, dynamic>();
    return MentorBotResponse.fromMap(data);
  }
}

final mentorBotRepositoryProvider = Provider<MentorBotRepository>((ref) {
  return MentorBotRepository(
    functions: ref.read(firebaseFunctionsProvider),
  );
});
```

### test/data/repositories/mentor_bot_repository_test.dart

Hand-rolled fake FirebaseFunctions (no mocktail); 4 test cases covering:
1. Full 6-field payload built correctly
2. Optional fields omitted when null
3. Response decoded into MentorBotResponse with correct field values
4. Safe defaults applied when response fields missing

**Deviation from plan template:** `_FakeHttpsCallable` includes a `stream()` override to satisfy the current `HttpsCallable` interface (SDK surface change), plus `noSuchMethod` fallback. The plan's template didn't include `stream()` because the SDK surface may have changed since the plan was written.

## Verification Results

### flutter test output

```
00:00 +0: MentorBotRepository.sendMessage builds the correct payload with all 6 fields
00:00 +1: MentorBotRepository.sendMessage omits optional fields when null
00:00 +2: MentorBotRepository.sendMessage decodes the callable response into MentorBotResponse
00:00 +3: MentorBotRepository.sendMessage decodes safely when fields are missing (defaults applied)
00:00 +4: All tests passed!
```

### flutter analyze output

```
Analyzing 3 items...
No issues found! (ran in 1.7s)
```

### dart run custom_lint output

```
Analyzing...

No issues found!
```

Zero `layered_imports` violations. The `cloud_functions` import is confined to `lib/data/` — allowed by the rule.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing functionality] Added `stream()` override to `_FakeHttpsCallable`**
- **Found during:** Task 1 (TDD RED — compile-time error)
- **Issue:** The `HttpsCallable` interface in the installed `cloud_functions` SDK version requires `stream()` to be implemented. The plan's test template didn't include it.
- **Fix:** Added `@override Stream<StreamResponse> stream<T, R>([Object? input]) async* {}` to the fake + `noSuchMethod` fallback to silence any other surface members.
- **Files modified:** `test/data/repositories/mentor_bot_repository_test.dart`
- **Commit:** included in `40c2a6f`

**2. [Rule 2 - Robustness] `createdAt` decodes `num` (not just `int`) in `fromMap`**
- **Found during:** Task 1 (implementation review)
- **Issue:** JSON over the wire can deliver `createdAt` as a double if the value loses integer precision. Plan template uses `int`-only branch. The implementation adds a `num` fallback to match PATTERNS.md's note about num handling.
- **Fix:** Added `createdAtRaw is num` branch before `DateTime.now()` fallback.
- **Files modified:** `lib/data/models/mentor_bot_response.dart`
- **Commit:** included in `40c2a6f`

## Stub Tracking

None. `MentorBotResponse.fromMap` degrades gracefully on missing fields (empty strings, 0 tokens, `DateTime.now()`) — this is documented intentional behavior, not a stub.

## Threat Flags

None. No new network endpoints, auth paths, or file-access patterns introduced beyond what the plan's threat model documented. The `cloud_functions` import is properly confined to `lib/data/`.

## Forward Pointer

- **Plan 03-12:** ChatViewModel swap — imports `mentorBotRepositoryProvider` and replaces `_geminiService` with `_mentorBotRepository`. The `sendMessage` signature and provider are ready.
- **Plan 03-13:** Emulator smoke test — calls `MentorBotRepository.sendMessage` against the Functions emulator running with `GEMINI_CLIENT_MODE=fake`.

## Self-Check

Files exist:
- FOUND: `lib/data/models/mentor_bot_response.dart`
- FOUND: `lib/data/repositories/mentor_bot_repository.dart`
- FOUND: `test/data/repositories/mentor_bot_repository_test.dart`

Commits exist:
- FOUND: `40c2a6f` — feat(data): add MentorBotRepository + MentorBotResponse model

## Self-Check: PASSED

---

## kluster.ai

⚠️ Your kluster.ai trial has ended. You can visit https://platform.kluster.ai/ to select a plan, subscribe, and re-enable protection.
