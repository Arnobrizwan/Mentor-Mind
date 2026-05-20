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
