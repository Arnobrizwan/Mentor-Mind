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
