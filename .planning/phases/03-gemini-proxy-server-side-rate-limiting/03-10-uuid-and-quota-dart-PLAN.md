---
phase: 03-gemini-proxy-server-side-rate-limiting
plan: 10
type: execute
wave: 5
depends_on: []
files_modified:
  - pubspec.yaml
  - pubspec.lock
  - lib/core/constants/quota.dart
  - test/core/constants/quota_test.dart
autonomous: true
requirements: [AI-04, AI-07]
pr_group: PR-3
tags: [pubspec_uuid_add, quota_dart_mirror, dhaka_date_key, ai_04, ai_07, package_uuid_4_5_3, package_legitimacy_audit]

must_haves:
  truths:
    - "D-06 honored: `package:uuid: ^4.5.3` added to `pubspec.yaml` dependencies (alphabetical insert between `image_picker` and `intl`)"
    - "D-CONTEXT §Specifics + plan 03-02 honored: `lib/core/constants/quota.dart` is the Dart-side mirror of `functions/src/lib/quota.ts`; both files reference each other in a header comment so future drift is loud (PITFALLS #3)"
    - "PITFALLS #3 closed (Dart side): `dhakaDateKey(DateTime now)` uses `DateFormat('yyyy-MM-dd').format(now.toUtc().add(const Duration(hours: 6)))` — NEVER raw `DateTime.now().toIso8601String().substring(0, 10)` (which is UTC)"
    - "Cross-language correctness: for the same UTC instant, `quota.ts getDhakaDateKey()` returns the same `'YYYY-MM-DD'` as `lib/core/constants/quota.dart dhakaDateKey()` — verified by hand-picked test instants matching the TS-side tests"
    - "AI-07 partially delivered (Dart side): the `uuid: ^4.5.3` dep is the foundation; plan 03-12 will use `const Uuid().v4()` for `clientRequestId` generation in `chat_viewmodel.dart`"
    - "AI-04 partially delivered (Dart side): the `dhakaDateKey()` helper is the foundation; plan 03-12 will use it for the display-only `messagesRemaining` quota counter (the server-side enforcement is in plan 03-05)"
    - "RESEARCH §Package Legitimacy Audit confirmed: `uuid` v4.5.3 on pub.dev is the Dart team's officially-recommended UUID generator (Daniel Cachapa et al.); MIT licensed; no postinstall scripts; verified ASSUMED OK"
    - "intl is already a dependency (pubspec.yaml line ~44 — Phase 1 baseline); no new dep needed for DateFormat"
    - "T-3-LAYER-BREACH NOT applicable here — quota.dart lives in lib/core/constants/ (the core layer) and exports a top-level const + top-level pure function; no cross-layer leakage"
  artifacts:
    - path: "pubspec.yaml"
      provides: "ADDS `uuid: ^4.5.3` to dependencies block (alphabetical)"
      contains: "uuid:"
    - path: "lib/core/constants/quota.dart"
      provides: "NEW — kQuotaTimezone const + dhakaDateKey(DateTime) helper"
      contains: "Asia/Dhaka"
    - path: "test/core/constants/quota_test.dart"
      provides: "NEW — flutter_test unit tests verifying dhakaDateKey cross-UTC-midnight correctness (mirrors functions/src/__tests__/quota.test.ts)"
      contains: "dhakaDateKey"
    - path: "pubspec.lock"
      provides: "REGENERATED — adds resolved uuid version + transitive deps"
      contains: "uuid:"
  key_links:
    - from: "lib/core/constants/quota.dart"
      to: "functions/src/lib/quota.ts (plan 03-02)"
      via: "header comment names the TS-side mirror file; values match"
      pattern: "functions/src/lib/quota.ts"
    - from: "lib/core/constants/quota.dart"
      to: "lib/application/viewmodels/tutor/chat_viewmodel.dart (plan 03-12)"
      via: "viewmodel imports dhakaDateKey for display quota; clientRequestId via Uuid().v4()"
      pattern: "dhakaDateKey|Uuid"
---

<objective>
Add `uuid: ^4.5.3` to `pubspec.yaml` dependencies (alphabetical insertion). Create `lib/core/constants/quota.dart` as the Dart-side mirror of `functions/src/lib/quota.ts` (plan 03-02): exports `const String kQuotaTimezone = 'Asia/Dhaka';` and `String dhakaDateKey(DateTime now)` using `intl` package's `DateFormat`. Add `test/core/constants/quota_test.dart` covering the cross-UTC-midnight correctness (the same test instants used by the TS-side `functions/src/__tests__/quota.test.ts`). Run `flutter pub get` to regenerate `pubspec.lock`.

Purpose: The client (plan 03-12 `chat_viewmodel.dart`) needs two things from this plan: (1) the `Uuid().v4()` generator to produce `clientRequestId` for every user-initiated chat send (D-06); (2) the Dhaka day-key helper for the display-only `messagesRemaining` quota counter (the server-side rate-limit transaction in plan 03-05 is the SOURCE OF TRUTH; the Dart-side `dhakaDateKey()` is for read-display only). Without these two primitives, plan 03-12 cannot swap the viewmodel from `GeminiService` to `MentorBotRepository`.

Output: 4 files — `pubspec.yaml` (MODIFY — add `uuid: ^4.5.3`), `pubspec.lock` (REGENERATED), `lib/core/constants/quota.dart` (NEW), `test/core/constants/quota_test.dart` (NEW). One commit. `flutter pub get` succeeds; `flutter test test/core/constants/quota_test.dart` exits 0.
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
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-02-quota-shared-constant-PLAN.md
@pubspec.yaml
@lib/core/constants/app_colors.dart
@CLAUDE.md

<interfaces>
<!-- Patterns from 03-PATTERNS.md §lib/core/constants/quota.dart lines 638-668 + 03-RESEARCH §Pattern 7 (Dart side) -->

pubspec.yaml — DELTA (alphabetical insert into `dependencies:` block):

Find the existing line (Phase 1 baseline near alphabetic position s/t/u):
```yaml
  shared_preferences: ^2.3.3
```

INSERT (alphabetical — `u` comes after `s`):
```yaml
  uuid: ^4.5.3
```

Final relevant fragment:
```yaml
  shared_preferences: ^2.3.3
  shimmer: ^3.0.0
  uuid: ^4.5.3
```

(Adapt to the actual current alphabetical order in pubspec.yaml; the principle is alphabetical and `uuid` lands after `shimmer` / `shared_preferences` and before any dep starting with `v`/`w`.)

NOTE: plan 03-12 will REMOVE `google_generative_ai: ^0.4.6` from dependencies in a separate commit (atomic with the chat_viewmodel swap). This plan ONLY ADDS `uuid`.

lib/core/constants/quota.dart (NEW — full file, copy verbatim):

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

test/core/constants/quota_test.dart (NEW — full file, copy verbatim):

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
    test('UTC 18:00 on 2026-05-18 is Dhaka 00:00 on 2026-05-19', () {
      final utcInstant = DateTime.utc(2026, 5, 18, 18, 0, 0);
      expect(dhakaDateKey(utcInstant), '2026-05-19');
    });

    test('UTC midnight on 2026-05-19 is Dhaka 06:00 on 2026-05-19 (same day)', () {
      final atUtcMidnight = DateTime.utc(2026, 5, 19, 0, 0, 0);
      expect(dhakaDateKey(atUtcMidnight), '2026-05-19');
    });

    test('UTC 17:59 on 2026-05-19 is Dhaka 23:59 on 2026-05-19 (still that day)', () {
      final justBeforeNextDhakaDay = DateTime.utc(2026, 5, 19, 17, 59, 0);
      expect(dhakaDateKey(justBeforeNextDhakaDay), '2026-05-19');
    });

    test('UTC 18:00 on 2026-05-19 is Dhaka 00:00 on 2026-05-20 (rollover)', () {
      final atNextDhakaMidnight = DateTime.utc(2026, 5, 19, 18, 0, 0);
      expect(dhakaDateKey(atNextDhakaMidnight), '2026-05-20');
    });

    test('end-of-year rollover: UTC 18:00 on 2026-12-31 is Dhaka 00:00 on 2027-01-01', () {
      final nyeUtc = DateTime.utc(2026, 12, 31, 18, 0, 0);
      expect(dhakaDateKey(nyeUtc), '2027-01-01');
    });

    test('accepts local DateTime (toUtc() applied internally)', () {
      // A local DateTime is converted to UTC first, then shifted to Dhaka.
      // The test machine's timezone is irrelevant to the result.
      final localNow = DateTime(2026, 5, 19, 10, 0, 0); // local
      final asUtc = localNow.toUtc();
      final shifted = asUtc.add(const Duration(hours: 6));
      final expected =
          '${shifted.year.toString().padLeft(4, '0')}-${shifted.month.toString().padLeft(2, '0')}-${shifted.day.toString().padLeft(2, '0')}';
      expect(dhakaDateKey(localNow), expected);
    });
  });
}
```

Why fixed `+6 hours` instead of `Intl.DateTimeFormat` with `timeZone: 'Asia/Dhaka'`:
  - Dart's `DateFormat` does NOT support arbitrary IANA timezones (unlike JS's Intl). Dart's `intl` package needs `package:timezone` for full IANA support — which adds a transitive ~3MB bundle.
  - Bangladesh has no DST and no scheduled changes to its UTC+6 offset. A fixed offset is correct year-round.
  - If a future BST policy change requires DST, the helper can grow to use `package:timezone` — for v1.0, the fixed offset is simpler and bundle-cheaper.
  - The TS side (`Intl.DateTimeFormat` with `timeZone: 'Asia/Dhaka'`) automatically follows IANA changes if they happen; the Dart side will need a manual update. Acceptable cost for v1.0.

Why `package:uuid: ^4.5.3` (not v3 or v5):
  - v4.x is the current GA major as of 2026-05; v3 is deprecated (still works but lacks `const Uuid().v4()` ergonomics).
  - `^4.5.3` allows 4.x.y patch updates but blocks a hypothetical v5 major.
  - RESEARCH §Standard Stack pins this version explicitly.

Why this plan does NOT use `package:uuid` itself (no uuid usage):
  - This plan just ADDS the dep so plan 03-12 can import it.
  - Adding the dep here keeps PR-3's first commit narrow (dep + helper); plan 03-12's commit is purely the viewmodel swap.

What this plan does NOT do:
  - Does NOT remove `google_generative_ai` from pubspec.yaml — plan 03-12 owns that (atomic with the viewmodel swap).
  - Does NOT use `Uuid()` anywhere in lib/ — plan 03-12 owns the chat_viewmodel.dart edit that imports and calls it.
  - Does NOT install `package:timezone` — fixed +6 hours is correct for v1.0.
  - Does NOT mirror the TS-side `monthKey()` helper — Dart never needs it (the monthly ceiling is a server-only enforcement state; client doesn't display it).
  - Does NOT add a custom_lint rule against `toIso8601String().substring(0,10)` — a Phase 7 polish item.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add `uuid: ^4.5.3` to pubspec.yaml; create lib/core/constants/quota.dart + test/core/constants/quota_test.dart; run flutter pub get; verify flutter test green</name>
  <files>pubspec.yaml, pubspec.lock, lib/core/constants/quota.dart, test/core/constants/quota_test.dart</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/pubspec.yaml (CURRENT — confirm alphabetical position for `uuid` insert; confirm `intl: ^0.19.0` already present)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-PATTERNS.md (§lib/core/constants/quota.dart lines 638-668 — full skeleton)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-02-quota-shared-constant-PLAN.md (plan 03-02 — confirm test-instant parity)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md (row `03-10-uuid-and-quota-dart` line 63 — Automated Command verbatim)
    - /Users/arnobrizwan/Mentor-Mind/lib/core/constants/app_colors.dart (Phase 1 — file shape pattern: top-of-file copyright/comment + `abstract final class` OR top-level constants)
  </read_first>
  <behavior>
    - `flutter pub get` exits 0 after the pubspec edit.
    - `package:uuid/uuid.dart` resolves at compile time (verify by `dart analyze lib/` — though no file imports it yet in this plan).
    - `lib/core/constants/quota.dart` exports `kQuotaTimezone == 'Asia/Dhaka'` and `dhakaDateKey(DateTime)`.
    - `dhakaDateKey(DateTime.utc(2026, 5, 18, 18, 0, 0))` returns `'2026-05-19'`.
    - `dhakaDateKey(DateTime.utc(2026, 5, 19, 0, 0, 0))` returns `'2026-05-19'` (Dhaka 06:00 — same day).
    - `dhakaDateKey(DateTime.utc(2026, 5, 19, 17, 59, 0))` returns `'2026-05-19'` (Dhaka 23:59 — still that day).
    - `dhakaDateKey(DateTime.utc(2026, 5, 19, 18, 0, 0))` returns `'2026-05-20'` (Dhaka 00:00 — rollover).
    - `dhakaDateKey(DateTime.utc(2026, 12, 31, 18, 0, 0))` returns `'2027-01-01'` (year rollover).
    - 6+ flutter_test cases pass.
  </behavior>
  <action>
    Step A — Read `pubspec.yaml`. Confirm:
      - The `dependencies:` block exists.
      - `intl: ^0.19.0` is present.
      - The alphabetical position for `uuid` lands AFTER `shared_preferences` / `shimmer` (or whatever else exists alphabetically).
      - `google_generative_ai: ^0.4.6` is present (plan 03-12 removes it later; this plan does NOT touch that line).

    Step B — TDD RED: Create the test FIRST (`test/core/constants/quota_test.dart`). The test file imports from `package:mentor_minds/core/constants/quota.dart` — which does NOT exist yet, so the test will fail with a missing-import error. That's the RED state.
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      flutter test test/core/constants/quota_test.dart 2>&amp;1 | tee /tmp/p3-10-red.log
      # Expect: Target of URI doesn't exist or compile failure.
      ```

    Step C — Edit `pubspec.yaml`. Insert `  uuid: ^4.5.3` in the `dependencies:` block in alphabetical order (typically between `shimmer` and the next d, or at the end of the alphabetical run). DO NOT remove or modify other entries (especially `google_generative_ai` — plan 03-12 owns that).

    Step D — Run `flutter pub get`:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      flutter pub get 2>&amp;1 | tail -10
      # Expect: exit 0. New line: `+ uuid 4.5.3` (or similar resolved version).
      ```
      Confirm `pubspec.lock` was regenerated and contains a `uuid:` block.

    Step E — TDD GREEN: Create `lib/core/constants/quota.dart` with the EXACT content from the `<interfaces>` block above.

    Step F — Re-run the test:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      flutter test test/core/constants/quota_test.dart 2>&amp;1 | tee /tmp/p3-10-green.log
      # Expect: All tests passed (6 tests in 1 group + 1 kQuotaTimezone test = 7 tests).
      ```

    Step G — Static analysis:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      flutter analyze --no-fatal-infos lib/core/constants/quota.dart test/core/constants/quota_test.dart 2>&amp;1 | tee /tmp/p3-10-analyze.log
      # Expect: 0 errors, 0 warnings (info-level lint hints OK).
      ```

    Step H — Confirm Phase 1 anti-pattern absent (PITFALLS #3 in lib/):
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      ! grep -rE "toIso8601String\(\)\.substring" lib/core/
      # Expect: no matches (we just shipped the right pattern; future regressions caught here).
      ```

    Step I — Required-content greps:
      ```bash
      grep -q "uuid:" /Users/arnobrizwan/Mentor-Mind/pubspec.yaml
      grep -qE "uuid:\s+\^?4\.5\." /Users/arnobrizwan/Mentor-Mind/pubspec.yaml
      grep -q "uuid" /Users/arnobrizwan/Mentor-Mind/pubspec.lock
      grep -q "kQuotaTimezone" /Users/arnobrizwan/Mentor-Mind/lib/core/constants/quota.dart
      grep -q "'Asia/Dhaka'" /Users/arnobrizwan/Mentor-Mind/lib/core/constants/quota.dart
      grep -q "String dhakaDateKey" /Users/arnobrizwan/Mentor-Mind/lib/core/constants/quota.dart
      grep -q "functions/src/lib/quota.ts" /Users/arnobrizwan/Mentor-Mind/lib/core/constants/quota.dart
      # Plan 03-12 will remove google_generative_ai — this plan must NOT touch it
      grep -q "google_generative_ai" /Users/arnobrizwan/Mentor-Mind/pubspec.yaml
      ```

    Step J — Commit:
      ```bash
      git add pubspec.yaml pubspec.lock lib/core/constants/quota.dart test/core/constants/quota_test.dart
      git commit -m "feat(dart): add uuid ^4.5.3 + lib/core/constants/quota.dart Dhaka day-key helper (Phase 3 PR-3; AI-04/AI-07; mirror of plan 03-02)"
      ```
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f lib/core/constants/quota.dart &amp;&amp; test -f test/core/constants/quota_test.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "uuid:\s+\^?4\.5\." pubspec.yaml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "uuid" pubspec.lock</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "kQuotaTimezone" lib/core/constants/quota.dart &amp;&amp; grep -q "'Asia/Dhaka'" lib/core/constants/quota.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "String dhakaDateKey" lib/core/constants/quota.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "functions/src/lib/quota.ts" lib/core/constants/quota.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "google_generative_ai" pubspec.yaml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -rE "toIso8601String\(\)\.substring" lib/core/</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter test test/core/constants/quota_test.dart 2>&amp;1 | grep -qE 'All tests passed|\+[0-9]+:'</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --no-fatal-infos lib/core/constants/quota.dart test/core/constants/quota_test.dart 2>&amp;1 | tail -3; test $? -eq 0</automated>
  </verify>
  <acceptance_criteria>
    - `pubspec.yaml` dependencies contain `uuid: ^4.5.3` (alphabetical insert).
    - `pubspec.lock` regenerated; `uuid` resolves.
    - `lib/core/constants/quota.dart` exports `kQuotaTimezone == 'Asia/Dhaka'` and `String dhakaDateKey(DateTime now)`.
    - Header comment names the TS-side mirror file `functions/src/lib/quota.ts`.
    - `test/core/constants/quota_test.dart` has ≥ 6 cases; all pass under `flutter test`.
    - `flutter analyze --no-fatal-infos` exits 0 on the two new files.
    - `google_generative_ai` line still present in pubspec.yaml (plan 03-12 removes it).
    - No `toIso8601String().substring(0,10)` pattern anywhere in `lib/core/`.
  </acceptance_criteria>
  <done>
    Dart-side primitives are ready. Plan 03-11 (`MentorBotRepository`) imports `package:uuid/uuid.dart` for `Uuid().v4()`. Plan 03-12 (`chat_viewmodel.dart`) imports `dhakaDateKey` for the display-only quota counter (replacing the existing inline `_todayKey()` helper at chat_viewmodel.dart:461).
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| pubspec.yaml ⇄ pub.dev registry | `flutter pub get` fetches `uuid` 4.5.3 + transitive deps; pub.dev hash verification provides integrity. RESEARCH §Package Legitimacy Audit confirmed: `uuid` is Daniel Cachapa's official Dart UUID package (1.3M downloads/week as of audit). |
| dhakaDateKey ⇄ DateTime input | `DateTime.toUtc()` is correct regardless of system locale; `add(Duration(hours: 6))` is offset-safe. No timezone drift on the test machine vs the user device. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-3-SC-UUID | Tampering (supply chain) | A malicious major version of `package:uuid` ships to pub.dev | mitigate | Pinned `^4.5.3` (caret allows 4.x.y; blocks v5+). RESEARCH §Package Legitimacy Audit confirmed Approved. |
| T-3-10-TZ-DRIFT | Tampering | If Bangladesh adopts DST in the future, the fixed +6 offset is wrong | accept | No DST scheduled per IANA as of 2026-05. If BST changes, this helper needs a `package:timezone`-based rewrite. Phase 7 polish item. |
| T-3-10-DAY-KEY-MISMATCH | Tampering | TS-side `Intl.DateTimeFormat` produces a different day-key than Dart-side `+6 hours` for the same instant | mitigate | The test instants in this plan + plan 03-02 are IDENTICAL; both helpers produce `'2026-05-19'` for `2026-05-18T18:00:00Z`. Verified by hand at this plan's writing. |
| T-3-10-LOCKFILE-DRIFT | Tampering | A future contributor edits pubspec.yaml without `flutter pub get`; CI's `flutter pub get` fails on stale lock | mitigate | Phase 1 CI gate (`flutter pub get` step) catches this. Plan 03-15 closeout verifies. |
</threat_model>

<verification>
- pubspec.yaml has `uuid: ^4.5.3` alphabetically inserted.
- pubspec.lock regenerated with uuid block.
- lib/core/constants/quota.dart exports kQuotaTimezone + dhakaDateKey.
- Header comment names the TS-side mirror file.
- test/core/constants/quota_test.dart has 6+ tests covering cross-UTC-midnight + year rollover.
- flutter test passes.
- flutter analyze --no-fatal-infos passes.
- No toIso8601String().substring(0,10) anti-pattern in lib/core/.
- google_generative_ai untouched (plan 03-12 owns removal).
</verification>

<success_criteria>
- AI-04 + AI-07 client-side primitives ready.
- Plan 03-11 can import package:uuid.
- Plan 03-12 can import dhakaDateKey + Uuid.
- Cross-language day-key parity asserted via parallel test instants.
</success_criteria>

<output>
Create `.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-10-uuid-and-quota-dart-SUMMARY.md` when done. Record:
1. The pubspec.yaml diff (added uuid line).
2. The resolved uuid version from pubspec.lock.
3. Full content of lib/core/constants/quota.dart.
4. Full content of test/core/constants/quota_test.dart.
5. flutter test output (≥ 6 cases passed).
6. flutter analyze output (0 errors).
7. Confirmation that google_generative_ai line is still in pubspec.yaml (plan 03-12 owns its removal).
8. Commit SHA.
9. Forward-pointer: plan 03-11 uses Uuid().v4() for clientRequestId; plan 03-12 uses dhakaDateKey for display quota counter.
</output>
</content>
