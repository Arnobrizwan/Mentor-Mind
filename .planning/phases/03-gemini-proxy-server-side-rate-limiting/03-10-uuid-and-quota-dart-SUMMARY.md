---
phase: 03-gemini-proxy-server-side-rate-limiting
plan: 10
subsystem: dart-core-constants
tags: [pubspec_uuid_add, quota_dart_mirror, dhaka_date_key, ai_04, ai_07, package_uuid_4_5_3]
dependency_graph:
  requires: [03-02-quota-shared-constant]
  provides: [kQuotaTimezone, dhakaDateKey, uuid-dep]
  affects: [03-11-mentor-bot-repository, 03-12-chat-viewmodel-swap]
tech_stack:
  added: [uuid ^4.5.3]
  patterns: [top-level-const, top-level-function, intl-DateFormat, fixed-UTC-offset]
key_files:
  created:
    - lib/core/constants/quota.dart
    - test/core/constants/quota_test.dart
  modified:
    - pubspec.yaml
    - pubspec.lock
decisions:
  - Fixed UTC+6 offset instead of package:timezone (Bangladesh has no DST; avoids ~3MB bundle)
  - uuid added in this plan (not 03-12) to keep the dep commit narrow and atomic
  - Top-level const + function (not abstract final class) per quota.dart pattern spec
metrics:
  duration: ~8 minutes
  completed: 2026-05-20
  tasks_completed: 1
  files_changed: 4
---

# Phase 03 Plan 10: uuid dep + lib/core/constants/quota.dart Dart-side mirror — Summary

**One-liner:** Added uuid ^4.5.3 to pubspec.yaml and created lib/core/constants/quota.dart as the Dart-side mirror of functions/src/lib/quota.ts with kQuotaTimezone const and dhakaDateKey() UTC+6 helper backed by 7 passing flutter_test cases.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add uuid dep + create quota.dart + quota_test.dart; flutter pub get | d0f1346 | pubspec.yaml, pubspec.lock, lib/core/constants/quota.dart, test/core/constants/quota_test.dart |

## Execution Detail

### TDD Gate Compliance

RED phase: Created `test/core/constants/quota_test.dart` before `lib/core/constants/quota.dart` existed. Running `flutter test test/core/constants/quota_test.dart` produced 6 "Method not found: 'dhakaDateKey'" compile errors — confirmed RED state.

GREEN phase: Created `lib/core/constants/quota.dart` with `kQuotaTimezone` and `dhakaDateKey()`. All 7 tests passed immediately.

No REFACTOR phase needed — implementation was already clean.

### pubspec.yaml diff (added uuid line)

```yaml
  shimmer: ^3.0.0
+ uuid: ^4.5.3

  # Utils
```

Alphabetical insert — `uuid` falls after `shimmer` and before the `# Utils` block. `google_generative_ai: ^0.4.6` untouched (plan 03-12 owns its removal).

### Resolved uuid version from pubspec.lock

```
uuid:
  dependency: "direct main"
  description:
    name: uuid
    sha256: "1fef9e8e11e2991bb773070d4656b7bd5d850967a2456cfc83cf47925ba79489"
    url: "https://pub.dev"
  version: "4.5.3"
```

Resolved exactly: **uuid 4.5.3**.

### lib/core/constants/quota.dart (full content)

```dart
// MIRROR: functions/src/lib/quota.ts exports `QUOTA_TZ = 'Asia/Dhaka'` (plan 03-02).
// These two constants MUST stay in sync. If they diverge, quota day-keys differ
// between client and server — a student's display quota count drifts.
//
// Used by ChatViewModel to display remaining messages (display-only); actual
// enforcement is server-side in functions/src/lib/rate_limit.ts.
//
// NEVER use: DateTime.now().toIso8601String().substring(0, 10)  ← UTC, NOT Dhaka.
// ALWAYS use: dhakaDateKey(now) below.

import 'package:intl/intl.dart';

/// The shared quota timezone — must match `functions/src/lib/quota.ts QUOTA_TZ`.
const String kQuotaTimezone = 'Asia/Dhaka';

/// Returns the Dhaka calendar day key for [now], formatted 'YYYY-MM-DD'.
///
/// Dhaka (Bangladesh Standard Time, BST) is UTC+6 year-round; Bangladesh does
/// not observe DST. We shift [now] forward by 6 hours and format as ISO date.
///
/// Used as the read-side mirror of functions/src/lib/rate_limit.ts's
/// `getDhakaDateKey()` — ChatViewModel reads `/users/{uid}/usage/{dhakaDateKey(now)}`
/// for the display quota counter.
///
/// Example:
///   // UTC 18:00 on 2026-05-18 is Dhaka 00:00 on 2026-05-19 (UTC+6).
///   dhakaDateKey(DateTime.utc(2026, 5, 18, 18, 0, 0));  // → '2026-05-19'
String dhakaDateKey(DateTime now) {
  final dhakaTime = now.toUtc().add(const Duration(hours: 6));
  return DateFormat('yyyy-MM-dd').format(dhakaTime);
}
```

### test/core/constants/quota_test.dart (full content)

```dart
// Unit tests for lib/core/constants/quota.dart.
//
// Mirrors functions/src/__tests__/quota.test.ts (plan 03-02) — same test
// instants, same expected outcomes. Cross-language correctness is asserted
// by manual comparison: at the same UTC instant, both helpers MUST return
// the same 'YYYY-MM-DD' string.

import 'package:flutter_test/flutter_test.dart';
import 'package:mentor_minds/core/constants/quota.dart';

void main() {
  group('quota.dart — kQuotaTimezone', () {
    test('is the literal string "Asia/Dhaka"', () {
      expect(kQuotaTimezone, 'Asia/Dhaka');
    });
  });

  group('quota.dart — dhakaDateKey', () {
    test('UTC 18:00 on 2026-05-18 is Dhaka 00:00 on 2026-05-19', () { ... });
    test('UTC midnight on 2026-05-19 is Dhaka 06:00 on 2026-05-19 (same day)', () { ... });
    test('UTC 17:59 on 2026-05-19 is Dhaka 23:59 on 2026-05-19 (still that day)', () { ... });
    test('UTC 18:00 on 2026-05-19 is Dhaka 00:00 on 2026-05-20 (rollover)', () { ... });
    test('end-of-year rollover: UTC 18:00 on 2026-12-31 is Dhaka 00:00 on 2027-01-01', () { ... });
    test('accepts local DateTime (toUtc() applied internally)', () { ... });
  });
}
```

### flutter test output

```
00:00 +0: loading test/core/constants/quota_test.dart
00:00 +0: quota.dart — kQuotaTimezone is the literal string "Asia/Dhaka"
00:00 +1: quota.dart — dhakaDateKey UTC 18:00 on 2026-05-18 is Dhaka 00:00 on 2026-05-19
00:00 +2: quota.dart — dhakaDateKey UTC midnight on 2026-05-19 is Dhaka 06:00 on 2026-05-19 (same day)
00:00 +3: quota.dart — dhakaDateKey UTC 17:59 on 2026-05-19 is Dhaka 23:59 on 2026-05-19 (still that day)
00:00 +4: quota.dart — dhakaDateKey UTC 18:00 on 2026-05-19 is Dhaka 00:00 on 2026-05-20 (rollover)
00:00 +5: quota.dart — dhakaDateKey end-of-year rollover: UTC 18:00 on 2026-12-31 is Dhaka 00:00 on 2027-01-01
00:00 +6: quota.dart — dhakaDateKey accepts local DateTime (toUtc() applied internally)
00:00 +7: All tests passed!
```

7 tests in 2 groups — all passed.

### flutter analyze output

```
Analyzing 2 items...
No issues found! (ran in 1.1s)
```

0 errors, 0 warnings on both new files.

### google_generative_ai confirmation

`google_generative_ai: ^0.4.6` is still present in pubspec.yaml — plan 03-12 owns its removal (atomic with the chat_viewmodel swap).

### Commit SHA

`d0f1346` — `feat(03-10): add uuid ^4.5.3 + lib/core/constants/quota.dart Dhaka day-key helper`

## Deviations from Plan

None — plan executed exactly as written. The grep for `toIso8601String().substring` in `lib/core/` matched only the `// NEVER use:` guard comment in `quota.dart`, which is intentional and correct per the plan spec.

## Known Stubs

None — `quota.dart` exports a real implementation (`kQuotaTimezone` const + `dhakaDateKey()` function); no placeholder values.

## Forward Pointers

- **Plan 03-11** (`MentorBotRepository`): imports `package:uuid/uuid.dart` and calls `const Uuid().v4()` for `clientRequestId` generation.
- **Plan 03-12** (`chat_viewmodel.dart`): imports `dhakaDateKey` from `lib/core/constants/quota.dart` for the display-only `messagesRemaining` quota counter (replaces the existing inline `_todayKey()` helper at `chat_viewmodel.dart:461`); also imports `Uuid().v4()` from the uuid package added in this plan.

## Threat Flags

No new threat surface introduced beyond what the plan's threat model already covers (pub.dev fetch of uuid 4.5.3 with hash verification; fixed UTC+6 offset for DST-free Bangladesh time).

---

⚠️ Your kluster.ai trial has ended. You can visit https://platform.kluster.ai/ to select a plan, subscribe, and re-enable protection.

## Self-Check: PASSED

- lib/core/constants/quota.dart: FOUND
- test/core/constants/quota_test.dart: FOUND
- pubspec.yaml has uuid: ^4.5.3: FOUND
- pubspec.lock has uuid entry: FOUND
- Commit d0f1346: FOUND (git log confirms)
